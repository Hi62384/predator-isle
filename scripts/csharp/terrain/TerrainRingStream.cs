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
    private readonly record struct Key(TerrainRingLayout.Patch Patch,int Resolution,long SourceRevision);
    private sealed class BuildProgress
    {
        public string Stage="queued";
        public readonly Dictionary<string,double> Milliseconds=new();
        private ulong start;
        private long allocationStart;
        public long AllocatedBytes;
        public long CanonicalEvaluations;
        public void Mark(string next){ulong now=Time.GetTicksUsec();if(start!=0)Milliseconds[Stage]=Milliseconds.GetValueOrDefault(Stage)+(now-start)/1000.0;else allocationStart=GC.GetAllocatedBytesForCurrentThread();start=now;Volatile.Write(ref Stage,next);}
        public void Finish(){Mark("complete");AllocatedBytes=GC.GetAllocatedBytesForCurrentThread()-allocationStart;}
    }
    private readonly Dictionary<string,double> stageMilliseconds=new();
    private long allocatedWorkerBytes,completedJobs;
    public Godot.Collections.Dictionary Profile {get{var stages=new Godot.Collections.Dictionary();foreach(var pair in stageMilliseconds)stages[pair.Key]=pair.Value;return new Godot.Collections.Dictionary{["worker_stage_ms"]=stages,["managed_worker_allocated_bytes"]=allocatedWorkerBytes,["completed_jobs"]=completedJobs,["cancelled_jobs"]=CancelledJobs};}}
    private sealed record Job(Key Key,TerrainMeshBuilder Builder,CancellationTokenSource Cancellation,Task<TerrainRingMeshGeometry.Data> Task,ulong Started,BuildProgress Progress);
    private sealed record Cached(TerrainRingMeshGeometry.Data Data,long Bytes,LinkedListNode<Key> Order);
    private readonly TerrainRingMeshGeometry geometry;
    private readonly TerrainRingTransitions.Cache transitionCache=new();
    private TerrainSharedSamples sharedSamples=new();
    public bool ShareSamples {get;set;}=true;
    public bool GpuGrids{get;set;}
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
    private long publishedGeneration=-1;
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
        foreach(var job in jobs.Values)if(!wanted.Contains(job.Key)&&!prefetch.Contains(job.Key)&&!job.Cancellation.IsCancellationRequested){job.Cancellation.Cancel();CancelledJobs++;}
        foreach(var key in ready.Keys.ToArray())if(!wanted.Contains(key))ready.Remove(key);
        if(newSource){sharedSamples=new();foreach(var item in idle)item.Builder.Dispose();idle.Clear();foreach(var key in cache.Keys.Where(k=>k.SourceRevision!=sourceRevision).ToArray())RemoveCache(key);}
        sharedSamples.Protect(plan.Camera.X,plan.Camera.Y,plan.BaseSize*2+2);
        foreach(var key in wanted)
        {
            if(ready.ContainsKey(key)||jobs.TryGetValue(key,out var job)&&!job.Cancellation.IsCancellationRequested)continue;
            if(cache.TryGetValue(key,out var entry)){ready[key]=entry.Data;Touch(entry);CacheHits++;if(prefetched.Remove(key))PrefetchHits++;}else{pending.Add(key);CacheMisses++;}
        }
        pending.Sort((a,b)=>{int level=a.Patch.Key.Z.CompareTo(b.Patch.Key.Z);if(level!=0)return level;double Priority(TerrainRingLayout.Patch patch)=>plan.CollisionInterests.Length>0?plan.CollisionInterests.Min(point=>Distance(patch,point)):Distance(patch,plan.Camera);return Priority(a.Patch).CompareTo(Priority(b.Patch));});Trim();return true;
    }
    private static double Distance(TerrainRingLayout.Patch patch,Vector2 focus)
    {
        double dx=Math.Max(Math.Max(patch.OriginX-focus.X,focus.X-(patch.OriginX+patch.Size)),0),dz=Math.Max(Math.Max(patch.OriginZ-focus.Y,focus.Y-(patch.OriginZ+patch.Size)),0);return dx*dx+dz*dz;
    }
    /// <summary>Bounded incoming rows; speculative work uses only spare terrain slots after current requests.</summary>
    public void Prefetch(Vector2 focus,Vector2 velocity)
    {
        if(!completeEver||requested is null||CacheBudgetBytes<=0)return;
        var candidates=TerrainPrefetch.Select(focus,velocity,NearBuildSeconds,requested.BaseSize);
        prefetch.Clear();foreach(var patch in candidates){var key=new Key(patch,resolution,revision);if(!wanted.Contains(key))prefetch.Add(key);}
        pending.RemoveAll(key=>!wanted.Contains(key));
        foreach(var job in jobs.Values)if(!wanted.Contains(job.Key)&&!prefetch.Contains(job.Key)&&!job.Cancellation.IsCancellationRequested){job.Cancellation.Cancel();CancelledJobs++;}
        foreach(var key in prefetch)if(!cache.ContainsKey(key)&&!jobs.ContainsKey(key))pending.Add(key);
    }
    // An in-flight cancelled job may still own a key. Examine the bounded queue
    // rather than blocking runnable work behind that key.
    internal static bool TryDequeueAvailable<T>(List<T> queue,Func<T,bool> eligible,Func<T,bool> busy,out T item)
    {
        int remaining=queue.Count;
        while(remaining-->0)
        {
            T candidate=queue[0];queue.RemoveAt(0);
            if(!eligible(candidate))continue;
            if(busy(candidate)){queue.Add(candidate);continue;}
            item=candidate;return true;
        }
        item=default!;return false;
    }
    public void Tick(int availableSharedWorkers,Func<TerrainMeshBuilder> createBuilder)
    {
        ObjectDisposedException.ThrowIf(disposed,this);
        foreach(var job in jobs.Values.ToArray())
        {
            if(!job.Task.IsCompleted)continue;jobs.Remove(job.Key);
            try{var data=job.Task.GetAwaiter().GetResult();completedJobs++;if(job.Key.Patch.Key.Z==0)NearBuildSeconds=NearBuildSeconds*.8+Math.Clamp((Time.GetTicksUsec()-job.Started)/1000000.0,.001,2)*.2;canonicalEvaluations+=job.Progress.CanonicalEvaluations;allocatedWorkerBytes+=job.Progress.AllocatedBytes;foreach(var pair in job.Progress.Milliseconds)stageMilliseconds[pair.Key]=stageMilliseconds.GetValueOrDefault(pair.Key)+pair.Value;if(job.Key.SourceRevision==revision){Store(job.Key,data);if(wanted.Contains(job.Key))ready[job.Key]=data;else {PrefetchCompletions++;if(cache.ContainsKey(job.Key))prefetched.Add(job.Key);}}}
            catch(OperationCanceledException){if(wanted.Contains(job.Key)&&!pending.Contains(job.Key))pending.Add(job.Key);}
            catch(Exception error){if(wanted.Contains(job.Key))LastError=error.ToString();else LastRetiredWorkerError=error.ToString();}
            finally{job.Cancellation.Dispose();if(job.Key.SourceRevision==revision&&idle.Count<Math.Max(MaximumWorkers,1))idle.Enqueue((revision,job.Builder));else job.Builder.Dispose();}
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
        while(RunningJobs<allowance&&TryDequeueAvailable(pending,
            candidate=>(wanted.Contains(candidate)||prefetch.Contains(candidate))&&!ready.ContainsKey(candidate),
            candidate=>jobs.ContainsKey(candidate),out var key))
        {
            TerrainMeshBuilder builder;try{builder=idle.Count>0?idle.Dequeue().Builder:createBuilder();}catch(Exception error){LastError=error.ToString();pending.Insert(0,key);return;}
            var cancellation=new CancellationTokenSource();var token=cancellation.Token;
            var progress=new BuildProgress();TerrainSharedSamples? samples=ShareSamples?sharedSamples:null;ulong started=Time.GetTicksUsec();try{var task=Task.Run(()=>{long evaluations=builder._native_height.CanonicalEvaluations;var data=geometry.Build(builder,key.Patch,key.Resolution,()=>token.IsCancellationRequested,progress.Mark,samples);progress.CanonicalEvaluations=builder._native_height.CanonicalEvaluations-evaluations;progress.Finish();return data;},token);jobs[key]=new Job(key,builder,cancellation,task,started,progress);}
            catch(Exception error){builder.Dispose();cancellation.Dispose();LastError=error.ToString();pending.Insert(0,key);return;}
        }
        TryStartPreparation(allowance);
    }
    private void TryStartPreparation(int allowance)
    {
        if(preparation is not null||preparedCut is not null||requested is null||ReferenceEquals(requested,committed)||RunningJobs>=allowance)return;
        bool complete=wanted.All(key=>ready.ContainsKey(key)),startup=!completeEver&&(committed is null||publishedGeneration==generation);int available=wanted.Count(key=>ready.ContainsKey(key));
        bool local=AllowLocalPublication&&!complete&&!startup&&completeEver&&committed is not null&&committedSourceRevision==revision&&requested.BaseSize==committed.BaseSize;
        if(!complete&&!local&&(!startup||available<=publishedCount||!CentralReady()))return;
        if(local&&available<=lastLocalAttempt)return;
        if(local)lastLocalAttempt=available;
        {
            var source=requested.Patches.Select(p=>new Key(p,resolution,revision)).Where(key=>ready.ContainsKey(key)).Select(key=>ready[key]).ToArray();var plan=complete?requested:requested with{Patches=source.Select(data=>data.Patch).ToArray()};var desired=requested;var prior=committed;var originals=committedSources;long requestedGeneration=generation;preparationGeneration=generation;preparationCancellation=new CancellationTokenSource();var token=preparationCancellation.Token;
            preparation=Task.Run(()=>
            {
                if(local)
                {
                    var next=source.ToDictionary(d=>d.Patch);var patches=TerrainLocalPublication.Select(prior!.Patches,desired.Patches,next.Keys.ToHashSet(),()=>token.IsCancellationRequested);
                    if(patches is null)return new Prepared(requestedGeneration,plan,null,false,Array.Empty<TerrainRingMeshGeometry.Data>());
                    var old=originals.ToDictionary(d=>d.Patch);source=patches.Select(p=>next.TryGetValue(p,out var data)?data:old[p]).ToArray();plan=prior with{Patches=patches,Camera=desired.Camera,CollisionInterests=desired.CollisionInterests};
                }
                var cut=TerrainRingTransitions.Stitch(plan,source,()=>token.IsCancellationRequested,transitionCache,GpuGrids);return new Prepared(requestedGeneration,plan,cut,complete,source);
            },token);
        }
    }
    private bool CentralReady()
    {
        if(requested is null)return false;int x=(int)Math.Floor(requested.Camera.X/requested.BaseSize),z=(int)Math.Floor(requested.Camera.Y/requested.BaseSize);for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++){var key=new Key(new TerrainRingLayout.Patch(new Vector3I(x+dx,z+dz,0),requested.BaseSize,TerrainRingLayout.Mask.None),resolution,revision);if(!ready.ContainsKey(key))return false;}return true;
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
        if(!IsCurrent(preparedGeneration)||this.preparedGeneration!=preparedGeneration||preparedCut is null||preparedPlan is null||requested is null)return false;if(completeEver&&!preparedComplete)LocalPublications++;committed=preparedComplete?requested:preparedPlan;committedSources=preparedSources;committedSourceRevision=revision;preparedSources=Array.Empty<TerrainRingMeshGeometry.Data>();completeEver|=preparedComplete;publishedCount=preparedCut.Meshes.Length;publishedGeneration=generation;preparedCut=null;preparedPlan=null;this.preparedGeneration=-1;return true;
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
