using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;
namespace PredatorIsle.Checks;
internal static class CaveFeatureDispatchChecks
{
    internal static void Run(Action<bool, string> require)
    {
        using var field = new CaveField(); field.height = Callable.From<double, double, double>((x,z) => 200);
        require(field.append_feature(new Vector3(32, 0, 32), new Vector3(32, 0, 32), new Vector2(20, 20), 2), "Feature dispatch field fixture rejected");
        field.BiomeFields["fixture"] = new List<Vector2> { Vector2.One }; require(field.biome_ids_for_cell(Vector3I.Zero).Count == 1, "Feature fixture has no admitted biome");
        var oldBind = GD.Load<GDScript>("res://scripts/caves/surface_biomes.gd"); using var currentBind = new CaveSurfaceBiomes(); var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); arrays[(int)Mesh.ArrayType.Vertex] = new[] { new Vector3(32, 2, 32), new Vector3(34, 2, 32), new Vector3(32, 2, 32) };
        foreach (var ids in new[] { new A(), new A { "fixture" }, new A { "a", "b", "c", "d", "e" } })
            require(GD.VarToBytes(oldBind.Call("bind", arrays, field, Vector3I.Zero, ids)).SequenceEqual(GD.VarToBytes(currentBind.bind(arrays, field, Vector3I.Zero, ids))), "Local biome channel binding differs");
        require(arrays[(int)Mesh.ArrayType.TexUV].VariantType == Variant.Type.Nil, "Biome binding overwrote original mesh controls");
        using var definition = new CaveBiomeDefinition { biome_id = "fixture", feature_provider = GD.Load<CSharpScript>("res://tools/csharp/CaveFeatureTestProvider.cs") };
        using var registry = new CaveBiomeRegionSettings { definitions = new Godot.Collections.Array<Resource> { definition } };
        var configuration = GD.Load<Resource>("res://config/caves/cave_settings.tres").Duplicate(); configuration.Set("biome_regions", registry);
        var old = GD.Load<GDScript>("res://scripts/caves/biome_features.gd"); using var current = new CaveBiomeFeatures();
        foreach (var settings in new[] { new D(), new D { ["reject"] = true }, new D { ["vertices"] = 240003 } })
        {
            definition.feature_configuration = settings; var expected = old.Call("build", field, Vector3I.Zero, 17, new A(), registry, new D()); var actual = current.build(field, Vector3I.Zero, 17, new A(), registry, new D());
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), "Feature dispatch or vertex budget differs");
            require(actual["valid"].AsBool() == (settings.Count == 0), "Feature rejection/budget fixture did not exercise refusal");
        }
        using var thermal = new CaveFeatureTestProvider();
        foreach (bool withContext in new[] { false, true })
        {
            var region = new D { ["valid"] = true }; var height = Callable.From<double, double, double>((x,z) => x + z + 100); Variant context = withContext ? Variant.From(thermal) : default;
            var expected = old.Call("decorate", region.Duplicate(true), configuration, 17, height, context); var actual = current.decorate(region.Duplicate(true), configuration, 17, height, withContext ? thermal : null);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)), "Region provider dispatch/thermal annotation differs");
        }
    }
}
