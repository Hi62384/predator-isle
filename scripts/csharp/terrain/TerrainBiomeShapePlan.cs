using Godot;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using PredatorIsle.Biomes;

namespace PredatorIsle.Terrain;

/// <summary>Shared arithmetic kernels for specialized biome raw landforms.
/// The CPU retains discrete ownership, site and water-network planning. Only
/// immutable numerical inputs cross into the GPU queue.</summary>
internal sealed class TerrainBiomeShapePlan
{
    internal const int Bands=16,MaximumQueries=8192;
    internal const string ShaderPath="res://shaders/terrain_biome_shape_gpu.gdshader";
    internal readonly record struct Key(object Owner,Vector2 Point,int Subtype);
    internal readonly record struct Result(Vector4 Value,Vector2 Auxiliary);
    internal sealed record Query(Key Key,int Family,Vector4[] Input,Func<Vector4> Reference,Vector4 Tolerance,Vector2 Auxiliary);
    private readonly HashSet<Key> keys=new();
    private readonly Dictionary<object,List<int>> groups=new();
    internal readonly List<Query> Queries=new();
    internal int Count=>Queries.Count;
    internal bool Full=>Count>=MaximumQueries;
    internal static Vector4 F(double x=0,double y=0,double z=0,double w=0)=>new((float)x,(float)y,(float)z,(float)w);
    internal static Vector4 ExtensionResult(double[] v)=>F(v[0],v[1],v[2],v[4]);
    internal static readonly Vector4 LandTolerance=F(.002,.002,.0002,.0002);
    internal static readonly Vector4 ClassicTolerance=F(.002,.0002,.0002,.0002);

    internal void Add(object owner,Vector2 p,int subtype,int family,Vector4[] bands,Func<Vector4> reference,
        Vector4 tolerance,Vector2 auxiliary=default)
    {
        if(Full||bands.Length!=Bands||!p.IsFinite()||Math.Abs(p.X)>TerrainGpuSampler.MaximumCoordinate||
           Math.Abs(p.Y)>TerrainGpuSampler.MaximumCoordinate)return;
        foreach(var v in bands)if(!v.IsFinite())return;
        if(!auxiliary.IsFinite())return;
        var key=new Key(owner,p,subtype);
        if(!keys.Add(key))return;
        bands[0]=F(family,subtype,p.X,p.Y);
        if(!groups.TryGetValue(owner,out var indices)){indices=new List<int>();groups.Add(owner,indices);}
        indices.Add(Count);Queries.Add(new Query(key,family,bands,reference,tolerance,auxiliary));
    }
    internal static Vector4[] ClassicBands(Vector4 noise,Vector2 rotated,float[] weights,Vector4 auxiliary,
        params double[] parameters)
    {
        var bands=new Vector4[Bands];bands[1]=noise;bands[6]=F(rotated.X,rotated.Y);bands[7]=auxiliary;
        for(int i=0;i<weights.Length&&i<16;i++)bands[2+i/4][i%4]=weights[i];
        if(parameters.Length>(Bands-8)*4)throw new ArgumentException("Too many biome shape parameters");
        for(int i=0;i<parameters.Length;i++)bands[8+i/4][i%4]=(float)parameters[i];
        return bands;
    }
    internal static Vector4[] ExtensionBands(params Vector4[] data)
    {
        var bands=new Vector4[Bands];
        if(data.Length>=Bands)throw new ArgumentException("Too many extension shape inputs");
        Array.Copy(data,0,bands,1,data.Length);return bands;
    }
    internal static TerrainBiomeShapePlan Create(TerrainBiomeNoisePlan noise,TerrainBiomeNoiseCache cache,
        CancellationToken cancellation=default)
    {
        var result=new TerrainBiomeShapePlan();
        using(cache.Activate())
        {
            foreach(var (owner,p) in noise.RawPoints)
            {
                cancellation.ThrowIfCancellationRequested();
                if(result.Full)break;
                switch(owner)
                {
                    case ForestSampler forest:forest.CaptureGpuShape(result,p);break;
                    case JungleSampler jungle:jungle.CaptureGpuShape(result,p);break;
                    case SavannaSampler savanna:savanna.CaptureGpuShape(result,p);break;
                    case SwampSampler swamp:swamp.CaptureGpuShape(result,p);break;
                }
            }
        }
        return result;
    }
    internal static bool Matches(Vector4 value,Vector4 reference,Vector4 tolerance)=>
        value.IsFinite()&&reference.IsFinite()&&Math.Abs((double)value.X-reference.X)<=tolerance.X&&
        Math.Abs((double)value.Y-reference.Y)<=tolerance.Y&&Math.Abs((double)value.Z-reference.Z)<=tolerance.Z&&
        Math.Abs((double)value.W-reference.W)<=tolerance.W;

    internal async Task<int> BakeAsync(TerrainBiomeNoiseGpu gpu,TerrainBiomeNoiseCache cache,
        CancellationToken cancellation=default)
    {
        if(!gpu.Available||Count==0||cancellation.IsCancellationRequested)return 0;
        const int columns=256;
        int rows=Math.Max(2,(Count*4+columns-1)/columns),inputRows=(Count*Bands+columns-1)/columns;
        var inputs=new Vector4[columns*inputRows];
        for(int i=0;i<Count;i++)Queries[i].Input.CopyTo(inputs,i*Bands);
        var values=await gpu.BakeRawAsync(inputs,Count*4,columns,rows,inputRows,cancellation).ConfigureAwait(false);
        if(values is null||values.Length!=Count*4||cancellation.IsCancellationRequested)return 0;
        var accepted=new Dictionary<Key,Result>();
        foreach(var group in groups.Values)
        {
            cancellation.ThrowIfCancellationRequested();
            bool valid=true;int checks=Math.Min(9,group.Count);
            // The full rendered fixture compares every query; runtime checks
            // a bounded set per independently configured family.
            for(int k=0;k<checks;k++)
            {
                int i=group[checks==1?0:(int)((long)k*(group.Count-1)/(checks-1))];
                var q=Queries[i];
                if(!Matches(ValueAt(i),q.Reference(),q.Tolerance)){valid=false;break;}
            }
            if(!valid){gpu.ReportRejection();continue;}
            foreach(int i in group)
            {
                var q=Queries[i];var v=ValueAt(i);
                if(v.IsFinite())accepted.Add(q.Key,new Result(v,q.Auxiliary));
            }
        }
        cache.InstallShapes(accepted,gpu.ReportCacheHits);
        return accepted.Count;
        Vector4 ValueAt(int i)=>new(values[i*4],values[i*4+1],values[i*4+2],values[i*4+3]);
    }
}
