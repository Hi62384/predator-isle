using Godot;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveFeatureRenderer : RefCounted
{
    private readonly CaveBiomeMaterials _materials = new();
    private static Variant Get(D data, string key, Variant fallback = default) => data.ContainsKey(key) ? data[key] : fallback;
    public void discard(A prepared)
    {
        foreach (var value in prepared) { var item = value.AsGodotDictionary(); foreach (var node in item["nodes"].AsGodotArray()) node.As<Node3D>().Free(); var shape = item["shape"].As<CollisionShape3D>(); if (shape != null) shape.Free(); }
    }
    public bool attach(Node3D parent, A batches, Resource? registry, bool common, bool shadows)
    {
        var prepared = new List<(List<MeshInstance3D> Nodes, CollisionShape3D? Shape)>();
        bool Reject() { foreach (var item in prepared) { foreach (var node in item.Nodes) node.Free(); item.Shape?.Free(); } return false; }
        foreach (var value in batches)
        {
            var batch = value.AsGodotDictionary(); string id = batch["biome_id"].AsString(), kind = batch["kind"].AsString(); var definition = _materials.definition(registry, id); var script = definition?.Get("surface_provider").As<Script>();
            if (definition == null || script == null) return Reject(); using var provider = script.Call("new").AsGodotObject(); if (!provider.HasMethod("feature_material")) return Reject();
            var material = provider.Call("feature_material", kind, definition.Get("material_configuration"), common).As<ShaderMaterial>(); if (material == null || material.Shader == null) return Reject();
            var arrays = batch["arrays"].AsGodotArray(); var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays, new Godot.Collections.Array<A>(), Get(batch, "lods", new D()).AsGodotDictionary()); mesh.SurfaceSetMaterial(0, material);
            var node = new MeshInstance3D { Name = "CaveBiome_" + id + "_" + kind, Mesh = mesh, CastShadow = shadows && Get(batch, "shadows", true).AsBool() ? GeometryInstance3D.ShadowCastingSetting.DoubleSided : GeometryInstance3D.ShadowCastingSetting.Off }; var nodes = new List<MeshInstance3D> { node };
            if (batch.ContainsKey("source_basins")) node.SetMeta("source_basins", batch["source_basins"].AsGodotArray().Duplicate());
            if (batch.ContainsKey("far_kind"))
            {
                var far = provider.Call("feature_material", batch["far_kind"].AsString(), definition.Get("material_configuration"), common).As<ShaderMaterial>(); if (far == null || far.Shader == null) { node.Free(); return Reject(); }
                float distance = (float)Get(batch, "near_distance", 32).AsDouble(); node.VisibilityRangeEnd = distance;
                nodes.Add(new MeshInstance3D { Name = node.Name + "_OpaqueFar", Mesh = mesh, MaterialOverride = far, CastShadow = node.CastShadow, VisibilityRangeBegin = distance });
            }
            var faces = Get(batch, "collision_faces", arrays[(int)Mesh.ArrayType.Vertex]).AsVector3Array(); CollisionShape3D? shape = null;
            if (faces.Length > 0) shape = new CollisionShape3D { Name = "BiomeCollision_" + id + "_" + kind, Shape = new ConcavePolygonShape3D { BackfaceCollision = true, Data = faces } };
            prepared.Add((nodes, shape));
        }
        foreach (var item in prepared) { foreach (var node in item.Nodes) parent.AddChild(node); if (item.Shape != null) parent.GetNode<StaticBody3D>("CaveCollision").AddChild(item.Shape); } return true;
    }
}

