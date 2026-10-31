using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveSurfaceCutChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var old = GD.Load<GDScript>("res://scripts/caves/surface_cut.gd"); using var current = new CaveSurfaceCut();
        var projection = GD.Load<GDScript>("res://scripts/caves/vertex_projection.gd");
        bool Equal(Variant a, Variant b) => GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b));
        foreach (var center in new[] { Vector2.Zero, new Vector2(-1, -64), new Vector2(1024, 1024), Vector2.Inf })
        foreach (int side in new[] { 15, 16, 17, 64, 1024, 1025 })
        {
            var columns = new D { [Vector2I.Zero] = true, [new Vector2I(-1, -1)] = true, [new Vector2I(40, 20)] = true };
            require(Equal(old.Call("mask", columns, center, side), current.mask(columns, center, side)), "Cave mask differs");
        }
        var rng = new Random(73921);
        foreach (var origin in new[] { Vector3.Zero, new Vector3(-128, 0, 64), new Vector3(31.25f, 20, -17.5f) })
        for (int sample = 0; sample < 200; sample++)
        {
            var faces = new Vector3[12]; for (int i = 0; i < faces.Length; i++) faces[i] = new Vector3((float)(rng.NextDouble() * 240 - 120), (float)(rng.NextDouble() * 20), (float)(rng.NextDouble() * 240 - 120));
            var columns = new D { [Vector2I.Zero] = true, [new Vector2I(-1, -1)] = true };
            require(Equal(old.Call("ground", faces, origin, columns), current.ground(faces, origin, columns)), $"Entrance subtraction differs: {sample}/{origin}");
        }
        var huge = new[] { new Vector3(-100000000000f, 0, 0), new Vector3(100000000000f, 0, 0), new Vector3(0, 1, 10) };
        var hugeColumns = new D { [Vector2I.Zero] = true };
        require(Equal(old.Call("ground", huge, Vector3.Zero, hugeColumns), current.ground(huge, Vector3.Zero, hugeColumns)), "Oversized entrance clipping bounds not rejected");
        foreach (string source in new[] {
            "shader_type spatial;\nvoid vertex() { VERTEX.y+=1.; }\nvoid fragment() {}",
            "shader_type spatial; render_mode unshaded;\nvoid vertex () { /* } */ if(true){VERTEX.y=0.;} // }\n}\nvoid fragment() {}",
            "shader_type spatial; void vertex(){ /* broken }", "shader_type spatial; void fragment(){}",
            "shader_type spatial; void vertex(){} void vertex(){}", "missing; void vertex(){}" })
            require(projection.Call("source", source).AsString() == CaveVertexProjection.Source(source), "Projection source differs: " + source);
        string terrainSource = System.IO.File.ReadAllText(ProjectSettings.GlobalizePath("res://shaders/terrain_biomes.gdshader"));
        using var surfaceShader = new CaveSurfaceShader(); var referenceSurfaceShader = GD.Load<GDScript>("res://scripts/caves/surface_shader.gd");
        foreach (bool parent in new[] { false, true }) foreach (bool entry in new[] { false, true })
        foreach (bool hive in new[] { false, true }) foreach (bool common in new[] { false, true })
            require(referenceSurfaceShader.Call("code", terrainSource, parent, entry, hive, common).AsString() == surfaceShader.code(terrainSource, parent, entry, hive, common), $"Cave surface decode shader differs: {parent}/{entry}/{hive}/{common}");
        require(surfaceShader.code("shader_type spatial; void vertex(){}") == "", "Unknown terrain payload layout accepted");
        foreach (bool common in new[] { false, true })
        {
            using var shader = new Shader { Code = terrainSource };
            var expected = old.Call("shader", shader, common).As<Shader>(); var actual = current.shader(shader, common);
            require(expected?.Code == actual?.Code, "Cave cut shader differs");
            require(current.shader(shader, common) == actual, "Cave shader cache not reused");
        }
    }
}

