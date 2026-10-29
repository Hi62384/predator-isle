using Godot;
using System;
using System.Collections.Generic;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Immutable block index. Face order and mesh extrema survive every subset selection.</summary>
public partial class StructureCollisionIndex : RefCounted
{
    public const int TrianglesPerBlock = 64;
    public const double CellMetres = 256, PreloadMetres = 600, BinMetres = 1024;
    private const int BlockVertices = TrianglesPerBlock * 3;
    private const long MaxCell = 2147483646;
    public Vector3I cell(Vector3 point) => Cell(point);
    internal static Vector3I Cell(Vector3 p) => new((int)Math.Floor(p.X / CellMetres), (int)Math.Floor(p.Y / CellMetres), (int)Math.Floor(p.Z / CellMetres));

    public Vector3[] block_bounds(Vector3[] faces)
    {
        if (faces.Length % 3 != 0) return System.Array.Empty<Vector3>();
        var bounds = new List<Vector3>();
        for (int start = 0; start < faces.Length; start += BlockVertices)
        {
            var low = Vector3.Inf; var high = -Vector3.Inf;
            for (int i = start; i < Math.Min(start + BlockVertices, faces.Length); i++)
            {
                if (!faces[i].IsFinite()) return System.Array.Empty<Vector3>();
                low = low.Min(faces[i]); high = high.Max(faces[i]);
            }
            bounds.Add(low); bounds.Add(high);
        }
        return bounds.ToArray();
    }

    public D build(Vector3[] faces)
    {
        if (faces.Length == 0 || faces.Length % 3 != 0) return new();
        var bounds = block_bounds(faces);
        if (bounds.Length == 0) return new();
        int[] extrema = { -1, -1, -1, -1, -1, -1 };
        var low = Vector3.Inf; var high = -Vector3.Inf;
        var bins = new Dictionary<Vector2I, List<int>>(); var overflow = new List<int>();
        for (int block = 0; block < bounds.Length / 2; block++)
        {
            var a = bounds[block * 2]; var b = bounds[block * 2 + 1];
            if (Math.Max(Math.Max(Math.Abs(a.X), Math.Abs(a.Z)), Math.Max(Math.Abs(b.X), Math.Abs(b.Z))) > MaxCell * BinMetres) return new();
            if (a.X < low.X) { low.X = a.X; extrema[0] = block; }
            if (a.Y < low.Y) { low.Y = a.Y; extrema[1] = block; }
            if (a.Z < low.Z) { low.Z = a.Z; extrema[2] = block; }
            if (b.X > high.X) { high.X = b.X; extrema[3] = block; }
            if (b.Y > high.Y) { high.Y = b.Y; extrema[4] = block; }
            if (b.Z > high.Z) { high.Z = b.Z; extrema[5] = block; }
            var first = Bin(a); var last = Bin(b);
            if (((long)last.X - first.X + 1) * ((long)last.Y - first.Y + 1) > 64) { overflow.Add(block); continue; }
            for (int z = first.Y; z <= last.Y; z++)
            for (int x = first.X; x <= last.X; x++)
            {
                var key = new Vector2I(x, z);
                if (!bins.TryGetValue(key, out var bucket)) bins[key] = bucket = new();
                bucket.Add(block);
            }
        }
        long references = 0; var packedBins = new D();
        foreach (var (key, bucket) in bins) { references += bucket.Count; packedBins[key] = bucket.ToArray(); }
        return new D { ["version"] = 1, ["faces_count"] = faces.Length, ["bounds"] = bounds, ["bins"] = packedBins, ["overflow"] = overflow.ToArray(), ["extrema"] = extrema, ["references"] = references };
    }
    private static Vector2I Bin(Vector3 p) => new((int)Math.Floor(p.X / BinMetres), (int)Math.Floor(p.Z / BinMetres));
    public long numeric_bytes(D metadata) => metadata.Count == 0 ? 0 : metadata["bounds"].AsVector3Array().LongLength * 12
        + (metadata["references"].AsInt64() + metadata["overflow"].AsInt32Array().Length + metadata["extrema"].AsInt32Array().Length) * 4;

