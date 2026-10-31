using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array<string>;

namespace PredatorIsle.Caves;
[Tool]
public partial class CaveBiomeRegionSettings : Resource
{
    [Export] public bool enabled { get; set; } = true;
    [Export] public Godot.Collections.Array<Resource> definitions { get; set; } = new() { GD.Load<Resource>("res://config/caves/biomes/default_cave_definition.tres") };
    [Export] public StringName fallback_biome_id { get; set; } = "default";
    [Export] public float[] depth_bands { get; set; } = { 0, 40, 100, 180, 280, 400 };
    public int discovery_halo()
    {
        if (enabled) foreach (var definition in definitions)
            if (definition != null && definition.Get("enabled").AsBool() && definition.Get("spawn_chance_percent").AsDouble() > 0 && definition.Get("maximum_extent_metres").AsDouble() > 1536) return 2;
        return 1;
    }
    public A validation_errors()
    {
        var errors = new A(); var ids = new HashSet<string>(StringComparer.Ordinal); bool fallback = false;
        if (definitions.Count == 0 || definitions.Count > 16) errors.Add("Registry requires1–16definitions");
        if (depth_bands.Length != 6) errors.Add("Depth bands require six ordered boundaries");
        else
        {
            for (int i = 0; i < 6; i++)
                if (!float.IsFinite(depth_bands[i]) || i > 0 && depth_bands[i] <= depth_bands[i - 1]) errors.Add("Depth bands must be finite and strictly increasing");
            if (depth_bands[0] != 0) errors.Add("Depth bands begin at the real terrain surface");
        }
        foreach (var definition in definitions)
        {
            if (definition == null || !definition.HasMethod("validation_errors")) { errors.Add("Invalid cave biome definition"); continue; }
            foreach (var error in definition.Call("validation_errors").AsGodotArray()) errors.Add(error.AsString());
            string id = definition.Get("biome_id").AsString();
            if (!ids.Add(id)) errors.Add("Duplicate cave biome ID " + id);
            if (id == fallback_biome_id.ToString() && definition.Get("enabled").AsBool()) fallback = true;
        }
        if (!fallback) errors.Add("An enabled Default fallback is required;unassigned cave air never disappears");
        return errors;
    }
}
