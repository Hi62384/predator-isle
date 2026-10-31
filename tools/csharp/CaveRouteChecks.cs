using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class CaveRouteChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var profileReference = GD.Load<GDScript>("res://scripts/caves/chamber_profiles.gd"); using var profiles = new CaveChamberProfiles();
        int admittedPockets = 0;
        foreach (int seed in new[] { -17, 17, 73921 })
        for (int geology = 0; geology < 6; geology++)
        {
            var nodes = new Godot.Collections.Array();
            for (int i = 0; i < 8; i++) nodes.Add(new D { ["id"] = "room:" + i, ["point"] = new Vector3(i * 150, i % 2 == 0 ? 0 : 25, i * -130), ["level"] = i % 3, ["chamber_radius"] = 18.0, ["chamber_height"] = 18.0 });
            var region = new D { ["valid"] = true, ["id"] = new Vector2I(-7, 9), ["geology"] = geology, ["nodes"] = nodes, ["edges"] = new Godot.Collections.Array() };
            foreach (double ceiling in new[] { 20.0, 100.0, 500.0 })
            {
                var surface = Callable.From<double, double, double>((x,z) => ceiling + Math.Sin(x * .01));
                var expected = profileReference.Call("make", region, surface, seed, 400.0, 10.0); var actual = profiles.make(region, surface, seed, 400, 10);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), "Chamber admission differs: " + MigrationComparison.FirstDifference(expected, actual));
                admittedPockets += actual.Count;
                require(GD.VarToBytes(profileReference.Call("passages", region, actual)).SequenceEqual(GD.VarToBytes(profiles.passages(region, actual))), "Chamber neck passage differs");
                require(GD.VarToBytes(profileReference.Call("protected_edges", actual)).SequenceEqual(GD.VarToBytes(profiles.protected_edges(actual))), "Chamber connector protection differs");
            }
        }
        require(admittedPockets > 0, "Chamber admission fixtures never created a lobe");
        var reference = GD.Load<GDScript>("res://scripts/caves/route_solver.gd"); using var candidate = new RouteSolver();
        var path = new Vector2[40];
        for (int i = 0; i < path.Length; i++) path[i] = new Vector2(i * 12, MathF.Sin(i * .3f) * 20);
        foreach (double variation in new[] { 0.0, 20.0, 80.0 })
        foreach (double end in new[] { -30.0, 0.0, 70.0, 110.0 })
        foreach (double flat in new[] { 0.0, 26.0 })
        {
            var sample = Callable.From<double, double, double>((x, z) => 100 + variation * Math.Sin(x * .02) + z * .01);
            foreach (bool useCover in new[] { false, true })
            {
                var cover = useCover ? Enumerable.Range(0, path.Length).Select(i => (float)Math.Clamp(i / 10.0, 0, 1)).ToArray() : System.Array.Empty<float>();
                var expected = reference.Call("solve", path, sample, 4.0, 8.0, 10.0, 400.0, .2, 0.0, end, cover, flat, flat);
                var actual = candidate.solve(path, sample, 4, 8, 10, 400, .2, 0, end, cover, flat, flat);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), $"Route envelope differs: variation={variation}, end={end}, flat={flat}, cover={useCover}");
            }
        }
        var bad = candidate.solve(path, default, 4, 8, 10, 400, .2, 0, -30);
        require(!bad["valid"].AsBool() && bad["reason"].AsString() == "invalid_input", "Null route surface accepted");
        var networkScript = GD.Load<GDScript>("res://scripts/caves/network.gd");
        using var curveReference = networkScript.New().AsGodotObject(); using var curveCandidate = new CaveNetwork();
        foreach (var controls in new[] { new[] { Vector2.Zero, new Vector2(100, 30) }, new[] { new Vector2(-1000, 100), new Vector2(350, -240), new Vector2(500, 600) } })
        {
            var expected = curveReference.Call("curve", controls); Variant actual = curveCandidate.curve(controls);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), "Canonical cave curve differs: " + MigrationComparison.FirstDifference(expected, actual));
        }
        foreach (int seed in new[] { 17, 73921 })
        {
            using var oldNetwork = networkScript.New().AsGodotObject(); using var newNetwork = new CaveNetwork();
            oldNetwork.Set("Solver", reference);
            var surface = Callable.From<double, double, double>((x, z) => 100 + 8 * Math.Sin(x * .001) + 5 * Math.Sin(z * .002));
            var water = Callable.From<double, double, double>((x, z) => -1000);
            foreach (var network in new[] { oldNetwork, newNetwork }) { network.Call("configure", surface, water, seed, 400.0); network.Set("activity", 1.0); }
            foreach (var cell in new[] { Vector2I.Zero, new Vector2I(-2, 3), new Vector2I(9, -3) })
            {
                var expected = oldNetwork.Call("region", cell); var actual = newNetwork.Call("region", cell);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), $"Complete cave region differs after route migration: {seed}/{cell}; {MigrationComparison.FirstDifference(expected, actual)}");
                require(actual.AsGodotDictionary()["valid"].AsBool(), "Cave region fixture was not admitted");
            }
            foreach (var pair in new[] { (Vector2I.Zero, Vector2I.Right), (new Vector2I(-2,3), new Vector2I(-2,4)) })
                require(GD.VarToBytes(oldNetwork.Call("connection", pair.Item1, pair.Item2)).SequenceEqual(GD.VarToBytes(newNetwork.connection(pair.Item1, pair.Item2))), "Canonical inter-region connection differs");
        }
        using var contextualReference = networkScript.New().AsGodotObject(); using var contextualCandidate = new CaveNetwork();
        var context = Callable.From<Vector2I, D>(cell => new D { ["half_width"] = 5.0, ["headroom"] = 9.0, ["flat_radius"] = 30.0, ["planning_depth_reserve"] = 2.0, ["render_style"] = 7, ["hive_region"] = "fixture" });
        var decorate = Callable.From<D, D, D>((region, active) => { region["decorated"] = true; return region; });
        var finalize = Callable.From<D, D>(region => { region["finalized"] = true; return region; });
        foreach (var network in new GodotObject[] { contextualReference, contextualCandidate })
        {
            network.Call("configure", Callable.From<double,double,double>((x,z) => 100 + x * .001), Callable.From<double,double,double>((x,z) => -1000), 17, 400.0);
            network.Set("activity", 1.0); network.Set("chamber_variety", true); network.Set("geological_morphology", true); network.Set("seepage_density", .6);
            network.Set("region_context", context); network.Set("region_decorator", decorate); network.Set("region_finalizer", finalize); network.Set("access_admission", Callable.From<D,bool>(edge => true));
        }
        var contextualExpected = contextualReference.Call("region", Vector2I.Zero); var contextualActual = contextualCandidate.region(Vector2I.Zero);
        require(GD.VarToBytes(contextualExpected).SequenceEqual(GD.VarToBytes(contextualActual)), "Contextual cave graph/profile/seepage differs: " + MigrationComparison.FirstDifference(contextualExpected, contextualActual));
        require(contextualCandidate.half_width == 4 && contextualCandidate.headroom == 8 && contextualCandidate.flat_radius == 26, "Context overrides leaked into later regions");
        foreach (var network in new GodotObject[] { contextualReference, contextualCandidate }) network.Set("activity", -1.0);
        for (int i = 1; i < 36; i++)
            require(GD.VarToBytes(contextualReference.Call("region", new Vector2I(i,-i))).SequenceEqual(GD.VarToBytes(contextualCandidate.region(new Vector2I(i,-i)))), "Rejected region context or FIFO eviction differs");
        require(contextualCandidate._regions.Count == 32 && !contextualCandidate._regions.ContainsKey(Vector2I.Zero), "Cave region cache exceeded its bound or evicted in a different order");
        var envelopeReference = GD.Load<GDScript>("res://scripts/caves/traversal_envelope.gd"); using var envelope = new TraversalEnvelope();
        foreach (var p in new[] { Vector3.Zero, new Vector3(-1, -1, -1), new Vector3(2, 62, 64), new Vector3(32, 32, 32), new Vector3(-64, 0, 64), Vector3.Inf })
        {
            var resident = new D(); var wanted = new D();
            for (int z = -2; z < 3; z++) for (int y = -2; y < 3; y++) for (int x = -2; x < 3; x++) { var key = new Vector3I(x, y, z); resident[key] = true; wanted[key] = true; }
            require(envelopeReference.Call("ready", p, resident, wanted).AsBool() == envelope.ready(p, resident, wanted), "Resident traversal envelope differs");
            foreach (var key in resident.Keys.ToArray())
            {
                resident.Remove(key);
                require(envelopeReference.Call("ready", p, resident, wanted).AsBool() == envelope.ready(p, resident, wanted), "Partial traversal envelope differs");
            }
        }
    }
}
