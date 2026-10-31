using Godot;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveBiomeMaterials : RefCounted
{
    private readonly CaveBiomeBlend _blend = new(); private readonly Dictionary<string, Shader> _shaders = new(); private readonly Queue<string> _ring = new();
    public Resource? definition(Resource? registry, string id)
    {
        if (registry == null) return null; foreach (var value in registry.Get("definitions").AsGodotArray()) { var item = value.As<Resource>(); if (item.Get("biome_id").AsString() == id) return item; } return null;
    }
    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    private static Script? Provider(Resource? definition) => definition?.Get("surface_provider").As<Script>();
    private static string Fingerprint(Script script) => script is CSharpScript ? script.ResourcePath + "/" + typeof(CaveBiomeMaterials).Assembly.ManifestModule.ModuleVersionId : Hash(script.SourceCode);
    public Shader? shader(Shader original, A ids, Resource? registry) => shader(original, ids, registry, false);
    public Shader? shader(Shader original, A ids, Resource? registry, bool entry)
    {
        if (ids.Count == 0) return original;
        string key = Hash(original.Code) + "/" + ids + "/" + entry + "/independent_targets_v1/csharp/" + typeof(CaveBiomeBlend).Assembly.ManifestModule.ModuleVersionId;
        foreach (var id in ids)
        {
            var provider = Provider(definition(registry, id.AsString())); if (provider == null) return null;
            if (ids.Count > 1) { using var adapter = provider.Call("new").AsGodotObject(); if (!adapter.HasMethod("supports_weighted_blend") || !adapter.Call("supports_weighted_blend").AsBool()) return null; }
            key += "/" + Fingerprint(provider);
        }
        if (_shaders.TryGetValue(key, out var cached)) return cached;
        string code = _blend.source(original.Code, ids.Count, true); if (code.Length == 0) return null;
        if (ids.Count > 1) code = code.Insert(code.LastIndexOf('}'), _blend.begin(ids.Count));
        for (int slot = 0; slot < ids.Count; slot++)
        {
            var item = definition(registry, ids[slot].AsString()); var provider = Provider(item); if (provider == null) return null;
            if (ids.Count > 1) code = code.Insert(code.LastIndexOf('}'), _blend.restore());
            using var adapter = provider.Call("new").AsGodotObject(); code = adapter.Call("source", code, slot, entry).AsString(); if (code.Length == 0) return null;
            if (ids.Count > 1) code = code.Insert(code.LastIndexOf('}'), _blend.accumulate(slot));
        }
        if (ids.Count > 1) code = code.Insert(code.LastIndexOf('}'), _blend.finish());
        var result = new Shader { Code = code }; if (_ring.Count >= 16) _shaders.Remove(_ring.Dequeue()); _ring.Enqueue(key); _shaders[key] = result; return result;
    }
    public void bind(ShaderMaterial material, A ids, Resource? registry) => bind(material, ids, registry, new D());
    public void bind(ShaderMaterial material, A ids, Resource? registry, D context)
    {
        foreach (var id in ids)
        {
            var item = definition(registry, id.AsString()); var provider = Provider(item); if (provider == null) continue;
            using var adapter = provider.Call("new").AsGodotObject(); adapter.Call("bind", material, item!.Get("material_configuration")); if (adapter.HasMethod("bind_context")) adapter.Call("bind_context", material, context);
        }
    }
}
