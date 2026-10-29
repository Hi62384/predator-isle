using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Propagate roof, depth and slope bounds in both directions before selecting floors.</summary>
public partial class RouteSolver : RefCounted
{
    public D solve(Vector2[] stations, Callable surface, double half_width, double headroom, double roof,
        double maximum_depth, double grade, double start_floor, double end_floor, float[]? cover = null,
        double flat_start_metres = 0, double flat_end_metres = 0)
    {
        var reject = new D { ["valid"] = false, ["points"] = System.Array.Empty<Vector3>(), ["reason"] = "invalid_input" };
        D Reject(string reason) { reject["reason"] = reason; return reject; }
        bool validSurface = surface.Delegate != null || (GodotObject.IsInstanceValid(surface.Target) && surface.Target!.HasMethod(surface.Method));
        if (!validSurface || stations.Length < 2 || stations.Length > 4096) return reject;
        foreach (double number in new[] { half_width, headroom, roof, maximum_depth, grade, start_floor, end_floor, flat_start_metres, flat_end_metres }) if (!double.IsFinite(number)) return reject;
        if (half_width <= 0 || headroom <= 0 || roof < 0 || maximum_depth <= roof + headroom + 2 || grade <= 0 || grade > .5 || flat_start_metres < 0 || flat_end_metres < 0) return reject;
        cover ??= System.Array.Empty<float>();
        if (cover.Length > 0 && cover.Length != stations.Length) return reject;
        int count = stations.Length;
        var lower = new double[count]; var upper = new double[count]; var distances = new double[count]; var cumulative = new double[count]; var fieldBounds = new Vector2[count]; double length = 0;
        for (int i = 0; i < count; i++)
        {
            var point = stations[i]; if (!point.IsFinite()) return reject;
            var tangent = (stations[Math.Min(i + 1, count - 1)] - stations[Math.Max(i - 1, 0)]).Normalized();
            if (tangent.LengthSquared() < .5) return reject;
            var side = new Vector2(-tangent.Y, tangent.X); double lowest = double.PositiveInfinity, highest = double.NegativeInfinity;
            foreach (float fraction in new[] { -1f, -.5f, 0f, .5f, 1f })
            {
                var q = point + side * (float)(half_width + 2) * fraction; double h = surface.Call(q.X, q.Y).AsDouble();
                if (!double.IsFinite(h)) return reject;
                lowest = Math.Min(lowest, h); highest = Math.Max(highest, h);
            }
            double coverage = cover.Length > 0 ? cover[i] : 1;
            if (!double.IsFinite(coverage) || coverage < 0 || coverage > 1) return reject;
            lower[i] = highest - maximum_depth + 4; upper[i] = lowest - (roof + headroom) * coverage; fieldBounds[i] = new((float)lowest, (float)highest);
            double distance = i > 0 ? stations[i].DistanceTo(stations[i - 1]) : 0;
            if (i > 0 && distance < .01) return reject;
            distances[i] = distance; length += distance; cumulative[i] = length;
        }
        if (start_floor < lower[0] || start_floor > upper[0] || end_floor < lower[^1] || end_floor > upper[^1]) return Reject("endpoint_outside_depth_roof_envelope");
        if (flat_start_metres + flat_end_metres >= length) return reject;
        for (int i = 0; i < count; i++)
        {
            double fixedHeight = double.NaN;
            if (cumulative[i] <= flat_start_metres) fixedHeight = start_floor;
            if (cumulative[i] >= length - flat_end_metres) fixedHeight = end_floor;
            if (double.IsFinite(fixedHeight))
            {
                if (fixedHeight < lower[i] || fixedHeight > upper[i]) return Reject("flat_junction_outside_envelope");
                lower[i] = fixedHeight; upper[i] = fixedHeight;
            }
        }
        lower[0] = start_floor; upper[0] = start_floor; lower[^1] = end_floor; upper[^1] = end_floor;
        for (int i = 1; i < count; i++)
        {
            double rise = distances[i] * grade; lower[i] = Math.Max(lower[i], lower[i - 1] - rise); upper[i] = Math.Min(upper[i], upper[i - 1] + rise);
            if (lower[i] > upper[i] + .0000001) return Reject("forward_slope_envelope_empty");
        }
        for (int i = count - 2; i >= 0; i--)
        {
            double rise = distances[i + 1] * grade; lower[i] = Math.Max(lower[i], lower[i + 1] - rise); upper[i] = Math.Min(upper[i], upper[i + 1] + rise);
            if (lower[i] > upper[i] + .0000001) return Reject("backward_slope_envelope_empty");
        }
        var points = new Vector3[count]; double previous = start_floor, maximumGrade = 0, minCover = double.PositiveInfinity, maxDepth = 0;
        for (int i = 0; i < count; i++)
        {
            double t = Math.Clamp((cumulative[i] - flat_start_metres) / (length - flat_start_metres - flat_end_metres), 0, 1);
            double desired = start_floor + (end_floor - start_floor) * (t * t * (3 - 2 * t)), low = lower[i], high = upper[i];
            if (i > 0) { low = Math.Max(low, previous - distances[i] * grade); high = Math.Min(high, previous + distances[i] * grade); }
            if (low > high + .0000001) return Reject("selected_floor_envelope_empty");
            double floor = Math.Clamp(desired, low, Math.Max(low, high)); points[i] = new(stations[i].X, (float)floor, stations[i].Y);
            if (i > 0) maximumGrade = Math.Max(maximumGrade, Math.Abs(floor - previous) / distances[i]);
            previous = floor; minCover = Math.Min(minCover, fieldBounds[i].X - floor - headroom); maxDepth = Math.Max(maxDepth, fieldBounds[i].Y - floor);
        }
        return new D { ["valid"] = true, ["points"] = points, ["reason"] = "", ["maximum_grade"] = maximumGrade, ["minimum_measured_roof_m"] = minCover,
            ["maximum_measured_depth_m"] = maxDepth, ["horizontal_length_m"] = length, ["sample_count"] = count, ["lateral_samples_per_station"] = 5 };
    }
}
