using Godot;
using System;
using System.Collections.Generic;
using System.Threading;

namespace PredatorIsle.Terrain;

/// <summary>Exact canonical noise-coordinate plans for all non-grassland families.
/// Site placement, subtype selection, nonlinear shaping and arbitrary misses remain CPU.</summary>
internal sealed class TerrainBiomeNoisePlan
{
    internal const int MaximumQueries=32768;
    internal const float MaximumNoiseError=.000002f;
    internal readonly record struct Key(FastNoiseLite Noise,Vector2 Position);
    internal readonly record struct Query(Key Key,Vector4 Input,Vector4 Configuration);
    private readonly record struct Spec(Vector2 Offset,float Frequency,int Seed,Vector4 Configuration,double MaximumOctaveScale);
    private readonly Dictionary<FastNoiseLite,Spec?> specs=new();
    private readonly Dictionary<FastNoiseLite,List<int>> groups=new();
    private readonly HashSet<Key> unique=new();
    private readonly HashSet<(object Owner,Vector2I Cell)> nodes=new();
    internal readonly List<Query> Queries=new();
    internal int Count=>Queries.Count;
    internal bool Full=>Count>=MaximumQueries;
    internal bool MarkNode(object owner,Vector2I cell)=>!Full&&nodes.Add((owner,cell));

    private static Spec? Capture(FastNoiseLite noise)
    {
        if(noise.NoiseType!=FastNoiseLite.NoiseTypeEnum.SimplexSmooth||
           noise.FractalType!=FastNoiseLite.FractalTypeEnum.Fbm||
           noise.DomainWarpEnabled||noise.FractalWeightedStrength!=0||
           noise.FractalOctaves<1||noise.FractalOctaves>8)return null;
        float gain=noise.FractalGain,frequency=noise.Frequency,lacunarity=noise.FractalLacunarity;
        var offset=noise.Offset;
        if(!float.IsFinite(gain)||!float.IsFinite(frequency)||frequency<=0||
           !float.IsFinite(lacunarity)||lacunarity<=0||!offset.IsFinite())return null;
        float sum=1,amplitude=Math.Abs(gain);
        for(int i=1;i<noise.FractalOctaves;i++){sum+=amplitude;amplitude*=Math.Abs(gain);}
        if(!float.IsFinite(sum)||sum<=0)return null;
        return new Spec(new Vector2(offset.X,offset.Y),frequency,noise.Seed,
            new Vector4(gain,lacunarity,1/sum,noise.FractalOctaves),Math.Pow(Math.Max(1,lacunarity),noise.FractalOctaves-1));
    }
    internal void Add(FastNoiseLite noise,Vector2 p)
    {
        if(Full||!p.IsFinite()||Math.Abs(p.X)>TerrainGpuSampler.MaximumCoordinate||
           Math.Abs(p.Y)>TerrainGpuSampler.MaximumCoordinate)return;
        if(!specs.TryGetValue(noise,out var spec)){spec=Capture(noise);specs.Add(noise,spec);}
        if(spec is not Spec s)return;
        var key=new Key(noise,p);
        if(unique.Contains(key))return;
        float x=(p.X+s.Offset.X)*s.Frequency,z=(p.Y+s.Offset.Y)*s.Frequency;
        float skew=(x+z)*0.366025388240814208984375f;x+=skew;z+=skew;
        double maxOctave=Math.Max(Math.Abs(x),Math.Abs(z))*s.MaximumOctaveScale;
        if(!double.IsFinite(maxOctave)||maxOctave>1000000)return;
        uint seed=unchecked((uint)s.Seed);
        if(!groups.TryGetValue(noise,out var group)){group=new List<int>();groups.Add(noise,group);}
        group.Add(Count);unique.Add(key);
        Queries.Add(new Query(key,new Vector4(x,z,seed&65535u,seed>>16),s.Configuration));
    }
    internal Vector4[] Inputs(int columns,int rows)
    {
        int plane=checked(columns*rows);
        var data=new Vector4[checked(plane*2)];
        for(int i=0;i<Count;i++){data[i]=Queries[i].Input;data[plane+i]=Queries[i].Configuration;}
        return data;
    }
    internal TerrainBiomeNoiseCache? Accept(float[] values,Action<long> report,CancellationToken token,out double maximumError)
    {
        maximumError=0;
        if(values.Length!=Count)return null;
        // Every distinct noise configuration has its own evenly distributed sentinels.
        foreach(var group in groups.Values)
        {
            int checks=Math.Min(9,group.Count);
            for(int k=0;k<checks;k++)
            {
                token.ThrowIfCancellationRequested();
                int i=group[checks==1?0:(int)((long)k*(group.Count-1)/(checks-1))];
                var q=Queries[i].Key;
                double error=Math.Abs((double)values[i]-q.Noise.GetNoise2Dv(q.Position));
                if(!double.IsFinite(error))return null;
                maximumError=Math.Max(maximumError,error);
                if(error>MaximumNoiseError)return null;
            }
        }
        var accepted=new Dictionary<Key,float>(Count);
        for(int i=0;i<Count;i++)
        {
            if((i&1023)==0)token.ThrowIfCancellationRequested();
            if(!float.IsFinite(values[i]))return null;
            accepted.Add(Queries[i].Key,values[i]);
        }
        return new TerrainBiomeNoiseCache(accepted,report);
    }

