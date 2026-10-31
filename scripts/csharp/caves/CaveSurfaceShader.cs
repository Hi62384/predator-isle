using Godot;
using System;
using System.Text;

namespace PredatorIsle.Caves;
public partial class CaveSurfaceShader : RefCounted
{
    public ShaderInclude Extensions { get; set; } = GD.Load<ShaderInclude>("res://shaders/biome_extensions.gdshaderinc");
    private static readonly (string Name, int Width)[] Layout = {
        ("geology_control",3),("jungle_control",3),("forest_control",3),("forest_ecology",3),("forest_geology",2),("savanna_control",3),("savanna_geology",3),("savanna_water",3),("savanna_surface",3),("swamp_control",3),("swamp_hydro",3),("swamp_land",3),("swamp_ecology",3),("mountain_control",3),("mountain_geology",3),("mountain_shape",3),("mountain_wet",1),("terrain_surface",2),("coast_control",3),("coast_sediment",1),("beach_control",2),("tropical_control",3),("badlands_control",2),("swamp_water_level",1),("UV.y",1),("COLOR",4) };
    private const string Begin = "\n geology_control=CUSTOM0.xyz;", End = "\n}\n// Shared jittered junctions";
    public string load_texels()
    {
        var code = new StringBuilder("\n int surface_base=VERTEX_ID*17;\n");
        for (int i = 0; i < 17; i++) code.Append($" vec4 surface_p{i}=texelFetch(cave_surface_payload,ivec2((surface_base+{i})%1024,(surface_base+{i})/1024),0);\n");
        return code.ToString();
    }
    public string component(int index) => $"surface_p{index / 4}[{index % 4}]";
    public string uniforms() => uniforms(false, false, false);
    public string uniforms(bool parent_space) => uniforms(parent_space, false, false);
    public string uniforms(bool parent_space, bool entry_transition) => uniforms(parent_space, entry_transition, false);
    public string uniforms(bool parent_space, bool entry_transition, bool hive_entry)
    {
        string result = "\nuniform sampler2D cave_surface_payload:filter_nearest,repeat_disable;\n";
        if (parent_space) result += "uniform vec3 cave_parent_offset=vec3(0);\nuniform vec3 cave_parent_origin=vec3(0);\n";
        if (entry_transition) result += "varying float cave_entry_depth;\n" + (hive_entry ? "uniform bool cave_hive_entry_material=true;\n" : "#include \"res://shaders/cave_entry_rock.gdshaderinc\"\n");
        return result;
    }
    private static int Count(string source, string token)
    { int count = 0, start = 0; while ((start = source.IndexOf(token, start, StringComparison.Ordinal)) >= 0) { count++; start += token.Length; } return count; }
    public string code(string original) => code(original, false, false, false, false);
    public string code(string original, bool parent_space) => code(original, parent_space, false, false, false);
    public string code(string original, bool parent_space, bool entry_transition) => code(original, parent_space, entry_transition, false, false);
    public string code(string original, bool parent_space, bool entry_transition, bool hive_entry) => code(original, parent_space, entry_transition, hive_entry, false);
    public string code(string original, bool parent_space, bool entry_transition, bool hive_entry, bool common_projection)
    {
        if (Count(original, Begin) != 1 || Count(original, End) != 1) return "";
        int begin = original.IndexOf(Begin, StringComparison.Ordinal), end = original.IndexOf(End, begin, StringComparison.Ordinal);
        if (end <= begin) return "";
        var replacement = new StringBuilder(load_texels()); int offset = 0;
        foreach (var item in Layout)
        {
            replacement.Append(' ').Append(item.Name).Append('='); if (item.Width > 1) replacement.Append("vec").Append(item.Width).Append('(');
            for (int i = 0; i < item.Width; i++) { if (i > 0) replacement.Append(','); replacement.Append(component(offset++)); }
            replacement.Append(item.Width > 1 ? ");\n" : ";\n");
        }
        if (offset != 67) throw new InvalidOperationException("Unexpected terrain surface payload layout");
        replacement.Append(" UV.x=swamp_water_level;forest_local_position=VERTEX").Append(parent_space ? "+cave_parent_offset" : "").Append(";forest_origin=").Append(parent_space ? "cave_parent_origin" : "MODEL_MATRIX[3].xyz").Append(";\n");
        if (entry_transition) replacement.Append(" cave_entry_depth=surface_p16.w;\n");
        string result = original[..begin].Replace("void vertex() {", uniforms(parent_space, entry_transition, hive_entry) + "\nvoid vertex() {", StringComparison.Ordinal) + replacement + original[end..];
        if (hive_entry && entry_transition)
        {
            string biology = Extensions.Code;
            const string coverage = "float coverage=family==3?feature*patch*(1.0-rock*.65):.65+feature*.35;";
            const string pigment = "color=mix(color,bio*.55,clamp(coverage,0.0,1.0));rough=tissue_rough;";
            const string relief = "if(abs(denominator)>.000001)gradient-=clamp((r1*dFdx(height)+r2*dFdy(height))/denominator,vec3(-.25),vec3(.25))*extension_normals[family]*fine;";
            const string include = "#include \"res://shaders/biome_extensions.gdshaderinc\"";
            if (Count(biology, coverage) != 1 || Count(biology, pigment) != 1 || Count(biology, relief) != 1 || Count(result, include) != 1) return "";
            biology = biology.Replace(coverage, coverage + "\n float cave_hive_amount=family==7 && cave_hive_entry_material?smoothstep(1.0,10.0,cave_entry_depth):0.0;coverage=mix(coverage,1.0,cave_hive_amount);", StringComparison.Ordinal);
            biology = biology.Replace(pigment, "color=mix(color,bio*mix(.55,.5,cave_hive_amount),clamp(coverage,0.0,1.0));rough=tissue_rough;", StringComparison.Ordinal);
            biology = biology.Replace(relief, "vec3 cave_hive_gradient=vec3(0);if(abs(denominator)>.000001)cave_hive_gradient=-clamp((r1*dFdx(height)+r2*dFdy(height))/denominator,vec3(-.25),vec3(.25))*extension_normals[family]*fine;gradient+=cave_hive_gradient;gradient=mix(gradient,cave_hive_gradient,cave_hive_amount);", StringComparison.Ordinal);
            result = result.Replace(include, biology, StringComparison.Ordinal);
        }
        if (entry_transition)
        {
            int final = result.LastIndexOf("\n}", StringComparison.Ordinal); if (final < 0) return "";
            result = result[..final] + (hive_entry ? HiveBlend : RockBlend) + result[final..];
        }
        return common_projection ? CaveVertexProjection.Source(result) : result;
    }
    private const string RockBlend = "\n" + """
 if(debug_view==0 && ground_debug==0 && cliff_normal_debug==0){
  float entry_amount=smoothstep(1.0,10.0,cave_entry_depth);
  if(entry_amount>.0001){
   vec3 entry_base,entry_mapped;float entry_rough;
   vec3 entry_position=forest_local_position+mod(forest_origin,vec3(3840.0));
   shade_cave_entry(entry_position,n,dFdx(entry_position),dFdy(entry_position),entry_base,entry_rough,entry_mapped);
   vec3 entry_previous=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0)).xyz);
   ALBEDO=mix(ALBEDO,entry_base,entry_amount);ROUGHNESS=mix(ROUGHNESS,entry_rough,entry_amount);SPECULAR=mix(SPECULAR,.2,entry_amount);EMISSION*=1.0-entry_amount;
   AO=mix(AO,.08,entry_amount);AO_LIGHT_AFFECT=0.0;
   NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(entry_previous,entry_mapped,entry_amount)),0)).xyz);
  }
 }
""" + "\n";
    private const string HiveBlend = "\n" + """
 if(debug_view==0 && ground_debug==0 && cliff_normal_debug==0){
  float entry_amount=smoothstep(1.0,10.0,cave_entry_depth);
  AO=mix(AO,.08,entry_amount);AO_LIGHT_AFFECT=0.0;EMISSION*=1.0-entry_amount;
 }
""" + "\n";
}
