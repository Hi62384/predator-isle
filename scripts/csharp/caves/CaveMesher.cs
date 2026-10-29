using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Native C# field implementations bypass the transitional language boundary.</summary>
public interface ICaveField
{
    double Sample(Vector3 point);
    Vector3 Normal(Vector3 point);
    bool HasChunk(Vector3I key);
    A PreciseShores { get; }
    bool HasSurfaceColumn(Vector2I column);
    double SurfaceHeight(Vector2 point);
}

internal sealed class LegacyCaveField : ICaveField
{
    private readonly GodotObject _volume;
    private readonly Callable _sample, _normal, _hasChunk, _surfaceHeight;
    public LegacyCaveField(GodotObject volume)
    {
        _volume = volume; _sample = new(volume, "sample"); _normal = new(volume, "normal");
        _hasChunk = new(volume, "has_chunk"); _surfaceHeight = new(volume, "surface_height");
    }
    public double Sample(Vector3 point) => _sample.Call(point).AsDouble();
    public Vector3 Normal(Vector3 point) => _normal.Call(point).AsVector3();
    public bool HasChunk(Vector3I key) => _hasChunk.Call(key).AsBool();
    public A PreciseShores { get { var value = _volume.Get("precise_shores"); return value.VariantType == Variant.Type.Array ? value.AsGodotArray() : new(); } }
    public bool HasSurfaceColumn(Vector2I column) => _volume.Get("surface_columns").AsGodotDictionary().ContainsKey(column);
    public double SurfaceHeight(Vector2 point) => _surfaceHeight.Call(point).AsDouble();
}

/// <summary>Fixed-grid tetrahedra, canonical welded crossings and original sign-case winding.</summary>
public partial class CaveMesher : RefCounted
{
    private static readonly int[][] Tets = { new[] { 0, 5, 1, 6 }, new[] { 0, 1, 2, 6 }, new[] { 0, 2, 3, 6 }, new[] { 0, 3, 7, 6 }, new[] { 0, 7, 4, 6 }, new[] { 0, 4, 5, 6 } };
    private static readonly bool[] Flip = { false, false, true, false, false, true, false, false, true, false, true, true, false, false, true, false };
    private readonly List<Vector3> _vertices = new(), _normals = new();
    private readonly Dictionary<Vector3, Vector3> _normalCache = new();
    protected ICaveField? Field;
    private A _shores = new();
    public Vector3 origin { get; set; }
    public bool capture_boundary_values { get; set; }
    public A boundary_values { get; set; } = new();
    public bool case_flip { get; set; }
    public Vector3[] vertices => _vertices.ToArray();
    public Vector3[] normals => _normals.ToArray();
    public Color[] colors { get { var result = new Color[_vertices.Count]; System.Array.Fill(result, new Color(.38f, .35f, .30f, 1)); return result; } }

    public Vector3 crossing(Vector3 a, Vector3 b, double va, double vb)
    {
        if (a.X > b.X || (a.X == b.X && (a.Y > b.Y || (a.Y == b.Y && a.Z > b.Z)))) { (a, b) = (b, a); (va, vb) = (vb, va); }
        var original = Weld(a.Lerp(b, (float)Math.Clamp(va / (va - vb), 0, 1)));
        foreach (var value in _shores)
        {
            var shore = value.AsGodotDictionary(); var center = shore["center"].AsVector3();
            if (new Vector2(original.X - center.X, original.Z - center.Z).Length() > shore["radius"].AsDouble() + 4 || Math.Abs(original.Y - center.Y) > 6) continue;
            var low = a; var high = b; bool inside = va < 0;
            for (int iteration = 0; iteration < 12; iteration++)
            {
                var middle = (low + high) * .5f;
                if ((Field!.Sample(middle) < 0) == inside) low = middle; else high = middle;
            }
            return Weld((low + high) * .5f);
        }
        return original;
    }
    // Godot's native vector round uses half-away-from-zero; .NET Vector3.Round uses ties-to-even.
    private static Vector3 Weld(Vector3 p) => new(
        MathF.Round(p.X * 4096, MidpointRounding.AwayFromZero) / 4096,
        MathF.Round(p.Y * 4096, MidpointRounding.AwayFromZero) / 4096,
        MathF.Round(p.Z * 4096, MidpointRounding.AwayFromZero) / 4096);

    public virtual void emit(Vector3 a, Vector3 b, Vector3 c)
    {
        var cross = (c - a).Cross(b - a);
        if (cross.LengthSquared() == 0) return;
        if (case_flip) { (b, c) = (c, b); cross = -cross; }
        var face = cross.Normalized();
        AddVertex(a, face); AddVertex(b, face); AddVertex(c, face);
    }
    private void AddVertex(Vector3 point, Vector3 face)
    {
        if (!_normalCache.TryGetValue(point, out var normal))
        {
            normal = Field!.Normal(point);
            if (_normalCache.Count < 65536) _normalCache[point] = normal;
        }
        if (normal.LengthSquared() < .5 || normal.Dot(face) < .15) normal = face;
        _vertices.Add(point - origin); _normals.Add(normal);
    }

