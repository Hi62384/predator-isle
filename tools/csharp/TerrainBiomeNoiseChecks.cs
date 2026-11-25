using Godot;
using System;
using System.Threading;
using System.Threading.Tasks;
using PredatorIsle.Terrain;
using PredatorIsle.Biomes;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

namespace PredatorIsle.Checks;

/// <summary>Actual shader execution and consumption of raw GPU noise in all
/// fifteen non-grassland numerical samplers. No reference geometry is altered.</summary>
internal static class TerrainBiomeNoiseChecks
{
    internal static async Task<D> Run(Node host,Action<bool,string> require)
    {
        using var resources=new TerrainBenchmarkResources();
        var settings=TerrainGpuPipelineChecks.GrassSettings();
        settings.Set("grass_coverage",0.0);
        string[] families=["forest","savanna","swamp","jungle","mountain","tropical","badlands",
            "quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"];
        foreach(var family in families)settings.Set(family+"_coverage",100.0);
        resources.Retain(settings);
        using var reference=TerrainGpuPipelineChecks.Builder(settings);
        using var candidate=TerrainGpuPipelineChecks.Builder(settings);
        var points=new Vector2[24];
        for(int i=0;i<points.Length;i++)
            points[i]=new Vector2(-1180+i*31.25f,2500+i*19.5f);
        var plan=new TerrainBiomeNoisePlan();
        for(int family=1;family<=15;family++)
        foreach(var point in points)plan.PlanBiome(candidate,family,point.X,point.Y);
        require(plan.Count>512&&plan.Count<TerrainBiomeNoisePlan.MaximumQueries,
            "All-biome GPU noise fixture did not plan a bounded numerical batch");
        var baker=new TerrainBiomeNoiseGpu{RequestTimeoutSeconds=120};
        host.AddChild(baker);
        try
        {
            require(baker.Available,"Biome noise render pass unavailable");
            var cache=await baker.BakeAsync(plan);
            require(cache is not null,"Biome GPU noise rejected: "+baker.LastFailure);
            if(cache is null)throw new InvalidOperationException("Biome GPU noise was not accepted");
            double maximum=0;
            foreach(var query in plan.Queries)
            {
                var key=query.Key;
                require(cache.TryRead(key.Noise,key.Position,out float value),"GPU noise cache lost a planned point");
                double error=Math.Abs((double)value-key.Noise.GetNoise2Dv(key.Position));
                maximum=Math.Max(maximum,error);
                require(error<=TerrainBiomeNoisePlan.MaximumNoiseError,"GPU noise differs from canonical FastNoiseLite at "+key.Position+": "+error);
            }
            var results=new A();
            for(int family=1;family<=15;family++)
            {
                long before=cache.Hits;double maxHeight=0;
                foreach(var point in points)
                {
                    double expected=Height(reference,family,point);
                    double actual;
                    using(cache.Activate())actual=Height(candidate,family,point);
                    maxHeight=Math.Max(maxHeight,Math.Abs(expected-actual));
                    require(double.IsFinite(actual)&&Math.Abs(expected-actual)<=.01,
                        "GPU numerical noise changed "+families[family-1]+" height beyond 1 cm");
                }
                require(cache.Hits>before,"GPU noise was never consumed by "+families[family-1]);
                results.Add(new D{["biome"]=families[family-1],["cache_hits"]=cache.Hits-before,["maximum_height_error"]=maxHeight});
            }
            require(baker.CompletedScalars==plan.Count&&baker.CacheHits==cache.Hits,
                "GPU numerical noise telemetry did not measure actual consumed samples");
            using var cancelled=new CancellationTokenSource();cancelled.Cancel();
            require(await baker.BakeAsync(plan,cancelled.Token) is null,"Cancelled biome noise request did not fall back");
            return new D{["families"]=results,["noise_scalars"]=plan.Count,["maximum_noise_error"]=maximum};
        }
        finally{baker.Shutdown();baker.Free();}
    }
    private static double Height(TerrainMeshBuilder b,int family,Vector2 p)=>family switch
    {
        1=>b._forest!.sample(p.X,p.Y),2=>b._savanna!.sample(p.X,p.Y),3=>b._swamp!.sample(p.X,p.Y),
        4=>b._jungle!.sample(p.X,p.Y),5=>b._mountain!.sample(p.X,p.Y),6=>b._tropical!.sample(p.X,p.Y),
        7=>b._badlands!.sample(p.X,p.Y),
        _=>((BiomeExtensionSampler)b._extras[family-8].AsGodotObject()!).sample(p.X,p.Y)
    };
}
