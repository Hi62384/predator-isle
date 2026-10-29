using Godot;
using System;
using System.Collections.Generic;
using D = Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

internal static class CaveFieldThermal
{
    internal static bool Append(CaveField f, D source)
    {
        if (f.thermal_sources.Count >= 2048 || !source.TryGetValue("point", out var p) || p.VariantType != Variant.Type.Vector3) return false;
        var point = p.AsVector3(); double radius = Num(source, "radius", double.NaN), height = Num(source, "height", double.NaN), strength = Num(source, "heat", double.NaN);
        if (!point.IsFinite() || !double.IsFinite(radius) || !double.IsFinite(height) || !double.IsFinite(strength) || radius <= 0 || radius > 96 || height <= 0 || height > 96 || strength < 0 || strength > 1) return false;
        if (!SafePoint(point)) return false;
        var first = f.cell(point - new Vector3((float)radius, 4, (float)radius)); var last = f.cell(point + new Vector3((float)radius, (float)(height + 8), (float)radius));
        long size = ((long)last.X - first.X + 1) * ((long)last.Y - first.Y + 1) * ((long)last.Z - first.Z + 1);
        if (size > 64 || f.thermal_references + size > 131072) return false;
        int index = f.thermal_sources.Count; f.thermal_sources.Add(source.Duplicate()); f.thermal_references += size;
        for (int z = first.Z; z <= last.Z; z++) for (int y = first.Y; y <= last.Y; y++) for (int x = first.X; x <= last.X; x++)
        {
            var key = new Vector3I(x, y, z); if (!f.ThermalBins.TryGetValue(key, out var bucket)) f.ThermalBins[key] = bucket = new(); bucket.Add(index);
        }
        f.InvalidatePacked(); return true;
    }
    internal static double SourceHeat(D source, Vector3 point)
    {
        var floor = source["point"].AsVector3(); double radius = new Vector2(point.X - floor.X, point.Z - floor.Z).Length() / Num(source, "radius");
        double vertical = Smooth(floor.Y - 4.0, floor.Y, point.Y) * (1 - Smooth(floor.Y + Num(source, "height"), floor.Y + Num(source, "height") + 8, point.Y));
        return Num(source, "heat") * (1 - Smooth(.55, 1, radius)) * vertical;
    }
    internal static double HeatAt(CaveField f, Vector3 point)
    {
        if (f.thermal_sources.Count == 0 || !point.IsFinite()) return 0;
        double result = 0;
        if (f.ThermalBins.TryGetValue(f.cell(point), out var bucket)) foreach (int index in bucket) result = Math.Max(result, SourceHeat(f.thermal_sources[index].AsGodotDictionary(), point));
        return result;
    }
    internal static bool HotBounds(CaveField f, Aabb bounds, double threshold)
    {
        if (f.thermal_sources.Count == 0) return false;
        var visited = new HashSet<int>(); var first = f.cell(bounds.Position); var last = f.cell(bounds.End);
        for (int z = first.Z; z <= last.Z; z++) for (int y = first.Y; y <= last.Y; y++) for (int x = first.X; x <= last.X; x++)
        {
            if (!f.ThermalBins.TryGetValue(new Vector3I(x, y, z), out var bucket)) continue;
            foreach (int index in bucket)
            {
                if (!visited.Add(index)) continue;
                var source = f.thermal_sources[index].AsGodotDictionary(); var point = source["point"].AsVector3(); point.Y += (float)(Num(source, "height") * .5);
                point = point.Clamp(bounds.Position, bounds.End);
                if (SourceHeat(source, point) > threshold) return true;
            }
        }
        return false;
    }
}
