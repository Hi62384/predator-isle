using Godot;
using System;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveMaterialPalette : RefCounted
{
    public D paths(int style) => paths(style, true);
    public D paths(int style, bool specialize_insect)
    {
        bool compact = style == 6 && specialize_insect;
        return new D { ["colors"] = compact ? "res://materials/cave_insect_colors.tres" : "res://materials/cave_colors.tres", ["normals"] = compact ? "res://materials/cave_insect_normals.tres" : "res://materials/cave_normals.tres", ["compact"] = compact };
    }
    public A water_sources(A pools)
    {
        var result = new A(); foreach (var value in pools) { var pool = value.AsGodotDictionary(); if (!pool.ContainsKey("fluid_kind") || pool["fluid_kind"].AsString() == "water") result.Add(pool); } return result;
    }
    public void bind(ShaderMaterial material, int style) => bind(material, style, new A(), true);
    public void bind(ShaderMaterial material, int style, A pools) => bind(material, style, pools, true);
    public void bind(ShaderMaterial material, int style, A pools, bool specialize_insect)
    {
        pools = water_sources(pools); var bank = paths(style, specialize_insect);
        material.SetShaderParameter("cave_rock_colors", GD.Load<Resource>(bank["colors"].AsString())); material.SetShaderParameter("cave_rock_normals", GD.Load<Resource>(bank["normals"].AsString())); material.SetShaderParameter("cave_compact_palette", bank["compact"]); material.SetShaderParameter("geological_style", style);
        var positions = new Vector4[4];
        for (int i = 0; i < 4 && i < pools.Count; i++) { var pool = pools[i].AsGodotDictionary(); if (pool.Count == 0) continue; var center = pool["center"].AsVector3(); positions[i] = new Vector4(center.X, (float)pool["water_y"].AsDouble(), center.Z, (float)pool["radius"].AsDouble()); }
        material.SetShaderParameter("cave_pool_positions", positions); material.SetShaderParameter("cave_pool_count", Math.Min(4, pools.Count));
    }
}
