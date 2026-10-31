using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveBiomeMaterialChecks
{
    internal static void Run(Node owner, Action<bool, string> require)
    {
        var oldBlend = GD.Load<GDScript>("res://scripts/caves/biome_blend.gd"); using var blend = new CaveBiomeBlend();
        string source = GD.Load<Shader>("res://shaders/default_cave_rock.gdshader").Code;
        for (int count = 1; count <= 5; count++) foreach (bool independent in new[] { false, true })
        {
            require(oldBlend.Call("source", source, count, independent).AsString() == blend.source(source, count, independent), "Biome fragment blend source differs");
            require(oldBlend.Call("begin", count).AsString() == blend.begin(count), "Independent material target initialization differs");
        }
        require(oldBlend.Call("restore").AsString() == blend.restore() && oldBlend.Call("finish").AsString() == blend.finish(), "Independent material outputs differ");
        for (int slot = 0; slot < 4; slot++) require(oldBlend.Call("accumulate", slot).AsString() == blend.accumulate(slot), "Independent material accumulation differs");
        using var current = new CaveBiomeMaterials(); var old = GD.Load<GDScript>("res://scripts/caves/biome_materials.gd"); var registry = GD.Load<Resource>("res://config/caves/cave_biome_regions.tres");
        var referenceRegistry = registry.Duplicate(true);
        var referenceDefinitions = new Godot.Collections.Array<Resource>();
        foreach (var value in registry.Get("definitions").AsGodotArray())
        {
            var definition = value.As<Resource>().Duplicate(true); string id = definition.Get("biome_id").AsString();
            if (id == "frozen") definition.Set("surface_provider", GD.Load<GDScript>("res://scripts/caves/frozen_surface.gd"));
            if (id == "magma") definition.Set("surface_provider", GD.Load<GDScript>("res://scripts/caves/magma_surface.gd"));
            if (id == "crystal") definition.Set("surface_provider", GD.Load<GDScript>("res://scripts/caves/crystal_surface.gd"));
            referenceDefinitions.Add(definition);
        }
        referenceRegistry.Set("definitions", referenceDefinitions);
        using var original = new Shader { Code = source };
        foreach (var ids in new[] { new A { "frozen" }, new A { "crystal" }, new A { "magma" }, new A { "frozen", "crystal" }, new A { "frozen", "magma" }, new A { "crystal", "magma" }, new A { "frozen", "crystal", "magma" } })
        {
            var expected = old.Call("shader", original, ids, referenceRegistry, false).As<Shader>(); var actual = current.shader(original, ids, registry, false);
            require(expected != null && actual != null && expected.Code == actual.Code, "Biome shader composition differs: " + ids);
            require(current.shader(original, ids, registry, false) == actual, "Biome material cache was not reused");
        }
        require(current.shader(original, new A { "missing" }, registry) == null, "Unknown biome adapter was accepted");
        using var features = new CaveFeatureRenderer(); var referenceFeatures = GD.Load<GDScript>("res://scripts/caves/feature_renderer.gd");
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); arrays[(int)Mesh.ArrayType.Vertex] = new[] { Vector3.Zero, Vector3.Right, Vector3.Back };
        var batches = new A { new D { ["biome_id"] = "frozen", ["kind"] = "thin_ice", ["far_kind"] = "ice", ["arrays"] = arrays, ["near_distance"] = 40.0, ["source_basins"] = new A { "pool" } } };
        var expectedParent = new Node3D(); var actualParent = new Node3D(); foreach (var parent in new[] { expectedParent, actualParent }) { parent.AddChild(new StaticBody3D { Name = "CaveCollision" }); owner.AddChild(parent); }
        require(referenceFeatures.Call("attach", expectedParent, batches, referenceRegistry, true, false).AsBool() && features.attach(actualParent, batches, registry, true, false), "Biome feature upload rejected");
        require(expectedParent.GetChildCount() == actualParent.GetChildCount(), "Feature proxy count differs");
        for (int i = 1; i < expectedParent.GetChildCount(); i++)
        {
            var a = expectedParent.GetChild<MeshInstance3D>(i); var b = actualParent.GetChild<MeshInstance3D>(i);
            require(a.Name == b.Name && a.CastShadow == b.CastShadow && a.VisibilityRangeBegin == b.VisibilityRangeBegin && a.VisibilityRangeEnd == b.VisibilityRangeEnd, "Biome near/far feature state differs");
            require(GD.VarToBytes(((ArrayMesh)a.Mesh).SurfaceGetArrays(0)).SequenceEqual(GD.VarToBytes(((ArrayMesh)b.Mesh).SurfaceGetArrays(0))), "Feature uploaded mesh differs");
        }
        require(expectedParent.GetNode("CaveCollision").GetChildCount() == actualParent.GetNode("CaveCollision").GetChildCount(), "Biome collision attachment differs");
        var invalid = new A { batches[0], new D { ["biome_id"] = "missing", ["kind"] = "ice" } }; var empty = new Node3D(); empty.AddChild(new StaticBody3D { Name = "CaveCollision" }); owner.AddChild(empty);
        require(!features.attach(empty, invalid, registry, true, false) && empty.GetChildCount() == 1 && empty.GetNode("CaveCollision").GetChildCount() == 0, "Rejected feature batch partially mutated scene");
        expectedParent.Free(); actualParent.Free(); empty.Free();
    }
}
