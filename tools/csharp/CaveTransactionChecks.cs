using Godot;
using System;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveTransactionChecks
{
    internal static void Run(Node owner, Action<bool, string> require)
    {
        foreach (bool collision in new[] { false, true }) foreach (bool stale in new[] { false, true })
        {
            using var old = GD.Load<GDScript>("res://scripts/caves/surface_transaction.gd").New().AsGodotObject(); using var current = new CaveSurfaceTransaction();
            var originals = new[] { Parent(owner), Parent(owner) }; var replacements = new[] { Patch(owner), Patch(owner) };
            var columns = new D { [Vector2I.Zero] = true }; old.Set("collision_enabled", collision); current.collision_enabled = collision;
            require(old.Call("prepare", new A { originals[0] }, new A { replacements[0] }, columns, Vector2.Zero).AsBool() == current.prepare(new A { originals[1] }, new A { replacements[1] }, columns, Vector2.Zero), "Surface transaction preparation differs");
            require(current.prepared && originals[1].GetSurfaceOverrideMaterial(0) == null && !replacements[1].Visible, "Preparation altered visible terrain");
            require(old.Call("ready_to_commit").AsBool() == current.ready_to_commit(), "Surface cut readiness differs");
            if (stale) { originals[0].Position += Vector3.Right; originals[1].Position += Vector3.Right; }
            bool expected = old.Call("commit").AsBool(), actual = current.commit(); require(expected == actual && actual == !stale, "Stale surface cut committed");
            require(replacements[0].Visible == replacements[1].Visible && replacements[0].GetNode<StaticBody3D>("CaveCollision").CollisionLayer == replacements[1].GetNode<StaticBody3D>("CaveCollision").CollisionLayer, "Replacement visibility/physics differs");
            require(old.Call("materials").AsGodotArray().Count == current.materials().Count, "Committed cut material list differs");
            old.Call("reset"); current.reset();
            require(originals[1].GetSurfaceOverrideMaterial(0) == null && !replacements[1].Visible && replacements[1].GetNode<StaticBody3D>("CaveCollision").CollisionLayer == 0, "Reset failed to restore original surface");
            var restored = originals[1].GetNode<CollisionShape3D>("NearTerrainCollision/Heightfield");
            require(restored.Shape is BoxShape3D && restored.Position == new Vector3(32, 0, 32), "Reset failed to restore original ground shape and transform");
            foreach (var node in originals) node.Free(); foreach (var node in replacements) node.Free();
        }
        foreach (bool legacy in new[] { true, false })
        {
            using GodotObject first = legacy ? GD.Load<GDScript>("res://scripts/caves/surface_transaction.gd").New().AsGodotObject() : new CaveSurfaceTransaction();
            using GodotObject second = legacy ? GD.Load<GDScript>("res://scripts/caves/surface_transaction.gd").New().AsGodotObject() : new CaveSurfaceTransaction();
            var parent = Parent(owner); var initial = Patch(owner); var replacement = Patch(owner); var columns = new D { [Vector2I.Zero] = true };
            require(first.Call("prepare", new A { parent }, new A { initial }, columns, Vector2.Zero).AsBool() && first.Call("commit").AsBool(), "Initial cut did not commit");
            require(second.Call("prepare", new A { parent }, new A { replacement }, columns, Vector2.Zero, first).AsBool() && second.Call("commit").AsBool(), "Replacement cut did not supersede old cut");
            require(!initial.Visible && initial.GetNode<StaticBody3D>("CaveCollision").CollisionLayer == 0 && replacement.Visible && !first.Get("committed").AsBool(), "Superseded cave patch remained active");
            second.Call("reset");
            require(parent.GetSurfaceOverrideMaterial(0) == null && parent.GetNode<CollisionShape3D>("NearTerrainCollision/Heightfield").Shape is BoxShape3D, "Replacement reset restored a previous mask instead of original terrain");
            parent.Free(); initial.Free(); replacement.Free();
        }
    }
    private static A Arrays()
    {
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = new[] { Vector3.Zero, new Vector3(64, 0, 0), new Vector3(0, 0, 64), new Vector3(64, 0, 64) };
        arrays[(int)Mesh.ArrayType.Index] = new[] { 0, 1, 2, 1, 3, 2 }; return arrays;
    }
    private static MeshInstance3D Parent(Node owner)
    {
        var arrays = Arrays(); var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        mesh.SurfaceSetMaterial(0, new ShaderMaterial { Shader = new Shader { Code = "shader_type spatial;\nvarying vec3 forest_local_position;\nvoid vertex() {forest_local_position=VERTEX;}\nvoid fragment() {ALBEDO=vec3(.5);}" } });
        mesh.SetMeta("terrain_cpu_arrays", arrays); var node = new MeshInstance3D { Mesh = mesh }; node.SetMeta("resolution", 1); node.SetMeta("tile", Vector3I.Zero);
        var body = new StaticBody3D { Name = "NearTerrainCollision" }; body.AddChild(new CollisionShape3D { Name = "Heightfield", Shape = new BoxShape3D(), Position = new Vector3(32, 0, 32) }); node.AddChild(body); owner.AddChild(node); return node;
    }
    private static MeshInstance3D Patch(Node owner)
    {
        var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, Arrays()); var node = new MeshInstance3D { Mesh = mesh, Visible = false };
        node.AddChild(new StaticBody3D { Name = "CaveCollision", CollisionLayer = 0, CollisionMask = 0 }); owner.AddChild(node); return node;
    }
}
