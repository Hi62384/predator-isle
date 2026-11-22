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
        // Exercise single-cell no-clip, boundary-spanning no-hit, degenerate
        // no-hit, and fully removed triangles against the original GDScript.
        // The optimized path must not silently emit a degenerate triangle.
        var noHit = new Vector3[]
        {
            new(71,0,71),new(75,0,71),new(71,0,75),
            new(63,0,200),new(65,0,201),new(67,0,200),
            new(63,0,200),new(65,0,200),new(67,0,200),
            new(10,0,10),new(12,0,11),new(11,0,13)
        };
        var noHitColumns = new D { [Vector2I.Zero] = true };
        require(Equal(old.Call("ground",noHit,Vector3.Zero,noHitColumns),current.ground(noHit,Vector3.Zero,noHitColumns)),
            "Allocation-free cave cut changed retained, boundary or degenerate geometry");
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
        {
            string expected = referenceSurfaceShader.Call("code", terrainSource, parent, entry, hive, common).AsString();
            // The original oracle assigns logical vector l-values. The runtime
            // shader stores these exact components in shared smooth W lanes.
            // Spell out their canonical payload indices independently of the
            // production layout table, preserving the rest of the source check.
            if (terrainSource.Contains("varying vec4 terrain_jungle_control_values;", StringComparison.Ordinal))
                expected = expected.Replace(" tropical_control=vec3(surface_p14[0],surface_p14[1],surface_p14[2]);\n",
                    " terrain_jungle_control_values.w=surface_p14[0];\n terrain_forest_control_values.w=surface_p14[1];\n terrain_savanna_control_values.w=surface_p14[2];\n", StringComparison.Ordinal);
            if (terrainSource.Contains("varying vec4 terrain_savanna_geology_values;", StringComparison.Ordinal))
                expected = expected.Replace(" mountain_shape=vec3(surface_p11[0],surface_p11[1],surface_p11[2]);\n",
                    " terrain_savanna_geology_values.w=surface_p11[0];\n terrain_savanna_water_values.w=surface_p11[1];\n terrain_savanna_surface_values.w=surface_p11[2];\n", StringComparison.Ordinal);
            if (terrainSource.Contains("varying vec4 terrain_forest_local_values;", StringComparison.Ordinal))
            {
                expected = expected.Replace(" badlands_control=vec2(surface_p14[3],surface_p15[0]);\n",
                    " terrain_forest_values.w=surface_p14[3];\n terrain_forest_local_values.w=surface_p15[0];\n", StringComparison.Ordinal);
                expected = expected.Replace(" swamp_ecology=vec3(surface_p8[3],surface_p9[0],surface_p9[1]);\n",
                    " terrain_swamp_control_values.w=surface_p8[3];\n terrain_swamp_hydro_values.w=surface_p9[1];\n", StringComparison.Ordinal);
                expected = expected.Replace(";forest_origin=" + (parent ? "cave_parent_origin" : "MODEL_MATRIX[3].xyz") + ";\n",
                    ";COLOR=terrain_coast_values;UV2=terrain_surface;\n", StringComparison.Ordinal);
                if (parent) expected = expected.Replace("vec3 forest_origin=MODEL_MATRIX[3].xyz;", "vec3 forest_origin=cave_parent_origin;", StringComparison.Ordinal);
            }
            require(expected == surfaceShader.code(terrainSource, parent, entry, hive, common), $"Cave surface decode shader differs: {parent}/{entry}/{hive}/{common}");
        }
        require(surfaceShader.code("shader_type spatial; void vertex(){}") == "", "Unknown terrain payload layout accepted");
        foreach (bool common in new[] { false, true })
        {
            using var shader = new Shader { Code = terrainSource };
            // The old guard recognizes a standalone vec3 declaration only.
            // A comment supplies that guard token without changing the shader;
            // every byte of its generated clipping adapter still compares.
            const string guard = "// Original guard: varying vec3 forest_local_position;\n";
            using var referenceInput = new Shader { Code = guard + terrainSource };
            var expected = old.Call("shader", referenceInput, common).As<Shader>(); var actual = current.shader(shader, common);
            require(expected is not null && actual is not null && expected.Code.StartsWith(guard, StringComparison.Ordinal)
                && expected.Code[guard.Length..] == actual.Code, "Cave cut shader differs");
            require(current.shader(shader, common) == actual, "Cave shader cache not reused");
        }
    }
}

