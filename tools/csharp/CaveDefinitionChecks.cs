using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveDefinitionChecks
{
    internal static void Run(Action<bool, string> require)
    {
        var original = GD.Load<GDScript>("res://scripts/caves/biome_definition.gd");
        using var palette = new CaveMaterialPalette(); var originalPalette = GD.Load<GDScript>("res://scripts/caves/material_palette.gd");
        foreach (int style in Enumerable.Range(0, 8)) foreach (bool compact in new[] { false, true })
            require(GD.VarToBytes(originalPalette.Call("paths", style, compact)).SequenceEqual(GD.VarToBytes(palette.paths(style, compact))), "Geological palette changed");
        var pools = new Godot.Collections.Array { new D { ["center"] = Vector3.Zero, ["water_y"] = 1.0, ["radius"] = 2.0 }, new D { ["fluid_kind"] = "magma" }, new D { ["fluid_kind"] = "water", ["center"] = Vector3.One, ["water_y"] = 3.0, ["radius"] = 4.0 } };
        require(GD.VarToBytes(originalPalette.Call("water_sources", pools)).SequenceEqual(GD.VarToBytes(palette.water_sources(pools))), "Molten pool supplied water wetness");
        foreach (int style in new[] { 0, 6 })
        {
            using var expected = new ShaderMaterial { Shader = GD.Load<Shader>("res://shaders/default_cave_rock.gdshader") };
            using var actual = new ShaderMaterial { Shader = expected.Shader };
            originalPalette.Call("bind", expected, style, pools, true); palette.bind(actual, style, pools, true);
            foreach (string name in new[] { "cave_rock_colors", "cave_rock_normals", "cave_compact_palette", "geological_style", "cave_pool_positions", "cave_pool_count" })
                require(GD.VarToBytes(expected.GetShaderParameter(name)).SequenceEqual(GD.VarToBytes(actual.GetShaderParameter(name))), "Cave palette material binding differs: " + name);
        }
        foreach (string id in new[] { "default", "frozen", "crystal", "magma" })
        {
            using var current = (CaveBiomeDefinition)GD.Load<CaveBiomeDefinition>($"res://config/caves/biomes/{id}_cave_definition.tres").Duplicate();
            using var old = original.New().AsGodotObject();
            foreach (var property in current.GetPropertyList())
            {
                string name = property["name"].AsString();
                if ((property["usage"].AsInt32() & (int)PropertyUsageFlags.ScriptVariable) != 0) old.Set(name, current.Get(name));
            }
            require(GD.VarToBytes(old.Call("validation_errors")).SequenceEqual(GD.VarToBytes(current.validation_errors())), $"Definition validation differs: {id}");
            foreach (bool exclude in new[] { false, true })
            {
                current.exclude_zero_depth_bands = exclude; old.Set("exclude_zero_depth_bands", exclude);
                float[] bands = { 0, 40, 100, 180, 280, 400 };
                for (int i = -10; i <= 4200; i++)
                {
                    double depth = i / 10.0;
                    require(old.Call("depth_preference", depth, bands).AsDouble() == current.depth_preference(depth, bands), $"Depth preference differs: {id} at {depth}");
                }
            }
            foreach (var mix in new[] { new D(), new D { ["grass"] = .6, ["snow"] = .4 }, new D { [0] = .3, [1] = .7 }, new D { ["missing"] = -1.0 } })
            foreach (var preferences in new[] { current.surface_preferences, current.geological_preferences, new D { ["0"] = 50.0, [1] = 100.0 } })
                require(original.Call("preference", preferences, mix).AsDouble() == current.preference(preferences, mix), $"Suitability differs: {id}");
            foreach (double value in new[] { -1.0, 101.0, double.NaN, double.PositiveInfinity })
            {
                current.spawn_chance_percent = value; old.Set("spawn_chance_percent", value);
                require(GD.VarToBytes(old.Call("validation_errors")).SequenceEqual(GD.VarToBytes(current.validation_errors())), $"Invalid definition validation differs: {id}");
            }
        }
    }
}

