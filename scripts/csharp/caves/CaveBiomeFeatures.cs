using Godot;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveBiomeFeatures : RefCounted
{
    public const int MaximumVertices = 240000;
    private static Variant Get(D d, string key, Variant fallback) => d.ContainsKey(key) ? d[key] : fallback;
    private static Variant ObjectValue(GodotObject? value) => value == null ? default : Variant.From(value);
    public D decorate(D region, Resource? configuration, long seed_id, Callable height) => decorate(region, configuration, seed_id, height, null);
    public D decorate(D region, Resource? configuration, long seed_id, Callable height, GodotObject? thermal_context)
    {
        if (configuration == null) return region; var registry = configuration.Get("biome_regions").As<Resource>(); if (!registry.Get("enabled").AsBool()) return region;
        foreach (var value in registry.Get("definitions").AsGodotArray())
        {
            var definition = value.As<Resource>(); var script = definition.Get("feature_provider").As<Script>(); if (!definition.Get("enabled").AsBool() || script == null) continue;
            using var provider = script.Call("new").AsGodotObject();
            if (provider.HasMethod("decorate_region_with_context")) region = provider.Call("decorate_region_with_context", region, height, seed_id, definition.Get("feature_configuration"), configuration.Get("maximum_depth_metres"), configuration.Get("minimum_rock_cover_metres"), ObjectValue(thermal_context)).AsGodotDictionary();
            else if (provider.HasMethod("decorate_region")) region = provider.Call("decorate_region", region, height, seed_id, definition.Get("feature_configuration"), configuration.Get("maximum_depth_metres"), configuration.Get("minimum_rock_cover_metres")).AsGodotDictionary();
        }
        return thermal_context != null ? thermal_context.Call("annotate_region", region).AsGodotDictionary() : region;
    }
    public D build(GodotObject field, Vector3I key, long seed_id, A regions, Resource? registry, D water)
    {
        var batches = new A(); int count = 0; if (registry == null || !registry.Get("enabled").AsBool()) return new D { ["valid"] = true, ["batches"] = batches };
        var ids = field is CaveField native ? native.biome_ids_for_cell(key) : field.Call("biome_ids_for_cell", key).AsGodotArray();
        foreach (var value in registry.Get("definitions").AsGodotArray())
        {
            var definition = value.As<Resource>(); var script = definition.Get("feature_provider").As<Script>(); string id = definition.Get("biome_id").AsString();
            if (!definition.Get("enabled").AsBool() || script == null || !ids.Contains(id)) continue;
            using var provider = script.Call("new").AsGodotObject(); var result = provider.Call("build", field, key, seed_id, regions, definition.Get("feature_configuration"), water).AsGodotDictionary();
            if (!Get(result, "valid", false).AsBool()) return new D { ["valid"] = false, ["reason"] = Get(result, "reason", "Invalid cave biome feature result"), ["batches"] = new A() };
            foreach (var item in Get(result, "batches", new A()).AsGodotArray())
            {
                var batch = item.AsGodotDictionary(); count += batch["arrays"].AsGodotArray()[(int)Mesh.ArrayType.Vertex].AsVector3Array().Length;
                if (count > MaximumVertices) return new D { ["valid"] = false, ["reason"] = "Cave biome feature vertex bound exceeded", ["batches"] = new A() };
                batch["biome_id"] = id; batches.Add(batch);
            }
        }
        return new D { ["valid"] = true, ["batches"] = batches };
    }
}
