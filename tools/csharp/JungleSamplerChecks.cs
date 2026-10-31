using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class JungleSamplerChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var script = GD.Load<GDScript>("res://scripts/jungle_sampler.gd");
        var config = GD.Load<Resource>("res://config/world/terrain_settings.tres").Get("jungle").As<Resource>();
        foreach (long seed in new[] { 17L, 73921L, -17L })
        {
            using var old = script.New().AsGodotObject(); using var current = new JungleSampler(); old.Call("configure", config, seed); current.configure(config, seed);
            var random = new Random(73921);
            for (int i = 0; i < 800; i++)
            {
                double x = i < 20 ? (i - 10) * 64 : random.NextDouble() * 40000 - 20000;
                double z = i < 20 ? (i - 10) * -512 : random.NextDouble() * 40000 - 20000;
                bool publish = i % 3 != 0;
                double expected = old.Call("sample", x, z, publish).AsDouble(), actual = current.sample(x, z, publish);
                require(expected == actual, $"Jungle height differs: seed={seed}, x={x:R}, z={z:R}, old={expected:R}, new={actual:R}");
                foreach (string name in new[] { "weights", "wetness", "drainage", "rock", "region", "river", "lake" })
                    require(GD.VarToBytes(old.Get(name)).SequenceEqual(GD.VarToBytes(current.Get(name))), $"Jungle state differs: {name} seed={seed}, x={x:R}, z={z:R}");
            }
        }
        using var originalBuilder = MigrationComparison.CreateReferenceTerrainBuilder();
        using var currentBuilder = new PredatorIsle.Terrain.TerrainMeshBuilder();
        var terrain = GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);
        foreach(var item in terrain.GetPropertyList())
        {
            string name=item["name"].AsString();if(name.EndsWith("_coverage",StringComparison.Ordinal))terrain.Set(name,name=="jungle_coverage"?100:0);
        }
        terrain.Set("beaches_enabled",false);terrain.Set("rocky_coast_enabled",false);
        foreach (var builder in new[] { originalBuilder, currentBuilder })
        { builder.Set("settings", terrain); builder.Set("world_seed", 73921); builder.Set("water_level", 0.0); builder.Call("_configure_noise"); }
        using var originalSampler = script.New().AsGodotObject(); originalSampler.Call("configure", config, 73921); originalBuilder.Set("_jungle", originalSampler);
        require(currentBuilder.Get("_jungle").AsGodotObject() is JungleSampler, "Terrain builder did not use C# jungle sampler");
        for (int i = 0; i < 100; i++)
        {
            double x = i * 137.25 - 7000, z = i * -91.5 + 3000;
            require(originalBuilder.Call("_jungle_height", x, z, .8, true).AsDouble() == currentBuilder.Call("_jungle_height", x, z, .8, true).AsDouble(), "Jungle water/terrain integration differs");
            require(GD.VarToBytes(originalBuilder.Get("_last_jungle")).SequenceEqual(GD.VarToBytes(currentBuilder.Get("_last_jungle"))), "Jungle packed terrain material differs");
        }
        var placement = GD.Load<GDScript>("res://scripts/jungle_placement.gd");bool positive=false;
        for(int i=0;i<100;i++)
        {
            double x=i*137.25-7000,z=i*-91.5+3000;var expected=placement.Call("habitat",originalBuilder,x,z);var actual=placement.Call("habitat",currentBuilder,x,z);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Jungle placement habitat interface differs: "+MigrationComparison.FirstDifference(expected,actual));positive|=actual.AsGodotDictionary()["jungle"].AsDouble()>0;
        }
        require(positive,"Jungle placement interface fixture did not reach a positive habitat query");
    }
}

