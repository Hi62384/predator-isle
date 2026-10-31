using Godot;
using System;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class MagmaCaveLighting : RefCounted
{
    public D settings { get; set; } = new();
    public OmniLight3D? light { get; set; }
    public string source_id { get; set; } = "";
    public Vector3I source_key { get; set; } = new(int.MaxValue, int.MaxValue, int.MaxValue);
    private Vector3 _lastPoint = Vector3.Inf; private ulong _lastUsec;
    private static Variant Get(D d, string key, Variant fallback) => d.ContainsKey(key) ? d[key] : fallback;
    public void configure(D configuration) { settings = configuration.Duplicate(true); _lastPoint = Vector3.Inf; _lastUsec = 0; }
    public bool uploaded(Node3D stream, Vector3I key, string pool_id)
    {
        var cells = stream.Get("_cells").AsGodotDictionary(); var node = cells.ContainsKey(key) ? cells[key].As<Node3D>() : null;
        if (!GodotObject.IsInstanceValid(node) || !node.IsVisibleInTree()) return false;
        var molten = node.GetNodeOrNull<Node3D>("CaveBiome_magma_molten_volcanic");
        return GodotObject.IsInstanceValid(molten) && molten.IsVisibleInTree() && molten.GetMeta("source_basins", new A()).AsGodotArray().Contains(pool_id);
    }
    public void update(Node3D stream, Vector3 point)
    {
        var bundle = stream.Get("_bundle").AsGodotDictionary();
        if (!point.IsFinite() || bundle.Count == 0 || !Get(settings, "lava_lighting", true).AsBool() || Get(settings, "lava_light_energy", .9).AsDouble() <= 0)
        { if (GodotObject.IsInstanceValid(light)) light!.Visible = false; return; }
        if (GodotObject.IsInstanceValid(light) && !uploaded(stream, source_key, source_id)) light!.Visible = false;
        ulong now = Time.GetTicksUsec(); if (_lastPoint.IsFinite() && _lastPoint.DistanceSquaredTo(point) < 1 && now - _lastUsec < 250000) return;
        _lastPoint = point; _lastUsec = now; var best = new D(); double distance = double.PositiveInfinity;
        foreach (var item in Get(bundle, "regions", new A()).AsGodotArray())
        foreach (var value in Get(item.AsGodotDictionary(), "pools", new A()).AsGodotArray())
        {
            var pool = value.AsGodotDictionary(); if (Get(pool, "fluid_kind", "").AsString() != "magma" || Get(pool, "source_heat", 0).AsDouble() < .5 || Get(pool, "thermal_source", "").AsString().Length == 0) continue;
            var center = pool["center"].AsVector3(); var p = new Vector3(center.X, (float)pool["water_y"].AsDouble(), center.Z); double reach = Math.Min(80, Math.Max(48, pool["radius"].AsDouble() * 3 + 24)), squared = point.DistanceSquaredTo(p);
            if (squared > reach * reach || squared > distance) continue;
            var key = new Vector3I((int)Math.Floor(p.X / 64.0), (int)Math.Floor(p.Y / 64.0), (int)Math.Floor(p.Z / 64.0));
            if (!uploaded(stream, key, pool["id"].AsString()) || squared == distance && best.Count > 0 && string.CompareOrdinal(pool["id"].AsString(), best["id"].AsString()) >= 0) continue;
            best = pool; distance = squared; source_key = key;
        }
        if (best.Count == 0) { if (GodotObject.IsInstanceValid(light)) light!.Visible = false; source_id = ""; return; }
        if (!GodotObject.IsInstanceValid(light)) { light = new OmniLight3D { Name = "CaveNearestMoltenLight", LightColor = new Color(1, .23f, .035f), ShadowEnabled = true }; stream.AddChild(light); }
        var location = best["center"].AsVector3(); light!.Position = new Vector3(location.X, (float)(best["water_y"].AsDouble() + .9), location.Z); light.OmniRange = (float)Math.Clamp(best["radius"].AsDouble() * 3, 12, 48);
        light.LightEnergy = (float)(Get(settings, "lava_light_energy", .9).AsDouble() * (.5 + .5 * Math.Clamp(best["source_heat"].AsDouble(), 0, 1)));
        var host = stream.Get("host").AsGodotObject(); var shadows = GodotObject.IsInstanceValid(host) ? host.Get("terrain_shadows") : default;
        light.ShadowEnabled = !GodotObject.IsInstanceValid(host) || shadows.VariantType != Variant.Type.Bool || shadows.AsBool(); light.Visible = true; source_id = best["id"].AsString();
        light.SetMeta("source_pool", source_id); light.SetMeta("source_id", best["thermal_source"]); light.SetMeta("source_kind", Get(best, "heat_source_kind", "explicit_diagnostic_intrusion"));
    }
    public void release() { if (GodotObject.IsInstanceValid(light)) light!.Free(); light = null; source_id = ""; _lastPoint = Vector3.Inf; _lastUsec = 0; }
}
