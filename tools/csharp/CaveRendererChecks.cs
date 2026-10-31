using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveRendererChecks
{
    internal static void Run(Node owner, Action<bool, string> require)
    {
        var old = GD.Load<GDScript>("res://scripts/caves/surface_renderer.gd"); using var current = new CaveSurfaceRenderer();
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); var vertices = new Vector3[33 * 33]; var indices = new int[32 * 32 * 6];
        for (int z = 0; z < 33; z++) for (int x = 0; x < 33; x++) vertices[x + z * 33] = new Vector3(x * 2, 0, z * 2);
        for (int z = 0, cursor = 0; z < 32; z++) for (int x = 0; x < 32; x++) { int a = x + z * 33; foreach (int index in new[] { a, a + 1, a + 33, a + 1, a + 34, a + 33 }) indices[cursor++] = index; }
        arrays[(int)Mesh.ArrayType.Vertex] = vertices; arrays[(int)Mesh.ArrayType.Index] = indices;
        var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays); mesh.SetMeta("terrain_cpu_arrays", arrays);
        using var material = new ShaderMaterial { Shader = new Shader { Code = "shader_type spatial; uniform bool extension_payload_enabled=false; void fragment(){ALBEDO=vec3(.5);}" } }; mesh.SurfaceSetMaterial(0, material);
        material.SetShaderParameter("extension_payload_enabled", false);
        material.SetMeta("biome_registry", GD.Load<Resource>("res://config/caves/cave_biome_regions.tres"));
        var parent = new MeshInstance3D { Mesh = mesh }; parent.SetMeta("tile", Vector3I.Zero); parent.SetMeta("resolution", 32); owner.AddChild(parent);
        var nodes = new A { parent }; var columns = new D { [Vector2I.Zero] = true };
        foreach (int resolution in new[] { 0, 1, 32 })
        {
            parent.SetMeta("resolution", resolution); var expected = old.Call("capture", nodes, columns); var actual = current.capture(nodes, columns);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), "Surface snapshot capture differs");
            if (actual["valid"].AsBool())
            {
                require(old.Call("matches", actual, nodes, columns).AsBool() == current.matches(actual, nodes, columns), "Surface snapshot match differs");
                parent.Position = Vector3.Right; require(!current.matches(actual, nodes, columns), "Moved parent retained stale snapshot"); parent.Position = Vector3.Zero;
            }
        }
        var surface = new A(); surface.Resize((int)Mesh.ArrayType.Max); var faces = new[] { Vector3.Zero, Vector3.Right, Vector3.Back }; surface[(int)Mesh.ArrayType.Vertex] = faces;
        var data = new D { ["valid"] = true, ["key"] = new Vector3I(1, -1, 2), ["groups"] = new D { ["__interior__"] = new D { ["arrays"] = surface } }, ["collision_faces"] = faces };
        var expectedNode = old.Call("node", data, new D(), material, 0).AsGodotDictionary()["node"].As<MeshInstance3D>(); var actualNode = current.node(data, new D(), material, 0)["node"].As<MeshInstance3D>();
        require(expectedNode.Position == actualNode.Position && expectedNode.Visible == actualNode.Visible && expectedNode.CastShadow == actualNode.CastShadow, "Replacement node state differs");
        require(GD.VarToBytes(((ArrayMesh)expectedNode.Mesh).SurfaceGetArrays(0)).SequenceEqual(GD.VarToBytes(((ArrayMesh)actualNode.Mesh).SurfaceGetArrays(0))), "Uploaded replacement mesh differs");
        var expectedBody = expectedNode.GetNode<StaticBody3D>("CaveCollision"); var actualBody = actualNode.GetNode<StaticBody3D>("CaveCollision");
        require(expectedBody.CollisionLayer == actualBody.CollisionLayer && actualBody.CollisionLayer == 0 && ((ConcavePolygonShape3D)expectedBody.GetChild<CollisionShape3D>(0).Shape).Data.SequenceEqual(((ConcavePolygonShape3D)actualBody.GetChild<CollisionShape3D>(0).Shape).Data), "Hidden replacement collision differs");
        var released = data.Duplicate(); var referenceReleased = data.Duplicate(); current.release_uploaded_data(released); old.Call("release_uploaded_data", referenceReleased);
        require(GD.VarToBytes(released).SequenceEqual(GD.VarToBytes(referenceReleased)), "Uploaded surface buffers retained");
        expectedNode.Free(); actualNode.Free(); parent.Free();
    }
}
