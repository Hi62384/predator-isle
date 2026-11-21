using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Worker-built collision arrays; native physics installation follows the committed cut.</summary>
public partial class TerrainCollision : RefCounted
{
    private readonly StructureCollisionIndex _index = new();
    private const string SourceMesh = "terrain_collision_source_mesh";
    private const string SourceSpan = "terrain_collision_source_span";
    private const string SourceResolution = "terrain_collision_source_resolution";
    private const string GroundReady = "terrain_collision_ground_ready";
    private const string StructuresReady = "terrain_collision_structures_ready";
    private const string CavitiesReady = "terrain_collision_cavities_ready";
    public double heightfield_error_bound(float[] heights, int resolution)
    {
        double low = double.PositiveInfinity, high = double.NegativeInfinity, range = 0;
        int row = resolution + 1;
        foreach (float h in heights) { low = Math.Min(low, h); high = Math.Max(high, h); }
        for (int z = 0; z < resolution; z += 2)
        for (int x = 0; x < resolution; x += 2)
        {
            double blockLow = double.PositiveInfinity, blockHigh = double.NegativeInfinity;
            for (int dz = 0; dz < 3; dz++)
            for (int dx = 0; dx < 3; dx++)
            {
                double h = heights[Math.Min(z + dz, resolution) * row + Math.Min(x + dx, resolution)];
                blockLow = Math.Min(blockLow, h); blockHigh = Math.Max(blockHigh, h);
            }
            range = Math.Max(range, blockHigh - blockLow);
        }
        return range / 508.0 + 2.0 * (high - low) / 65534.0 + .00001;
    }

    public Vector3[] surface_faces(A arrays, int resolution)
    {
        var vertices = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var indices = arrays[(int)Mesh.ArrayType.Index].AsInt32Array();
        var result = new Vector3[resolution * resolution * 6];
        for (int i = 0; i < result.Length; i++) result[i] = vertices[indices[i]];
        return result;
    }

    public D prepare(A arrays, int resolution, bool terrain_enabled, A structures, D features) => prepare(arrays, resolution, terrain_enabled, structures, features, false);
    public D prepare(A arrays, int resolution, bool terrain_enabled, A structures, D features, bool index_structures)
    {
        var data = new D { ["heights"] = System.Array.Empty<float>(), ["ground_faces"] = System.Array.Empty<Vector3>(),
            ["structure_faces"] = System.Array.Empty<Vector3>(), ["cavity_faces"] = System.Array.Empty<Vector3>(), ["cavity_bounds"] = new Aabb() };
        if (terrain_enabled)
        {
            if (features.Count > 0 && features["openings"].AsVector4Array().Length > 0)
                data["ground_faces"] = features.TryGetValue("ground_collision", out var ground) ? ground : clipped_ground(arrays, features["openings"].AsVector4Array(), resolution);
            else
            {
                var vertices = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(); var heights = new float[(resolution + 1) * (resolution + 1)];
                for (int i = 0; i < heights.Length; i++) heights[i] = vertices[i].Y;
                data["heights"] = heights;
                double bound = heightfield_error_bound(heights, resolution); data["heightfield_error_bound_m"] = bound;
                if (bound > .01) data["ground_faces"] = surface_faces(arrays, resolution);
            }
        }
        var faces = new List<Vector3>();
        foreach (var value in structures)
        {
            if (value.VariantType == Variant.Type.Nil) continue;
            var surface = value.AsGodotArray();
            if (surface.Count > 0) faces.AddRange(surface[(int)Mesh.ArrayType.Vertex].AsVector3Array());
        }
        var packedFaces = faces.ToArray(); data["structure_faces"] = packedFaces;
        if (index_structures && packedFaces.Length > 0) data["structure_index"] = _index.build(packedFaces);
        if (features.Count > 0)
        {
            var surface = features["surfaces"].AsGodotArray()[0].AsGodotArray();
            if (surface.Count > 0)
            {
                var cavity = surface[(int)Mesh.ArrayType.Vertex].AsVector3Array(); data["cavity_faces"] = cavity;
                var bounds = new Aabb(cavity[0], Vector3.Zero);
                foreach (var point in cavity) bounds = bounds.Expand(point);
                data["cavity_bounds"] = bounds;
            }
        }
        return data;
    }

