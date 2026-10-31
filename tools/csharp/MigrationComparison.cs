using Godot;
using System;
using System.Linq;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
namespace PredatorIsle.Checks;
internal static class MigrationComparison
{
    // Adapt only the resource declaration to the migrated saved configuration;
    // keep the preserved scalar algorithms and their independent sampler state.
    internal static GodotObject CreateReferenceTerrainBuilder()
    {
        var source=FileAccess.GetFileAsString("res://tools/reference/terrain_mesh_builder_pre_csharp_fields.gd")
            .Replace("var settings: TerrainSettings =", "var settings =")
            .Replace(":=", "=")
            .Replace("TerrainSettings.EXTENSION_KEYS", "[\"quarry\",\"wise_mountains\",\"volcanic\",\"spore_forest\",\"radiation_wasteland\",\"crystal_wastes\",\"insect_colony\",\"alien_infected\"]");
        var script=new GDScript { SourceCode=source };
        if(script.Reload()!=Error.Ok) throw new InvalidOperationException("Reference terrain fixture failed to compile");
        return script.New().AsGodotObject();
    }
    internal static string FirstDifference(Variant expected, Variant actual, string path = "$")
    {
        if (GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual))) return "";
        if (expected.VariantType != actual.VariantType) return $"{path}: type {expected.VariantType} / {actual.VariantType}";
        if(expected.VariantType==Variant.Type.Vector3){var a=expected.AsVector3();var b=actual.AsVector3();return $"{path}: ({a.X:R},{a.Y:R},{a.Z:R}) / ({b.X:R},{b.Y:R},{b.Z:R})";}
        if (expected.VariantType == Variant.Type.Dictionary)
        {
            var a = expected.AsGodotDictionary(); var b = actual.AsGodotDictionary(); if (a.Count != b.Count) return $"{path}: dictionary count {a.Count}/{b.Count}; keys [{string.Join(",",a.Keys)}] / [{string.Join(",",b.Keys)}]";
            var ak = a.Keys.ToArray(); var bk = b.Keys.ToArray();
            for (int i = 0; i < a.Count; i++)
            {
                var key = ak[i]; if (!b.ContainsKey(key)) return path + ": missing key " + key;
                if (key.VariantType != bk[i].VariantType || !GD.VarToBytes(key).SequenceEqual(GD.VarToBytes(bk[i]))) return $"{path}: key order/type {key}({key.VariantType}) / {bk[i]}({bk[i].VariantType})";
                string diff = FirstDifference(a[key], b[key], path + "." + key); if (diff.Length > 0) return diff;
            }
        }
        if (expected.VariantType == Variant.Type.PackedVector2Array)
        {
            var a = expected.AsVector2Array(); var b = actual.AsVector2Array(); if (a.Length != b.Length) return $"{path}: point count {a.Length}/{b.Length}";
            for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return $"{path}[{i}]: ({a[i].X:R},{a[i].Y:R}) / ({b[i].X:R},{b[i].Y:R})";
        }
        if (expected.VariantType == Variant.Type.Array)
        {
            var a = expected.AsGodotArray(); var b = actual.AsGodotArray(); if (a.Count != b.Count) return $"{path}: array count {a.Count}/{b.Count}";
            for (int i = 0; i < a.Count; i++) { string diff = FirstDifference(a[i], b[i], path + "[" + i + "]"); if (diff.Length > 0) return diff; }
        }
        if (expected.VariantType == Variant.Type.PackedVector3Array)
        {
            var a = expected.AsVector3Array(); var b = actual.AsVector3Array(); if (a.Length != b.Length) return $"{path}: point count {a.Length}/{b.Length}";
            for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return $"{path}[{i}]: ({a[i].X:R},{a[i].Y:R},{a[i].Z:R}) / ({b[i].X:R},{b[i].Y:R},{b[i].Z:R})";
        }
        return $"{path}: {expected} / {actual}";
    }
}
