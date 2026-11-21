using System;
using System.Collections.Concurrent;
using System.Threading;

namespace PredatorIsle.Terrain;

/// <summary>Source-scoped sparse numerical cache; exact coordinates, immutable products and coalesced producers.</summary>
internal sealed class TerrainSharedSamples
{
    internal sealed record Surface(double Height,TerrainRingMeshGeometry.Sample Controls);
    private const int HeightPageCapacity=256,SurfacePageCapacity=32,OffGridCapacity=4096;
    private readonly TerrainLatticePages<Surface> surfacePages=new(SurfacePageCapacity);
    private readonly TerrainLatticePages<double> heightPages=new(HeightPageCapacity);
    private readonly ConcurrentDictionary<(double X,double Z),Lazy<Surface>> surfaces=new();
    private readonly ConcurrentDictionary<(double X,double Z),Lazy<double>> heights=new();
    private readonly ConcurrentQueue<(double X,double Z)> surfaceOrder=new(),heightOrder=new();
    private long hits,misses,evaluations;
    private int surfaceCount,heightCount;
    private sealed record Interest(double X,double Z,double Radius);
    private Interest interest=new(double.PositiveInfinity,double.PositiveInfinity,0);
    internal void Protect(double x,double z,double radius){Volatile.Write(ref interest,new Interest(x,z,radius));surfacePages.Protect(x,z,radius);heightPages.Protect(x,z,radius*3);}
    internal const int Capacity=HeightPageCapacity*256+OffGridCapacity;
    // Charged against the stream cache budget; includes dictionary/Lazy/queue overhead.
    internal const long BudgetBytes=8L*1024*1024;
    internal long Hits=>Interlocked.Read(ref hits);
    internal long Misses=>Interlocked.Read(ref misses);
    internal long Evaluations=>Interlocked.Read(ref evaluations);
    internal int ScalarCount=>heightPages.Count+Volatile.Read(ref heightCount);
    private static bool Lattice(double x,double z)=>double.IsFinite(x)&&double.IsFinite(z)&&Math.Abs(x)<=2000000000&&Math.Abs(z)<=2000000000&&x==Math.Floor(x)&&z==Math.Floor(z);
    internal Surface GetSurface(double x,double z,Func<Surface> produce)
    {
        if(Lattice(x,z))
        {
            var result=surfacePages.Get(x,z,produce,out bool hit);if(hit)Interlocked.Increment(ref hits);else{Interlocked.Increment(ref misses);Interlocked.Increment(ref evaluations);}heightPages.Remember(x,z,result.Height);return result;
        }
        var key=(x,z);if(surfaces.TryGetValue(key,out var found)){Interlocked.Increment(ref hits);return found.Value;}
        var candidate=new Lazy<Surface>(()=>{Interlocked.Increment(ref evaluations);return produce();},LazyThreadSafetyMode.ExecutionAndPublication);
        Interlocked.Increment(ref surfaceCount);found=surfaces.GetOrAdd(key,candidate);
        if(ReferenceEquals(found,candidate)){Interlocked.Increment(ref misses);surfaceOrder.Enqueue(key);}else{Interlocked.Decrement(ref surfaceCount);Interlocked.Increment(ref hits);}
        try{return found.Value;}catch{Remove(surfaces,key,ref surfaceCount);throw;}
        finally{Trim(surfaces,surfaceOrder,ref surfaceCount);}
    }
    internal double GetHeight(double x,double z,Func<double> produce)
    {
        if(Lattice(x,z))
        {
            if(surfacePages.TryGet(x,z,out var surfaceValue)){Interlocked.Increment(ref hits);return surfaceValue.Height;}double result=heightPages.Get(x,z,produce,out bool hit);if(hit)Interlocked.Increment(ref hits);else{Interlocked.Increment(ref misses);Interlocked.Increment(ref evaluations);}return result;
        }
        var key=(x,z);if(surfaces.TryGetValue(key,out var surface)){Interlocked.Increment(ref hits);return surface.Value.Height;}
        if(heights.TryGetValue(key,out var found)){Interlocked.Increment(ref hits);return found.Value;}
        var candidate=new Lazy<double>(()=>{Interlocked.Increment(ref evaluations);return produce();},LazyThreadSafetyMode.ExecutionAndPublication);
        Interlocked.Increment(ref heightCount);found=heights.GetOrAdd(key,candidate);
        if(ReferenceEquals(found,candidate)){Interlocked.Increment(ref misses);heightOrder.Enqueue(key);}else{Interlocked.Decrement(ref heightCount);Interlocked.Increment(ref hits);}
        try{return found.Value;}catch{Remove(heights,key,ref heightCount);throw;}
        finally{Trim(heights,heightOrder,ref heightCount);}
    }
    private static void Remove<T>(ConcurrentDictionary<(double X,double Z),Lazy<T>> entries,(double X,double Z) key,ref int count)
    {if(entries.TryRemove(key,out _))Interlocked.Decrement(ref count);}
    private void Trim<T>(ConcurrentDictionary<(double X,double Z),Lazy<T>> entries,ConcurrentQueue<(double X,double Z)> order,ref int count)
    {
        int attempts=Volatile.Read(ref count);if(attempts<=OffGridCapacity)return;
        while(Volatile.Read(ref count)>OffGridCapacity&&attempts-->0&&order.TryDequeue(out var key))
        {
            var focus=Volatile.Read(ref interest);bool near=Math.Abs(key.X-focus.X)<=focus.Radius&&Math.Abs(key.Z-focus.Z)<=focus.Radius;
            if(entries.TryGetValue(key,out var entry)&&(!entry.IsValueCreated||near)){order.Enqueue(key);continue;}
            Remove(entries,key,ref count);
        }
        // A high-density profile can exceed the protected working set. Preserve
        // the hard bound rather than allowing protected entries to grow without limit.
        attempts=Volatile.Read(ref count);while(Volatile.Read(ref count)>OffGridCapacity&&attempts-->0&&order.TryDequeue(out var key))
        {if(entries.TryGetValue(key,out var entry)&&!entry.IsValueCreated){order.Enqueue(key);continue;}Remove(entries,key,ref count);}
    }
}
