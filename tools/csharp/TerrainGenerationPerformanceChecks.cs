using Godot;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Security.Cryptography;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

/// <summary>A repeatable generation workload, separate from full-world frame-rate measurements.</summary>
internal static class TerrainGenerationPerformanceChecks
{
    internal static D Measurements { get; private set; } = new();
    internal const long Seed = 73921;
    internal const int Resolution = 16;
    internal static readonly int[] Levels = { 0, 2, 4 };

    internal static TerrainRingLayout.Patch Patch(int level)
    {
        double size = 16 * Math.Pow(3, level);
        return new TerrainRingLayout.Patch(new Vector3I(0, (int)Math.Floor(70 / size), level), size, TerrainRingLayout.Mask.None);
    }

    private static TerrainMeshBuilder Builder(Resource settings, TerrainBenchmarkResources resources)
    {
        var builder = new TerrainMeshBuilder
        {
            settings = resources.Retain(settings.DuplicateDeep(Resource.DeepDuplicateMode.All)),
            world_seed = Seed,
            water_level = 0
        };
        builder._configure_noise();
        return builder;
    }

    internal static void Run(Action<bool, string> require)
    {
        using var resources = new TerrainBenchmarkResources();
        var settings = resources.Retain(GD.Load<Resource>("res://config/world/terrain_settings.tres"));
        // Warm JIT and shared engine code without warming the measured builders' caches.
        using (var warm = Builder(settings, resources))
            new TerrainRingMeshGeometry(new TerrainRingTopology()).Build(warm, Patch(0), Resolution);
        var records = new A();
        foreach (int level in Levels)
        {
            var configured = Stopwatch.StartNew();
            using var builder = Builder(settings, resources);
            double configureMs = configured.Elapsed.TotalMilliseconds;
            var record = MeasurePatch(builder, new TerrainRingMeshGeometry(new TerrainRingTopology()), Patch(level), require);
            record["configure_ms"] = configureMs;
            records.Add(record);
        }
        Measurements = new D
        {
            ["seed"] = Seed,
            ["resolution"] = Resolution,
            ["repetitions"] = 1,
            ["processor_count"] = System.Environment.ProcessorCount,
            ["records"] = records,
            ["scope"] = "Three direct full terrain-product builds from fresh builders using the saved world settings. Includes surface, normals, features, structures, refinement, and collision products. Excludes scene streaming, GPU upload, physics installation, and frame rate. Warm JIT; each measured builder has cold terrain caches. Timings depend on the machine and must be compared on the same environment."
        };
    }

    internal static D MeasurePatch(TerrainMeshBuilder builder, TerrainRingMeshGeometry geometry,
        TerrainRingLayout.Patch patch, Action<bool, string> require)
    {
        var stages = new Dictionary<string, double>(StringComparer.Ordinal);
        string current = "setup";
        long previous = Stopwatch.GetTimestamp();
        void Stage(string next)
        {
            long now = Stopwatch.GetTimestamp();
            stages[current] = stages.GetValueOrDefault(current) + (now - previous) * 1000.0 / Stopwatch.Frequency;
            previous = now;
            current = next;
        }
        long beforeBytes = GC.GetAllocatedBytesForCurrentThread();
        long beforeSamples = builder._native_height.CanonicalEvaluations;
        long start = Stopwatch.GetTimestamp();
        var data = geometry.Build(builder, patch, Resolution, stage: Stage);
        long end = Stopwatch.GetTimestamp();
        long bytes = GC.GetAllocatedBytesForCurrentThread() - beforeBytes;
        stages[current] = stages.GetValueOrDefault(current) + (end - previous) * 1000.0 / Stopwatch.Frequency;
        require(data.Products is not null && data.Products.Vertices.Length == data.Topology.VertexCount, "Performance case lost terrain vertices");
        foreach (var vertex in data.Products!.Vertices) require(vertex.IsFinite(), "Performance case produced a non-finite terrain vertex");
        require(patch.Key.Z > 1 || data.AuthoritativeGround.Count > 0, "Near performance case lost authoritative collision ground");
        var stageData = new D();
        foreach (var pair in stages) stageData[pair.Key] = pair.Value;
        return new D
        {
            ["level"] = patch.Key.Z,
            ["origin_x"] = patch.OriginX,
            ["origin_z"] = patch.OriginZ,
            ["size_metres"] = patch.Size,
            ["build_ms"] = (end - start) * 1000.0 / Stopwatch.Frequency,
            ["managed_allocated_bytes"] = bytes,
            ["canonical_evaluations"] = builder._native_height.CanonicalEvaluations - beforeSamples,
            ["vertices"] = data.Products.Vertices.Length,
            ["surface_sha256"] = Hash(GD.VarToBytes(data.Arrays)),
            ["authoritative_ground_sha256"] = Hash(GD.VarToBytes(data.AuthoritativeGround)),
            ["stage_ms"] = stageData
        };
    }

    private static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
}
