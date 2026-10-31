using Godot;
using System;
using System.Text;
using System.Text.RegularExpressions;

namespace PredatorIsle.Caves;
public partial class CaveBiomeBlend : RefCounted
{
    private static readonly string[] Outputs = { "ALBEDO", "NORMAL", "EMISSION", "ROUGHNESS", "SPECULAR", "METALLIC", "AO", "AO_LIGHT_AFFECT" };
    public double control(Vector4 weights, int slot, int count)
    { double later = 0; for (int i = slot + 1; i < count; i++) later += weights[i]; return Math.Clamp(weights[slot] / Math.Max(1 - later, .000001), 0, 1); }
    public string source(string original, int count) => source(original, count, false);
    public string source(string original, int count, bool independent_targets)
    {
        if (count <= 1) return original; if (count > 4 || original.Contains("varying vec4 cave_biome_raw_weights;", StringComparison.Ordinal)) return "";
        int render = original.IndexOf("render_mode ", StringComparison.Ordinal); if (render < 0) return ""; int declaration = original.IndexOf(';', render); if (declaration < 0) return "";
        string header = independent_targets ? "\nvarying vec4 cave_biome_raw_weights;\nfloat cave_biome_control(float own,int slot){return 1.0;}\n" : "\nvarying vec4 cave_biome_raw_weights;\nfloat cave_biome_control(float own,int slot){float later=0.0;for(int i=0;i<4;i++){if(i>slot&&i<" + count + ")later+=cave_biome_raw_weights[i];}return clamp(own/max(1.0-later,.000001),0.0,1.0);}\n";
        string code = original.Insert(declaration + 1, header); var matches = Regex.Matches(code, @"void\s+vertex\s*\(\s*\)\s*\{");
        return matches.Count != 1 ? "" : code.Insert(matches[0].Index + matches[0].Length, "\n cave_biome_raw_weights=vec4(UV,UV2);\n");
    }
    public string begin(int count)
    {
        var expression = new StringBuilder("1.0"); for (int i = 0; i < count; i++) expression.Append("-cave_biome_raw_weights[").Append(i).Append(']');
        var code = new StringBuilder("\nfloat cave_mix_default=max(0.0," + expression + ");\n");
        foreach (string name in Outputs) { string type = name is "ALBEDO" or "NORMAL" or "EMISSION" ? "vec3" : "float"; code.Append(type).Append(" cave_mix_base_").Append(name).Append('=').Append(name).Append(';').Append(type).Append(" cave_mix_sum_").Append(name).Append('=').Append(name).Append("*cave_mix_default;\n"); } return code.ToString();
    }
    public string restore() { var code = new StringBuilder("\n"); foreach (string name in Outputs) code.Append(name).Append("=cave_mix_base_").Append(name).Append(';'); return code.Append('\n').ToString(); }
    public string accumulate(int slot) { var code = new StringBuilder("\n"); foreach (string name in Outputs) code.Append("cave_mix_sum_").Append(name).Append("+=").Append(name).Append("*cave_biome_raw_weights[").Append(slot).Append("];"); return code.Append('\n').ToString(); }
    public string finish() { var code = new StringBuilder("\n"); foreach (string name in Outputs) code.Append(name).Append('=').Append(name == "NORMAL" ? "normalize(cave_mix_sum_NORMAL)" : "cave_mix_sum_" + name).Append(';'); return code.Append('\n').ToString(); }
}
