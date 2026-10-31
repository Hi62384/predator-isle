using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using D = Godot.Collections.Dictionary;
using A = Godot.Collections.Array;

namespace PredatorIsle.Checks;
internal static class CaveFrontierChecks
{
    internal static void Run(Node owner, Action<bool, string> require)
    {
        var old = GD.Load<GDScript>("res://scripts/caves/stream_frontiers.gd"); using var current = new CaveStreamFrontiers();
        using var field = new CaveField(); field.height = Callable.From<double, double, double>((x, z) => 200); field.opening_rock_cover = 10;
        require(field.append_feature(new Vector3(-20, 0, 30), new Vector3(150, 0, 30), new Vector2(10, 20), 0), "Frontier fixture not admitted");
        int sealedFaces = 0;
        foreach (var key in new[] { new Vector3I(-1, 0, 0), Vector3I.Zero, new Vector3I(1, 0, 0), new Vector3I(2, 0, 0), new Vector3I(10, 10, 10) })
        {
            var expected = old.Call("build", field, key); var actual = current.build(field, key);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), "Frontier seal differs: " + key);
            require(field.opening_rock_cover == 10, "Frontier failed to restore roof clip");
            if (actual.Count == 0) continue;
            var mesh = new MeshInstance3D(); owner.AddChild(mesh); using var material = new StandardMaterial3D();
            current.attach(mesh, actual, material, false); var cells = new D { [key] = mesh }; current.synchronize(cells);
            foreach (var node in mesh.GetNode<Node3D>("CaveFrontiers").GetChildren().Cast<MeshInstance3D>())
            {
                sealedFaces++;
                require(node.Visible && node.GetNode<StaticBody3D>("FrontierCollision").CollisionLayer == 1, "Missing neighbour not sealed");
                require(node.GetNode<StaticBody3D>("FrontierCollision").GetChild<CollisionShape3D>(0).Shape is ConcavePolygonShape3D, "Frontier physics shape missing");
            }
            var neighbour = new MeshInstance3D(); owner.AddChild(neighbour);
            cells[key + Vector3I.Right] = neighbour; current.synchronize(cells);
            foreach (var node in mesh.GetNode<Node3D>("CaveFrontiers").GetChildren().Cast<MeshInstance3D>())
                if (node.GetMeta("face").AsInt32() == 1) require(!node.Visible && node.GetNode<StaticBody3D>("FrontierCollision").CollisionLayer == 0, "Ready neighbour remained sealed");
            cells.Remove(key + Vector3I.Right);
            neighbour.Free();
            current.synchronize(cells, false);
            foreach (var node in mesh.GetNode<Node3D>("CaveFrontiers").GetChildren().Cast<MeshInstance3D>()) require(node.GetNode<StaticBody3D>("FrontierCollision").CollisionLayer == 0, "Disabled frontier collision remained active");
            mesh.Free();
        }
        require(sealedFaces > 0, "Frontier fixture never exercised visible seals or native collision");
        var captured = new A(); for (int i = 0; i < 6; i++) { var values = new float[1089]; for (int j = 0; j < values.Length; j++) values[j] = j % 3 == 0 ? -.5f : 1.5f; captured.Add(values); }
        require(GD.VarToBytes(old.Call("build", field, Vector3I.Zero, captured)).SequenceEqual(GD.VarToBytes(current.build(field, Vector3I.Zero, captured))), "Captured frontier lattice differs");
        using var water = new CaveWaterRenderer(); var originalWater = GD.Load<GDScript>("res://scripts/caves/water_renderer.gd");
        foreach (bool common in new[] { false, true })
        {
            var expected = originalWater.Call("material", common).As<ShaderMaterial>(); var actual = water.material(common);
            require(expected.Shader.Code == actual.Shader.Code, "Cave water shader differs");
            foreach (string name in new[] { "swamp_water_opacity", "swamp_ripple", "swamp_flood_stage" }) require(expected.GetShaderParameter(name).Equals(actual.GetShaderParameter(name)), "Water material control differs");
            require(water.material(common) == actual, "Water material was recreated");
        }
        var parent = new Node3D(); owner.AddChild(parent);
        require(water.attach(parent, new D()) == null, "Empty water payload created a node");
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); arrays[(int)Mesh.ArrayType.Vertex] = new[] { Vector3.Zero, Vector3.Right, Vector3.Back };
        var waterNode = water.attach(parent, new D { ["arrays"] = arrays, ["ids"] = new A { "pool" } });
        require(waterNode != null && waterNode.GetMeta("pool_ids").AsGodotArray()[0].AsString() == "pool" && waterNode.GetChildCount() == 0, "Water renderer lost pool identity or created walking collision");
        parent.Free();
    }
}
