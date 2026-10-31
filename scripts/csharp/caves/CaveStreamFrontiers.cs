using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Temporary matching face seals keep unloaded cave neighbours safe.</summary>
public partial class CaveStreamFrontiers : RefCounted
{
    private static readonly Vector3I[] Directions = { Vector3I.Left, Vector3I.Right, Vector3I.Down, Vector3I.Up, Vector3I.Forward, Vector3I.Back };
    private static readonly Vector3[] Axes = { Vector3.Up, Vector3.Up, Vector3.Right, Vector3.Right, Vector3.Right, Vector3.Right };
    private static readonly Vector3[] Other = { Vector3.Back, Vector3.Back, Vector3.Back, Vector3.Back, Vector3.Up, Vector3.Up };
    public D build(GodotObject volume, Vector3I key) => build(volume, key, new A());
    public D build(GodotObject volume, Vector3I key, A boundary_values)
    {
        var result = new D(); var origin = (Vector3)key * 64; using var mesher = new CaveMesher();
        if (!volume.Call("has_chunk", key).AsBool()) return result;
        double cover = volume.Get("opening_rock_cover").AsDouble(); volume.Set("opening_rock_cover", Math.Max(6, cover));
        try
        {
            bool caveOnly = volume.HasMethod("cave_sample");
            for (int face = 0; face < 6; face++)
            {
                var direction = (Vector3)Directions[face]; var start = origin + direction.Max(Vector3.Zero) * 64;
                var u = Axes[face]; var v = Other[face]; var points = new Vector3[1089]; var values = new float[1089];
                float[]? reuse = boundary_values.Count == 6 ? boundary_values[face].AsFloat32Array() : null;
                if (reuse?.Length != 1089) reuse = null;
                for (int y = 0; y < 33; y++) for (int x = 0; x < 33; x++)
                {
                    int index = x + y * 33; var point = start + u * x * 2 + v * y * 2; points[index] = point;
                    values[index] = reuse != null ? reuse[index] : (float)(caveOnly ? volume.Call("cave_sample", point).AsDouble() : volume is ICaveField native ? native.Sample(point) : volume.Call("sample", point).AsDouble());
                }
                var vertices = new List<Vector3>(); var inward = -direction;
                for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++)
                {
                    int a = x + y * 33;
                    Emit(a, a + 1, a + 34); Emit(a, a + 34, a + 33);
                }
                if (vertices.Count == 0) continue;
                var normals = new Vector3[vertices.Count]; var colors = new Color[vertices.Count];
                System.Array.Fill(normals, inward); System.Array.Fill(colors, new Color(.38f, .35f, .3f, 1));
                var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max); arrays[(int)Mesh.ArrayType.Vertex] = vertices.ToArray(); arrays[(int)Mesh.ArrayType.Normal] = normals; arrays[(int)Mesh.ArrayType.Color] = colors; result[face] = arrays;
                void Emit(int a, int b, int c)
                {
                    if (values[a] >= 0 && values[b] >= 0 && values[c] >= 0) return;
                    Span<int> indices = stackalloc int[3] { a, b, c }; Span<Vector3> polygon = stackalloc Vector3[6]; int count = 0;
                    for (int i = 0; i < 3; i++)
                    {
                        int first = indices[i], next = indices[(i + 1) % 3];
                        if (values[first] < 0) polygon[count++] = points[first];
                        if ((values[first] < 0) != (values[next] < 0)) polygon[count++] = mesher.crossing(points[first], points[next], values[first], values[next]);
                    }
                    for (int i = 1; i < count - 1; i++)
                    {
                        var p = polygon[0]; var q = polygon[i]; var r = polygon[i + 1]; var normal = (r - p).Cross(q - p);
                        if (normal.LengthSquared() == 0) continue; if (normal.Dot(inward) < 0) (q, r) = (r, q);
                        vertices.Add(p - origin); vertices.Add(q - origin); vertices.Add(r - origin);
                    }
                }
            }
            return result;
        }
        finally { volume.Set("opening_rock_cover", cover); }
    }
    public void attach(MeshInstance3D parent, D payload, Material material, bool shadows)
    {
        if (payload.Count == 0) return;
        var container = new Node3D { Name = "CaveFrontiers" }; parent.AddChild(container);
        foreach (var entry in payload)
        {
            var arrays = entry.Value.AsGodotArray(); var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays); mesh.SurfaceSetMaterial(0, material);
            var node = new MeshInstance3D { Mesh = mesh, CastShadow = shadows ? GeometryInstance3D.ShadowCastingSetting.DoubleSided : GeometryInstance3D.ShadowCastingSetting.Off }; node.SetMeta("face", entry.Key);
            var body = new StaticBody3D { Name = "FrontierCollision", CollisionLayer = 0, CollisionMask = 0 };
            var shape = new ConcavePolygonShape3D { BackfaceCollision = true, Data = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array() };
            body.AddChild(new CollisionShape3D { Shape = shape }); node.AddChild(body); container.AddChild(node);
        }
    }
    public void synchronize(D cells) => synchronize(cells, true);
    public void synchronize(D cells, bool collision_enabled)
    {
        foreach (var entry in cells)
        {
            var parent = entry.Value.As<Node>(); if (!GodotObject.IsInstanceValid(parent)) continue;
            var container = parent.GetNodeOrNull<Node3D>("CaveFrontiers"); if (container == null) continue;
            foreach (var child in container.GetChildren())
            {
                var node = (MeshInstance3D)child; bool closed = !cells.ContainsKey(entry.Key.AsVector3I() + Directions[node.GetMeta("face").AsInt32()]);
                node.Visible = closed; node.GetNode<StaticBody3D>("FrontierCollision").CollisionLayer = closed && collision_enabled ? 1u : 0u;
            }
        }
    }
}
