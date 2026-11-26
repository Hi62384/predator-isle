using Godot;
using System;

namespace PredatorIsle.Terrain;

/// <summary>Register and retain worker helper script handles on the main thread.
/// First-use loading on competing workers can reach a fatal null-script binding.
/// </summary>
internal static class TerrainWorkerScripts
{
    private static CSharpScript[]? retained;
    internal static int RetainedCount => retained?.Length ?? 0;
    internal static void Prepare()
    {
        if (OS.GetThreadCallerId() != OS.GetMainThreadId())
            throw new InvalidOperationException("Terrain worker scripts must be registered on the main thread.");
        if (retained is not null) return;
        string[] paths =
        {
            "res://scripts/csharp/terrain/BiomeStructureGeometry.cs",
            "res://scripts/csharp/terrain/RetainedLiquidGeometry.cs",
            "res://scripts/csharp/terrain/TerrainFeatureMeshes.cs",
            "res://scripts/csharp/terrain/LodBiomeStructureGeometry.cs",
            "res://scripts/csharp/terrain/StructureCollisionIndex.cs",
            "res://scripts/csharp/terrain/TerrainCollision.cs",
            "res://scripts/csharp/biomes/AlienTissueCoordinates.cs"
        };
        var scripts = new CSharpScript[paths.Length];
        for (int i = 0; i < paths.Length; i++)
        {
            scripts[i] = GD.Load<CSharpScript>(paths[i]);
            if (scripts[i] is null || !scripts[i].CanInstantiate())
                throw new InvalidOperationException("Cannot initialize terrain worker script: " + paths[i]);
        }
        // Strong references keep registration alive through cache eviction and GC.
        retained = scripts;
    }
}
