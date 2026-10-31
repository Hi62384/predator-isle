using Godot;
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using A = Godot.Collections.Array<string>;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
[Tool]
public partial class CrystalCaveSurface : RefCounted
{
    private static readonly Dictionary<string, ShaderMaterial> Materials = new();
    private static Variant Get(D d, string key, Variant fallback) => d.ContainsKey(key) ? d[key] : fallback;
    private static bool Numeric(Variant v) => v.VariantType is Variant.Type.Int or Variant.Type.Float;
    public bool supports_weighted_blend() => true;
    public A validation_errors(D material, D features)
    {
        var result = new A(); bool Valid(Variant v, double low, double high) => Numeric(v) && double.IsFinite(v.AsDouble()) && v.AsDouble() >= low && v.AsDouble() <= high;
        if (!Valid(Get(material, "ambient_shelter", .08), 0, 1)) result.Add("Invalid finite Crystal ambient_shelter");
        foreach (var setting in new[] { (material,"mineral_strength",0.0,1.0), (features,"density",0.0,1.0), (features,"giant_chance",0.0,1.0), (features,"maximum_height",1.0,40.0), (features,"geode_frequency",0.0,1.0), (features,"ravine_frequency",0.0,1.0), (features,"large_lake_frequency",0.0,1.0) }) if (!Valid(Get(setting.Item1, setting.Item2, setting.Item3), setting.Item3, setting.Item4)) result.Add("Invalid finite Crystal setting " + setting.Item2);
        if (material.ContainsKey("localized_veins") && material["localized_veins"].VariantType != Variant.Type.Bool) result.Add("Crystal material localized_veins must be boolean");
        if (!Valid(Get(features, "floor_ridge_height", .65), 0, 1)) result.Add("Invalid finite Crystal floor_ridge_height");
        foreach (string name in new[] { "chamber_growth", "selective_transmission", "mesh_lods", "geode_lining", "spanning_crystals", "crystal_debris", "localized_veins", "corridor_growth", "lake_chambers", "precise_shores", "luminous_minerals", "shallow_chambers", "floor_ridges" }) if (features.ContainsKey(name) && features[name].VariantType != Variant.Type.Bool) result.Add("Crystal switch must be boolean: " + name);
        foreach (var setting in new[] { (features,"luminous_region_chance",.005,1.0), (features,"luminous_form_chance",.12,1.0), (material,"luminous_strength",0.0,.05) }) if (!Valid(Get(setting.Item1, setting.Item2, setting.Item3), 0, setting.Item4)) result.Add("Invalid finite Crystal setting " + setting.Item2);
        if (!Valid(Get(features, "spanning_chance", .15), 0, 1)) result.Add("Invalid finite Crystal setting spanning_chance");
        foreach (var setting in new[] { (features,"debris_chance"), (material,"sediment_strength") }) if (!Valid(Get(setting.Item1, setting.Item2, 0.0), 0, 1)) result.Add("Invalid finite Crystal setting " + setting.Item2);
        if (Get(features, "geode_frequency", .15).AsDouble() + Get(features, "ravine_frequency", .08).AsDouble() > 1) result.Add("Geode and ravine room frequencies must sum to at most1"); return result;
    }
    public string source(string original, int slot, bool entry)
    {
        if (slot < 0 || slot > 3 || original.Contains("varying float cave_crystal_weight;", StringComparison.Ordinal)) return ""; bool rock = original.Contains("varying vec3 cave_position;", StringComparison.Ordinal);
        if (!rock && !(entry && original.Contains("varying vec3 forest_local_position;", StringComparison.Ordinal))) return ""; int header = original.IndexOf("render_mode ", StringComparison.Ordinal); if (header < 0) return ""; int declaration = original.IndexOf(';', header); if (declaration < 0) return "";
        string code = original.Insert(declaration + 1, "\n#include \"res://shaders/cave_crystal_surface.gdshaderinc\"\nuniform float cave_crystal_mineral_strength=.65;\nvarying float cave_crystal_weight;\n"); var matches = Regex.Matches(code, @"void\s+vertex\s*\(\s*\)\s*\{"); if (matches.Count != 1) return "";
        string control = slot switch { 0 => "UV.x", 1 => "UV.y", 2 => "UV2.x", _ => "UV2.y" }; code = code.Insert(matches[0].Index + matches[0].Length, "\n cave_crystal_weight=" + control + ";\n"); int final = code.LastIndexOf('}'); if (final < 0) return "";
        string p = rock ? "cave_position" : "(forest_local_position+mod(forest_origin,vec3(3840.0)))", amount = original.Contains("float cave_biome_control(", StringComparison.Ordinal) ? "cave_biome_control(cave_crystal_weight," + slot + ")" : "clamp(cave_crystal_weight,0.0,1.0)"; if (entry) amount += "*smoothstep(1.0,10.0,cave_entry_depth)";
        code = code.Insert(final, "\n float crystal_amount=" + amount + ";if(crystal_amount>.00001){float crystal_vein=cave_crystal_vein(" + p + ");float crystal_replace=crystal_amount*cave_crystal_mineral_strength*(.10+.70*crystal_vein);vec3 crystal_rock=ALBEDO;vec3 crystal_min=vec3(.67,.66,.59)*mix(.65,1.0,crystal_vein);ALBEDO=mix(crystal_rock,crystal_min,crystal_replace);ROUGHNESS=mix(ROUGHNESS,.27,crystal_replace);SPECULAR=mix(SPECULAR,.40,crystal_replace);EMISSION*=1.0-crystal_replace;}\n");
        if (rock)
        {
            code = code.Insert(code.IndexOf("varying float cave_crystal_weight;", StringComparison.Ordinal), "uniform float cave_crystal_sediment_strength=0.0;\n");
            code = code.Insert(code.LastIndexOf('}'), "\n if(cave_crystal_sediment_strength>.00001){vec3 crystal_floor_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);float crystal_sediment=crystal_amount*cave_crystal_sediment_strength*smoothstep(.65,.94,crystal_floor_normal.y)*smoothstep(.4,.7,ROUGHNESS)*cave_crystal_sediment(cave_position);if(crystal_sediment>.00001){ALBEDO=mix(ALBEDO,vec3(.52,.49,.42),crystal_sediment);ROUGHNESS=mix(ROUGHNESS,.83,crystal_sediment);SPECULAR=mix(SPECULAR,.22,crystal_sediment);}}\n");
        }
        return code;
    }
    public void bind(ShaderMaterial material, D configuration)
    {
        material.SetShaderParameter("cave_crystal_mineral_strength", Math.Clamp(Get(configuration, "mineral_strength", .65).AsDouble(), 0, 1)); material.SetShaderParameter("cave_crystal_sediment_strength", Math.Clamp(Get(configuration, "sediment_strength", 0).AsDouble(), 0, 1)); material.SetShaderParameter("cave_crystal_localized_veins", Get(configuration, "localized_veins", true).AsBool());
    }
    public ShaderMaterial? feature_material(string kind, D configuration, bool common)
    {
        if (kind is not "mineral_opaque" and not "mineral_clear" and not "mineral_grains" and not "mineral_bed") return null; string key = kind + configuration + common; if (Materials.TryGetValue(key, out var cached)) return cached;
        var shader = GD.Load<Shader>("res://shaders/cave_crystal_feature.gdshader");
        if (kind == "mineral_clear")
        {
            shader = (Shader)shader.Duplicate(); string code = shader.Code.Replace("varying vec3 crystal_position;", "uniform sampler2D cave_crystal_scene:hint_screen_texture,filter_linear_mipmap,repeat_disable;\nvarying vec3 crystal_position;", StringComparison.Ordinal);
            shader.Code = code.Replace("// SELECTIVE_NEAR_TRANSMISSION", "vec3 n=normalize(NORMAL),incident=-normalize(VIEW);float incidence=max(dot(-incident,n),0.0);float fresnel=f0+(1.0-f0)*pow(1.0-incidence,5.0);vec3 through=mineral_throughput(kind,UV.y,incidence,COLOR.rgb)*(1.0-fresnel);vec3 ray=refract(incident,n,1.0/mineral_ior(kind));vec2 shift=ray.xy/max(abs(ray.z),.35)*.004*clamp(UV.y/4.0,.05,1.0);vec3 behind=textureLod(cave_crystal_scene,clamp(SCREEN_UV+shift,vec2(.002),vec2(.998)),kind==2?1.5:0.5).rgb;ALBEDO*=1.0-dot(through,vec3(.3,.5,.2));EMISSION=behind*through;", StringComparison.Ordinal);
        }
        var result = new ShaderMaterial { Shader = shader }; result.SetShaderParameter("cave_common_projection", common); result.SetShaderParameter("cave_crystal_bed", kind == "mineral_bed"); result.SetShaderParameter("cave_crystal_luminous_strength", Get(configuration, "luminous_strength", 0.0)); result.SetShaderParameter("cave_crystal_ambient_shelter", Get(configuration, "ambient_shelter", .08));
        if (Materials.Count >= 8) { foreach (string oldest in Materials.Keys) { Materials.Remove(oldest); break; } } Materials[key] = result; return result;
    }
}