    public double portal_distance(Vector3 p, Vector4 portal)
    {
        var q = new Vector2(p.X - portal.X, p.Z - portal.Y); double angle = q.Angle();
        return q.Length() - portal.Z * (1 + .1 * Math.Sin(angle * 3 + portal.W) + .06 * Math.Sin(angle * 7 - portal.W));
    }
    public Vector3[] clipped_ground(A arrays, Vector4[] portals, int resolution)
        => ClipGround(arrays,portals,checked(resolution*resolution*6));
    public Vector3[] clipped_indexed_ground(A arrays,Vector4[] portals)=>ClipGround(arrays,portals,int.MaxValue);
    private Vector3[] ClipGround(A arrays, Vector4[] portals, int maximumIndices)
    {
        var source = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(); var indices = arrays[(int)Mesh.ArrayType.Index].AsInt32Array(); var faces = new List<Vector3>();
        for (int i = 0; i < Math.Min(indices.Length, maximumIndices); i += 3)
        {
            var polygon = new List<Vector3> { source[indices[i]], source[indices[i + 1]], source[indices[i + 2]] };
            foreach (var portal in portals)
            {
                var clipped = new List<Vector3>();
                for (int j = 0; j < polygon.Count; j++)
                {
                    var p = polygon[j]; var q = polygon[(j + 1) % polygon.Count]; bool outsideP = portal_distance(p, portal) >= 0, outsideQ = portal_distance(q, portal) >= 0;
                    if (outsideP) clipped.Add(p);
                    if (outsideP == outsideQ) continue;
                    var a = outsideP ? p : q; var b = outsideP ? q : p;
                    for (int iteration = 0; iteration < 14; iteration++)
                    {
                        var middle = (a + b) * .5f;
                        if (portal_distance(middle, portal) >= 0) a = middle; else b = middle;
                    }
                    clipped.Add(a);
                }
                polygon = clipped;
            }
            for (int j = 1; j < polygon.Count - 1; j++) { faces.Add(polygon[0]); faces.Add(polygon[j]); faces.Add(polygon[j + 1]); }
        }
        return faces.ToArray();
    }
    public D prepare_irregular(A arrays,bool terrainEnabled,A structures,D features,bool indexStructures)
    {
        var data=prepare(arrays,1,false,structures,features,indexStructures);
        if(terrainEnabled)data["ground_faces"]=clipped_indexed_ground(arrays,features.TryGetValue("openings",out var portals)?portals.AsVector4Array():System.Array.Empty<Vector4>());
        return data;
    }

