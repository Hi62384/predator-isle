using Godot;
using System;
using PredatorIsle.Terrain;

namespace PredatorIsle.Caves;

/// <summary>Bind known C# scalar callbacks without a native Variant round trip per probe.</summary>
internal static class CaveHeightSampler
{
    internal static bool TrySamplePair(Callable surface, Callable water, double x, double z,
        out double ground, out double level)
    {
        if (surface.Target is TerrainMeshBuilder terrain && water.Target == terrain &&
            (surface.Method == "_sample_normal_height" || surface.Method == "_get_height") &&
            water.Method == "get_water_surface_height")
        {
            // The published query already computes both fields. The following water
            // read reuses its state, including raised biome water and coastal levels.
            ground = terrain._sample_grid_height(x, z);
            level = terrain.get_water_surface_height(x, z);
            return true;
        }
        ground = level = 0;
        return false;
    }
    internal static bool CanShortCircuit(Callable surface)=>surface.Target is TerrainMeshBuilder&&surface.Method=="_sample_normal_height";
    internal static Func<double,double,double> Bind(Callable surface)
    {
        if(surface.Delegate is Func<double,double,double> managed)return managed;
        if(surface.Target is TerrainMeshBuilder terrain)
        {
            if(surface.Method=="_sample_normal_height")return terrain._sample_normal_height;
            if(surface.Method=="_get_height")return terrain._get_height;
            if(surface.Method=="get_water_surface_height")return terrain.get_water_surface_height;
        }
        if(surface.Target is CaveSurfaceContext context){
            if(surface.Method=="grid_height")return context.grid_height;
            if(surface.Method=="height_at")return context.height_at;
        }
        // Preserve custom providers and original GDScript comparison callbacks.
        return (x,z)=>surface.Call(x,z).AsDouble();
    }
}