    private void Tetra(ReadOnlySpan<Vector3> points, ReadOnlySpan<float> values, int[] indices)
    {
        int mask = 0;
        for (int i = 0; i < 4; i++) if (values[indices[i]] < 0) mask |= 1 << i;
        if (mask is 0 or 15) return;
        var p = points[indices[0]]; var a = points[indices[1]] - p; var b = points[indices[2]] - p; var c = points[indices[3]] - p;
        case_flip = Flip[mask] != (a.Dot(b.Cross(c)) < 0);
        Span<int> inside = stackalloc int[4], outside = stackalloc int[4]; int ni = 0, no = 0;
        foreach (int index in indices) { if (values[index] < 0) inside[ni++] = index; else outside[no++] = index; }
        if (ni == 1 || no == 1)
        {
            int single = ni == 1 ? inside[0] : outside[0]; var others = ni == 1 ? outside[..no] : inside[..ni];
            Span<Vector3> cuts = stackalloc Vector3[3]; int cursor = 0;
            foreach (int other in others) cuts[cursor++] = crossing(points[single], points[other], values[single], values[other]);
            emit(cuts[0], cuts[1], cuts[2]); return;
        }
        var c0 = crossing(points[inside[0]], points[outside[0]], values[inside[0]], values[outside[0]]);
        var c1 = crossing(points[inside[0]], points[outside[1]], values[inside[0]], values[outside[1]]);
        var c2 = crossing(points[inside[1]], points[outside[1]], values[inside[1]], values[outside[1]]);
        var c3 = crossing(points[inside[1]], points[outside[0]], values[inside[1]], values[outside[0]]);
        emit(c0, c1, c2); emit(c0, c2, c3);
    }

    public A build(GodotObject volume, Vector3I coordinate, double step_metres = 2)
    {
        _vertices.Clear(); _normals.Clear(); _normalCache.Clear(); boundary_values = new();
        Field = volume as ICaveField ?? new LegacyCaveField(volume); origin = (Vector3)coordinate * 64;
        _shores = Field.PreciseShores;
        if ((step_metres != 1 && step_metres != 2 && step_metres != 4) || !Field.HasChunk(coordinate)) return new();
        int count = (int)Math.Round(64 / step_metres), row = count + 1, plane = row * row;
        var points = new Vector3[row * plane]; var values = new float[points.Length];
        for (int z = 0; z < row; z++)
        for (int y = 0; y < row; y++)
        for (int x = 0; x < row; x++)
        {
            int index = x + row * y + plane * z; var point = origin + new Vector3(x, y, z) * (float)step_metres;
            points[index] = point; values[index] = (float)Field.Sample(point);
        }
        if (capture_boundary_values && step_metres == 2)
            for (int face = 0; face < 6; face++)
            {
                var faceValues = new float[plane];
                for (int y = 0; y < row; y++)
                for (int x = 0; x < row; x++)
                {
                    int index = face < 2 ? ((face % 2 == 1 ? count : 0) + row * x + plane * y)
                        : face < 4 ? (x + row * (face % 2 == 1 ? count : 0) + plane * y)
                        : x + row * y + plane * (face % 2 == 1 ? count : 0);
                    faceValues[x + row * y] = values[index];
                }
                boundary_values.Add(faceValues);
            }
        int[] offsets = { 0, 1, 1 + row, row, plane, 1 + plane, 1 + row + plane, row + plane };
        Span<Vector3> cubePoints = stackalloc Vector3[8]; Span<float> cubeValues = stackalloc float[8];
        for (int z = 0; z < count; z++)
        for (int y = 0; y < count; y++)
        for (int x = 0; x < count; x++)
        {
            int start = x + row * y + plane * z; bool air = false, rock = false;
            foreach (int offset in offsets)
            {
                air |= values[start + offset] < 0; rock |= values[start + offset] >= 0;
                if (air && rock) break;
            }
            if (!air || !rock) continue;
            for (int i = 0; i < 8; i++) { cubePoints[i] = points[start + offsets[i]]; cubeValues[i] = values[start + offsets[i]]; }
            foreach (var tet in Tets) Tetra(cubePoints, cubeValues, tet);
        }
        if (_vertices.Count == 0) return new();
        var arrays = new A(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices; arrays[(int)Mesh.ArrayType.Normal] = normals; arrays[(int)Mesh.ArrayType.Color] = colors;
        return arrays;
    }
}
