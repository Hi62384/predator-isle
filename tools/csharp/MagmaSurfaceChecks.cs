using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class MagmaSurfaceChecks
{
    internal static void Run(Node owner, Action<bool, string> require)
    {
        using var old = GD.Load<GDScript>("res://scripts/caves/magma_surface.gd").New().AsGodotObject(); using var current = new MagmaCaveSurface();
        using var loaded = GD.Load<CSharpScript>("res://scripts/csharp/caves/MagmaCaveSurface.cs").Call("new").AsGodotObject(); require(loaded is MagmaCaveSurface, "Magma provider factory failed");
        string rock = GD.Load<Shader>("res://shaders/default_cave_rock.gdshader").Code; using var surfaceShader = new CaveSurfaceShader(); string entrance = surfaceShader.code(GD.Load<Shader>("res://shaders/terrain_biomes.gdshader").Code, true, true, false, true);
        foreach (string source in new[] { rock, entrance, "shader_type spatial; void vertex(){}", rock + "\nvarying float cave_magma_weight;" }) foreach (int slot in new[] { -1, 0, 1, 2, 3, 4 }) foreach (bool entry in new[] { false, true })
            require(old.Call("source", source, slot, entry).AsString() == current.source(source, slot, entry), "Magma source adapter differs");
        foreach (var material in new[] { new D(), new D { ["cooled_strength"] = double.NaN }, new D { ["lava_emission_strength"] = 9.0 }, new D { ["lava_lighting"] = 1, ["lava_detail_quality"] = 1.0 } })
        foreach (var features in new[] { new D(), new D { ["density"] = "wrong" }, new D { ["column_frequency"] = 5.0 }, new D { ["deposit_height"] = .7, ["source_heat"] = 1 } })
            require(GD.VarToBytes(old.Call("validation_errors", material, features)).SequenceEqual(GD.VarToBytes(current.validation_errors(material, features))), "Magma settings validation differs");
        var config = new D { ["lava_emission_strength"] = 2.5, ["lava_detail_quality"] = 2 };
        foreach (string kind in new[] { "cooled_volcanic", "molten_volcanic" }) foreach (bool common in new[] { false, true })
        {
            var expected = old.Call("feature_material", kind, config, common).As<ShaderMaterial>(); var actual = current.feature_material(kind, config, common); require(actual != null && expected.Shader.Code == actual.Shader.Code, "Magma feature shader differs");
            foreach (string name in kind == "cooled_volcanic" ? new[] { "volcanic_color", "volcanic_normal" } : new[] { "lava_emission_strength", "lava_animation_speed", "lava_crust_strength", "lava_normal_strength", "lava_detail_quality" })
            {
                var a = expected.GetShaderParameter(name); var b = actual!.GetShaderParameter(name);
                if (a.VariantType == Variant.Type.Object) require(a.As<Texture2D>().GetImage().GetData().SequenceEqual(b.As<Texture2D>().GetImage().GetData()), "Magma photographed texture changed");
                else require(GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b)), "Magma feature material control differs");
            }
        }
        using var oldLighting = GD.Load<GDScript>("res://scripts/caves/magma_lighting.gd").New().AsGodotObject(); using var lighting = new MagmaCaveLighting();
        var referenceStream = (Node3D)GD.Load<GDScript>("res://scripts/caves/streamer.gd").New().AsGodotObject(); var stream = (Node3D)GD.Load<GDScript>("res://scripts/caves/streamer.gd").New().AsGodotObject();
        foreach (var item in new[] { referenceStream, stream })
        {
            owner.AddChild(item); var cell = new MeshInstance3D(); var molten = new MeshInstance3D { Name = "CaveBiome_magma_molten_volcanic" }; molten.SetMeta("source_basins", new A { "A", "B" }); cell.AddChild(molten); item.AddChild(cell); item.Set("_cells", new D { [Vector3I.Zero] = cell });
            var pools = new A(); foreach (string id in new[] { "B", "A" }) pools.Add(new D { ["id"] = id, ["center"] = Vector3.Zero, ["water_y"] = 2.0, ["radius"] = 10.0, ["fluid_kind"] = "magma", ["source_heat"] = .8, ["thermal_source"] = "source" }); item.Set("_bundle", new D { ["regions"] = new A { new D { ["pools"] = pools } } });
        }
        foreach (var point in new[] { new Vector3(10, 4, 0), new Vector3(1000, 4, 0), Vector3.Inf })
        {
            oldLighting.Call("configure", new D()); lighting.configure(new D()); oldLighting.Call("update", referenceStream, point); lighting.update(stream, point);
            require(oldLighting.Get("source_id").AsString() == lighting.source_id && oldLighting.Get("source_key").AsVector3I() == lighting.source_key, "Magma nearest-source selection differs");
            var expected = oldLighting.Get("light").As<OmniLight3D>();
            if (expected != null) require(lighting.light != null && expected.Position == lighting.light.Position && expected.Visible == lighting.light.Visible && expected.LightEnergy == lighting.light.LightEnergy && expected.OmniRange == lighting.light.OmniRange && expected.ShadowEnabled == lighting.light.ShadowEnabled, "Magma nearest-source light differs");
        }
        oldLighting.Call("release"); lighting.release(); require(lighting.light == null, "Magma light was not released"); referenceStream.Free(); stream.Free();
        require(current.create_runtime_controller(new D { ["lava_lighting"] = false }) == null, "Disabled magma lighting created a controller");
    }
}
