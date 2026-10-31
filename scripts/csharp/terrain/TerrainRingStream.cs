using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.Runtime.InteropServices;

namespace PredatorIsle.Terrain;

/// <summary>
/// Numerical ring streaming. The host supplies the shared terrain/cave worker allowance and
/// publishes a complete hidden GPU/collision cut only after its own safety checks succeed.
/// </summary>
public sealed class TerrainRingStream : IDisposable
{
    private readonly record struct Key(TerrainRingLayout.Patch Patch,int Resolution,long SourceRevision);
    private sealed class BuildProgress{public string Stage="queued";}
    private sealed record Job(Key Key,TerrainMeshBuilder Builder,CancellationTokenSource Cancellation,Task<TerrainRingMeshGeometry.Data> Task,ulong Started,BuildProgress Progress);
    private sealed record Cached(TerrainRingMeshGeometry.Data Data,long Bytes,LinkedListNode<Key> Order);
    private readonly TerrainRingMeshGeometry geometry;
    private readonly Dictionary<Key,Job> jobs=new();
    private readonly Dictionary<Key,TerrainRingMeshGeometry.Data> ready=new();
    private readonly Dictionary<Key,Cached> cache=new();
    private readonly LinkedList<Key> lru=new();
    private readonly Queue<(long Revision,TerrainMeshBuilder Builder)> idle=new();
    private readonly HashSet<Key> wanted=new();
    private readonly List<Key> pending=new();
    private TerrainRingLayout.Plan? requested,committed;
    private long generation,revision,cacheBytes;
    private long preparedGeneration=-1;
    private TerrainRingTransitions.Result? preparedCut;
    private Task<(long Generation,TerrainRingLayout.Plan Plan,TerrainRingTransitions.Result Cut,bool Complete)>? preparation;
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
    public int PendingPatches=>pending.Count;
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
        bool newSource=sourceRevision!=revision;requested=plan;revision=sourceRevision;resolution=subdivisions;generation++;preparationCancellation?.Cancel();preparedGeneration=-1;preparedCut=null;preparedPlan=null;publishedCount=0;LastError="";wanted.Clear();pending.Clear();foreach(var patch in plan.Patches)wanted.Add(new Key(patch,subdivisions,sourceRevision));
        foreach(var job in jobs.Values)if(!wanted.Contains(job.Key)&&!job.Cancellation.IsCancellationRequested){job.Cancellation.Cancel();CancelledJobs++;}
        foreach(var key in ready.Keys.ToArray())if(!wanted.Contains(key))ready.Remove(key);
        if(newSource){foreach(var item in idle)item.Builder.Dispose();idle.Clear();foreach(var key in cache.Keys.Where(k=>k.SourceRevision!=sourceRevision).ToArray())RemoveCache(key);}
        foreach(var key in wanted)
        {
            if(ready.ContainsKey(key)||jobs.TryGetValue(key,out var job)&&!job.Cancellation.IsCancellationRequested)continue;
            if(cache.TryGetValue(key,out var entry)){ready[key]=entry.Data;Touch(entry);CacheHits++;}else{pending.Add(key);CacheMisses++;}
        }
        pending.Sort((a,b)=>{int level=a.Patch.Key.Z.CompareTo(b.Patch.Key.Z);if(level!=0)return level;double Priority(TerrainRingLayout.Patch patch)=>plan.CollisionInterests.Length>0?plan.CollisionInterests.Min(point=>Distance(patch,point)):Distance(patch,plan.Camera);return Priority(a.Patch).CompareTo(Priority(b.Patch));});Trim();return true;
    }
    private static double Distance(TerrainRingLayout.Patch patch,Vector2 focus)
    {
        double dx=Math.Max(Math.Max(patch.OriginX-focus.X,focus.X-(patch.OriginX+patch.Size)),0),dz=Math.Max(Math.Max(patch.OriginZ-focus.Y,focus.Y-(patch.OriginZ+patch.Size)),0);return dx*dx+dz*dz;
    }
    public void Tick(int availableSharedWorkers,Func<TerrainMeshBuilder> createBuilder)
    {
        ObjectDisposedException.ThrowIf(disposed,this);
        foreach(var job in jobs.Values.ToArray())
        {
            if(!job.Task.IsCompleted)continue;jobs.Remove(job.Key);
            try{var data=job.Task.GetAwaiter().GetResult();if(job.Key.SourceRevision==revision){Store(job.Key,data);if(wanted.Contains(job.Key))ready[job.Key]=data;}}
            catch(OperationCanceledException){if(wanted.Contains(job.Key)&&!pending.Contains(job.Key))pending.Add(job.Key);}
            catch(Exception error){if(wanted.Contains(job.Key))LastError=error.ToString();else LastRetiredWorkerError=error.ToString();}
            finally{job.Cancellation.Dispose();if(job.Key.SourceRevision==revision&&idle.Count<Math.Max(MaximumWorkers,1))idle.Enqueue((revision,job.Builder));else job.Builder.Dispose();}
        }
        if(preparation is not null&&preparation.IsCompleted)
        {
            try{var result=preparation.GetAwaiter().GetResult();if(result.Generation==generation){preparedCut=result.Cut;preparedGeneration=result.Generation;preparedPlan=result.Plan;preparedComplete=result.Complete;}}
            catch(OperationCanceledException){}
            catch(Exception error){if(preparationGeneration==generation)LastError=error.ToString();else LastRetiredWorkerError=error.ToString();}
            finally{preparation=null;preparationCancellation?.Dispose();preparationCancellation=null;preparationGeneration=-1;}
        }
        Trim();if(LastError.Length>0)return;int allowance=Math.Max(0,Math.Min(MaximumWorkers,availableSharedWorkers));
        TryStartPreparation(allowance);
        while(RunningJobs<allowance&&pending.Count>0)
        {
            var key=pending[0];pending.RemoveAt(0);if(!wanted.Contains(key)||ready.ContainsKey(key))continue;if(jobs.ContainsKey(key)){pending.Add(key);break;}
            TerrainMeshBuilder builder;try{builder=idle.Count>0?idle.Dequeue().Builder:createBuilder();}catch(Exception error){LastError=error.ToString();pending.Insert(0,key);return;}
            var cancellation=new CancellationTokenSource();var token=cancellation.Token;
            var progress=new BuildProgress();ulong started=Time.GetTicksUsec();try{var task=Task.Run(()=>geometry.Build(builder,key.Patch,key.Resolution,()=>token.IsCancellationRequested,stage=>Volatile.Write(ref progress.Stage,stage)),token);jobs[key]=new Job(key,builder,cancellation,task,started,progress);}
            catch(Exception error){builder.Dispose();cancellation.Dispose();LastError=error.ToString();pending.Insert(0,key);return;}
        }
        TryStartPreparation(allowance);
    }
    private void TryStartPreparation(int allowance)
    {
        if(preparation is not null||preparedCut is not null||requested is null||ReferenceEquals(requested,committed)||RunningJobs>=allowance)return;
        bool complete=wanted.All(key=>ready.ContainsKey(key)),startup=!completeEver&&(committed is null||publishedGeneration==generation);int available=wanted.Count(key=>ready.ContainsKey(key));
        if(!complete&&(!startup||available<=publishedCount||!CentralReady()))return;
        {
            var source=requested.Patches.Select(p=>new Key(p,resolution,revision)).Where(key=>ready.ContainsKey(key)).Select(key=>ready[key]).ToArray();var plan=complete?requested:requested with{Patches=source.Select(data=>data.Patch).ToArray()};long requestedGeneration=generation;preparationGeneration=generation;preparationCancellation=new CancellationTokenSource();var token=preparationCancellation.Token;
            preparation=Task.Run(()=>
            {
                var cut=TerrainRingTransitions.Stitch(plan,source,()=>token.IsCancellationRequested);var meshes=new TerrainRingMeshGeometry.Data[cut.Meshes.Length];for(int i=0;i<meshes.Length;i++){token.ThrowIfCancellationRequested();var data=cut.Meshes[i];meshes[i]=data with{LocalWater=TerrainRingWater.Build(data,data.WaterLevel,data.BeachesEnabled,data.WaterEnabled),GeometryFingerprint=Fingerprint(data)};}return (requestedGeneration,plan,cut with{Meshes=meshes},complete);
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
        if(!IsCurrent(preparedGeneration))return;LastError=error.ToString();preparedCut=null;preparedPlan=null;this.preparedGeneration=-1;
    }
    public bool Acknowledge(long preparedGeneration)
    {
        if(!IsCurrent(preparedGeneration)||this.preparedGeneration!=preparedGeneration||preparedCut is null||preparedPlan is null||requested is null)return false;committed=preparedComplete?requested:preparedPlan;completeEver|=preparedComplete;publishedCount=preparedCut.Meshes.Length;publishedGeneration=generation;preparedCut=null;preparedPlan=null;this.preparedGeneration=-1;return true;
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
    private static string Fingerprint(TerrainRingMeshGeometry.Data data)
    {
        using var hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);var vertices=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();var normals=data.Arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();hash.AppendData(MemoryMarshal.AsBytes(vertices.AsSpan()));hash.AppendData(MemoryMarshal.AsBytes(normals.AsSpan()));hash.AppendData(MemoryMarshal.AsBytes(data.Topology.Indices.Span));return Convert.ToHexString(hash.GetHashAndReset());
    }
    private void Touch(Cached entry){lru.Remove(entry.Order);lru.AddLast(entry.Order);}
    private void RemoveCache(Key key){if(!cache.Remove(key,out var entry))return;lru.Remove(entry.Order);cacheBytes-=entry.Bytes;}
    private void Trim(){while(cacheBytes>Math.Max(CacheBudgetBytes,0)&&lru.First is not null)RemoveCache(lru.First.Value);}
    public void Dispose()
    {
        if(disposed)return;disposed=true;preparationCancellation?.Cancel();foreach(var job in jobs.Values)job.Cancellation.Cancel();foreach(var job in jobs.Values){try{job.Task.GetAwaiter().GetResult();}catch(OperationCanceledException){}catch(Exception error){LastError=error.ToString();}finally{job.Cancellation.Dispose();job.Builder.Dispose();}}jobs.Clear();if(preparation is not null){try{preparation.GetAwaiter().GetResult();}catch(OperationCanceledException){}catch(Exception error){LastError=error.ToString();}preparation=null;}preparationCancellation?.Dispose();preparationCancellation=null;foreach(var entry in idle)entry.Builder.Dispose();idle.Clear();ready.Clear();cache.Clear();lru.Clear();wanted.Clear();pending.Clear();cacheBytes=0;
    }
}
