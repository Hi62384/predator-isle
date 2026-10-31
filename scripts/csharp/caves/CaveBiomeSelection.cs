using System;
using System.Collections.Generic;
using System.Linq;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Double precision graph-distance blending used while compiling cave fields.</summary>
internal static class CaveBiomeSelection
{
    internal static D AlongEdge(D assignment, string from, string to, double station, double length)
    {
        string fallback = assignment.ContainsKey("fallback") ? assignment["fallback"].AsString() : "default";
        var fields = new Dictionary<string, double>(StringComparer.Ordinal);
        var nearest = new D(); var winners = new D();
        if (double.IsFinite(station) && double.IsFinite(length) && length >= 0)
        {
            station = Math.Clamp(station, 0, length);
            if (assignment.ContainsKey("candidates"))
            foreach (var item in assignment["candidates"].AsGodotArray())
            {
                var candidate = item.AsGodotDictionary(); var distances = candidate["distances"].AsGodotDictionary();
                double distance = Math.Min(Number(distances, from, double.PositiveInfinity) + station,
                    Number(distances, to, double.PositiveInfinity) + length - station);
                double reach = candidate["reach_m"].AsDouble();
                if (distance >= reach) continue;
                double start = reach - candidate["transition_m"].AsDouble();
                double t = Math.Clamp((distance - start) / (reach - start), 0, 1);
                double amount = 1 - t * t * (3 - 2 * t);
                string id = candidate["biome_id"].AsString(), identity = candidate["id"].AsString();
                double previous = fields.GetValueOrDefault(id);
                double tolerance = Math.Max(.00001, .00001 * Math.Abs(amount));
                bool equal = amount == previous || Math.Abs(amount - previous) < tolerance;
                string winner = winners.ContainsKey(id) ? winners[id].AsString() : "~";
                if (amount > previous || (equal && string.CompareOrdinal(identity, winner) < 0))
                { fields[id] = amount; nearest[id] = distance; winners[id] = identity; }
            }
        }
        double maximum = 0;
        foreach (var pair in fields) if (pair.Key != fallback) maximum = Math.Max(maximum, pair.Value);
        fields[fallback] = 1 - maximum;
        double total = fields.Values.Sum(); var weights = new D(); string primary = fallback; double strongest = -1;
        foreach (string id in fields.Keys.OrderBy(id => id, StringComparer.Ordinal))
        {
            double weight = fields[id] / Math.Max(total, .000001); weights[id] = weight;
            if (weight > strongest) { strongest = weight; primary = id; }
        }
        return new D { ["primary"] = primary, ["weights"] = weights, ["candidate_ids"] = winners, ["graph_distances"] = nearest };
    }
    private static double Number(D values, string key, double fallback) => values.ContainsKey(key) ? values[key].AsDouble() : fallback;
}
