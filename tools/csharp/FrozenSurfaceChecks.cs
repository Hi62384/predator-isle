using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class FrozenSurfaceChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var providerScript = GD.Load<CSharpScript>("res://scripts/csharp/caves/FrozenCaveSurface.cs");
        using var loadedProvider = providerScript.Call("new").AsGodotObject();
        require(loadedProvider is FrozenCaveSurface && loadedProvider.HasMethod("source") && loadedProvider.HasMethod("bind"), "Frozen provider factory or script method registration failed");
        using var old = GD.Load<GDScript>("res://scripts/caves/frozen_surface.gd").New().AsGodotObject(); using var current = new FrozenCaveSurface();
        string rock = GD.Load<Shader>("res://shaders/default_cave_rock.gdshader").Code; using var surfaceShader = new CaveSurfaceShader(); string entrance = surfaceShader.code(GD.Load<Shader>("res://shaders/terrain_biomes.gdshader").Code, true, true, false, true);
        foreach (string source in new[] { rock, entrance, "shader_type spatial; void vertex(){}", rock + "\nvarying float cave_frozen_weight;" })
        foreach (int slot in new[] { -1, 0, 1, 2, 3, 4 }) foreach (bool entry in new[] { false, true })
            require(old.Call("source", source, slot, entry).AsString() == current.source(source, slot, entry), "Frozen surface source differs");
        foreach (var material in new[] { new D(), new D { ["texture_metres"] = 0.0 }, new D { ["normal_strength"] = double.NaN }, new D { ["texture_metres"] = "wrong" } })
        foreach (var features in new[] { new D(), new D { ["density"] = 2.0 }, new D { ["lake_ice"] = 1 }, new D { ["lake_radius_minimum"] = 12, ["lake_radius_maximum"] = 3 } })
            require(GD.VarToBytes(old.Call("validation_errors", material, features)).SequenceEqual(GD.VarToBytes(current.validation_errors(material, features))), "Frozen adapter validation differs");
        var config = new D { ["texture_metres"] = 7.0, ["normal_strength"] = .6 };
        foreach (string kind in new[] { "ice", "thin_ice" }) foreach (bool common in new[] { false, true })
        {
            var expected = old.Call("feature_material", kind, config, common).As<ShaderMaterial>(); var actual = current.feature_material(kind, config, common);
            require(actual != null && expected.Shader.Code == actual.Shader.Code, "Frozen feature shader differs");
            foreach (string name in new[] { "cave_frozen_colors", "cave_frozen_normals", "cave_frozen_texture_metres", "cave_frozen_normal_strength", "cave_common_projection" })
                require(GD.VarToBytes(expected.GetShaderParameter(name)).SequenceEqual(GD.VarToBytes(actual!.GetShaderParameter(name))), "Frozen feature material parameter differs");
        }
        using var expectedMaterial = new ShaderMaterial { Shader = new Shader { Code = old.Call("source", rock, 0, false).AsString() } }; using var actualMaterial = new ShaderMaterial { Shader = expectedMaterial.Shader };
        var context = new D { ["pools"] = new A { new D { ["center"] = Vector3.One, ["water_y"] = 2.0, ["radius"] = 5.0 }, new D { ["fluid_kind"] = "magma" } } };
        old.Call("bind_context", expectedMaterial, context); current.bind_context(actualMaterial, context);
        foreach (string name in new[] { "cave_frozen_water_sources", "cave_frozen_water_source_count" }) require(GD.VarToBytes(expectedMaterial.GetShaderParameter(name)).SequenceEqual(GD.VarToBytes(actualMaterial.GetShaderParameter(name))), "Frozen moisture source differs");
    }
}
