using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

internal static class CaveFieldCompiler
{
    internal static bool Compile(CaveField f, A regions, Callable surface, A extraEdges, D assignment)
    {
        f.clear(); f.height = surface;
        if (surface.Delegate == null && (!GodotObject.IsInstanceValid(surface.Target) || !surface.Target!.HasMethod(surface.Method))) return false;
        bool Failed() { f.clear(); return false; }
        var specialized = new A();
        foreach (var item in Arr(assignment, "candidates"))
        {
            var candidate = item.AsGodotDictionary(); string id = Text(candidate, "biome_id");
            if (id == Text(assignment, "fallback", "default")) continue;
            specialized.Add(candidate); f.BiomeFields[id] = new();
        }
        if (specialized.Count > 0) { f._biome_assignment = assignment.Duplicate(); f._biome_assignment["candidates"] = specialized; }
        var edges = extraEdges.Duplicate();
        foreach (var item in regions)
        {
            var region = item.AsGodotDictionary(); if (!Flag(region, "valid")) continue;
            int family = Int(region, "cave_family", -1);
            if (f.enable_thermal_sources && family is not (6 or 7))
                foreach (var source in Arr(region, "cave_thermal_sources")) if (!f.append_thermal_source(source.AsGodotDictionary())) return Failed();
            foreach (var pair in Dict(region, "cave_floor_relief"))
            {
                string id = pair.Key.AsString(); var strength = pair.Value;
                if (!f.BiomeFields.ContainsKey(id) || strength.VariantType is not (Variant.Type.Float or Variant.Type.Int)) return Failed();
                double value = strength.AsDouble(); if (!double.IsFinite(value) || value < 0 || value > 1) return Failed();
                f.floor_relief[id] = Math.Max(Num(f.floor_relief, id), value);
                if (f.floor_relief.Count > 4) return Failed();
            }
            if (f.BiomeFields.Count > 0 && family is 6 or 7) f._biome_locks[region["id"]] = true;
            int style = Int(region, "cross_section_style");
            var regionEdges = Arr(region, "edges").Duplicate(); foreach (var edge in Arr(region, "pocket_passages")) regionEdges.Add(edge);
            foreach (var raw in regionEdges)
            {
                var edge = raw.AsGodotDictionary(); var decorated = edge.Duplicate(); decorated["cross_section_style"] = Flag(edge, "retain_cross_section_style") ? Int(edge, "cross_section_style", style) : style; edges.Add(decorated);
            }
            var rooms = Arr(region, "nodes").Duplicate(); foreach (var room in Arr(region, "pockets")) rooms.Add(room);
            foreach (var raw in Arr(region, "pools"))
            {
                var pool = raw.AsGodotDictionary(); var center = pool["center"].AsVector3(); double radius = Num(pool, "radius");
                if (Flag(pool, "precise_shore"))
                {
                    if (f.precise_shores.Count >= 128) return Failed();
                    f.precise_shores.Add(new D { ["center"] = center, ["radius"] = radius });
                }
                if (Flag(pool, "crystal_large_lake") || Flag(pool, "protected_dry_bank"))
                {
                    if (f._protected_shores.Count >= 128) return Failed();
                    f._protected_shores.Add(new D { ["center"] = center, ["inner"] = radius + .75, ["outer"] = radius + 3.25, ["low"] = center.Y - .75, ["high"] = center.Y + 8.0 });
                }
                string parent = Text(pool, "id"); if (parent.EndsWith(":seepage", StringComparison.Ordinal)) parent = parent[..^8];
                var bed = Dict(pool, "bed").Duplicate(); bed["biome_parent"] = parent; rooms.Add(bed);
                foreach (string name in new[] { "bed_lobes", "bank_lobes" })
                    foreach (var lobe in Arr(pool, name)) { var part = lobe.AsGodotDictionary().Duplicate(); part["biome_parent"] = parent; rooms.Add(part); }
                foreach (string name in new[] { "stream_edges", "bank_access" })
                    foreach (var access in Arr(pool, name)) { var part = access.AsGodotDictionary().Duplicate(); part["cross_section_style"] = style; part["biome_parent"] = parent; edges.Add(part); }
            }
            foreach (var raw in rooms)
            {
                var node = raw.AsGodotDictionary(); if (Int(node, "level", -1) < 0) continue;
                var point = node["point"].AsVector3();
                if (!f.append_feature(point, point, new Vector2((float)Num(node, "chamber_radius"), (float)Num(node, "chamber_height")), 2, Int(node, "cross_section_style", style))) return Failed();
                if (f.BiomeFields.Count > 0) { string id = Text(node, "biome_parent", Text(node, "id")); f.bind_feature_biomes(f.Begins.Count - 1, id, id, 0, 0, 0); }
            }
        }
        foreach (var raw in edges)
        {
            var edge = raw.AsGodotDictionary(); var points = edge["points"].AsVector3Array(); double length = 0, station = 0;
            if (f.BiomeFields.Count > 0) for (int i = 1; i < points.Length; i++) length += points[i - 1].DistanceTo(points[i]);
            for (int i = 0; i < points.Length - 1; i++)
            {
                if (!f.append_feature(points[i], points[i + 1], new Vector2((float)Num(edge, "half_width"), (float)Num(edge, "headroom")), Flag(edge, "entrance") ? 1 : 0, Int(edge, "cross_section_style"))) return Failed();
                int feature = f.Begins.Count - 1;
                if (f.continuous_route_floors)
                {
                    if (i > 0) f.EndpointGrades[feature * 2] = ((double)points[i].Y - points[i - 1].Y) / Math.Max(new Vector2(points[i].X - points[i - 1].X, points[i].Z - points[i - 1].Z).Length(), .000001);
                    if (i + 2 < points.Length) f.EndpointGrades[feature * 2 + 1] = ((double)points[i + 2].Y - points[i + 1].Y) / Math.Max(new Vector2(points[i + 2].X - points[i + 1].X, points[i + 2].Z - points[i + 1].Z).Length(), .000001);
                }
                if (f.BiomeFields.Count > 0)
                {
                    double end = station + points[i].DistanceTo(points[i + 1]); string parent = Text(edge, "biome_parent");
                    f.bind_feature_biomes(feature, parent.Length == 0 ? Text(edge, "from") : parent, parent.Length == 0 ? Text(edge, "to") : parent, station, end, parent.Length == 0 ? length : 0); station = end;
                }
            }
        }
        foreach (var bucket in f.Bins.Values) f.references += bucket.Count;
        f.InvalidatePacked(); return true;
    }
}
