using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CrystalSurfaceChecks
{
    internal static void Run(Action<bool, string> require)
    {
        using var old = GD.Load<GDScript>("res://scripts/caves/crystal_surface.gd").New().AsGodotObject(); using var current = new CrystalCaveSurface();
        using var loaded = GD.Load<CSharpScript>("res://scripts/csharp/caves/CrystalCaveSurface.cs").Call("new").AsGodotObject(); require(loaded is CrystalCaveSurface, "Crystal provider factory failed");
        string rock = GD.Load<Shader>("res://shaders/default_cave_rock.gdshader").Code; using var surfaceShader = new CaveSurfaceShader(); string entrance = surfaceShader.code(GD.Load<Shader>("res://shaders/terrain_biomes.gdshader").Code, true, true, false, true);
        foreach (string source in new[] { rock, entrance, "shader_type spatial; void vertex(){}", rock + "\nvarying float cave_crystal_weight;" }) foreach (int slot in new[] { -1, 0, 1, 2, 3, 4 }) foreach (bool entry in new[] { false, true })
            require(old.Call("source", source, slot, entry).AsString() == current.source(source, slot, entry), "Crystal source adapter differs");
        foreach (var material in new[] { new D(), new D { ["ambient_shelter"] = double.NaN }, new D { ["mineral_strength"] = "wrong" }, new D { ["localized_veins"] = 1, ["luminous_strength"] = .1 } })
        foreach (var features in new[] { new D(), new D { ["density"] = 2.0 }, new D { ["maximum_height"] = 100.0 }, new D { ["geode_frequency"] = .8, ["ravine_frequency"] = .8, ["floor_ridges"] = 1 } })
            require(GD.VarToBytes(old.Call("validation_errors", material, features)).SequenceEqual(GD.VarToBytes(current.validation_errors(material, features))), "Crystal adapter validation differs");
        var config = new D { ["ambient_shelter"] = .12, ["luminous_strength"] = .01, ["mineral_strength"] = .7, ["sediment_strength"] = .1, ["localized_veins"] = true };
        foreach (string kind in new[] { "mineral_opaque", "mineral_clear", "mineral_grains", "mineral_bed" }) foreach (bool common in new[] { false, true })
        {
            var expected = old.Call("feature_material", kind, config, common).As<ShaderMaterial>(); var actual = current.feature_material(kind, config, common); require(actual != null && expected.Shader.Code == actual.Shader.Code, "Crystal feature shader differs");
            foreach (string name in new[] { "cave_common_projection", "cave_crystal_bed", "cave_crystal_luminous_strength", "cave_crystal_ambient_shelter" }) require(GD.VarToBytes(expected.GetShaderParameter(name)).SequenceEqual(GD.VarToBytes(actual!.GetShaderParameter(name))), "Crystal material parameter differs");
        }
        using var expectedMaterial = new ShaderMaterial { Shader = new Shader { Code = old.Call("source", rock, 0, false).AsString() } }; using var actualMaterial = new ShaderMaterial { Shader = expectedMaterial.Shader };
        old.Call("bind", expectedMaterial, config); current.bind(actualMaterial, config);
        foreach (string name in new[] { "cave_crystal_mineral_strength", "cave_crystal_sediment_strength", "cave_crystal_localized_veins" }) require(GD.VarToBytes(expectedMaterial.GetShaderParameter(name)).SequenceEqual(GD.VarToBytes(actualMaterial.GetShaderParameter(name))), "Crystal host surface binding differs");
    }
}
