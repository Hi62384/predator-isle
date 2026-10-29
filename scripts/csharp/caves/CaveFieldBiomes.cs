using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

internal static class CaveFieldBiomes
{
    private static readonly GDScript Regions = GD.Load<GDScript>("res://scripts/caves/biome_regions.gd");
    internal static void Bind(CaveField f, int feature, string from, string to, double first, double last, double length)
    {
        var a = Regions.Call("along_edge", f._biome_assignment, from, to, first, length).AsGodotDictionary()["weights"].AsGodotDictionary();
        var b = Regions.Call("along_edge", f._biome_assignment, from, to, last, length).AsGodotDictionary()["weights"].AsGodotDictionary();
        foreach (var pair in f.BiomeFields) pair.Value[feature] = new Vector2((float)Num(a, pair.Key), (float)Num(b, pair.Key));
        f.InvalidatePacked();
    }
    internal static A Ids(CaveField f, Vector3I key)
    {
        if (f.BiomeFields.Count == 0 || f._biome_locks.ContainsKey(new Vector2I((int)Math.Floor(key.X / 24.0), (int)Math.Floor(key.Z / 24.0)))) return new();
        var found = new HashSet<string>(); var first = key * 4;
        for (int z = 0; z < 4; z++) for (int y = 0; y < 4; y++) for (int x = 0; x < 4; x++)
        {
            if (!f.Bins.TryGetValue(first + new Vector3I(x, y, z), out var features)) continue;
            foreach (int feature in features)
                foreach (var pair in f.BiomeFields) { var weights = pair.Value[feature]; if (Math.Max(weights.X, weights.Y) > .00001) found.Add(pair.Key); }
        }
        var result = new A(); foreach (string id in found.OrderBy(id => id, StringComparer.Ordinal)) result.Add(id); return result;
    }
    internal static Vector4 Weights(CaveField f, Vector3 point, A ids)
    {
        double admission = Admission(f, point); if (admission <= 0) return Vector4.Zero;
        double best = Far; var result = Vector4.Zero;
        if (f.Bins.TryGetValue(f.bin_cell(point), out var features))
            foreach (int feature in features)
            {
                double value = f.Evaluate(point, new[] { feature }); if (value >= Far || value > best) continue;
                if (value < best) { best = value; result = Vector4.Zero; }
                var ab = f.Directions[feature]; var begin = f.Begins[feature];
                double t = Math.Clamp(new Vector2(point.X - begin.X, point.Z - begin.Z).Dot(ab) / f.SpanSquared[feature], 0, 1);
                for (int i = 0; i < Math.Min(4, ids.Count); i++)
                {
                    if (!f.BiomeFields.TryGetValue(ids[i].AsString(), out var field)) continue;
                    var weights = field[feature]; result[i] = (float)Math.Max(result[i], Lerp(weights.X, weights.Y, t));
                }
            }
        double total = (double)result.X + result.Y + result.Z + result.W;
        if (total > 1) result /= (float)total;
        if (f.thermal_sources.Count > 0)
        {
            int frost = -1; for (int i = 0; i < ids.Count; i++) if (ids[i].AsString() == "frozen") { frost = i; break; }
            if (frost >= 0 && frost < 4 && result[frost] > 0)
            {
                double heat = f.heat_at(point);
                if (heat > .08)
                {
                    double oldFrost = result[frost]; result[frost] = (float)(result[frost] * (1 - Smooth(.08, .35, heat))); double remaining = 1 - oldFrost + result[frost];
                    result = remaining > .000001 ? result / (float)remaining : Vector4.Zero;
                }
            }
        }
        return result * (float)admission;
    }
    internal static double Admission(CaveField f, Vector3 point)
    {
        if (f._biome_locks.Count == 0) return 1;
        var region = new Vector2I((int)Math.Floor(point.X / 1536.0), (int)Math.Floor(point.Z / 1536.0)); double nearest = double.PositiveInfinity;
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var id = region + new Vector2I(x, z); if (!f._biome_locks.ContainsKey(id)) continue;
            double dx = Math.Max(Math.Max(id.X * 1536.0 - point.X, point.X - (id.X + 1) * 1536.0), 0);
            double dz = Math.Max(Math.Max(id.Y * 1536.0 - point.Z, point.Z - (id.Y + 1) * 1536.0), 0); nearest = Math.Min(nearest, Math.Sqrt(dx * dx + dz * dz));
        }
        return Smooth(0, 32, nearest);
    }
}
