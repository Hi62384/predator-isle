using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class SavannaSamplerChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var script = GD.Load<GDScript>("res://scripts/savanna_sampler.gd");
        var config = GD.Load<Resource>("res://config/world/terrain_settings.tres").Get("savanna").As<Resource>();
        foreach (long seed in new[] { 17L, 73921L, -17L })
        {
            using var old = script.New().AsGodotObject(); using var current = new SavannaSampler(); old.Call("configure", config, seed); current.configure(config, seed);
            var random = new Random(73921);
            for (int i = 0; i < 800; i++)
            {
                double x = i < 20 ? (i - 10) * 64 : random.NextDouble() * 40000 - 20000;
                double z = i < 20 ? (i - 10) * -512 : random.NextDouble() * 40000 - 20000;
                bool publish = i % 3 != 0;
                double expected = old.Call("sample", x, z, publish).AsDouble(), actual = current.sample(x, z, publish);
                require(expected == actual, $"Savanna height differs: seed={seed}, x={x:R}, z={z:R}, old={expected:R}, new={actual:R}");
                foreach (string name in new[] { "weights", "wetness", "drainage", "rock", "aridity", "laterite", "soil", "erosion", "water", "region", "river", "lake" })
                    require(GD.VarToBytes(old.Get(name)).SequenceEqual(GD.VarToBytes(current.Get(name))), $"Savanna state differs: {name} seed={seed}, x={x:R}, z={z:R}");
            }
        }
        using var originalBuilder = MigrationComparison.CreateReferenceTerrainBuilder();
        using var currentBuilder = new PredatorIsle.Terrain.TerrainMeshBuilder();
        var terrain = GD.Load<Resource>("res://config/world/terrain_settings.tres");
        foreach (var builder in new[] { originalBuilder, currentBuilder })
        { builder.Set("settings", terrain); builder.Set("world_seed", 73921); builder.Set("water_level", 0.0); builder.Call("_configure_noise"); }
        using var originalSampler = script.New().AsGodotObject(); originalSampler.Call("configure", config, 73921); originalBuilder.Set("_savanna", originalSampler);
        require(currentBuilder.Get("_savanna").AsGodotObject() is SavannaSampler, "Terrain builder did not use C# savanna sampler");
        for (int i = 0; i < 100; i++)
        {
            double x = i * 137.25 - 7000, z = i * -91.5 + 3000;
            require(originalBuilder.Call("_savanna_height", x, z, .8, true).AsDouble() == currentBuilder.Call("_savanna_height", x, z, .8, true).AsDouble(), "Savanna water/terrain integration differs");
            require(GD.VarToBytes(originalBuilder.Get("_last_savanna")).SequenceEqual(GD.VarToBytes(currentBuilder.Get("_last_savanna"))), "Savanna packed terrain material differs");
        }
    }
}