    public void stage(MeshInstance3D node, double span, int resolution, bool enabled) => stage(node, span, resolution, enabled, false, default);
    public void stage(MeshInstance3D node, double span, int resolution, bool enabled, bool structure_enabled) => stage(node, span, resolution, enabled, structure_enabled, default);
    public void stage(MeshInstance3D node, double span, int resolution, bool enabled, bool structure_enabled, Variant structure_point)
    {
        var structurePoint = structure_point.VariantType == Variant.Type.Nil ? Vector3.Inf : structure_point.AsVector3();
        bool profiling = node.GetMeta("profile_collision", false).AsBool(); ulong started = profiling ? Time.GetTicksUsec() : 0;
        var body = node.GetNodeOrNull<StaticBody3D>("NearTerrainCollision");
        if (body == null && !enabled && !structure_enabled) return;
        if (body == null)
        {
            body = new StaticBody3D { Name = "NearTerrainCollision" }; node.AddChild(body);
            foreach (string name in new[] { "Heightfield", "Structures", "Cavities" }) body.AddChild(new CollisionShape3D { Name = name });
        }
        body.CollisionLayer = 0; body.CollisionMask = 0;
        var terrainShape = body.GetNode<CollisionShape3D>("Heightfield"); var structureShape = body.GetNode<CollisionShape3D>("Structures"); var cavityShape = body.GetNode<CollisionShape3D>("Cavities");
        var mesh = node.Mesh;
        long identity = unchecked((long)(mesh?.GetInstanceId() ?? 0));
        bool sameSource = body.GetMeta(SourceMesh, -1L).AsInt64() == identity &&
            body.GetMeta(SourceSpan, double.NaN).AsDouble() == span &&
            body.GetMeta(SourceResolution, -1).AsInt32() == resolution;
        if (!sameSource)
        {
            // Pooled nodes, replacement meshes and changed sample spacing must never
            // inherit a shape from another payload, even when their tile keys match.
            ClearShapes(body);
            body.SetMeta(SourceMesh, identity); body.SetMeta(SourceSpan, span); body.SetMeta(SourceResolution, resolution);
            ClearStructureSelection(node);
        }
        bool detailsEnabled = enabled || structure_enabled;
        terrainShape.Disabled = !enabled; structureShape.Disabled = cavityShape.Disabled = !detailsEnabled;
        if (mesh is null || !detailsEnabled) return;
        bool groundReady = body.GetMeta(GroundReady, false).AsBool();
        bool structuresReady = body.GetMeta(StructuresReady, false).AsBool();
        bool cavitiesReady = body.GetMeta(CavitiesReady, false).AsBool();
        if (mesh.HasMeta("collision_data"))
        {
            var data = mesh.GetMeta("collision_data").AsGodotDictionary(); ulong nodesEnd = profiling ? Time.GetTicksUsec() : 0;
            if (enabled && !groundReady)
            {
                var ground = data["ground_faces"].AsVector3Array(); var heights = data["heights"].AsFloat32Array();
                if (ground.Length > 0) SetGround(terrainShape, ground);
                else if (heights.Length > 0) SetHeightfield(terrainShape, heights, resolution, span);
                body.SetMeta(GroundReady, true);
            }
            ulong terrainEnd = profiling ? Time.GetTicksUsec() : 0;
            var cell = StructureCell(structurePoint);
            if (!structuresReady || data.ContainsKey("structure_index") && node.GetMeta("structure_collision_cell", Vector3.Inf).AsVector3() != cell)
            {
                set_structure_subset(node, structureShape, data, structurePoint);
                body.SetMeta(StructuresReady, true);
            }
            ulong structuresEnd = profiling ? Time.GetTicksUsec() : 0;
            if (!cavitiesReady)
            {
                var cavity = data["cavity_faces"].AsVector3Array();
                if (cavity.Length > 0) cavityShape.Shape = Concave(cavity, true);
                body.SetMeta(CavitiesReady, true);
            }
            if (profiling) node.SetMeta("collision_stage_profile", new D { ["nodes_ms"] = (nodesEnd - started) / 1000.0, ["terrain_shape_ms"] = (terrainEnd - nodesEnd) / 1000.0,
                ["structure_shape_ms"] = (structuresEnd - terrainEnd) / 1000.0, ["cavity_shape_ms"] = (Time.GetTicksUsec() - structuresEnd) / 1000.0 });
            return;
        }
        if (enabled && !groundReady)
        {
            var arrays = mesh.SurfaceGetArrays(0);
            if (mesh.HasMeta("cavity_portals")) SetGround(terrainShape, mesh.HasMeta("cavity_ground_faces") ? mesh.GetMeta("cavity_ground_faces").AsVector3Array() : clipped_ground(arrays, mesh.GetMeta("cavity_portals").AsVector4Array(), resolution));
            else
            {
                var vertices = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(); var heights = new float[(resolution + 1) * (resolution + 1)];
                for (int i = 0; i < heights.Length; i++) heights[i] = vertices[i].Y;
                SetHeightfield(terrainShape, heights, resolution, span);
            }
            body.SetMeta(GroundReady, true);
        }
        if (!structuresReady)
        {
            if (mesh.HasMeta("extension_structures"))
            {
                var faces = MeshFaces(mesh.GetMeta("extension_structures").As<ArrayMesh>());
                if (faces.Length > 0) structureShape.Shape = Concave(faces);
            }
            body.SetMeta(StructuresReady, true);
        }
        if (!cavitiesReady)
        {
            if (mesh.HasMeta("cavity_collision"))
            {
                var faces = MeshFaces(mesh.GetMeta("cavity_collision").As<ArrayMesh>());
                if (faces.Length > 0) cavityShape.Shape = Concave(faces, true);
            }
            body.SetMeta(CavitiesReady, true);
        }
    }
    private static Vector3 StructureCell(Vector3 point) => (point / (float)StructureCollisionIndex.CellMetres).Floor();
    /// <summary>
    /// Retain an installed/cave-clipped shape when the shared GPU carrier is replaced
    /// by its exact CPU surface. Other mesh replacements always invalidate in stage.
    /// </summary>
    internal static bool RebindEquivalentMesh(MeshInstance3D node, Mesh oldMesh, Mesh newMesh)
    {
        var body = node.GetNodeOrNull<StaticBody3D>("NearTerrainCollision");
        if (body is null || node.Mesh != newMesh || !oldMesh.HasMeta("terrain_cpu_payload") ||
            !newMesh.HasMeta("terrain_cpu_arrays") || !oldMesh.HasMeta("collision_data") || !newMesh.HasMeta("collision_data") ||
            body.GetMeta(SourceMesh, -1L).AsInt64() != unchecked((long)oldMesh.GetInstanceId())) return false;
        var source = oldMesh.GetMeta("terrain_cpu_payload").As<TerrainCpuSurfacePayload>().Data;
        int resolution = body.GetMeta(SourceResolution, -1).AsInt32();
        if (body.GetMeta(SourceSpan, double.NaN).AsDouble() != source.Patch.Size ||
            resolution != source.Topology.Axis.Length - 1 ||
            node.GetMeta("resolution", resolution).AsInt32() != resolution ||
            !oldMesh.GetMeta("collision_data").AsGodotDictionary().RecursiveEqual(newMesh.GetMeta("collision_data").AsGodotDictionary())) return false;
        body.SetMeta(SourceMesh, unchecked((long)newMesh.GetInstanceId()));
        return true;
    }
    private static void ClearStructureSelection(MeshInstance3D node)
    {
        foreach (string name in new[] { "structure_collision_cell", "structure_collision_triangles" })
            if (node.HasMeta(name)) node.RemoveMeta(name);
    }
    private static void ClearShapes(StaticBody3D body)
    {
        foreach (var child in body.GetChildren()) if (child is CollisionShape3D shape)
        { shape.Disabled = true; shape.Shape = null; shape.Transform = Transform3D.Identity; }
        foreach (string name in new[] { GroundReady, StructuresReady, CavitiesReady })
            if (body.HasMeta(name)) body.RemoveMeta(name);
    }
    private static Vector3[] MeshFaces(ArrayMesh mesh)
    {
        var faces = new List<Vector3>();
        for (int i = 0; i < mesh.GetSurfaceCount(); i++) faces.AddRange(mesh.SurfaceGetArrays(i)[(int)Mesh.ArrayType.Vertex].AsVector3Array());
        return faces.ToArray();
    }
    private static ConcavePolygonShape3D Concave(Vector3[] faces, bool backface = false)
    {
        var shape = new ConcavePolygonShape3D { BackfaceCollision = backface }; shape.SetFaces(faces); return shape;
    }
    private static void SetGround(CollisionShape3D node, Vector3[] faces) { node.Shape = Concave(faces); node.Position = Vector3.Zero; node.Scale = Vector3.One; }
    private static void SetHeightfield(CollisionShape3D node, float[] heights, int resolution, double span)
    {
        node.Shape = new HeightMapShape3D { MapWidth = resolution + 1, MapDepth = resolution + 1, MapData = heights };
        node.Position = new Vector3((float)(span * .5), 0, (float)(span * .5)); node.Scale = new Vector3((float)(span / resolution), 1, (float)(span / resolution));
    }
    public void set_structure_subset(MeshInstance3D node, CollisionShape3D shape_node, D data, Vector3 point)
    {
        var selected = _index.select(data["structure_faces"].AsVector3Array(), data.TryGetValue("structure_index", out var metadata) ? metadata.AsGodotDictionary() : new(), point);
        var faces = selected["faces"].AsVector3Array(); shape_node.Shape = faces.Length == 0 ? null : Concave(faces);
        node.SetMeta("structure_collision_cell", StructureCell(point)); node.SetMeta("structure_collision_triangles", faces.Length / 3);
    }
    public void refresh_structure_subset(MeshInstance3D node, Vector3 point)
    {
        if (!node.Mesh.HasMeta("collision_data")) return;
        var body = node.GetNodeOrNull<StaticBody3D>("NearTerrainCollision"); if (body == null) return;
        var data = node.Mesh.GetMeta("collision_data").AsGodotDictionary(); if (!data.ContainsKey("structure_index")) return;
        if (body.GetNode<CollisionShape3D>("Structures").Disabled) return;
        // A converted/replaced mesh is installed by stage before its new payload
        // can supply a subset. Do not pair new faces with an old retained source.
        if (body.GetMeta(SourceMesh, -1L).AsInt64() != unchecked((long)node.Mesh.GetInstanceId())) return;
        var key = StructureCell(point);
        if (node.GetMeta("structure_collision_cell", Vector3.Inf).AsVector3() == key) return;
        set_structure_subset(node, body.GetNode<CollisionShape3D>("Structures"), data, point);
    }
    public void activate(MeshInstance3D node, bool enabled)
    {
        var body = node.GetNodeOrNull<StaticBody3D>("NearTerrainCollision"); if (body != null) body.CollisionLayer = enabled ? 1u : 0u;
    }
    public void release(MeshInstance3D node)
    {
        var body = node.GetNodeOrNull<StaticBody3D>("NearTerrainCollision"); if (body == null) return;
        body.CollisionLayer = 0; body.CollisionMask = 0; ClearShapes(body); ClearStructureSelection(node);
        foreach (string name in new[] { SourceMesh, SourceSpan, SourceResolution })
            if (body.HasMeta(name)) body.RemoveMeta(name);
    }
}
