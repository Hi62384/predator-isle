using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveBiomeRegionChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var reference = GD.Load<GDScript>("res://scripts/caves/biome_regions.gd"); using var current = new CaveBiomeRegions();
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        foreach (long seed in new[] { -73921L, 0L, 17L, 73921L })
        foreach (string id in new[] { "A", "-73/138/room", "crystal/é🌋" })
        foreach (string channel in new[] { "competition", "spawn/frozen", "extent/crystal" })
            require(reference.Call("random", id, seed, channel).AsDouble() == current.random(id, seed, channel), "Biome random channel differs");
        var terrain = GD.Load<Resource>("res://config/world/terrain_settings.tres").Duplicate(true);
        using var builder = GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();
        builder.Set("settings", terrain); builder.Set("world_seed", 17); builder.Set("water_level", 0.0); builder.Call("_configure_noise");
        var settings = GD.Load<Resource>("res://config/caves/cave_biome_regions.tres").Duplicate(true);
        using var old = reference.New().AsGodotObject(); old.Call("configure", builder, settings, 17); current.configure(builder, settings, 17);
        foreach (var point in new[] { Vector3.Zero, new Vector3(-712, 80, -548), new Vector3(10000, -50, -12000) })
            require(Equal(old.Call("surface_mix", point), current.surface_mix(point)), "Surface owner mixture differs");
        var regions = new A();
        for (int n = 0; n < 3; n++)
        {
            var nodes = new A(); var edges = new A();
            for (int i = 0; i < 8; i++)
            {
                string id = n + "/" + i; var point = new Vector3(n * 1000 + i * 30, -100, n * -1000 + i * 20);
                nodes.Add(new D { ["id"] = id, ["point"] = point, ["level"] = i == 0 ? -1 : 1 });
                if (i > 0) edges.Add(new D { ["from"] = n + "/" + (i - 1), ["to"] = id, ["points"] = new[] { point - new Vector3(30, 0, 20), point } });
            }
            var region = new D { ["valid"] = true, ["nodes"] = nodes, ["edges"] = edges, ["geology"] = n };
            var topology = current.graph(region); require(Equal(reference.Call("graph", region), topology), "Graph topology differs");
            foreach (double reach in new[] { 0.0, 45.0, 1000.0 })
                require(Equal(reference.Call("distances", topology, n + "/1", reach), current.distances(topology, n + "/1", reach)), "Geodesic distances differ");
            var expected = old.Call("decorate", region.Duplicate(true)); var actual = current.decorate(region.Duplicate(true));
            require(Equal(expected, actual), "Decorated region differs"); regions.Add(actual);
        }
        var connections = new A { new D { ["from"] = "0/7", ["to"] = "1/1", ["points"] = new[] { Vector3.Zero, new Vector3(20, 0, 0) } } };
        foreach (bool connected in new[] { false, true })
        {
            foreach (var value in regions) foreach (var candidate in value.AsGodotDictionary()["cave_biome_regions"].AsGodotDictionary()["candidates"].AsGodotArray())
                candidate.AsGodotDictionary()["connected_growth"] = connected;
            var expected = reference.Call("combine", regions, connections, "default"); var actual = current.combine(regions, connections);
            require(Equal(expected, actual), "Combined cave regions differ");
            require(reference.Call("description", expected).AsString() == current.description(actual), "Biome description differs");
        }
        using var registry = new CaveBiomeRegionSettings(); using var originalRegistry = GD.Load<GDScript>("res://scripts/caves/biome_region_settings.gd").New().AsGodotObject();
        foreach (var bands in new[] { new float[] { 0, 40, 100, 180, 280, 400 }, new float[] { 1, 1, 3, 4, float.NaN, 6 }, new float[] { 0 } })
        {
            registry.depth_bands = bands; originalRegistry.Set("depth_bands", bands);
            require(Equal(originalRegistry.Call("validation_errors"), registry.validation_errors()), "Registry validation differs");
            require(originalRegistry.Call("discovery_halo").AsInt32() == registry.discovery_halo(), "Registry halo differs");
        }
    }
}
