using Godot;
using System;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Prepare hidden resources, then exchange a complete visual/physics cut atomically.</summary>
public partial class CaveSurfaceTransaction : RefCounted
{
    private readonly CaveSurfaceCut _cut = new(); private readonly TerrainCollision _collision = new();
    public A records { get; set; } = new();
    public A patches { get; set; } = new();
    public D columns { get; set; } = new();
    public bool prepared { get; set; }
    public bool committed { get; set; }
    public ImageTexture? mask_texture { get; set; }
    public GodotObject? previous { get; set; }
    public bool collision_enabled { get; set; } = true;
    public bool common_vertex_projection { get; set; } = true;
    private static Variant Get(D d, string key, Variant fallback = default) => d.ContainsKey(key) ? d[key] : fallback;
    private static Variant ObjectValue(GodotObject? value) => value == null ? default : Variant.From(value);
    public D baseline(MeshInstance3D node)
    {
        foreach (var value in records) { var record = value.AsGodotDictionary(); if (record["node"].AsGodotObject() == node && GodotObject.IsInstanceValid(node) && node.Mesh == record["mesh"].As<Mesh>()) return record; } return new();
    }
    public bool prepare(A nodes, A replacements, D requested_columns, Vector2 center) => prepare(nodes, replacements, requested_columns, center, null, new D());
    public bool prepare(A nodes, A replacements, D requested_columns, Vector2 center, GodotObject? prior) => prepare(nodes, replacements, requested_columns, center, prior, new D());
    public bool prepare(A nodes, A replacements, D requested_columns, Vector2 center, GodotObject? prior, D prepared_ground)
    {
        if (prepared || committed || requested_columns.Count == 0) return false;
        records.Clear(); patches.Clear(); columns.Clear(); mask_texture = null; previous = null;
        var mask = _cut.mask(requested_columns, center); if (mask.Count == 0 || mask["columns"].AsGodotDictionary().Count != requested_columns.Count) return false;
        mask_texture = ImageTexture.CreateFromImage(Image.CreateFromData(mask["side"].AsInt32(), mask["side"].AsInt32(), false, Image.Format.R8, mask["r8_bytes"].AsByteArray())); previous = prior; columns = requested_columns.Duplicate();
        foreach (var raw in replacements)
        {
            if (raw.VariantType != Variant.Type.Object || raw.AsGodotObject() is not MeshInstance3D node || !GodotObject.IsInstanceValid(node) || node.Mesh == null || !node.IsInsideTree()) return false;
            var body = node.GetNodeOrNull<StaticBody3D>("CaveCollision"); if (body == null || body.CollisionLayer != 0 || node.Visible) return false; patches.Add(node);
        }
        if (patches.Count == 0) return false;
        foreach (var raw in nodes)
        {
            if (raw.VariantType != Variant.Type.Object || raw.AsGodotObject() is not MeshInstance3D node || !GodotObject.IsInstanceValid(node) || node.Mesh == null || node.Mesh.GetSurfaceCount() == 0 || !node.GlobalBasis.IsEqualApprox(Basis.Identity)) return false;
            var inherited = prior != null ? prior.Call("baseline", node).AsGodotDictionary() : new D();
            var originalOverride = inherited.Count == 0 ? node.GetSurfaceOverrideMaterial(0) : inherited["original_override"].As<Material>();
            var material = originalOverride ?? node.Mesh.SurfaceGetMaterial(0); if (material is not ShaderMaterial source) return false;
            var shader = _cut.shader(source.Shader, common_vertex_projection); if (shader == null) return false;
            var replacement = (ShaderMaterial)source.Duplicate(); replacement.Shader = shader; replacement.SetShaderParameter("cave_cut_enabled", true); replacement.SetShaderParameter("cave_cut_mask", mask_texture);
            replacement.SetShaderParameter("cave_cut_tile_offset", new Vector2(node.GlobalPosition.X, node.GlobalPosition.Z) / 64 - (Vector2)mask["origin_cell"].AsVector2I());
            var shapeNode = node.GetNodeOrNull<CollisionShape3D>("NearTerrainCollision/Heightfield"); Shape3D? originalShape = null, groundShape = null;
            if (shapeNode != null)
            {
                originalShape = inherited.Count == 0 ? shapeNode.Shape : inherited["original_shape"].As<Shape3D>(); groundShape = originalShape;
                int resolution = node.GetMeta("resolution", 0).AsInt32(); var tile = node.GetMeta("tile", Vector3I.Zero).AsVector3I();
                if (originalShape != null && tile.Z <= 1)
                {
                    var clipped = Get(prepared_ground, tile.ToString(), new D()).AsGodotDictionary();
                    if (clipped.Count == 0)
                    {
                        var data = node.Mesh.GetMeta("collision_data", new D()).AsGodotDictionary(); var faces = Get(data, "ground_faces", System.Array.Empty<Vector3>()).AsVector3Array();
                        if (faces.Length == 0)
                        {
                            var arrays = node.Mesh.HasMeta("terrain_cpu_arrays") ? node.Mesh.GetMeta("terrain_cpu_arrays").AsGodotArray() : ((ArrayMesh)node.Mesh).SurfaceGetArrays(0);
                            if (resolution < 1 || arrays.Count == 0) return false; faces = _collision.surface_faces(arrays, resolution);
                        }
                        clipped = _cut.ground(faces, node.GlobalPosition, columns);
                    }
                    if (!clipped["valid"].AsBool()) return false;
                    if (clipped["removed_source_triangles"].AsInt32() > 0 || clipped["split_source_triangles"].AsInt32() > 0) groundShape = new ConcavePolygonShape3D { Data = clipped["faces"].AsVector3Array() };
                }
            }
            records.Add(new D { ["node"] = node, ["mesh"] = node.Mesh, ["transform"] = node.GlobalTransform, ["original_override"] = ObjectValue(originalOverride), ["material"] = replacement,
                ["shape_node"] = ObjectValue(shapeNode), ["original_shape"] = ObjectValue(originalShape), ["ground_shape"] = ObjectValue(groundShape),
                ["original_shape_transform"] = inherited.Count == 0 && shapeNode != null ? shapeNode.Transform : Get(inherited, "original_shape_transform", Transform3D.Identity) });
        }
        prepared = true; return true;
    }
    public bool ready_to_commit()
    {
        if (!prepared || committed) return false;
        foreach (var value in records)
        {
            var record = value.AsGodotDictionary(); var node = record["node"].As<MeshInstance3D>();
            if (!GodotObject.IsInstanceValid(node) || node.Mesh != record["mesh"].As<Mesh>() || node.GlobalTransform != record["transform"].AsTransform3D()) return false;
        }
        foreach (var value in patches) { var node = value.As<MeshInstance3D>(); if (!GodotObject.IsInstanceValid(node) || node.Mesh == null) return false; } return true;
    }
    public void restore_node(D record)
    {
        var node = record["node"].As<MeshInstance3D>(); if (!GodotObject.IsInstanceValid(node) || node.Mesh != record["mesh"].As<Mesh>()) return;
        node.SetSurfaceOverrideMaterial(0, record["original_override"].As<Material>()); var shapeNode = record["shape_node"].As<CollisionShape3D>();
        if (GodotObject.IsInstanceValid(shapeNode)) { shapeNode.Shape = record["original_shape"].As<Shape3D>(); shapeNode.Transform = record["original_shape_transform"].AsTransform3D(); }
    }
    public void apply_node(MeshInstance3D node)
    {
        var record = baseline(node); if (record.Count == 0) return;
        node.SetSurfaceOverrideMaterial(0, record["material"].As<Material>()); var shapeNode = record["shape_node"].As<CollisionShape3D>();
        if (GodotObject.IsInstanceValid(shapeNode)) { shapeNode.Shape = record["ground_shape"].As<Shape3D>(); if (record["ground_shape"].AsGodotObject() != record["original_shape"].AsGodotObject()) shapeNode.Transform = Transform3D.Identity; }
    }
    public bool commit()
    {
        if (!ready_to_commit()) return false;
        if (previous != null) foreach (var value in previous.Get("records").AsGodotArray()) previous.Call("restore_node", value);
        foreach (var value in records) apply_node(value.AsGodotDictionary()["node"].As<MeshInstance3D>());
        foreach (var value in patches) { var node = value.As<MeshInstance3D>(); node.Visible = true; node.GetNode<StaticBody3D>("CaveCollision").CollisionLayer = collision_enabled ? 1u : 0u; }
        if (previous != null)
        {
            foreach (var value in previous.Get("patches").AsGodotArray()) { var node = value.As<MeshInstance3D>(); if (GodotObject.IsInstanceValid(node) && !patches.Contains(value)) { node.Visible = false; node.GetNode<StaticBody3D>("CaveCollision").CollisionLayer = 0; } }
            previous.Set("committed", false);
        }
        previous = null; committed = true; return true;
    }
    public void reset()
    {
        if (committed) foreach (var value in records) restore_node(value.AsGodotDictionary());
        foreach (var value in patches) { var node = value.As<MeshInstance3D>(); if (GodotObject.IsInstanceValid(node)) { node.Visible = false; node.GetNode<StaticBody3D>("CaveCollision").CollisionLayer = 0; } } committed = false;
    }
    public void release_node(MeshInstance3D node) { var record = baseline(node); if (record.Count > 0) restore_node(record); }
    public A materials() { var result = new A(); if (committed) foreach (var value in records) result.Add(value.AsGodotDictionary()["material"]); return result; }
}
