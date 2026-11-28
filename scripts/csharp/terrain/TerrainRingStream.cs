using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace PredatorIsle.Terrain;

/// <summary>
/// Numerical ring streaming. The host supplies the shared terrain/cave worker allowance and
/// publishes a complete hidden GPU/collision cut only after its own safety checks succeed.
/// </summary>
public sealed class TerrainRingStream : IDisposable
{
    private const int PriorityLayerCount=5;
    private const int FlightBackdropResolution=12;
    private readonly record struct Key(TerrainRingLayout.Patch Patch,int Resolution,long SourceRevision);
    private sealed class BuildProgress
    {
        public string Stage="queued";
        public readonly Dictionary<string,double> Milliseconds=new();
        private ulong start;
        private long allocationStart;
        public long AllocatedBytes;
        public long CanonicalEvaluations;
        public long GpuSampleHits;
        public int GpuSamples;
        public bool GpuRejected;
        public double GpuPreparationMilliseconds;
        public double GpuMaximumHeightError;
        public void Mark(string next){ulong now=Time.GetTicksUsec();if(start!=0)Milliseconds[Stage]=Milliseconds.GetValueOrDefault(Stage)+(now-start)/1000.0;else allocationStart=GC.GetAllocatedBytesForCurrentThread();start=now;Volatile.Write(ref Stage,next);}
        public void Finish(){Mark("complete");AllocatedBytes=GC.GetAllocatedBytesForCurrentThread()-allocationStart;}
    }
    private readonly Dictionary<string,double> stageMilliseconds=new();
    private long allocatedWorkerBytes,completedJobs,gpuSamples,gpuSampleHits,gpuRejected;
    private double gpuPreparationMilliseconds,gpuMaximumHeightError;
    public Godot.Collections.Dictionary Profile {get{var stages=new Godot.Collections.Dictionary();foreach(var pair in stageMilliseconds)stages[pair.Key]=pair.Value;return new Godot.Collections.Dictionary{["worker_stage_ms"]=stages,["managed_worker_allocated_bytes"]=allocatedWorkerBytes,["completed_jobs"]=completedJobs,["cancelled_jobs"]=CancelledJobs,["gpu_generated_samples"]=gpuSamples,["gpu_sample_cache_hits"]=gpuSampleHits,["gpu_rejected_batches"]=gpuRejected,["gpu_preparation_ms"]=gpuPreparationMilliseconds,["gpu_maximum_checked_height_error"]=gpuMaximumHeightError};}}
    private sealed record Job(Key Key,TerrainMeshBuilder Builder,CancellationTokenSource Cancellation,Task<TerrainRingMeshGeometry.Data> Task,ulong Started,BuildProgress Progress);
    private sealed record Cached(TerrainRingMeshGeometry.Data Data,long Bytes,LinkedListNode<Key> Order);
    private readonly TerrainRingMeshGeometry geometry;
    internal TerrainGpuPreparation? GpuPreparation{get;set;}
    private readonly TerrainRingTransitions.Cache transitionCache=new();
    private TerrainSharedSamples sharedSamples=new();
    public bool ShareSamples {get;set;}=true;
    public bool GpuGrids{get;set;}
    public bool GenerateShapeRefinement
    {
        get=>geometry.GenerateShapeRefinement;
        set=>geometry.GenerateShapeRefinement=value;
    }
    public long SharedSampleHits=>sharedSamples.Hits;
    public long SharedSampleMisses=>sharedSamples.Misses;
    private long canonicalEvaluations;
    public long CanonicalEvaluations=>canonicalEvaluations;
    private readonly Dictionary<Key,Job> jobs=new();
    private readonly Dictionary<Key,TerrainRingMeshGeometry.Data> ready=new();
    private readonly Dictionary<Key,Cached> cache=new();
    private readonly LinkedList<Key> lru=new();
    private readonly Queue<(long Revision,TerrainMeshBuilder Builder)> idle=new();
    private readonly HashSet<Key> wanted=new();
    private readonly HashSet<Key> prefetch=new();
    private readonly HashSet<Key> prefetched=new();
    public int PrefetchPatches=>prefetch.Count;
    public long PrefetchCompletions{get;private set;}
    public long PrefetchHits{get;private set;}
    public double NearBuildSeconds{get;private set;}=.15;
    private readonly List<Key> pending=new();
    private TerrainRingLayout.Plan? requested,committed;
    private long generation,revision,cacheBytes;
    private long preparedGeneration=-1;
    private TerrainRingTransitions.Result? preparedCut;
    private sealed record Prepared(long Generation,TerrainRingLayout.Plan Plan,TerrainRingTransitions.Result? Cut,bool Complete,TerrainRingMeshGeometry.Data[] Source);
    private Task<Prepared>? preparation;
    private TerrainRingMeshGeometry.Data[] committedSources=Array.Empty<TerrainRingMeshGeometry.Data>(),preparedSources=Array.Empty<TerrainRingMeshGeometry.Data>();
    private long committedSourceRevision=-1;
    private int lastLocalAttempt=-1;
    public long LocalPublications{get;private set;}
    public bool AllowLocalPublication{get;set;}=true;
    public bool IsNearbyPublished
    {
        get
        {
            if(requested is null||committed is null||committedSourceRevision!=revision)return false;
            int x=(int)Math.Floor(requested.Camera.X/requested.BaseSize),z=(int)Math.Floor(requested.Camera.Y/requested.BaseSize);
            for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++)if(!committed.Patches.Contains(new TerrainRingLayout.Patch(new Godot.Vector3I(x+dx,z+dz,0),requested.BaseSize,TerrainRingLayout.Mask.None)))return false;
            return true;
        }
    }
    private TerrainRingLayout.Plan? preparedPlan;
    private bool preparedComplete,completeEver;
    private int publishedCount;
    private CancellationTokenSource? preparationCancellation;
    private long preparationGeneration=-1;
    private int resolution;
    private bool disposed;
    public long CacheBudgetBytes{get;set;}=128L*1024*1024;
    public int MaximumWorkers{get;set;}=4;
    public string LastError{get;private set;}="";
    public long CacheHits{get;private set;}
    public long CacheMisses{get;private set;}
    public long CancelledJobs{get;private set;}
    public string LastRetiredWorkerError{get;private set;}="";
    internal TerrainRingMeshGeometry.Data? ReadyFine(Vector2I cell)
    {
        return ReadyFlight(new Vector3I(cell.X,cell.Y,0));
    }
    internal TerrainRingMeshGeometry.Data? ReadyFlight(Vector3I tile)
    {
        if(requested is null)return null;
        var patch=new TerrainRingLayout.Patch(tile,requested.BaseSize*Math.Pow(3,tile.Z),default);
        var key=new Key(patch,resolution,revision);
        var data=ready.GetValueOrDefault(key)??flightReady.GetValueOrDefault(key)??cache.GetValueOrDefault(key)?.Data;
        if(data is not null || tile.Z!=2)return data;
        var preview=key with{Resolution=FlightBackdropResolution};
        return flightReady.GetValueOrDefault(preview)??cache.GetValueOrDefault(preview)?.Data;
    }
    private readonly List<Key> flightQueue=new();
    private readonly Dictionary<Key,TerrainRingMeshGeometry.Data> flightReady=new();
    private (Vector2I Cell,long Revision,int Resolution)? flightWindow;
    private bool sprinting;
    internal Vector2I FlightFocus { get; private set; }
    internal void FollowCamera(Vector2 position,bool enabled,Vector2 velocity=default)
    {
        sprinting=enabled && velocity.LengthSquared()>60*60;
        if(!enabled || requested is null)
        {
            flightWindow=null;flightReady.Clear();flightQueue.Clear();return;
        }
        var size=(float)requested.BaseSize;
        var cell=(Vector2I)(position/size).Floor();
        FlightFocus=(Vector2I)((position+(velocity*.55f).LimitLength(size*2))/size).Floor();
        var window=(cell,revision,resolution);
        if(flightWindow==window)return;
        flightWindow=window;
        flightQueue.Clear();
        var velocityLead=(velocity*.7f).LimitLength(size*2.5f);
        var lead = position + velocityLead;
        var nearby = new HashSet<Vector2I>();
        for(int z=-1;z<=1;z++)
        for(int x=-1;x<=1;x++)nearby.Add(cell+new Vector2I(x,z));
        if(sprinting)
        {
            for(int step=1;step<=3;step++)
                nearby.Add((Vector2I)((position+velocityLead*(step/3f))/size).Floor());
        }
        foreach(var nextCell in nearby.OrderBy(p=>((Vector2)p*size+Vector2.One*size*.5f).DistanceSquaredTo(lead)))
        {
            var patch=new TerrainRingLayout.Patch(new Vector3I(nextCell.X,nextCell.Y,0),size,default);
            flightQueue.Add(new Key(patch,resolution,revision));
        }
        for(int radius=0;radius<=1;radius++)
        for(int level=1;level<=Math.Min(2,requested.OuterRings);level++)
        {
            double span=size*Math.Pow(3,level);
            var middle=(Vector2I)(position/(float)span).Floor();
            for(int z=-radius;z<=radius;z++)
            for(int x=-radius;x<=radius;x++)
            {
                if(Math.Max(Math.Abs(x),Math.Abs(z))!=radius)continue;
                var patch=new TerrainRingLayout.Patch(new Vector3I(middle.X+x,middle.Y+z,level),span,default);
                flightQueue.Add(new Key(patch,resolution,revision));
            }
        }
        // One cheap coarse tile covers the next stretch when sprinting
        // outside the terrain already published around the camera.
        if(velocity.LengthSquared()>25*25 && resolution>FlightBackdropResolution)
        {
            double span=size*9;
            var ahead=(Vector2I)((position+(velocity*.65f).LimitLength(size*2))/(float)span).Floor();
            var patch=new TerrainRingLayout.Patch(new Vector3I(ahead.X,ahead.Y,2),span,default);
            double centerX=patch.OriginX+span*.5,centerZ=patch.OriginZ+span*.5;
            if(committed?.Owner(centerX,centerZ) is null)
                flightQueue.Add(new Key(patch,FlightBackdropResolution,revision));
        }
        foreach(var key in flightReady.Keys.ToArray())if(!flightQueue.Contains(key))flightReady.Remove(key);
        if(flightQueue.Any(key=>!FlightFinished(key)&&!jobs.ContainsKey(key)) && jobs.Count>0 &&
            jobs.Values.All(job=>!flightQueue.Contains(job.Key)&&!job.Cancellation.IsCancellationRequested))
        {
            var farthest=jobs.Values.Where(job=>!ReusableJob(job.Key)).MaxBy(job=>DistanceTo(job.Key.Patch,position));
            if(farthest is not null){farthest.Cancellation.Cancel();CancelledJobs++;}
        }
    }
    private static bool SameLattice(Key a,Key b)=>a.Patch.Key==b.Patch.Key && a.Patch.Size==b.Patch.Size &&
        a.Resolution==b.Resolution && a.SourceRevision==b.SourceRevision;
    private bool ReusableJob(Key key)=>key.Patch.Key.Z is 1 or 2 && wanted.Any(candidate=>SameLattice(candidate,key));
    private bool FlightFinished(Key key)=>flightReady.ContainsKey(key)||ready.ContainsKey(key)||cache.ContainsKey(key);
    private int nextPriorityLevel;
    private bool NextBuild(out Key key)
    {
        bool stationaryStartup = !completeEver && requested is not null &&
            (flightWindow is null || flightWindow.Value.Cell == (Vector2I)(requested.Camera/(float)requested.BaseSize).Floor());
        if (stationaryStartup)
        {
            // Reserve one worker for the handoff to layers four and five.
            // Their first full-resolution patches can build alongside layer three.
            if (AllowLocalPublication && CentralReady() && !jobs.Keys.Any(k=>k.Patch.Key.Z is 3 or 4))
            {
                for (int level=3;level<=4;level++)
                {
                    if (ready.Keys.Any(k=>k.Patch.Key.Z==level)) continue;
                    int index=pending.FindIndex(k=>wanted.Contains(k) && k.Patch.Key.Z==level && !jobs.ContainsKey(k));
                    if(index<0)continue;
                    key=pending[index];
                    pending.RemoveAt(index);
                    return true;
                }
            }
            // Dispatch nearest layers first, but start the next layer whenever a
            // worker is free. Visibility is ordered by the publication code.
            return TryDequeueAvailable(pending,
                candidate=>wanted.Contains(candidate)&&!ready.ContainsKey(candidate),
                candidate=>jobs.ContainsKey(candidate),out key);
        }
        // Keep one worker on the next fine tile during fast travel; farther
        // rings can use the other workers without exhausting all near capacity.
        if (sprinting && flightQueue.Count>0 && !jobs.Keys.Any(k=>k.Patch.Key.Z==0 && flightQueue.Contains(k)))
        {
            foreach(var nextFine in flightQueue)
            {
                if(nextFine.Patch.Key.Z!=0)break;
                if(FlightFinished(nextFine) || jobs.ContainsKey(nextFine))continue;
                var cell=new Vector2I(nextFine.Patch.Key.X,nextFine.Patch.Key.Y);
                if(cell!=FlightFocus && cell!=flightWindow?.Cell)continue;
                key=nextFine;
                return true;
            }
        }
        if (EntranceSupport is {} supports)
        {
            int index = pending.FindIndex(k => wanted.Contains(k) && !ready.ContainsKey(k) && !jobs.ContainsKey(k) && supports(k.Patch));
            if (index >= 0)
            {
                key = pending[index];
                pending.RemoveAt(index);
                return true;
            }
        }
        foreach(var preview in flightQueue)
        {
            if(preview.Resolution==resolution || FlightFinished(preview) || jobs.ContainsKey(preview))continue;
            key=preview;
            return true;
        }
        // Give every near ring a turn even while preview tiles are streaming.
        for (int turn = 0; turn < PriorityLayerCount; turn++)
        {
            int level = nextPriorityLevel;
            nextPriorityLevel = (level + 1) % PriorityLayerCount;
            foreach (var candidate in flightQueue)
            {
                if (candidate.Patch.Key.Z != level || FlightFinished(candidate) || jobs.ContainsKey(candidate)) continue;
                key = candidate;
                return true;
            }
            int index = pending.FindIndex(candidate => candidate.Patch.Key.Z == level &&
                wanted.Contains(candidate) && !ready.ContainsKey(candidate) && !jobs.ContainsKey(candidate) &&
                !(level is 1 or 2 && jobs.Keys.Any(job => SameLattice(job, candidate))));
            if (index < 0) continue;
            key = pending[index];
            pending.RemoveAt(index);
            return true;
        }
        return TryDequeueAvailable(pending,candidate=>(wanted.Contains(candidate)||prefetch.Contains(candidate))&&!ready.ContainsKey(candidate),
            candidate=>jobs.ContainsKey(candidate) || (candidate.Patch.Key.Z is 1 or 2 && jobs.Keys.Any(k=>SameLattice(k,candidate))),out key);
    }
    public bool PublicationInProgress => preparation is not null || preparedCut is not null;
    public int RunningJobs=>jobs.Count+(preparation is not null?1:0);
    public int PendingPatches=>pending.Count(key=>wanted.Contains(key));
    public int ReadyPatches=>ready.Count;
    public Godot.Collections.Array JobStages{get{var result=new Godot.Collections.Array();foreach(var job in jobs.Values)result.Add(new Godot.Collections.Dictionary{["level"]=job.Key.Patch.Key.Z,["seconds"]=(Time.GetTicksUsec()-job.Started)/1000000.0,["stage"]=Volatile.Read(ref job.Progress.Stage)});return result;}}
    public long ResidentCacheBytes=>cacheBytes;
    public long Generation=>generation;
    public TerrainRingLayout.Plan? Requested=>requested;
    public TerrainRingLayout.Plan? Committed=>committed;
    public bool IsCoverageComplete=>requested is not null&&ReferenceEquals(requested,committed);
    public bool HasCompletedCoverage=>completeEver;
    public TerrainRingStream(TerrainRingTopology topology,bool filterDistant=true){geometry=new TerrainRingMeshGeometry(topology,filterDistant);}
    public bool Request(TerrainRingLayout.Plan plan,int subdivisions,long sourceRevision)
    {
        ObjectDisposedException.ThrowIf(disposed,this);if(subdivisions<1||subdivisions>256)throw new ArgumentOutOfRangeException(nameof(subdivisions));
        if(requested is not null&&sourceRevision==revision&&subdivisions==resolution&&requested.BaseSize==plan.BaseSize&&requested.Patches.SequenceEqual(plan.Patches))return false;
        bool newSource=sourceRevision!=revision;if(newSource)prefetch.Clear();requested=plan;revision=sourceRevision;resolution=subdivisions;generation++;preparationCancellation?.Cancel();preparedGeneration=-1;preparedCut=null;preparedPlan=null;publishedCount=0;LastError="";wanted.Clear();pending.Clear();foreach(var patch in plan.Patches)wanted.Add(new Key(patch,subdivisions,sourceRevision));
        lastLocalAttempt=-1;preparedSources=Array.Empty<TerrainRingMeshGeometry.Data>();
        foreach(var job in jobs.Values)if(!wanted.Contains(job.Key)&&!prefetch.Contains(job.Key)&&!flightQueue.Contains(job.Key)&&!ReusableJob(job.Key)&&!job.Cancellation.IsCancellationRequested){job.Cancellation.Cancel();CancelledJobs++;}
        foreach(var key in ready.Keys.ToArray())if(!wanted.Contains(key))ready.Remove(key);
        if(newSource){sharedSamples=new();foreach(var item in idle)item.Builder.Dispose();idle.Clear();foreach(var key in cache.Keys.Where(k=>k.SourceRevision!=sourceRevision).ToArray())RemoveCache(key);}
        sharedSamples.Protect(plan.Camera.X,plan.Camera.Y,plan.BaseSize*2+2);
        foreach(var key in wanted)
        {
            if(ready.ContainsKey(key)||jobs.TryGetValue(key,out var job)&&!job.Cancellation.IsCancellationRequested)continue;
            if(cache.TryGetValue(key,out var entry)){ready[key]=entry.Data;Touch(entry);CacheHits++;if(prefetched.Remove(key))PrefetchHits++;}else{pending.Add(key);CacheMisses++;}
        }
        SortPending();
        if (AllowLocalPublication && committed is not null && pending.Count > 0)
        {
            int nextTier = PriorityTier(pending[0].Patch, plan, committed);
            foreach (var job in jobs.Values)
            {
                if (job.Cancellation.IsCancellationRequested || flightQueue.Contains(job.Key) || ReusableJob(job.Key) ||
                    (wanted.Contains(job.Key) && PriorityTier(job.Key.Patch, plan, committed) <= nextTier))
                    continue;
                job.Cancellation.Cancel();
                CancelledJobs++;
            }
        }
        Trim();
        return true;
    }

    private void SortPending()
    {
        if (requested is not { } plan) return;
        var tiers = pending.Distinct().ToDictionary(key => key, Tier);
        pending.Sort((a, b) =>
        {
            int tier = tiers[a].CompareTo(tiers[b]);
            if (tier != 0) return tier;
            if((!completeEver || tiers[a]==0) && a.Patch.Key.Z!=b.Patch.Key.Z)return a.Patch.Key.Z.CompareTo(b.Patch.Key.Z);
            int distance = Distance(a.Patch, plan).CompareTo(Distance(b.Patch, plan));
            if (distance != 0) return distance;
            int level = a.Patch.Key.Z.CompareTo(b.Patch.Key.Z);
            if (level != 0) return level;
            int row = a.Patch.Key.Y.CompareTo(b.Patch.Key.Y);
            return row != 0 ? row : a.Patch.Key.X.CompareTo(b.Patch.Key.X);
        });

        int Tier(Key key) => wanted.Contains(key) ? PriorityTier(key.Patch, plan, committed) : 3;
    }

    internal static int PriorityTier(TerrainRingLayout.Patch patch, TerrainRingLayout.Plan desired,
        TerrainRingLayout.Plan? published)
    {
        if (patch.Key.Z < PriorityLayerCount) return 0;
        if (published is null) return 1;
        foreach (var local in patch.OwnedRegions())
        {
            var region = new Rect2(local.Position + new Vector2((float)patch.OriginX, (float)patch.OriginZ), local.Size);
            double uncovered = (double)region.Size.X * region.Size.Y;
            foreach (var owner in published.Patches)
            {
                if (owner.OriginX >= region.End.X || owner.OriginX + owner.Size <= region.Position.X ||
                    owner.OriginZ >= region.End.Y || owner.OriginZ + owner.Size <= region.Position.Y)
                    continue;
                foreach (var owned in owner.OwnedRegions())
                {
                    var intersection = region.Intersection(new Rect2(
                        owned.Position + new Vector2((float)owner.OriginX, (float)owner.OriginZ), owned.Size));
                    uncovered -= (double)intersection.Size.X * intersection.Size.Y;
                }
                if (uncovered <= .01) break;
            }
            if (uncovered > .01) return 1;
        }
        return 2;
    }

    private static double Distance(TerrainRingLayout.Patch patch, TerrainRingLayout.Plan plan)
    {
        return plan.CollisionInterests.Length == 0
            ? DistanceTo(patch, plan.Camera)
            : plan.CollisionInterests.Min(point => DistanceTo(patch, point));
    }

    private static double DistanceTo(TerrainRingLayout.Patch patch, Vector2 focus)
    {
        double nearest = double.PositiveInfinity;
        foreach (var region in patch.OwnedRegions())
        {
            double dx = Math.Max(0, Math.Max(patch.OriginX + region.Position.X - focus.X, focus.X - patch.OriginX - region.End.X));
            double dz = Math.Max(0, Math.Max(patch.OriginZ + region.Position.Y - focus.Y, focus.Y - patch.OriginZ - region.End.Y));
            nearest = Math.Min(nearest, dx * dx + dz * dz);
        }
        return nearest;
    }

    /// <summary>Bounded incoming rows; speculative work uses only spare terrain slots after current requests.</summary>
    public void Prefetch(Vector2 focus,Vector2 velocity)
    {
        if(!completeEver||requested is null||CacheBudgetBytes<=0)return;
        var candidates=TerrainPrefetch.Select(focus,velocity,NearBuildSeconds,requested.BaseSize);
        prefetch.Clear();foreach(var patch in candidates){var key=new Key(patch,resolution,revision);if(!wanted.Contains(key))prefetch.Add(key);}
        pending.RemoveAll(key=>!wanted.Contains(key));
        foreach(var job in jobs.Values)if(!wanted.Contains(job.Key)&&!prefetch.Contains(job.Key)&&!flightQueue.Contains(job.Key)&&!ReusableJob(job.Key)&&!job.Cancellation.IsCancellationRequested){job.Cancellation.Cancel();CancelledJobs++;}
        foreach(var key in prefetch)if(!cache.ContainsKey(key)&&!jobs.ContainsKey(key))pending.Add(key);
    }
    // An in-flight cancelled job may still own a key. Examine the bounded queue
    // rather than blocking runnable work behind that key.
    internal static bool TryDequeueAvailable<T>(List<T> queue,Func<T,bool> eligible,Func<T,bool> busy,out T item)
    {
        for(int index=0;index<queue.Count;)
        {
            T candidate=queue[index];
            if(!eligible(candidate)){queue.RemoveAt(index);continue;}
            if(busy(candidate)){index++;continue;}
            queue.RemoveAt(index);
            item=candidate;
            return true;
        }
        item=default!;return false;
    }
    public void Tick(int availableSharedWorkers,Func<TerrainMeshBuilder> createBuilder)
    {
        ObjectDisposedException.ThrowIf(disposed,this);
        TerrainWorkerScripts.Prepare();
        foreach(var job in jobs.Values.ToArray())
        {
            if(!job.Task.IsCompleted)continue;jobs.Remove(job.Key);
            try{var data=job.Task.GetAwaiter().GetResult();completedJobs++;if(job.Key.Patch.Key.Z==0)NearBuildSeconds=NearBuildSeconds*.8+Math.Clamp((Time.GetTicksUsec()-job.Started)/1000000.0,.001,2)*.2;canonicalEvaluations+=job.Progress.CanonicalEvaluations;allocatedWorkerBytes+=job.Progress.AllocatedBytes;gpuSamples+=job.Progress.GpuSamples;gpuSampleHits+=job.Progress.GpuSampleHits;if(job.Progress.GpuRejected)gpuRejected++;gpuPreparationMilliseconds+=job.Progress.GpuPreparationMilliseconds;gpuMaximumHeightError=Math.Max(gpuMaximumHeightError,job.Progress.GpuMaximumHeightError);foreach(var pair in job.Progress.Milliseconds)stageMilliseconds[pair.Key]=stageMilliseconds.GetValueOrDefault(pair.Key)+pair.Value;if(job.Key.SourceRevision==revision){Store(job.Key,data);if(flightQueue.Contains(job.Key))flightReady[job.Key]=data;if(wanted.Contains(job.Key))ready[job.Key]=data;else {PrefetchCompletions++;if(cache.ContainsKey(job.Key))prefetched.Add(job.Key);}}}
            catch(OperationCanceledException){if(wanted.Contains(job.Key)&&!pending.Contains(job.Key)){pending.Add(job.Key);SortPending();}}
            catch(Exception error){if(wanted.Contains(job.Key))LastError=error.ToString();else LastRetiredWorkerError=error.ToString();}
            finally{job.Cancellation.Dispose();if(job.Key.SourceRevision==revision&&idle.Count<Math.Max(Math.Max(availableSharedWorkers,MaximumWorkers),1))idle.Enqueue((revision,job.Builder));else job.Builder.Dispose();}
        }
        if(preparation is not null&&preparation.IsCompleted)
        {
            try{var result=preparation.GetAwaiter().GetResult();if(result.Generation==generation&&result.Cut is not null){preparedCut=result.Cut;preparedGeneration=result.Generation;preparedPlan=result.Plan;preparedComplete=result.Complete;preparedSources=result.Source;}}
            catch(OperationCanceledException){}
            catch(Exception error){if(preparationGeneration==generation)LastError=error.ToString();else LastRetiredWorkerError=error.ToString();}
            finally{preparation=null;preparationCancellation?.Dispose();preparationCancellation=null;preparationGeneration=-1;}
        }
        Trim();if(LastError.Length>0)return;int allowance=Math.Max(0,Math.Min(MaximumWorkers,availableSharedWorkers));
        TryStartPreparation(allowance);
        // Retuning the background budget must not serialize live near terrain behind stitching.
        while(jobs.Count<availableSharedWorkers &&
              (jobs.Count<allowance || flightQueue.Any(k=>!FlightFinished(k)&&!jobs.ContainsKey(k)) ||
               pending.Any(k=>k.Patch.Key.Z<PriorityLayerCount&&wanted.Contains(k)&&!jobs.ContainsKey(k))) && NextBuild(out var key))
        {
            TerrainMeshBuilder builder;try{builder=idle.Count>0?idle.Dequeue().Builder:createBuilder();}catch(Exception error){LastError=error.ToString();pending.Insert(0,key);return;}
            var cancellation=new CancellationTokenSource();var token=cancellation.Token;
            var progress=new BuildProgress();TerrainSharedSamples? samples=ShareSamples?sharedSamples:null;ulong started=Time.GetTicksUsec();var sameTile=key.Patch.Key.Z is 1 or 2
                ? cache.FirstOrDefault(pair=>SameLattice(pair.Key,key)).Value?.Data : null;
            bool prepareFlightWater=key.Patch.Key.Z<=2 && key.Patch.Hole.Empty;
            bool backdrop=key.Resolution!=resolution;
            var gpuPreparation=sameTile is null&&!backdrop?GpuPreparation:null;
            try
            {
                var task=Task.Run(async ()=>
                {
                    long evaluations=builder._native_height.CanonicalEvaluations,hits=builder._native_grass.GpuSampleHits;
                    using var attempt=gpuPreparation?.Begin(builder,key.Patch,key.Resolution,key.SourceRevision);
                    TerrainBiomeNoiseCache? biomeNoise=null;
                    if(gpuPreparation is not null&&attempt is {UseGpu:true})
                    {
                        Volatile.Write(ref progress.Stage,"GPU heightmap");ulong gpuStart=Time.GetTicksUsec();
                        var result=await gpuPreparation.PrepareAsync(builder,key.Patch,key.Resolution,token).ConfigureAwait(false);
                        biomeNoise=await gpuPreparation.PrepareBiomeNoiseAsync(builder,key.Patch,key.Resolution,token).ConfigureAwait(false);
                        progress.GpuPreparationMilliseconds=(Time.GetTicksUsec()-gpuStart)/1000.0;
                        progress.GpuSamples=result.Samples;progress.GpuRejected=result.Rejected;progress.GpuMaximumHeightError=result.MaximumHeightError;
                        if(result.Samples>0||biomeNoise is {Count:>0})geometry.InvalidateHeightFilter(builder);
                    }
                    token.ThrowIfCancellationRequested();
                    // Allocation measurement begins after the await, on the same thread
                    // that performs the numerical build; thread-local counters cannot span awaits.
                    using var biomeScope=biomeNoise?.Activate();
                    var data=geometry.Build(builder,key.Patch,key.Resolution,()=>token.IsCancellationRequested,progress.Mark,samples,sameTile,surfaceOnly:backdrop);
                    if(prepareFlightWater)
                    {
                        var water=TerrainRingWater.Build(data,data.WaterLevel,data.BeachesEnabled,data.WaterEnabled);
                        data=data with{LocalWater=water,AdditionalBytes=data.AdditionalBytes+TerrainPayloadMemory.Estimate(water)};
                    }
                    progress.CanonicalEvaluations=builder._native_height.CanonicalEvaluations-evaluations;
                    progress.GpuSampleHits=builder._native_grass.GpuSampleHits-hits;progress.Finish();attempt?.Complete();return data;
                },token);
                jobs[key]=new Job(key,builder,cancellation,task,started,progress);
            }
            catch(Exception error){builder.Dispose();cancellation.Dispose();LastError=error.ToString();pending.Insert(0,key);return;}
        }
        TryStartPreparation(allowance);
    }

    internal Func<TerrainRingLayout.Patch,bool>? EntranceSupport { get; set; }
    private void TryStartPreparation(int allowance)
    {
        if(preparation is not null||preparedCut is not null||requested is null||ReferenceEquals(requested,committed)||allowance<=0)return;
        bool complete=wanted.All(key=>ready.ContainsKey(key)),startup=!completeEver&&(committed is null||(committedSourceRevision==revision && committed.Patches.All(p=>wanted.Contains(new Key(p,resolution,revision))))||!AllowLocalPublication||committedSourceRevision!=revision||requested.BaseSize!=committed.BaseSize);int available=wanted.Count(key=>ready.ContainsKey(key));
        // A finished numerical queue can still contain dozens of unshown meshes.
        // Present nearby closures first even if the last worker has already finished.
        if (complete && AllowLocalPublication && committed is not null && committedSourceRevision==revision &&
            committed.BaseSize==requested.BaseSize && requested.Patches.Except(committed.Patches).Skip(1).Any() &&
            lastLocalAttempt!=available)
            complete=false;
        bool local=AllowLocalPublication&&!complete&&!startup&&committed is not null&&committedSourceRevision==revision&&requested.BaseSize==committed.BaseSize;
        if(!complete&&!local&&(!startup||available<=publishedCount||!CentralReady()))return;
        // Let a ready nearby grid reach publication even when distant jobs occupy
        // the worker slots. Other stitching stays within the normal budget.
        // Once all requested meshes are ready, speculative workers must not delay their swap.
          if(!complete && RunningJobs>=allowance && !local && !startup)return;
        if(local&&available<=lastLocalAttempt)return;
        if(local)lastLocalAttempt=available;
        {
            var ordered = requested.Patches.OrderBy(p=>PriorityTier(p,requested,committed)).ThenBy(p=>Math.Min(p.Key.Z,PriorityLayerCount)).ThenBy(p => Distance(p, requested)).ThenBy(p => p.Key.Z).ToArray();
            // A slow tile must not hold up completed neighbors on the same ring.
            var candidates = ordered.AsEnumerable();
            if (startup && AllowLocalPublication)
            {
                var visible = committed?.Patches.ToHashSet();
                int firstMissingLevel = ordered.Where(p => visible?.Contains(p)!=true)
                    .Select(p => p.Key.Z).DefaultIfEmpty(int.MaxValue).Min();
                int lastLevel=firstMissingLevel;
                if (firstMissingLevel is >=2 and <=4)
                {
                    // Publish ready outer owners in the cut that finishes layer
                    // three. Layer five can keep growing while layer four fills.
                    bool thirdReady=ordered.Where(p=>p.Key.Z==2).All(IsReady);
                    if(thirdReady)
                    {
                        // Both next levels must have a full-resolution owner
                        // before the final layer-three batch goes visible.
                        for(int level=3;level<=4;level++)
                            if(ordered.Any(p=>p.Key.Z==level) && !ordered.Any(p=>p.Key.Z==level && IsReady(p)))
                                return;
                        lastLevel=4;
                    }
                    else lastLevel=2;
                }
                candidates = ordered.Where(p => p.Key.Z <= lastLevel);
                if(ordered.Any(p=>p.Key.Z>lastLevel))complete=false;
                if (EntranceSupport is {} support && ordered.Any(p => support(p) && !ready.ContainsKey(new Key(p,resolution,revision))))
                    candidates = candidates.Where(p => !support(p));
            }
            var source=candidates.Select(p=>new Key(p,resolution,revision)).Where(key=>ready.ContainsKey(key)).Select(key=>ready[key]).ToArray();if(startup && !complete && source.Length<=publishedCount)return;var plan=complete?requested:requested with{Patches=source.Select(data=>data.Patch).ToArray()};var desired=requested;var prior=committed;var originals=committedSources;long requestedGeneration=generation;preparationGeneration=generation;preparationCancellation=new CancellationTokenSource();var token=preparationCancellation.Token;
            var entranceGroup = local && EntranceSupport is {} includes ? ordered.Where(includes).ToHashSet() : null;
            preparation=Task.Run(()=>
            {
                if(local)
                {
                    var next=source.ToDictionary(d=>d.Patch);var patches=TerrainLocalPublication.Select(prior!.Patches,ordered,next.Keys.ToHashSet(),()=>token.IsCancellationRequested,4,entranceGroup);
                    if(patches is null)return new Prepared(requestedGeneration,plan,null,false,Array.Empty<TerrainRingMeshGeometry.Data>());
                    var old=originals.ToDictionary(d=>d.Patch);source=patches.Select(p=>next.TryGetValue(p,out var data)?data:old[p]).ToArray();plan=prior with{Patches=patches,Camera=desired.Camera,CollisionInterests=desired.CollisionInterests};
                }
                var cut=TerrainRingTransitions.Stitch(plan,source,()=>token.IsCancellationRequested,transitionCache,GpuGrids);return new Prepared(requestedGeneration,plan,cut,complete,source);
            },token);
        }
    }
    private bool IsReady(TerrainRingLayout.Patch patch) => ready.ContainsKey(new Key(patch,resolution,revision));
    private bool CentralReady()
    {
        if (requested?.Owner(requested.Camera.X, requested.Camera.Y) is not { } center) return false;
        return ready.ContainsKey(new Key(center,resolution,revision));
    }
    public bool TryPrepare(out long preparedGeneration,out TerrainRingTransitions.Result? cut)
    {
        preparedGeneration=generation;cut=null;if(requested is null||ReferenceEquals(requested,committed)||LastError.Length>0)return false;
        if(this.preparedGeneration==generation&&preparedCut is not null){cut=preparedCut;return true;}
        return false;
    }
    public bool IsCurrent(long preparedGeneration)=>!disposed&&preparedGeneration==generation;
    public void RejectPrepared(long preparedGeneration,Exception error)
    {
        if(!IsCurrent(preparedGeneration))return;LastError=error.ToString();preparedCut=null;preparedPlan=null;preparedSources=Array.Empty<TerrainRingMeshGeometry.Data>();this.preparedGeneration=-1;
    }
    public bool Acknowledge(long preparedGeneration)
    {
        if(!IsCurrent(preparedGeneration)||this.preparedGeneration!=preparedGeneration||preparedCut is null||preparedPlan is null||requested is null)return false;if(completeEver&&!preparedComplete)LocalPublications++;committed=preparedComplete?requested:preparedPlan;committedSources=preparedSources;committedSourceRevision=revision;lastLocalAttempt=-1;SortPending();preparedSources=Array.Empty<TerrainRingMeshGeometry.Data>();completeEver|=preparedComplete;publishedCount=preparedCut.Meshes.Length;preparedCut=null;preparedPlan=null;this.preparedGeneration=-1;return true;
    }
    private void Store(Key key,TerrainRingMeshGeometry.Data data)
    {
        if(cache.TryGetValue(key,out var prior)){Touch(prior);return;}long bytes=Estimate(data);if(bytes>Math.Max(CacheBudgetBytes,0))return;var node=lru.AddLast(key);cache[key]=new Cached(data,bytes,node);cacheBytes+=bytes;
    }
    private static long Estimate(TerrainRingMeshGeometry.Data data)
    {
        // This builder always emits position, normal, color, two UVs and four RGBA float controls.
        // Use the owned layout lengths instead of copying packed arrays just to count their bytes.
        return data.ExtensionData.LongLength+data.AlienFlow.LongLength+data.AdditionalBytes+256+(long)data.Topology.VertexCount*120+(long)data.Topology.Indices.Length*sizeof(int);
    }
    private void Touch(Cached entry){lru.Remove(entry.Order);lru.AddLast(entry.Order);}
    private void RemoveCache(Key key){if(!cache.Remove(key,out var entry))return;prefetched.Remove(key);lru.Remove(entry.Order);cacheBytes-=entry.Bytes;}
    private void Trim(){while(cacheBytes>Math.Max(CacheBudgetBytes-(ShareSamples?TerrainSharedSamples.BudgetBytes:0),0)&&lru.First is not null)RemoveCache(lru.First.Value);}
    public void Dispose()
    {
        if(disposed)return;disposed=true;preparationCancellation?.Cancel();foreach(var job in jobs.Values)job.Cancellation.Cancel();foreach(var job in jobs.Values){try{job.Task.GetAwaiter().GetResult();}catch(OperationCanceledException){}catch(Exception error){LastError=error.ToString();}finally{job.Cancellation.Dispose();job.Builder.Dispose();}}jobs.Clear();if(preparation is not null){try{preparation.GetAwaiter().GetResult();}catch(OperationCanceledException){}catch(Exception error){LastError=error.ToString();}preparation=null;}preparationCancellation?.Dispose();preparationCancellation=null;foreach(var entry in idle)entry.Builder.Dispose();idle.Clear();ready.Clear();cache.Clear();lru.Clear();wanted.Clear();prefetch.Clear();prefetched.Clear();pending.Clear();transitionCache.Clear();committedSources=preparedSources=Array.Empty<TerrainRingMeshGeometry.Data>();preparedCut=null;committed=preparedPlan=requested=null;cacheBytes=0;
    }
}
