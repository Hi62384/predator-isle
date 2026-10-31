using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class SwampSamplerChecks
{
    internal static double MaximumScalarError { get; private set; }
    internal static void Run(Action<bool, string> require)
    {
        var script = GD.Load<GDScript>("res://scripts/swamp_sampler.gd"); var terrain = GD.Load<Resource>("res://config/world/terrain_settings.tres"); var config = terrain.Get("swamp").As<Resource>();
        foreach (long seed in new[] { 17L, 73921L, -17L })
        {
            using var originalBuilder = MigrationComparison.CreateReferenceTerrainBuilder(); using var currentBuilder = new PredatorIsle.Terrain.TerrainMeshBuilder();
            foreach (var builder in new[] { originalBuilder, currentBuilder }) { builder.Set("settings", terrain); builder.Set("world_seed", seed); builder.Set("water_level", 0.0); builder.Call("_configure_noise"); }
            require(currentBuilder.Get("_swamp").AsGodotObject() is SwampSampler, "Terrain builder did not use C# swamp sampler");
            using var old = script.New().AsGodotObject(); using var current = new SwampSampler(); old.Call("configure", config, seed, originalBuilder); current.configure(config, seed, (RefCounted)currentBuilder);
            var random = new Random(73921);
            for (int i = 0; i < 400; i++)
            {
                double x = i < 20 ? (i - 10) * 16 : random.NextDouble() * 40000 - 20000, z = i < 20 ? (i - 10) * -512 : random.NextDouble() * 40000 - 20000; bool publish = i % 3 != 0;
                double expected = old.Call("sample", x, z, publish).AsDouble(), actual = current.sample(x, z, publish);
                MaximumScalarError = Math.Max(MaximumScalarError, Math.Abs(expected - actual));
                require((float)expected == (float)actual && Math.Abs(expected - actual) <= 1e-12, $"Swamp height differs beyond extraction precision: seed={seed}, x={x:R}, z={z:R}, old={expected:R}, new={actual:R}");
                var state = old.Get("state").AsFloat64Array();
                if (state.Length == current.state.Length && state.Length > 0) MaximumScalarError = Math.Max(MaximumScalarError, state.Zip(current.state, (a,b) => Math.Abs(a-b)).Max());
                require(state.Length == current.state.Length && state.Zip(current.state, (a,b) => (float)a == (float)b && Math.Abs(a-b) <= 1e-12).All(equal => equal), $"Swamp hydrology differs beyond extraction precision: {seed}/{x:R}/{z:R}");
            }
            originalBuilder.Set("_swamp", old); currentBuilder.Set("_swamp", current);
            for (int i = 0; i < 100; i++)
            {
                double x = i * 137.25 - 7000, z = i * -91.5 + 3000;
                double expected = originalBuilder.Call("_swamp_height", x, z, .8, true).AsDouble(), actual = currentBuilder.Call("_swamp_height", x, z, .8, true).AsDouble();
                MaximumScalarError = Math.Max(MaximumScalarError, Math.Abs(expected - actual));
                require((float)expected == (float)actual && Math.Abs(expected - actual) <= 1e-12, $"Swamp terrain integration differs beyond extraction precision: {expected:R}/{actual:R}");
                require(GD.VarToBytes(originalBuilder.Get("_last_swamp")).SequenceEqual(GD.VarToBytes(currentBuilder.Get("_last_swamp"))), "Swamp packed material differs");
            }
        }
    }
}