    internal static TerrainBiomeNoisePlan Create(TerrainMeshBuilder builder,TerrainRingTopology topology,
        TerrainRingLayout.Patch patch,int resolution,bool filtered,bool refinement,CancellationToken token)
    {
        var result=new TerrainBiomeNoisePlan();
        if(builder._forest is null&&builder._savanna is null&&builder._swamp is null&&
           builder._jungle is null&&builder._mountain is null&&builder._tropical is null&&
           builder._badlands is null&&!builder._extras_enabled)return result;
        var regions=builder._native_regions;
        var visited=new HashSet<Vector2>();
        TerrainGpuSamplePlan.Visit(topology,patch,resolution,filtered,token,refinement,(x,z)=>
        {
            if(result.Full||Math.Abs(x)>TerrainGpuSampler.MaximumCoordinate||Math.Abs(z)>TerrainGpuSampler.MaximumCoordinate)return;
            // Exact world coordinates matter for the forest's affine publication
            // probe, so do not collapse distinct double coordinates to a float.
            if((double)(float)x!=x||(double)(float)z!=z)return;
            if(!visited.Add(new Vector2((float)x,(float)z)))return;
            var w=regions.weights(x,z);
            if(w.Y>0)result.PlanBiome(builder,1,x,z);
            if(w.Z>0)result.PlanBiome(builder,2,x,z);
            if(w.W>0)result.PlanBiome(builder,3,x,z);
            if(regions.jungle_weight>0)result.PlanBiome(builder,4,x,z);
            if(regions.mountain_weight>0)result.PlanBiome(builder,5,x,z);
            if(regions.tropical_weight>0)result.PlanBiome(builder,6,x,z);
            if(regions.badlands_weight>0)result.PlanBiome(builder,7,x,z);
            if(builder._extras_enabled)
            {
                for(int i=0;i<8;i++)if(regions.extra_weights[i]>0)result.PlanBiome(builder,8+i,x,z);
                // Organic overlays may contribute in non-alien land regions.
                if(regions.extra_weights[7]<=0&&builder._extras[7].AsGodotObject() is Biomes.BiomeExtensionSampler alien)
                    alien.PlanOverlayGpuNoise(result,x,z);
            }
        });
        return result;
    }
    internal void PlanBiome(TerrainMeshBuilder b,int family,double x,double z)
    {
        switch(family)
        {
            case 1:b._forest?.PlanGpuNoise(this,x,z);break;
            case 2:b._savanna?.PlanGpuNoise(this,x,z);break;
            case 3:b._swamp?.PlanGpuNoise(this,x,z);break;
            case 4:b._jungle?.PlanGpuNoise(this,x,z);break;
            case 5:b._mountain?.PlanGpuNoise(this,x,z);break;
            case 6:b._tropical?.PlanGpuNoise(this,x,z);break;
            case 7:b._badlands?.PlanGpuNoise(this,x,z);break;
            default:
                if(family>=8&&family<16&&b._extras[family-8].AsGodotObject() is Biomes.BiomeExtensionSampler extra)
                    extra.PlanGpuNoise(this,x,z);
                break;
        }
    }
}
