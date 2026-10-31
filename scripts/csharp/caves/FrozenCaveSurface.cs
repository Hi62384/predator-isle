using Godot;
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using A = Godot.Collections.Array<string>;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
[Tool]
public partial class FrozenCaveSurface : RefCounted
{
    private const string Include = "\n#include \"res://shaders/cave_frozen_surface.gdshaderinc\"\nuniform vec4 cave_frozen_water_sources[8];\nuniform int cave_frozen_water_source_count=0;\nvarying float cave_frozen_weight;\nvarying vec3 cave_frozen_texture_position;\n";
    private static readonly Dictionary<string, ShaderMaterial> FeatureMaterials = new();
    public bool supports_weighted_blend() => true;
    public A validation_errors(D material, D features)
    {
        var result = new A();
        foreach (var setting in new[] { (material,"texture_metres",.5,20.0), (material,"normal_strength",0.0,2.0), (features,"density",0.0,1.0), (features,"curtain_chance",0.0,1.0), (features,"lake_radius_multiplier",1.0,3.0), (features,"lake_radius_minimum",3.0,12.0), (features,"lake_radius_maximum",3.0,12.0) })
        {
            if (!setting.Item1.ContainsKey(setting.Item2)) continue; var value = setting.Item1[setting.Item2];
            if (!Numeric(value) || !double.IsFinite(value.AsDouble()) || value.AsDouble() < setting.Item3 || value.AsDouble() > setting.Item4) result.Add("Invalid finite Frozen setting " + setting.Item2);
        }
        foreach (string name in new[] { "lake_ice", "large_lakes", "smooth_normals" }) if (features.ContainsKey(name) && features[name].VariantType != Variant.Type.Bool) result.Add("Frozen switch must be boolean: " + name);
        var low = Get(features, "lake_radius_minimum", 8); var high = Get(features, "lake_radius_maximum", 12);
        if (Numeric(low) && Numeric(high) && high.AsDouble() < low.AsDouble()) result.Add("Frozen lake radius bounds must be ordered"); return result;
    }
    private static bool Numeric(Variant value) => value.VariantType is Variant.Type.Int or Variant.Type.Float;
    private static Variant Get(D data, string key, Variant fallback) => data.ContainsKey(key) ? data[key] : fallback;
    public ShaderMaterial? feature_material(string kind, D configuration, bool common)
    {
        if (kind is not "ice" and not "thin_ice") return null; string key = kind + configuration + common;
        if (FeatureMaterials.TryGetValue(key, out var cached)) return cached;
        var shader = GD.Load<Shader>("res://shaders/cave_frozen_feature.gdshader");
        if (kind == "thin_ice") { shader = (Shader)shader.Duplicate(); string code = shader.Code.Replace("specular_schlick_ggx;", "specular_schlick_ggx,depth_prepass_alpha;", StringComparison.Ordinal); shader.Code = code.Insert(code.LastIndexOf('}'), "\n ALPHA=.82;\n"); }
        var result = new ShaderMaterial { Shader = shader }; bind(result, configuration); result.SetShaderParameter("cave_common_projection", common);
        if (FeatureMaterials.Count >= 8) { foreach (string oldest in FeatureMaterials.Keys) { FeatureMaterials.Remove(oldest); break; } }
        FeatureMaterials[key] = result; return result;
    }
    public string source(string original, int slot, bool entry)
    {
        if (slot < 0 || slot > 3 || original.Contains("varying float cave_frozen_weight;", StringComparison.Ordinal)) return "";
        bool rock = original.Contains("varying vec3 cave_position;", StringComparison.Ordinal); if (!rock && !(entry && original.Contains("varying vec3 forest_local_position;", StringComparison.Ordinal))) return "";
        int header = original.IndexOf("render_mode ", StringComparison.Ordinal); if (header < 0) return ""; int declaration = original.IndexOf(';', header); if (declaration < 0) return "";
        string code = original.Insert(declaration + 1, Include); var matches = Regex.Matches(code, @"void\s+vertex\s*\(\s*\)\s*\{"); if (matches.Count != 1) return "";
        string control = slot switch { 0 => "UV.x", 1 => "UV.y", 2 => "UV2.x", _ => "UV2.y" };
        code = code.Insert(matches[0].Index + matches[0].Length, "\n cave_frozen_weight=" + control + ";\n cave_frozen_texture_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(max(cave_frozen_texture_metres,.5)));\n"); int final = code.LastIndexOf('}'); if (final < 0) return "";
        string p = rock ? "cave_position" : "(forest_local_position+mod(forest_origin,vec3(3840.0)))", normal = rock ? "normalize(cave_normal)" : "normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz)";
        string amount = "clamp(cave_frozen_weight,0.0,1.0)" + (entry ? "*smoothstep(1.0,10.0,cave_entry_depth)" : ""); if (original.Contains("float cave_biome_control(", StringComparison.Ordinal)) amount = amount.Replace("clamp(cave_frozen_weight,0.0,1.0)", "cave_biome_control(cave_frozen_weight," + slot + ")", StringComparison.Ordinal);
        string world = rock ? "cave_world" : "(forest_local_position+forest_origin)";
        string blend = "\n vec3 frozen_p=" + p + ",frozen_n=" + normal + ";vec3 frozen_dx=dFdx(frozen_p),frozen_dy=dFdy(frozen_p);float frozen_amount=" + amount + ";if(frozen_amount>.00001){float frozen_moisture=0.0;for(int i=0;i<8;i++){if(i>=cave_frozen_water_source_count)break;vec4 water=cave_frozen_water_sources[i];frozen_moisture=max(frozen_moisture,1.0-smoothstep(water.w+10.0,water.w+72.0,length(" + world + "-water.xyz)));}float frozen_crust=(.12+.86*frozen_moisture)*mix(.45,1.0,smoothstep(.25,.8,abs(frozen_n.y)));frozen_amount*=frozen_crust;vec3 frozen_base,frozen_mapped;float frozen_rough;cave_frozen_sample(frozen_p,frozen_n,frozen_dx,frozen_dy,frozen_base,frozen_rough,frozen_mapped);vec3 frozen_previous=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);ALBEDO=mix(ALBEDO,frozen_base,frozen_amount);ROUGHNESS=mix(ROUGHNESS,frozen_rough,frozen_amount);SPECULAR=mix(SPECULAR,.28,frozen_amount);NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(frozen_previous,frozen_mapped,frozen_amount)),0.0)).xyz);EMISSION*=1.0-frozen_amount;}\n";
        blend = blend.Replace("cave_frozen_sample(frozen_p,frozen_n,", "cave_frozen_sample(frozen_p,cave_frozen_texture_position,frozen_n,", StringComparison.Ordinal); return code.Insert(final, blend);
    }
    public void bind_context(ShaderMaterial material, D context)
    {
        using var palette = new CaveMaterialPalette(); var pools = palette.water_sources(Get(context, "pools", new Godot.Collections.Array()).AsGodotArray()); var sources = new Vector4[8];
        for (int i = 0; i < 8 && i < pools.Count; i++) { var pool = pools[i].AsGodotDictionary(); if (pool.Count == 0) continue; var center = pool["center"].AsVector3(); sources[i] = new Vector4(center.X, (float)pool["water_y"].AsDouble(), center.Z, (float)pool["radius"].AsDouble()); }
        material.SetShaderParameter("cave_frozen_water_sources", sources); material.SetShaderParameter("cave_frozen_water_source_count", Math.Min(8, pools.Count));
    }
    public void bind(ShaderMaterial material, D configuration)
    {
        material.SetShaderParameter("cave_frozen_colors", GD.Load<Resource>("res://materials/cave_frozen_colors.tres")); material.SetShaderParameter("cave_frozen_normals", GD.Load<Resource>("res://materials/cave_frozen_normals.tres"));
        material.SetShaderParameter("cave_frozen_texture_metres", Math.Clamp(Get(configuration, "texture_metres", 6).AsDouble(), .5, 20)); material.SetShaderParameter("cave_frozen_normal_strength", Math.Clamp(Get(configuration, "normal_strength", .35).AsDouble(), 0, 2));
    }
}

