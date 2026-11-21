using Godot;
using System;
using System.Diagnostics;
using PredatorIsle.Terrain;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>Identical numerical workloads for baseline/candidate CPU and allocation comparisons.</summary>
internal static class TerrainSamplingBenchmark
{
    internal static D Run()
    {
        using var resources = new TerrainBenchmarkResources();
        var source = resources.Retain(GD.Load<Resource>("res://config/world/terrain_settings.tres"));
        var measurements = new D();
        foreach (string preset in new[] { "default", "grass", "tropical" })
        {
            var settings = resources.Retain((TerrainConfiguration)source.DuplicateDeep(Resource.DeepDuplicateMode.All));
            if (preset != "default")
            {
                foreach (string biome in new[] { "grass", "forest", "savanna", "swamp", "jungle", "mountain", "tropical", "badlands", "quarry", "wise_mountains", "volcanic", "spore_forest", "radiation_wasteland", "crystal_wastes", "insect_colony", "alien_infected" })
                    settings.Set(biome + "_coverage", biome == preset ? 100.0 : 0.0);
                settings.alien_infected.Set("overlay_strength", 0.0);
                settings.beaches_enabled = settings.rocky_coast_enabled = false;
            }
            settings.island_size = 100400;
            settings.island_position_jitter = settings.island_size_variation = settings.island_coast_irregularity = 0;
            using var builder = new TerrainMeshBuilder { settings = settings, world_seed = 73921 };
            builder._configure_noise();
            // Warm method bodies and managed/native interop separately from the measured cache state.
            for (int i = 0; i < 64; i++) builder._get_height(i * 7.125, i * -9.375);
            foreach (bool withWater in new[] { false, true })
            {
                builder._configure_noise();
                long beforeAllocations = GC.GetAllocatedBytesForCurrentThread();
                long beforeEvaluations = builder._native_height.CanonicalEvaluations;
                var watch = Stopwatch.StartNew();
                ulong hash = 14695981039346656037UL;
                double sum = 0;
                const int count = 4096;
                for (int i = 0; i < count; i++)
                {
                    double x = (i % 64 - 32) * 17.125 + .25;
                    double z = (i / 64 - 32) * 19.375 - .5;
                    double h = withWater ? builder._get_height(x, z) : builder._sample_normal_height(x, z);
                    double water = withWater ? builder.get_water_surface_height(x, z) : 0;
                    sum += h + water;
                    hash = unchecked((hash ^ (ulong)BitConverter.DoubleToInt64Bits(h)) * 1099511628211UL);
                    hash = unchecked((hash ^ (ulong)BitConverter.DoubleToInt64Bits(water)) * 1099511628211UL);
                }
                watch.Stop();
                var result = new D
                {
                    ["queries"] = count,
                    ["elapsed_ms"] = watch.Elapsed.TotalMilliseconds,
                    ["managed_allocated_bytes"] = GC.GetAllocatedBytesForCurrentThread() - beforeAllocations,
                    ["canonical_evaluations"] = builder._native_height.CanonicalEvaluations - beforeEvaluations,
                    ["checksum"] = hash.ToString("x16"),
                    ["height_sum"] = sum
                };
                measurements[preset + (withWater ? "_height_and_water" : "_height_only")] = result;
                GD.Print($"Terrain sampling {preset} {(withWater ? "height+water" : "height")}: {Json.Stringify(result)}");
            }
        }
        return measurements;
    }
}
