using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Immutable parent snapshots and worker-local decoded controls.</summary>
public partial class CaveSurfaceContext : RefCounted
{
    public D parents { get; set; } = new();
    public Callable canonical { get; set; }
    private readonly CaveSurfacePayload _payload = new();
    private sealed class Parent
    {
        internal required Vector3 Origin; internal required double Span; internal required int Resolution;
        internal required CaveSurfacePayload.Buffer Buffer; internal required bool Normalize; internal bool CanonicalSurface;
        internal readonly Dictionary<int, float[]> Decoded = new();
    }
    private readonly Dictionary<string, Parent> _parents = new(StringComparer.Ordinal);
    private readonly Dictionary<Vector2, double> _heights = new(); private readonly List<Vector2> _heightRing = new(); private int _heightCursor;
    public bool configure(A records, Callable original_height)
    {
        parents.Clear(); _parents.Clear(); canonical = original_height; _heights.Clear(); _heightRing.Clear(); _heightCursor = 0;
        if (!(original_height.Delegate != null || GodotObject.IsInstanceValid(original_height.Target) && original_height.Target.HasMethod(original_height.Method))) return false;
        foreach (var value in records)
        {
            var record = value.AsGodotDictionary();
            foreach (string key in new[] { "id", "origin", "span", "resolution", "arrays" }) if (!record.ContainsKey(key)) return Reject();
            var origin = record["origin"].AsVector3(); double span = record["span"].AsDouble(); int resolution = record["resolution"].AsInt32(); var arrays = record["arrays"].AsGodotArray();
            if (!origin.IsFinite() || !double.IsFinite(span) || span <= 0 || resolution < 1 || arrays.Count != (int)Mesh.ArrayType.Max || arrays[(int)Mesh.ArrayType.Vertex].VariantType == Variant.Type.Nil || arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array().LongLength < ((long)resolution + 1) * (resolution + 1L)) return Reject();
            string id = record["id"].AsString(); var data = record.Duplicate(); data["decoded"] = new D(); parents[id] = data;
            _parents[id] = new Parent { Origin = origin, Span = span, Resolution = resolution, Buffer = new CaveSurfacePayload.Buffer(arrays), Normalize = record.ContainsKey("extension_normalization") && record["extension_normalization"].AsBool(), CanonicalSurface = record.ContainsKey("canonical_surface") && record["canonical_surface"].AsBool() };
        }
        return parents.Count > 0;
        bool Reject() { parents.Clear(); _parents.Clear(); return false; }
    }
    public string owner_at(Vector2 point)
    {
        string selected = ""; double smallest = double.PositiveInfinity;
        foreach (var entry in _parents)
        {
            var parent = entry.Value; var local = point - new Vector2(parent.Origin.X, parent.Origin.Z);
            if (local.X < 0 || local.Y < 0 || local.X > parent.Span || local.Y > parent.Span) continue;
            if (parent.Span < smallest) { smallest = parent.Span; selected = entry.Key; }
        }
        return selected;
    }
    public D selection(string id, Vector2 point) => _parents.TryGetValue(id, out var parent) ? _payload.triangle(point - new Vector2(parent.Origin.X, parent.Origin.Z), parent.Span, parent.Resolution) : new();
    public bool contains_triangle(string id, Vector3[] points, int first, Vector3 origin)
    {
        for (int corner = 0; corner < 3; corner++) { var point = points[first + corner] + origin; if (selection(id, new Vector2(point.X, point.Z)).Count == 0) return false; } return true;
    }
    public string triangle_owner(Vector3[] points, int first, Vector3 origin, string preferred)
    {
        if (preferred.Length == 0 || contains_triangle(preferred, points, first, origin)) return preferred;
        foreach (string id in _parents.Keys.OrderBy(id => id, StringComparer.Ordinal)) if (contains_triangle(id, points, first, origin)) return id;
        return preferred;
    }
    public double height_at(double x, double z)
    {
        var point = new Vector2((float)x, (float)z); bool cacheable = point.X == x && point.Y == z;
        if (!point.IsFinite()) return double.NaN; if (cacheable && _heights.TryGetValue(point, out double cached)) return cached;
        double value = uncached_height(point);
        if (cacheable && double.IsFinite(value))
        {
            if (_heightRing.Count < 8192) _heightRing.Add(point); else { _heights.Remove(_heightRing[_heightCursor]); _heightRing[_heightCursor] = point; _heightCursor = (_heightCursor + 1) % 8192; }
            _heights[point] = value;
        }
        return value;
    }
    public double uncached_height(Vector2 point)
    {
        string id = owner_at(point); if (id.Length == 0) return canonical.Call(point.X, point.Y).AsDouble();
        var parent = _parents[id]; if(parent.CanonicalSurface)return canonical.Call(point.X,point.Y).AsDouble();var chosen = selection(id, point); if (chosen.Count == 0) return double.NaN;
        var indices = chosen["indices"].AsInt32Array(); var weights = chosen["weights"].AsVector3(); double y = 0;
        for (int corner = 0; corner < 3; corner++) y += (double)parent.Buffer.Positions[indices[corner]].Y * weights[corner]; return y + parent.Origin.Y;
    }
    public float[] controls(string id, Vector2 point)
    {
        var chosen = selection(id, point); if (chosen.Count == 0) return System.Array.Empty<float>();
        var parent = _parents[id]; var result = new float[CaveSurfacePayload.Stride]; var indices = chosen["indices"].AsInt32Array(); var weights = chosen["weights"].AsVector3();
        for (int corner = 0; corner < 3; corner++)
        {
            int index = indices[corner];
            if (!parent.Decoded.TryGetValue(index, out var values))
            {
                values = _payload.Decode(parent.Buffer, index, parent.Normalize); parent.Decoded[index] = values;
                parents[id].AsGodotDictionary()["decoded"].AsGodotDictionary()[index] = values;
            }
            if (values.Length != CaveSurfacePayload.Stride) return System.Array.Empty<float>();
            for (int component = 0; component < result.Length; component++) result[component] = (float)(result[component] + (double)values[component] * weights[corner]);
        }
        return result;
    }
    public Vector3 normal_at(string id, Vector2 point)
    {
        var chosen = selection(id, point); if (chosen.Count == 0 || _parents[id].Buffer.Normals.Length == 0) return Vector3.Up;
        var normals = _parents[id].Buffer.Normals; var indices = chosen["indices"].AsInt32Array(); var weights = chosen["weights"].AsVector3(); var value = Vector3.Zero;
        for (int corner = 0; corner < 3; corner++) value += normals[indices[corner]] * weights[corner]; return value.Normalized();
    }
    private sealed class Group
    {
        internal readonly List<Vector3> Vertices = new(), Normals = new(); internal readonly List<Color> Colors = new();
        internal readonly List<float> Payload = new(); internal readonly List<int> Indices = new(); internal readonly Dictionary<string, int> Lookup = new(StringComparer.Ordinal);
    }
    public D surfaces(A arrays, Vector3 chunk_origin) => Surfaces(arrays, chunk_origin, false, true);
    public D surfaces_indexed(A arrays, Vector3 chunk_origin) => surfaces_indexed(arrays, chunk_origin, false);
    public D surfaces_indexed(A arrays, Vector3 chunk_origin, bool retain_source) => Surfaces(arrays, chunk_origin, true, retain_source);
    private D Surfaces(A arrays, Vector3 chunkOrigin, bool indexed, bool retainSource)
    {
        if (arrays.Count == 0) return new D { ["valid"] = true, ["groups"] = new D(), ["collision_faces"] = System.Array.Empty<Vector3>() };
        var groups = new Dictionary<string, Group>(StringComparer.Ordinal); var positions = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(); var normals = arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
        var colors = arrays[(int)Mesh.ArrayType.Color].VariantType == Variant.Type.Nil ? null : arrays[(int)Mesh.ArrayType.Color].AsColorArray();
        Span<float> keyBits = stackalloc float[10];
        for (int i = 0; i < positions.Length; i += 3)
        {
            var center = (positions[i] + positions[i + 1] + positions[i + 2]) / 3 + chunkOrigin; double ground = height_at(center.X, center.Z);
            string id = ground - center.Y < 12 ? triangle_owner(positions, i, chunkOrigin, owner_at(new Vector2(center.X, center.Z))) : "", groupKey = id.Length == 0 ? "__interior__" : id;
            if (!groups.TryGetValue(groupKey, out var group)) groups[groupKey] = group = new();
            for (int j = 0; j < 3; j++)
            {
                var local = positions[i + j]; var n = normals[i + j]; var color = colors == null ? new Color(.38f, .35f, .30f, 1) : colors[i + j];
                if (indexed)
                {
                    keyBits[0] = local.X; keyBits[1] = local.Y; keyBits[2] = local.Z; keyBits[3] = n.X; keyBits[4] = n.Y; keyBits[5] = n.Z; keyBits[6] = color.R; keyBits[7] = color.G; keyBits[8] = color.B; keyBits[9] = color.A;
                    string key = Convert.ToHexString(MemoryMarshal.AsBytes(keyBits));
                    if (group.Lookup.TryGetValue(key, out int previous)) { group.Indices.Add(previous); continue; }
                    int index = group.Vertices.Count; group.Lookup[key] = index; group.Indices.Add(index);
                }
                var world = local + chunkOrigin;
                if (id.Length > 0)
                {
                    var payload = controls(id, new Vector2(world.X, world.Z));
                    if (payload.Length == 0) return new D { ["valid"] = false, ["reason"] = "Surface replacement triangle crosses unsupported parent boundary" };
                    double depth = height_at(world.X, world.Z) - world.Y; payload[67] = (float)Math.Max(0, depth); group.Payload.AddRange(payload);
                    double t = Math.Clamp(depth / 2, 0, 1); t = t * t * (3 - 2 * t); n = n.Lerp(normal_at(id, new Vector2(world.X, world.Z)), (float)(1 - t)).Normalized();
                }
                group.Vertices.Add(local); group.Normals.Add(n); group.Colors.Add(color);
            }
        }
        var result = new D();
        foreach (var entry in groups)
        {
            var group = entry.Value; var built = new A(); built.Resize((int)Mesh.ArrayType.Max);
            var vertices = group.Vertices.ToArray(); var ns = group.Normals.ToArray(); var cs = group.Colors.ToArray(); var ps = group.Payload.ToArray(); var indices = group.Indices.ToArray();
            var output = new D { ["vertices"] = vertices, ["normals"] = ns, ["colors"] = cs, ["payload"] = ps };
            if (indexed) output["indices"] = indices;
            built[(int)Mesh.ArrayType.Vertex] = vertices; built[(int)Mesh.ArrayType.Normal] = ns; built[(int)Mesh.ArrayType.Color] = cs; if (indexed) built[(int)Mesh.ArrayType.Index] = indices; output["arrays"] = built;
            if (entry.Key != "__interior__") { var atlas = _payload.atlas(ps); if (atlas.Count == 0) return new D { ["valid"] = false, ["reason"] = "Surface material atlas exceeds declared per-group budget" }; output["atlas"] = atlas; }
            if (indexed && !retainSource) foreach (string field in new[] { "vertices", "normals", "colors", "indices", "payload" }) output.Remove(field);
            result[entry.Key] = output;
        }
        return new D { ["valid"] = true, ["groups"] = result, ["collision_faces"] = positions };
    }
}