    public D select(Vector3[] faces, D metadata, Vector3 point)
    {
        D Fallback() => new() { ["faces"] = faces, ["ranges"] = new[] { 0, faces.Length }, ["fallback"] = true };
        if (!metadata.TryGetValue("version", out var version) || version.AsInt32() != 1 || !metadata.TryGetValue("faces_count", out var fc) || fc.AsInt32() != faces.Length
            || !point.IsFinite() || Math.Max(Math.Abs(point.X), Math.Max(Math.Abs(point.Y), Math.Abs(point.Z))) > MaxCell * CellMetres) return Fallback();
        if (!Typed(metadata, "bounds", Variant.Type.PackedVector3Array) || !Typed(metadata, "bins", Variant.Type.Dictionary)
            || !Typed(metadata, "overflow", Variant.Type.PackedInt32Array) || !Typed(metadata, "extrema", Variant.Type.PackedInt32Array)) return Fallback();
        var bounds = metadata["bounds"].AsVector3Array(); var extrema = metadata["extrema"].AsInt32Array();
        int count = (int)Math.Ceiling((double)faces.Length / BlockVertices);
        if (bounds.Length != count * 2 || extrema.Length != 6) return Fallback();
        var origin = (Vector3)Cell(point) * (float)CellMetres;
        var low = origin - Vector3.One * (float)PreloadMetres; var high = origin + Vector3.One * (float)(CellMetres + PreloadMetres);
        var first = Bin(low); var last = Bin(high); var flags = new byte[count]; var chosen = new List<int>();
        var groups = new List<int[]> { metadata["overflow"].AsInt32Array() }; var bins = metadata["bins"].AsGodotDictionary();
        for (int z = first.Y; z <= last.Y; z++)
        for (int x = first.X; x <= last.X; x++)
        {
            if (!bins.TryGetValue(new Vector2I(x, z), out var bucket)) continue;
            if (bucket.VariantType != Variant.Type.PackedInt32Array) return Fallback();
            groups.Add(bucket.AsInt32Array());
        }
        foreach (var group in groups)
        foreach (int block in group)
        {
            if (block < 0 || block >= count) return Fallback();
            if (flags[block] > 0) continue;
            flags[block] = 1; var a = bounds[block * 2]; var b = bounds[block * 2 + 1];
            if (!a.IsFinite() || !b.IsFinite() || a.X > b.X || a.Y > b.Y || a.Z > b.Z) return Fallback();
            if (a.X <= high.X && b.X >= low.X && a.Y <= high.Y && b.Y >= low.Y && a.Z <= high.Z && b.Z >= low.Z) { flags[block] = 2; chosen.Add(block); }
        }
        foreach (int block in extrema)
        {
            if (block < 0 || block >= count) return Fallback();
            if (flags[block] != 2) { flags[block] = 2; chosen.Add(block); }
        }
        chosen.Sort(); var ranges = new List<int>();
        foreach (int block in chosen)
        {
            int begin = block * BlockVertices, end = Math.Min(begin + BlockVertices, faces.Length);
            if (ranges.Count > 0 && ranges[^1] == begin) ranges[^1] = end;
            else { ranges.Add(begin); ranges.Add(end); }
        }
        if (chosen.Count == count) return new D { ["faces"] = faces, ["ranges"] = ranges.ToArray(), ["fallback"] = false };
        var selected = new List<Vector3>();
        for (int i = 0; i < ranges.Count; i += 2)
            for (int j = ranges[i]; j < ranges[i + 1]; j++) selected.Add(faces[j]);
        return new D { ["faces"] = selected.ToArray(), ["ranges"] = ranges.ToArray(), ["fallback"] = false };
    }
    private static bool Typed(D data, string key, Variant.Type type) => data.TryGetValue(key, out var value) && value.VariantType == type;
}
