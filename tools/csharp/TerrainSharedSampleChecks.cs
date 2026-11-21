using System;
using System.Threading;
using System.Threading.Tasks;
using PredatorIsle.Terrain;
namespace PredatorIsle.Checks;
internal static class TerrainSharedSampleChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var cache=new TerrainSharedSamples();int produced=0;var values=new double[128];
        Parallel.For(0,values.Length,i=>values[i]=cache.GetHeight(-16.125,48.75,()=>{Interlocked.Increment(ref produced);Thread.SpinWait(10000);return 37.125;}));
        require(produced==1,"Shared scalar requests were not coalesced");foreach(double value in values)require(value==37.125,"Shared scalar result differs");
        require(cache.GetHeight(-16.1250001,48.75,()=>99)==99,"Off-grid cave coordinates were silently quantized");
        var lattice=new TerrainSharedSamples();int latticeProduced=0;
        Parallel.For(0,128,i=>lattice.GetSurface(-17,48,()=>{Interlocked.Increment(ref latticeProduced);Thread.SpinWait(10000);return new TerrainSharedSamples.Surface(-9.5,default);}));
        require(latticeProduced==1&&lattice.GetHeight(-17,48,()=>throw new Exception("Repeated lattice height"))==-9.5,"Numerical pages did not coalesce surface producers and share canonical heights");
        require(lattice.GetHeight(-16,48,()=>71)==71,"Negative page boundaries aliased neighboring samples");
        cache.GetSurface(-32,16,()=>new TerrainSharedSamples.Surface(123.125,default));
        require(cache.GetHeight(-32,16,()=>throw new Exception("Repeated surface height"))==123.125,"Collision failed to reuse the canonical surface sample");
        var fresh=new TerrainSharedSamples();require(fresh.GetHeight(-32,16,()=>-456)==-456,"Different source scopes shared stale samples");
        bool threw=false;try{cache.GetHeight(9,9,()=>throw new InvalidOperationException());}catch(InvalidOperationException){threw=true;}
        require(threw&&cache.GetHeight(9,9,()=>7)==7,"Failed shared producer poisoned a later request");
        cache.Protect(0,0,100000);for(int i=0;i<TerrainSharedSamples.Capacity+2;i++)cache.GetHeight(i,1,()=>i);
        require(cache.ScalarCount<=TerrainSharedSamples.Capacity,"Protected working set exceeded its hard bound");
    }
}
