using Godot;
using System;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Connected geological room growth with passage and roof clearance admission.</summary>
public partial class CaveChamberProfiles : RefCounted
{
    public double random(Vector2I cell, long seed_id, long salt)
    {
        long h = unchecked(cell.X * 374761393L + cell.Y * 668265263L + seed_id * 69069 + salt * 1274126177) & 0x7fffffff;
        h = unchecked((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
        return (double)(h ^ (h >> 16)) / 2147483647.0;
    }
    private static double N(D d, string key) => d[key].AsDouble();
    private static long Level(D d, long fallback) => d.ContainsKey("level") ? d["level"].AsInt64() : fallback;
    public bool compatible(Vector3 p, double radius, double headroom, D region, A pockets)
    {
        var nodes = region["nodes"].AsGodotArray();
        for (int i = 0; i < nodes.Count + pockets.Count; i++)
        {
            var other = (i < nodes.Count ? nodes[i] : pockets[i - nodes.Count]).AsGodotDictionary();
            if (Level(other, 0) < 0) continue;
            var point = other["point"].AsVector3(); double separation = Math.Abs((double)p.Y - point.Y);
            if (separation <= .25 || separation >= Math.Max(headroom, N(other, "chamber_height")) + 3) continue;
            if (new Vector2((float)((double)p.X - point.X), (float)((double)p.Z - point.Z)).Length() < radius + N(other, "chamber_radius") + 2) return false;
        }
        foreach (var item in region["edges"].AsGodotArray())
        {
            var edge = item.AsGodotDictionary(); var points = edge["points"].AsVector3Array(); double clearance = radius + N(edge, "half_width") + 2;
            for (int i = 0; i < points.Length - 1; i++)
            {
                var a = points[i]; var b = points[i + 1];
                if (p.X + clearance < Math.Min(a.X, b.X) || p.X - clearance > Math.Max(a.X, b.X) || p.Z + clearance < Math.Min(a.Z, b.Z) || p.Z - clearance > Math.Max(a.Z, b.Z)) continue;
                var ab = new Vector2(b.X - a.X, b.Z - a.Z); var q = new Vector2(p.X - a.X, p.Z - a.Z);
                double t = Math.Clamp(q.Dot(ab) / Math.Max(ab.LengthSquared(), .000001), 0, 1);
                if ((q - ab * (float)t).Length() >= clearance) continue;
                double floor = a.Y + ((double)b.Y - a.Y) * t, separation = Math.Abs(p.Y - floor);
                if (separation > .25 && separation < Math.Max(headroom, N(edge, "headroom")) + 3) return false;
            }
        }
        return true;
    }
    public A make(D region, Callable height, long seed_id) => make(region, height, seed_id, 400, 10);
    public A make(D region, Callable height, long seed_id, double maximum_depth) => make(region, height, seed_id, maximum_depth, 10);
    public A make(D region, Callable height, long seed_id, double maximum_depth, double minimum_roof)
    {
        var pockets = new A();
        if (!region.ContainsKey("valid") || !region["valid"].AsBool() || !(height.Delegate != null || GodotObject.IsInstanceValid(height.Target) && height.Target.HasMethod(height.Method))) return pockets;
        var sampleHeight=CaveHeightSampler.Bind(height);
        bool shortCircuit=CaveHeightSampler.CanShortCircuit(height);
        var cell = region["id"].AsVector2I(); long geology = region.ContainsKey("geology") ? region["geology"].AsInt64() : 0;
        bool soluble = geology is 0 or 2 or 5; double chance = soluble ? .6 : .22;
        var nodes = region["nodes"].AsGodotArray();
        for (int index = 0; index < nodes.Count; index++)
        {
            var node = nodes[index].AsGodotDictionary();
            if (Level(node, -1) < 0 || random(cell, seed_id, 900 + index) > chance) continue;
            for (int lobe = 0; lobe < (soluble ? 2 : 1); lobe++)
            {
                if (pockets.Count >= 24) break;
                int salt = 1000 + index * 16 + lobe * 4; double angle = random(cell, seed_id, salt) * Math.Tau;
                double radius = 22 + random(cell, seed_id, salt + 1) * 6, span = 23 + random(cell, seed_id, salt + 2) * 7;
                var origin = node["point"].AsVector3(); var p = origin + new Vector3((float)(Math.Cos(angle) * span), 0, (float)(Math.Sin(angle) * span));
                double headroom = 18 + random(cell, seed_id, salt + 3) * 8;
                if (!compatible(p, radius, headroom, region, pockets)) continue;
                bool admitted = true; int stations = (int)Math.Ceiling(span / 2);
                for (int station = 0; station <= stations; station++)
                    if (!compatible(origin.Lerp(p, (float)((double)station / stations)), 4, 8, region, pockets)) { admitted = false; break; }
                if (!admitted) continue;
                // Every accepted lobe still passes the complete footprint.
                // A rejected lobe needs no further scalar probes.
                for (int z = -2; z <= 2&&(!shortCircuit||admitted); z++) for (int x = -2; x <= 2; x++)
                {
                    if (new Vector2(x, z).Length() > 2.1) continue;
                    double surface = sampleHeight(p.X + x * radius * .5, p.Z + z * radius * .5);
                    if (!double.IsFinite(surface) || surface - p.Y > maximum_depth - 4 || surface - p.Y < headroom + minimum_roof + 4) { admitted = false; if(shortCircuit)break; }
                }
                if (admitted) pockets.Add(new D { ["id"] = node["id"].AsString() + ":lobe:" + lobe, ["point"] = p, ["level"] = node["level"], ["chamber_radius"] = radius, ["chamber_height"] = headroom, ["parent"] = node["id"] });
            }
        }
        return pockets;
    }
    public A passages(D region, A pockets)
    {
        var result = new A();
        foreach (var item in pockets)
        {
            var pocket = item.AsGodotDictionary();
            foreach (var value in region["nodes"].AsGodotArray())
            {
                var parent = value.AsGodotDictionary(); if (parent["id"].AsString() != pocket["parent"].AsString()) continue;
                result.Add(new D { ["from"] = parent["id"], ["to"] = pocket["id"], ["points"] = new[] { parent["point"].AsVector3(), pocket["point"].AsVector3() }, ["half_width"] = 4.0, ["headroom"] = 8.0, ["entrance"] = false, ["maximum_grade"] = 0.0 }); break;
            }
        }
        return result;
    }
    public A protected_edges(A pockets)
    {
        var result = new A();
        foreach (var item in pockets)
        {
            var pocket = item.AsGodotDictionary(); if (Level(pocket, -1) < 0) continue;
            var p = pocket["point"].AsVector3(); result.Add(new D { ["from"] = pocket["id"], ["to"] = pocket["id"], ["points"] = new[] { p, p }, ["half_width"] = pocket["chamber_radius"], ["headroom"] = pocket["chamber_height"], ["entrance"] = false });
        }
        return result;
    }
}
