using System;
using System.Text.RegularExpressions;

namespace PredatorIsle.Caves;

/// <summary>Fit every composed entrance into seventeen custom varying locations.</summary>
internal static class CaveVaryingPacking
{
    private static readonly string[] FrozenCarriers = { "swamp_land", "mountain_control", "mountain_geology" };
    private static readonly string[] Weights = { "cave_frozen_weight", "cave_crystal_weight", "cave_magma_weight" };
    internal static string Pack(string source)
    {
        // Interior shaders and the original reference interface use their own
        // layout. Finalize only after all native terrain adapters are composed.
        if (!source.Contains("varying vec4 terrain_forest_local_values;", StringComparison.Ordinal)
            || source.Contains("// PACKED_CAVE_ENTRANCE_VARYINGS", StringComparison.Ordinal)
            || source.Contains("cave_biome_raw_weights[3]", StringComparison.Ordinal)) return source;
        string result = source;
        // Independent targets are shaded at full strength, then combined with
        // the original raw weights. The constant helper ignores these scalar
        // arguments, so their producers/interpolators have no effect.
        if (result.Contains("float cave_biome_control(float own,int slot){return 1.0;}", StringComparison.Ordinal))
            foreach (string name in Weights)
            {
                if (!result.Contains("varying float " + name + ";", StringComparison.Ordinal)) continue;
                string assignment = @"\b" + name + @"=UV2?\.[xy];";
                string control = @"cave_biome_control\(" + name + @",[0-3]\)";
                if (Regex.Matches(result, assignment).Count != 1 || Regex.Matches(result, control).Count != 1) return "";
                result = Regex.Replace(result, assignment, "");
                result = Regex.Replace(result, control, "1.0");
                result = result.Replace("varying float " + name + ";", "", StringComparison.Ordinal);
            }
        const string depth = "varying float cave_entry_depth;";
        if (!result.Contains(depth, StringComparison.Ordinal)) return "";
        result = result.Replace(depth, "varying vec4 cave_entrance_values;\n#define cave_entry_depth cave_entrance_values.w", StringComparison.Ordinal);
        const string raw = "varying vec4 cave_biome_raw_weights;";
        if (result.Contains(raw, StringComparison.Ordinal))
        {
            // The registry contains three optional cave biomes. Keep their
            // three exact float values; the fourth raw component is never read.
            const string assignment = "cave_biome_raw_weights=vec4(UV,UV2);";
            if (!result.Contains(assignment, StringComparison.Ordinal)) return "";
            result = result.Replace(raw, "#define cave_biome_raw_weights vec4(cave_entrance_values.xyz,0.0)", StringComparison.Ordinal);
            result = result.Replace(assignment, "cave_entrance_values.xyz=vec3(UV,UV2.x);", StringComparison.Ordinal);
        }
        else
        {
            int lane = 0;
            foreach (string name in Weights)
                if (result.Contains("varying float " + name + ";", StringComparison.Ordinal))
                    result = result.Replace("varying float " + name + ";",
                        "#define " + name + " cave_entrance_values." + "xyz"[lane++], StringComparison.Ordinal);
        }
        const string textureDeclaration = "varying vec3 cave_frozen_texture_position;";
        if (result.Contains(textureDeclaration, StringComparison.Ordinal))
        {
            const string assignment = "cave_frozen_texture_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(max(cave_frozen_texture_metres,.5)));";
            if (!result.Contains(assignment, StringComparison.Ordinal)) return "";
            var lanes = new string[3];
            for (int i = 0; i < FrozenCarriers.Length; i++)
            {
                string name = FrozenCarriers[i], declaration = "varying vec3 " + name + ";", packed = "cave_packed_" + name;
                if (!result.Contains(declaration, StringComparison.Ordinal)) return "";
                result = result.Replace(declaration, "varying vec4 " + packed + ";\n#define " + name + " " + packed + ".xyz", StringComparison.Ordinal);
                lanes[i] = packed + ".w";
            }
            result = result.Replace(textureDeclaration,
                "#define cave_frozen_texture_position vec3(" + string.Join(',', lanes) + ")", StringComparison.Ordinal);
            result = result.Replace(assignment,
                "vec3 cave_packed_frozen_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(max(cave_frozen_texture_metres,.5)));"
                + lanes[0] + "=cave_packed_frozen_position.x;" + lanes[1] + "=cave_packed_frozen_position.y;"
                + lanes[2] + "=cave_packed_frozen_position.z;", StringComparison.Ordinal);
        }
        return "// PACKED_CAVE_ENTRANCE_VARYINGS\n" + result;
    }
}
