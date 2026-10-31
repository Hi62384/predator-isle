using Godot;
using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Buffers.Binary;
using D = Godot.Collections.Dictionary;
using A = Godot.Collections.Array;

namespace PredatorIsle.Caves;

public partial class CaveBiomeRegions : RefCounted
{
    public GodotObject? builder { get; set; }
    public Resource? settings { get; set; }
    public long seed_id { get; set; } = 73921;
    public Callable environment_provider { get; set; }
    public Callable geometry_provider { get; set; }
    public void configure(GodotObject owner, Resource configuration, long seed_value) { builder = owner; settings = configuration; seed_id = seed_value; }
    public double random(string identity, long seed_value, string channel)
    {
        Span<byte> digest = stackalloc byte[32];
        SHA256.HashData(Encoding.UTF8.GetBytes(seed_value.ToString(System.Globalization.CultureInfo.InvariantCulture) + "/" + identity + "/" + channel), digest);
        return BinaryPrimitives.ReadUInt32LittleEndian(digest) / 4294967296.0;
    }
    private static Variant Get(D d, string key, Variant fallback = default) => d.ContainsKey(key) ? d[key] : fallback;
    private static double Number(D d, string key, double fallback = 0) => d.ContainsKey(key) ? d[key].AsDouble() : fallback;
    private static A Items(D d, string key) => d.ContainsKey(key) ? d[key].AsGodotArray() : new A();
    private static string Text(D d, string key, string fallback = "") => d.ContainsKey(key) ? d[key].AsString() : fallback;
    private static string[] Keys(D d) => d.Keys.Select(v => v.AsString()).OrderBy(s => s, StringComparer.Ordinal).ToArray();
    private static bool Valid(Callable c) => c.Delegate != null || GodotObject.IsInstanceValid(c.Target) && c.Target.HasMethod(c.Method);
    public D proposal(Resource definition, string identity, long seed_value)
    {
        string id = definition.Get("biome_id").AsString();
        double minimum = definition.Get("minimum_extent_metres").AsDouble(), maximum = definition.Get("maximum_extent_metres").AsDouble();
        return new D { ["accepted"] = definition.Get("enabled").AsBool() && random(identity, seed_value, "spawn/" + id) * 100 < definition.Get("spawn_chance_percent").AsDouble(),
            ["extent_m"] = minimum + (maximum - minimum) * random(identity, seed_value, "extent/" + id) };
    }
    public bool suitability_admitted(Resource definition, string identity, long seed_value, double suitability) =>
        double.IsFinite(suitability) && suitability > 0 && random(identity, seed_value, "suitability/" + definition.Get("biome_id").AsString()) < Math.Clamp(suitability, 0, 1);
    public D graph(D region)
    {
        var nodes = new D(); var edges = new A(); var adjacency = new D();
        foreach (var value in Items(region, "nodes").Concat(Items(region, "pockets")))
        {
            var room = value.AsGodotDictionary(); string id = Text(room, "id");
            if (nodes.Count >= 128 || nodes.ContainsKey(id)) return new();
            nodes[id] = room; adjacency[id] = new A();
        }
        foreach (var value in Items(region, "edges").Concat(Items(region, "pocket_passages")))
        {
            var edge = value.AsGodotDictionary(); string from = Text(edge, "from"), to = Text(edge, "to");
            if (edges.Count >= 256 || !nodes.ContainsKey(from) || !nodes.ContainsKey(to)) return new();
            var points = edge["points"].AsVector3Array(); if (points.Length < 2) return new();
            double length = Length(points); if (!double.IsFinite(length) || length < 0) return new();
            int index = edges.Count; edges.Add(new D { ["from"] = from, ["to"] = to, ["length"] = length });
            adjacency[from].AsGodotArray().Add(index); adjacency[to].AsGodotArray().Add(index);
        }
        return new D { ["nodes"] = nodes, ["edges"] = edges, ["adjacency"] = adjacency };
    }
    private static double Length(Vector3[] points)
    { double length = 0; for (int i = 1; i < points.Length; i++) length += points[i - 1].DistanceTo(points[i]); return length; }
    public D distances(D topology, string anchor, double reach)
    {
        var result = new D { [anchor] = 0.0 }; var visited = new System.Collections.Generic.HashSet<string>();
        var nodes = topology["nodes"].AsGodotDictionary(); var edges = topology["edges"].AsGodotArray(); var adjacency = topology["adjacency"].AsGodotDictionary();
        for (int iteration = 0; iteration < nodes.Count; iteration++)
        {
            string nearest = ""; double distance = double.PositiveInfinity;
            foreach (string key in Keys(result)) if (!visited.Contains(key) && Number(result, key) < distance) { nearest = key; distance = Number(result, key); }
            if (nearest.Length == 0 || distance > reach) break;
            visited.Add(nearest);
            foreach (var index in adjacency[nearest].AsGodotArray())
            {
                var edge = edges[index.AsInt32()].AsGodotDictionary(); string other = Text(edge, "from") == nearest ? Text(edge, "to") : Text(edge, "from");
                double proposed = distance + Number(edge, "length");
                if (proposed < Number(result, other, double.PositiveInfinity)) result[other] = proposed;
            }
        }
        var ordered = new D(); foreach (string key in Keys(result)) ordered[key] = result[key]; return ordered;
    }
    public D combine(A regions, A connections) => combine(regions, connections, "default");
    public D combine(A regions, A connections, string fallback)
    {
        var candidates = new A(); var edges = new A(); var identities = new System.Collections.Generic.HashSet<string>();
        foreach (var item in regions)
        {
            var assignment = Get(item.AsGodotDictionary(), "cave_biome_regions", new D()).AsGodotDictionary();
            foreach (var value in Items(assignment, "candidates")) if (identities.Add(Text(value.AsGodotDictionary(), "id"))) candidates.Add(value);
            foreach (var edge in Items(assignment, "edges")) edges.Add(edge);
        }
        foreach (var value in connections)
        {
            var connection = value.AsGodotDictionary(); edges.Add(new D { ["from"] = Text(connection, "from"), ["to"] = Text(connection, "to"), ["length"] = Length(connection["points"].AsVector3Array()) });
        }
        candidates = new A(candidates.OrderBy(v => Text(v.AsGodotDictionary(), "id"), StringComparer.Ordinal));
        edges = new A(edges.OrderBy(v => Text(v.AsGodotDictionary(), "from") + "/" + Text(v.AsGodotDictionary(), "to"), StringComparer.Ordinal));
        if (candidates.Any(v => Get(v.AsGodotDictionary(), "connected_growth", false).AsBool()))
        {
            var nodes = new D(); var adjacency = new D(); var locked = new System.Collections.Generic.HashSet<string>();
            foreach (var value in regions)
            {
                var region = value.AsGodotDictionary(); int family = Get(region, "cave_family", -1).AsInt32();
                if (family is 6 or 7) foreach (var node in Items(region, "nodes").Concat(Items(region, "pockets"))) locked.Add(Text(node.AsGodotDictionary(), "id"));
            }
            for (int i = 0; i < edges.Count; i++)
            {
                var edge = edges[i].AsGodotDictionary(); string from = Text(edge, "from"), to = Text(edge, "to");
                if (locked.Contains(from) || locked.Contains(to)) continue;
                foreach (string id in new[] { from, to })
                { nodes[id] = true; if (!adjacency.ContainsKey(id)) adjacency[id] = new A(); adjacency[id].AsGodotArray().Add(i); }
            }
            foreach (var value in candidates)
            {
                var candidate = value.AsGodotDictionary(); string anchor = Text(candidate, "anchor");
                if (Get(candidate, "connected_growth", false).AsBool() && !nodes.ContainsKey(anchor)) { nodes[anchor] = true; adjacency[anchor] = new A(); }
            }
            if (nodes.Count > 4096 || edges.Count > 8192) return new D { ["valid"] = false, ["fallback"] = fallback, ["candidates"] = new A(), ["edges"] = new A() };
            var topology = new D { ["nodes"] = nodes, ["edges"] = edges, ["adjacency"] = adjacency };
            for (int i = 0; i < candidates.Count; i++)
            {
                var candidate = candidates[i].AsGodotDictionary(); if (!Get(candidate, "connected_growth", false).AsBool()) continue;
                candidate = candidate.Duplicate(); candidate["distances"] = distances(topology, Text(candidate, "anchor"), Number(candidate, "reach_m")); candidates[i] = candidate;
            }
        }
        return new D { ["fallback"] = fallback, ["candidates"] = candidates, ["edges"] = edges };
    }
    public D along_edge(D assignment, string from_id, string to_id, double station, double length_m) => CaveBiomeSelection.AlongEdge(assignment, from_id, to_id, station, length_m);
    public D surface_mix(Vector3 point)
    {
        var owner = builder!; var weights = owner.Call("_biome_weights", point.X, point.Z).AsVector4();
        var native=owner as Terrain.TerrainMeshBuilder;
        var mix = new D { ["grass"] = weights.X, ["forest"] = weights.Y, ["savanna"] = weights.Z, ["swamp"] = weights.W,
            ["jungle"] = native is not null?native._jungle_weight:owner.Get("_jungle_weight"), ["mountain"] = native is not null?native._mountain_weight:owner.Get("_mountain_weight"), ["tropical"] = native is not null?native._tropical_weight:owner.Get("_tropical_weight"), ["badlands"] = native is not null?native._badlands_weight:owner.Get("_badlands_weight") };
        var extensionKeys = Terrain.TerrainBiomeCatalog.ExtensionKeys;
        var extra = owner.Get("_extra_weights").AsFloat64Array();
        for (int i = 0; i < 8; i++) mix[extensionKeys[i]] = extra[i];
        bool wantsCoast = settings!.Get("definitions").AsGodotArray().Any(v => {
            var definition = v.AsGodotObject(); return definition.Get("enabled").AsBool() && definition.Get("spawn_chance_percent").AsDouble() > 0 && definition.Get("surface_preferences").AsGodotDictionary().ContainsKey("rocky_coast"); });
        var terrain = owner.Get("settings").AsGodotObject(); var coast = owner.Get("_coast").AsGodotObject();
        if (wantsCoast && owner.HasMethod("_coast_payload") && terrain.Get("rocky_coast_enabled").AsBool() && coast != null)
        {
            double hint = owner.Call("_island_mask", point.X, point.Z).AsDouble() * Math.Max(terrain.Get("island_size").AsDouble() * .5, 8);
            coast.Call("sample", point.X, point.Z, 0, hint, true); var state = coast.Get("state").AsFloat64Array();
            double amount = Math.Clamp(state[2], 0, 1) * (1 - Math.Clamp(state[19], 0, 1));
            if (amount > 0) { foreach (var key in mix.Keys.ToArray()) mix[key] = mix[key].AsDouble() * (1 - amount); mix["rocky_coast"] = amount; }
        }
        return mix;
    }
    public D decorate(D region)
    {
        if (settings == null || !settings.Get("enabled").AsBool() || !Get(region, "valid", false).AsBool() || Get(region, "cave_family", -1).AsInt32() is 6 or 7) return region;
        var topology = graph(region); if (topology.Count == 0) return region;
        var definitions = settings.Get("definitions").AsGodotArray().Select(v => v.As<Resource>()).OrderBy(d => d.Get("biome_id").AsString(), StringComparer.Ordinal).ToArray();
        var candidates = new A(); var nodes = topology["nodes"].AsGodotDictionary();
        using var preferenceHelper = new CaveBiomeDefinition();
        foreach (string anchor in Keys(nodes))
        {
            var room = nodes[anchor].AsGodotDictionary(); if (Get(room, "level", -1).AsInt32() < 0) continue;
            var point = room["point"].AsVector3(); double depth = builder!.Call("_get_height", point.X, point.Z).AsDouble() - point.Y;
            var mix = surface_mix(point); var eligible = new System.Collections.Generic.List<D>(); var independent = new System.Collections.Generic.List<D>(); double total = 0;
            foreach (var definition in definitions)
            {
                if (!proposal(definition, anchor, seed_id)["accepted"].AsBool()) continue;
                double depthWeight = definition.Call("depth_preference", depth, settings.Get("depth_bands")).AsDouble();
                double surface = preferenceHelper.preference(definition.Get("surface_preferences").AsGodotDictionary(), mix);
                double geology = preferenceHelper.preference(definition.Get("geological_preferences").AsGodotDictionary(), new D { [Get(region, "geology", 0)] = 1.0 });
                double environment = 1;
                if (Valid(environment_provider)) foreach (string channel in new[] { "temperature_channel", "moisture_channel" })
                {
                    var name = definition.Get(channel).AsStringName(); if (name.IsEmpty) continue;
                    double value = environment_provider.Call(name, point).AsDouble(); environment *= double.IsFinite(value) ? Math.Clamp(value, 0, 1) : 0;
                }
                double suitability = depthWeight * surface * geology * environment;
                var choice = new D { ["definition"] = definition, ["depth"] = depthWeight, ["surface"] = surface, ["geology"] = geology, ["environment"] = environment };
                if (definition.Get("independent_suitability_admission").AsBool())
                { if (suitability_admitted(definition, anchor, seed_id, suitability)) independent.Add(choice); continue; }
                double weight = suitability * Math.Pow(2, definition.Get("selection_priority").AsInt32()); if (weight <= 0) continue;
                total += weight; choice["weight"] = weight; eligible.Add(choice);
            }
            if (eligible.Count > 0)
            {
                double lottery = random(anchor, seed_id, "competition") * total; var choice = eligible[^1];
                foreach (var option in eligible) { lottery -= Number(option, "weight"); if (lottery < 0) { choice = option; break; } }
                independent.Insert(0, choice);
            }
            foreach (var choice in independent)
            {
                var definition = choice["definition"].As<Resource>(); string id = definition.Get("biome_id").AsString();
                double extent = proposal(definition, anchor, seed_id)["extent_m"].AsDouble(), reach = extent * .5;
                var candidate = new D { ["id"] = anchor + "/" + id, ["biome_id"] = id, ["anchor"] = anchor, ["point"] = point, ["extent_m"] = extent, ["reach_m"] = reach,
                    ["transition_m"] = Math.Min(definition.Get("transition_metres").AsDouble(), reach), ["depth_m"] = depth, ["depth_preference"] = choice["depth"],
                    ["surface_preference"] = choice["surface"], ["geological_preference"] = choice["geology"], ["environment_preference"] = choice["environment"],
                    ["distances"] = distances(topology, anchor, reach), ["debug_color"] = definition.Get("debug_color") };
                if (definition.Get("independent_suitability_admission").AsBool()) candidate["connected_growth"] = true; candidates.Add(candidate);
            }
        }
        region["cave_biome_regions"] = new D { ["fallback"] = settings.Get("fallback_biome_id").AsString(), ["candidates"] = candidates, ["edges"] = topology["edges"], ["depth_bands"] = settings.Get("depth_bands").AsFloat32Array() };
        return Valid(geometry_provider) ? geometry_provider.Call(region).AsGodotDictionary() : region;
    }
    public string description(D assignment)
    {
        var counts = new System.Collections.Generic.SortedDictionary<string, int>(StringComparer.Ordinal); double minimum = double.PositiveInfinity, maximum = 0;
        foreach (var value in Items(assignment, "candidates"))
        {
            var candidate = value.AsGodotDictionary(); string id = Text(candidate, "biome_id"); counts[id] = (counts.TryGetValue(id, out int count) ? count : 0) + 1;
            minimum = Math.Min(minimum, Number(candidate, "extent_m")); maximum = Math.Max(maximum, Number(candidate, "extent_m"));
        }
        if (counts.Count == 0) return "Cave biome: Default fallback";
        return "Graph biome regions " + string.Join(", ", counts.Select(p => p.Key + ":" + p.Value)) + " | extent " + minimum.ToString("F0", System.Globalization.CultureInfo.InvariantCulture) + "–" + maximum.ToString("F0", System.Globalization.CultureInfo.InvariantCulture) + "m";
    }
}

