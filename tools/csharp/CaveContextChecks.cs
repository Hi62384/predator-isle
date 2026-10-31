using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveContextChecks
{
    internal static void Run(Action<bool, string> require)
    {
        using var old = GD.Load<GDScript>("res://scripts/caves/surface_context.gd").New().AsGodotObject(); using var current = new CaveSurfaceContext();
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        var parentArrays = new A(); parentArrays.Resize((int)Mesh.ArrayType.Max); var vertices = new Vector3[9]; var normals = new Vector3[9]; var colors = new Color[9]; var uv = new Vector2[9]; var uv2 = new Vector2[9];
        for (int z = 0; z < 3; z++) for (int x = 0; x < 3; x++) { int i = x + z * 3; vertices[i] = new Vector3(x * 32, i * .25f, z * 32); normals[i] = new Vector3(.1f, 1, .2f).Normalized(); colors[i] = new Color(.7f, .3f, .2f, .1f); uv[i] = new Vector2(5, .1f); uv2[i] = new Vector2(.1f, .2f); }
        parentArrays[(int)Mesh.ArrayType.Vertex] = vertices; parentArrays[(int)Mesh.ArrayType.Normal] = normals; parentArrays[(int)Mesh.ArrayType.Color] = colors; parentArrays[(int)Mesh.ArrayType.TexUV] = uv; parentArrays[(int)Mesh.ArrayType.TexUV2] = uv2;
        for (int slot = (int)Mesh.ArrayType.Custom0; slot <= (int)Mesh.ArrayType.Custom3; slot++) parentArrays[slot] = Enumerable.Repeat(123456f, 9 * 4).ToArray();
        var records = new A { new D { ["id"] = "parent", ["origin"] = Vector3.Zero, ["span"] = 64.0, ["resolution"] = 2, ["arrays"] = parentArrays }, new D { ["id"] = "fine", ["origin"] = new Vector3(16, 0, 16), ["span"] = 32.0, ["resolution"] = 2, ["arrays"] = parentArrays, ["extension_normalization"] = true } };
        var height = Callable.From<double, double, double>((x, z) => 200 + x * .01 + z * .02);
        require(old.Call("configure", records, height).AsBool() && current.configure(records, height), "Surface parent snapshot rejected");
        for (int i = -10; i < 100; i++)
        {
            var p = new Vector2(i * .875f, i * .6875f);
            string id = current.owner_at(p); require(old.Call("owner_at", p).AsString() == id, "Parent ownership differs");
            require(old.Call("height_at", p.X, p.Y).AsDouble() == current.height_at(p.X, p.Y), "Parent barycentric height differs");
            require(Equal(old.Call("controls", id, p), current.controls(id, p)), "Parent controls differ");
            require(old.Call("normal_at", id, p).AsVector3() == current.normal_at(id, p), "Parent normal differs");
        }
        var source = new A(); source.Resize((int)Mesh.ArrayType.Max);
        source[(int)Mesh.ArrayType.Vertex] = new[] { new Vector3(4, -1, 4), new Vector3(8, -1, 4), new Vector3(4, -1, 8), new Vector3(8, -1, 4), new Vector3(8, -1, 8), new Vector3(4, -1, 8), new Vector3(20, -30, 20), new Vector3(24, -30, 20), new Vector3(20, -30, 24) };
        source[(int)Mesh.ArrayType.Normal] = Enumerable.Repeat(Vector3.Up, 9).ToArray(); source[(int)Mesh.ArrayType.Color] = Enumerable.Repeat(new Color(.4f, .3f, .2f, 1), 9).ToArray();
        require(Equal(old.Call("surfaces", source, Vector3.Zero), current.surfaces(source, Vector3.Zero)), "Decoded replacement surfaces differ");
        foreach (bool retain in new[] { false, true }) require(Equal(old.Call("surfaces_indexed", source, Vector3.Zero, retain), current.surfaces_indexed(source, Vector3.Zero, retain)), "Indexed replacement surfaces differ");
        require(!current.configure(new A { new D() }, height) && current.parents.Count == 0, "Invalid parent retained stale surface state");
    }
}
