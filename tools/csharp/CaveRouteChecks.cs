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
        foreach (int seed in new[] { 17, 73921 })
        {
            using var oldNetwork = networkScript.New().AsGodotObject(); using var newNetwork = networkScript.New().AsGodotObject();
            oldNetwork.Set("Solver", reference);
            var surface = Callable.From<double, double, double>((x, z) => 100 + 8 * Math.Sin(x * .001) + 5 * Math.Sin(z * .002));
            var water = Callable.From<double, double, double>((x, z) => -1000);
            foreach (var network in new[] { oldNetwork, newNetwork }) { network.Call("configure", surface, water, seed, 400.0); network.Set("activity", 1.0); }
            foreach (var cell in new[] { Vector2I.Zero, new Vector2I(-2, 3), new Vector2I(9, -3) })
            {
                var expected = oldNetwork.Call("region", cell); var actual = newNetwork.Call("region", cell);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), $"Complete cave region differs after route migration: {seed}/{cell}");
                require(actual.AsGodotDictionary()["valid"].AsBool(), "Cave region fixture was not admitted");
            }
        }
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
