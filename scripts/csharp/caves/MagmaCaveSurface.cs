using Godot;
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using A = Godot.Collections.Array<string>;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
[Tool]
public partial class MagmaCaveSurface : RefCounted
{
    private static readonly Dictionary<string, ShaderMaterial> FeatureMaterials = new(); private static readonly Dictionary<string, ImageTexture> FeatureTextures = new();
    private static Variant Get(D d, string key, Variant fallback) => d.ContainsKey(key) ? d[key] : fallback;
    private static bool Numeric(Variant v) => v.VariantType is Variant.Type.Float or Variant.Type.Int;
    public bool supports_weighted_blend() => true;
    public A validation_errors(D material, D features)
    {
        var errors = new A();
        void Range(D d, string name, double fallback, double maximum, string limit)
        { var value = Get(d, name, fallback); if (!Numeric(value) || !double.IsFinite(value.AsDouble()) || value.AsDouble() < 0 || value.AsDouble() > maximum) errors.Add("Magma " + name + " must be finite0–" + limit); }
        Range(material, "cooled_strength", .65, 1, "1"); Range(features, "density", .65, 1, "1"); Range(features, "active_pool_chance", .14, 1, "1");
        foreach (string id in new[] { "chamber_growth", "mesh_lods", "source_heat", "geological_intrusions", "cooled_tubes", "large_lake_chambers", "cooled_deposits", "cooled_intrusions", "chamber_variety", "molten_cascades" }) if (features.ContainsKey(id) && features[id].VariantType != Variant.Type.Bool) errors.Add("Magma " + id + " must be boolean");
        Range(features, "large_lake_chance", .08, 1, "1"); Range(material, "lava_light_energy", .9, 2, "2"); if (material.ContainsKey("lava_lighting") && material["lava_lighting"].VariantType != Variant.Type.Bool) errors.Add("Magma lava_lighting must be boolean");
        Range(features, "deposit_height", .45, .6, "0.6m"); Range(features, "molten_cascade_chance", .06, 1, "1");
        foreach (var spec in new[] { (material,"lava_emission_strength",1.9,4.0), (material,"lava_animation_speed",1.0,4.0), (material,"lava_crust_strength",1.0,1.0), (material,"lava_normal_strength",1.0,1.0), (features,"column_frequency",.75,1.0), (features,"obsidian_lens_chance",.12,1.0), (features,"tube_frequency",1.0,1.0), (features,"fissure_frequency",.12,1.0), (features,"intrusion_frequency",.55,1.0), (features,"lava_drip_frequency",.1,1.0) }) Range(spec.Item1, spec.Item2, spec.Item3, spec.Item4, Variant.From(spec.Item4).AsString());
        var quality = Get(material, "lava_detail_quality", 1); if (quality.VariantType != Variant.Type.Int || quality.AsInt64() < 0 || quality.AsInt64() > 2) errors.Add("Magma lava_detail_quality must be integer0–2"); return errors;
    }
    public MagmaCaveLighting? create_runtime_controller(D configuration)
    { if (!Get(configuration, "lava_lighting", true).AsBool() || Get(configuration, "lava_light_energy", .9).AsDouble() <= 0) return null; var controller = new MagmaCaveLighting(); controller.configure(configuration); return controller; }
    public string source(string original, int slot, bool entry)
    {
        if (slot < 0 || slot > 3 || original.Contains("varying float cave_magma_weight;", StringComparison.Ordinal)) return ""; bool rock = original.Contains("varying vec3 cave_position;", StringComparison.Ordinal);
        if (!rock && !(entry && original.Contains("varying vec3 forest_local_position;", StringComparison.Ordinal))) return "";
        int header = original.IndexOf("render_mode ", StringComparison.Ordinal); if (header < 0) return ""; int declaration = original.IndexOf(';', header); if (declaration < 0) return "";
        string code = original.Insert(declaration + 1, "\n#include \"res://shaders/cave_magma_surface.gdshaderinc\"\nuniform float cave_magma_cooled_strength=.85;\nvarying float cave_magma_weight;\n"); var matches = Regex.Matches(code, @"void\s+vertex\s*\(\s*\)\s*\{"); if (matches.Count != 1) return "";
        string control = slot switch { 0 => "UV.x", 1 => "UV.y", 2 => "UV2.x", _ => "UV2.y" }; code = code.Insert(matches[0].Index + matches[0].Length, "\n cave_magma_weight=" + control + ";\n");
        string amount = original.Contains("float cave_biome_control(", StringComparison.Ordinal) ? "cave_biome_control(cave_magma_weight," + slot + ")" : "clamp(cave_magma_weight,0.0,1.0)"; if (entry) amount += "*smoothstep(1.0,10.0,cave_entry_depth)";
        return code.Insert(code.LastIndexOf('}'), "\n float magma_cooled=" + amount + "*cave_magma_cooled_strength;if(magma_cooled>.00001){magma_cooled_surface(" + (rock ? "cave_position" : "forest_local_position") + ",magma_cooled,VERTEX,ALBEDO,NORMAL,ROUGHNESS,SPECULAR,EMISSION);}\n");
    }
    public void bind(ShaderMaterial material, D configuration) => material.SetShaderParameter("cave_magma_cooled_strength", Get(configuration, "cooled_strength", .85));
    public ShaderMaterial? feature_material(string kind, D configuration, bool common)
    {
        if (kind is not "cooled_volcanic" and not "molten_volcanic") return null; string key = kind + (common ? "true" : "false") + Convert.ToHexString(GD.VarToBytes(configuration)).ToLowerInvariant(); if (FeatureMaterials.TryGetValue(key, out var cached)) return cached;
        var material = new ShaderMaterial { Shader = GD.Load<Shader>(kind == "molten_volcanic" ? "res://shaders/cave_magma_molten.gdshader" : "res://shaders/cave_magma_cooled.gdshader") };
        if (kind == "cooled_volcanic")
        {
            if (FeatureTextures.Count == 0) { FeatureTextures["volcanic_color"] = ImageTexture.CreateFromImage(GD.Load<Image>("res://materials/mountain_color_massive_rock.res")); FeatureTextures["volcanic_normal"] = ImageTexture.CreateFromImage(GD.Load<Image>("res://materials/cave_normal_Rock051.res")); }
            foreach (var pair in FeatureTextures) material.SetShaderParameter(pair.Key, pair.Value);
        }
        else foreach (var pair in new[] { ("lava_emission_strength", (Variant)1.9), ("lava_animation_speed", (Variant)1.0), ("lava_crust_strength", (Variant)1.0), ("lava_normal_strength", (Variant)1.0), ("lava_detail_quality", (Variant)1) }) material.SetShaderParameter(pair.Item1, Get(configuration, pair.Item1, pair.Item2));
        material.SetShaderParameter("cave_common_projection", common); while (FeatureMaterials.Count >= 16) { foreach (string oldest in FeatureMaterials.Keys) { FeatureMaterials.Remove(oldest); break; } } FeatureMaterials[key] = material; return material;
    }
}

