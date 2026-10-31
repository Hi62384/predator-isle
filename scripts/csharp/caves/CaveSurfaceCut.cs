using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CaveSurfaceCut : RefCounted
{
    private readonly Dictionary<string, Shader> _shaders = new();
    private readonly Queue<string> _shaderRing = new();
    public D mask(D columns, Vector2 center) => mask(columns, center, 1024);
    public D mask(D columns, Vector2 center, int side)
    {
        if (!center.IsFinite() || side < 16 || side > 1024 || Math.Abs((double)center.X) > 2147480000.0 * 64 || Math.Abs((double)center.Y) > 2147480000.0 * 64) return new();
        var origin = new Vector2I((int)Math.Floor(center.X / 64.0), (int)Math.Floor(center.Y / 64.0)) - new Vector2I(side / 2, side / 2);
        var bytes = new byte[side * side]; var admitted = new D();
        foreach (var value in columns.Keys)
        {
            var key = value.AsVector2I(); var local = key - origin;
            if (local.X < 0 || local.Y < 0 || local.X >= side || local.Y >= side) continue;
            bytes[local.Y * side + local.X] = 255; admitted[key] = true;
        }
        return new D { ["origin_cell"] = origin, ["side"] = side, ["r8_bytes"] = bytes, ["columns"] = admitted };
    }
    public Shader? shader(Shader? original) => shader(original, false);
    public Shader? shader(Shader? original, bool common_projection)
    {
        if (original == null) return null;
        string source = original.Code; const string marker = "void fragment() {";
        int first = source.IndexOf(marker, StringComparison.Ordinal);
        if (first < 0 || source.IndexOf(marker, first + marker.Length, StringComparison.Ordinal) >= 0 || !source.Contains("varying vec3 forest_local_position;", StringComparison.Ordinal)) return null;
        string digest = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(source))).ToLowerInvariant() + (common_projection ? "/shared_projection" : "");
        if (_shaders.TryGetValue(digest, out var cached)) return cached;
        const string uniforms = "\nuniform bool cave_cut_enabled=false;\nuniform sampler2D cave_cut_mask:filter_nearest,repeat_disable;\nuniform vec2 cave_cut_tile_offset=vec2(0);\n";
        const string clipping = "\n if(cave_cut_enabled){\n  ivec2 cut_cell=ivec2(floor(forest_local_position.xz/64.0+cave_cut_tile_offset));\n  if(all(greaterThanEqual(cut_cell,ivec2(0)))&&all(lessThan(cut_cell,textureSize(cave_cut_mask,0)))&&texelFetch(cave_cut_mask,cut_cell,0).r>.5)discard;\n }\n";
        string code = source.Replace(marker, uniforms + marker + clipping, StringComparison.Ordinal);
        if (common_projection) code = CaveVertexProjection.Source(code);
        if (code.Length == 0) return null;
        var result = new Shader { Code = code };
        if (_shaderRing.Count >= 8) _shaders.Remove(_shaderRing.Dequeue());
        _shaderRing.Enqueue(digest); _shaders[digest] = result; return result;
    }
    private static List<List<Vector3>> Subtract(List<Vector3> polygon, Rect2 rect)
    {
        var remaining = polygon; var outside = new List<List<Vector3>>();
        for (int plane = 0; plane < 4; plane++)
        {
            if (remaining.Count < 3) break;
            int axis = plane < 2 ? 0 : 2;
            double boundary = plane switch { 0 => rect.Position.X, 1 => rect.End.X, 2 => rect.Position.Y, _ => rect.End.Y };
            double sign = plane % 2 == 0 ? 1 : -1; var inner = new List<Vector3>(); var outer = new List<Vector3>();
            for (int j = 0; j < remaining.Count; j++)
            {
                var a = remaining[j]; var b = remaining[(j + 1) % remaining.Count]; double da = (a[axis] - boundary) * sign, db = (b[axis] - boundary) * sign;
                if (da >= 0) inner.Add(a); if (da <= 0) outer.Add(a);
                if (da < 0 && db > 0 || da > 0 && db < 0)
                { var crossing = a.Lerp(b, (float)(da / (da - db))); crossing[axis] = (float)boundary; inner.Add(crossing); outer.Add(crossing); }
            }
            if (outer.Count >= 3) outside.Add(outer); remaining = inner;
        }
        return outside;
    }
    public D ground(Vector3[] faces, Vector3 world_origin, D columns)
    {
        var reject = new D { ["valid"] = false, ["faces"] = faces };
        if (!world_origin.IsFinite() || faces.Length % 3 != 0) return reject;
        if (columns.Count == 0) return new D { ["valid"] = true, ["faces"] = faces, ["removed_source_triangles"] = 0, ["split_source_triangles"] = 0 };
        var output = new List<Vector3>(); int removed = 0, split = 0;
        for (int i = 0; i < faces.Length; i += 3)
        {
            var triangle = new List<Vector3> { faces[i], faces[i + 1], faces[i + 2] };
            if (triangle.Any(p => !p.IsFinite())) return reject;
            var center = (triangle[0] + triangle[1] + triangle[2]) / 3 + world_origin;
            var minimum = triangle[0].Min(triangle[1]).Min(triangle[2]) + world_origin;
            var maximum = triangle[0].Max(triangle[1]).Max(triangle[2]) + world_origin;
            if (new[] { minimum.X, minimum.Z, maximum.X, maximum.Z }.Any(v => Math.Abs((double)v) > 2147480000.0 * 64)) return reject;
            var key = new Vector2I((int)Math.Floor(center.X / 64.0), (int)Math.Floor(center.Z / 64.0));
            if (minimum.X >= key.X * 64.0 && maximum.X <= (key.X + 1) * 64.0 && minimum.Z >= key.Y * 64.0 && maximum.Z <= (key.Y + 1) * 64.0)
            { if (columns.ContainsKey(key)) removed++; else output.AddRange(triangle); continue; }
            var first = new Vector2I((int)Math.Floor(minimum.X / 64.0), (int)Math.Floor(minimum.Z / 64.0));
            var last = new Vector2I((int)Math.Floor(maximum.X / 64.0), (int)Math.Floor(maximum.Z / 64.0));
            long width = (long)last.X - first.X + 1, height = (long)last.Y - first.Y + 1;
            if (width > 4096 || height > 4096 || width * height > 4096) return reject;
            var polygons = new List<List<Vector3>> { triangle }; bool touched = false;
            for (int z = first.Y; z <= last.Y; z++) for (int x = first.X; x <= last.X; x++)
            {
                if (!columns.ContainsKey(new Vector2I(x, z))) continue;
                touched = true; var rect = new Rect2(new Vector2(x * 64 - world_origin.X, z * 64 - world_origin.Z), Vector2.One * 64);
                var next = new List<List<Vector3>>(); foreach (var polygon in polygons) next.AddRange(Subtract(polygon, rect)); polygons = next;
            }
            if (touched) split++;
            foreach (var polygon in polygons) for (int j = 1; j < polygon.Count - 1; j++)
                if ((polygon[j] - polygon[0]).Cross(polygon[j + 1] - polygon[0]).LengthSquared() > 0) { output.Add(polygon[0]); output.Add(polygon[j]); output.Add(polygon[j + 1]); }
        }
        return new D { ["valid"] = true, ["faces"] = output.ToArray(), ["removed_source_triangles"] = removed, ["split_source_triangles"] = split };
    }
}
