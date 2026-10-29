using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;

internal static class SurfaceBatchChecks
{
    internal static void Run(Action<bool, string> require)
    {
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        var script = GD.Load<GDScript>("res://scripts/caves/surface_batch.gd");
        foreach (int count in new[] { 0, 1, 2, 4, 9, 64, 65 })
        {
            using var old = script.New().AsGodotObject(); using var current = new SurfaceBatch();
            var columns = new D(); for (int i = count - 1; i >= 0; i--) columns[new Vector2I(i / 8 - 4, i % 8 - 4)] = true;
            var request = new D { ["columns"] = columns };
            bool accepted = old.Call("configure", 31, 9, request).AsBool();
            require(accepted == current.configure(31, 9, request), "Surface batch configuration differs");
            if (!accepted) continue;
            require(Equal(old.Call("assemble"), current.assemble()), "Incomplete batch accepted");
            var parts = new System.Collections.Generic.List<D>();
            while (current.pending())
            {
                var part = current.take(); require(Equal(old.Call("take"), part), "Surface work partition differs"); parts.Add(part);
            }
            foreach (var part in parts.AsEnumerable().Reverse())
            {
                int index = part["part"].AsInt32();
                var data = new D { ["valid"] = true, ["owned_columns"] = part["columns"], ["columns"] = columns,
                    ["cells"] = new A { new D { ["key"] = new Vector3I(-index, index, 2) } }, ["ground"] = new D { ["original"] = true } };
                require(!current.accept(30, 9, index, data) && !current.accept(31, 8, index, data), "Stale surface batch accepted");
                require(old.Call("accept", 31, 9, index, data).AsBool() == current.accept(31, 9, index, data), "Part acceptance differs");
                require(!current.accept(31, 9, index, data), "Duplicate part accepted");
            }
            require(current.complete() && Equal(old.Call("assemble"), current.assemble()), "Complete surface batch differs");
        }
        using var policy = new SurfaceStreamingPolicy(); var oldPolicy = GD.Load<GDScript>("res://scripts/caves/surface_streaming_policy.gd");
        foreach (double depth in new[] { 95.999, 96, 96.001, double.NaN })
        foreach (bool entrance in new[] { false, true })
            require(oldPolicy.Call("can_defer", Vector3.Zero, depth, true, entrance).AsBool() == policy.can_defer(Vector3.Zero, depth, true, entrance), "Deep cover scheduling differs");
    }
}
