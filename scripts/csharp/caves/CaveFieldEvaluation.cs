using Godot;
using System;
using System.Collections.Generic;
using D = Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

internal static class CaveFieldEvaluation
{
    internal static double Evaluate(CaveField f, Vector3 point, IEnumerable<int> features)
    {
        double closed = Far, opening = Far, floorOffset = 0;
        if (f.floor_relief.Count > 0)
            foreach (int feature in features)
                if (f.Kinds[feature] == 2 && Math.Abs((double)point.Y - f.Begins[feature].Y) <= 5)
                {
                    foreach (var pair in f.floor_relief) floorOffset = Math.Max(floorOffset, FloorRelief.Offset(f, point, pair.Value.AsDouble(), pair.Key.AsString()));
                    break;
                }
        double wall = Math.Sin(point.X * .71 + Math.Sin(point.Y * .23)) * Math.Sin(point.Z * .53 + point.Y * .41) * .12;
        foreach (int feature in features)
        {
            var a = f.Begins[feature]; var b = f.Ends[feature]; var size = f.Dimensions[feature]; double floorY = a.Y, radius;
            if (f.Kinds[feature] == 2) radius = new Vector2(point.X - a.X, point.Z - a.Z).Length();
            else
            {
                var ab = f.Directions[feature]; var q = new Vector2(point.X - a.X, point.Z - a.Z); double along = q.Dot(ab) / f.SpanSquared[feature], t = Math.Clamp(along, 0, 1);
                radius = (q - ab * (float)t).Length(); floorY = Lerp(a.Y, b.Y, along);
                if (f.continuous_route_floors)
                {
                    if (along < 0 && double.IsFinite(f.EndpointGrades[feature * 2])) floorY = a.Y + along * f.SpanLength[feature] * f.EndpointGrades[feature * 2];
                    else if (along > 1 && double.IsFinite(f.EndpointGrades[feature * 2 + 1])) floorY = b.Y + (along - 1) * f.SpanLength[feature] * f.EndpointGrades[feature * 2 + 1];
                }
            }
            double y = point.Y - floorY;
            double arch = (new Vector2((float)(radius / size.X), (float)((y - f.ArchCenter[feature]) / f.ArchHeight[feature])).Length() - 1.0) * f.ArchScale[feature];
            int style = f.Styles[feature];
            if (style is 1 or 2 or 3 or 5)
            {
                double exponent = style == 1 ? 4 : style == 2 ? 3.4 : style == 3 ? 2.8 : 2.5;
                double radial = Math.Abs(radius / size.X), vertical = Math.Abs((y - f.ArchCenter[feature]) / f.ArchHeight[feature]);
                arch = (Math.Pow(Math.Pow(radial, exponent) + Math.Pow(vertical, exponent), 1 / exponent) - 1) * f.ArchScale[feature];
            }
            if (style is 2 or 3 or 4)
            {
                double joint = .5 + .5 * Math.Sin(point.Y * (style == 2 ? .61 : .19) + point.X * .013 + point.Z * .017);
                arch -= joint * (style == 3 ? .24 : .12) * Smooth(0, 1, y);
            }
            if (style == 7)
            {
                double phase = f.Kinds[feature] == 2 ? Math.Atan2((double)point.Z - a.Z, (double)point.X - a.X) * 9 : radius * .37 + point.X * .08 + point.Z * .11;
                double fold = .5 + .5 * Math.Sin(phase + y * .43 + Math.Sin(point.Y * .13) * .8); arch -= fold * fold * .65 * Smooth(1, 4, y);
            }
            double value = Math.Max(-y, arch + wall);
            if (floorOffset > 0 && f.Kinds[feature] == 2) value = Math.Max(value, -y + floorOffset);
            if (f.Kinds[feature] == 1) opening = Math.Min(opening, value); else closed = Math.Min(closed, value);
        }
        if (Math.Min(closed, opening) >= Far) return Far;
        double ground = f.ground_height(point); if (!double.IsFinite(ground)) return Far;
        double depth = ground - point.Y;
        if (f.opening_rock_cover > 0) opening = Math.Max(opening, f.opening_rock_cover - depth);
        return Math.Min(Far, Math.Max(Math.Min(Math.Max(closed, f.minimum_roof - depth), opening), depth - f.maximum_depth));
    }
}

internal static class FloorRelief
{
    internal static double Wave(Vector3 point)
    {
        double x = point.X % 3840.0, z = point.Z % 3840.0; if (x < 0) x += 3840; if (z < 0) z += 3840;
        double phase = Math.Tau * (x * .6 + z * .8) / 24 + .4 * Math.Sin(Math.Tau * z / 96) * Math.Sin(Math.Tau * x / 120), u = .5 + .5 * Math.Sin(phase);
        return u * u * u * u;
    }
    internal static double Offset(CaveField f, Vector3 point, double strength, string biome)
    {
        if (strength <= 0 || !f.BiomeFields.TryGetValue(biome, out var field)) return 0;
        double admission = f.biome_admission(point); if (admission <= 0) return 0;
        double amount = 0, mask = 1;
        if (f.Bins.TryGetValue(f.bin_cell(point), out var features))
            foreach (int feature in features)
            {
                var a = f.Begins[feature]; var b = f.Ends[feature]; var q = new Vector2(point.X - a.X, point.Z - a.Z);
                double t = 0, distance = q.Length(), floorY = a.Y, width = f.Dimensions[feature].X;
                if (f.Kinds[feature] != 2)
                {
                    t = Math.Clamp(q.Dot(f.Directions[feature]) / f.SpanSquared[feature], 0, 1); distance = (q - f.Directions[feature] * (float)t).Length(); floorY = Lerp(a.Y, b.Y, t);
                }
                double vertical = 1 - Smooth(2, 4, Math.Abs(point.Y - floorY)); var weights = field[feature];
                double raw = Lerp(weights.X, weights.Y, t), support = 1 - Smooth(width * .6, width * .6 + 4, distance); amount = Math.Max(amount, raw * vertical * support);
                if (f.Kinds[feature] != 2) mask = Math.Min(mask, 1 - vertical + vertical * Smooth(width + 1, width + 4, distance));
            }
        foreach (var item in f._protected_shores)
        {
            var shore = item.AsGodotDictionary(); var center = shore["center"].AsVector3(); double radius = new Vector2(point.X - center.X, point.Z - center.Z).Length();
            double ring = Smooth(Num(shore, "inner") - 3, Num(shore, "inner"), radius) * (1 - Smooth(Num(shore, "outer"), Num(shore, "outer") + 3, radius));
            double vertical = Smooth(Num(shore, "low") - 4, Num(shore, "low"), point.Y) * (1 - Smooth(Num(shore, "high"), Num(shore, "high") + 4, point.Y)); mask = Math.Min(mask, 1 - ring * vertical);
        }
        return Wave(point) * Math.Clamp(strength, 0, 1) * Math.Clamp(amount, 0, 1) * Math.Clamp(mask, 0, 1) * admission;
    }
}
