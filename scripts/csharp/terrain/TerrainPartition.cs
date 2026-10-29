using Godot;
using System;
using System.Collections.Generic;
using GDictionary = Godot.Collections.Dictionary;
using GArray = Godot.Collections.Array<Godot.Vector3I>;

namespace PredatorIsle.Terrain;

/// <summary>Spatial selection; heights continue to use the canonical terrain sampler.</summary>
public partial class TerrainPartition : RefCounted
{
    // Snake case preserves the existing resource/call contract during migration.
    public double base_size { get; set; } = 256;
    public int maximum_level { get; set; } = 5;
    public double split_ratio { get; set; } = 1.15;
    public double merge_ratio { get; set; } = 1.50;
    public Godot.Collections.Array<Rect2> forced_detail_regions { get; set; } = new();
    private Vector2I _rootCenter = new(int.MaxValue, int.MaxValue);

    public GArray children(Vector3I key) => new()
    {
        new(key.X * 2, key.Y * 2, key.Z - 1),
        new(key.X * 2 + 1, key.Y * 2, key.Z - 1),
        new(key.X * 2, key.Y * 2 + 1, key.Z - 1),
        new(key.X * 2 + 1, key.Y * 2 + 1, key.Z - 1)
    };

    public Rect2 bounds(Vector3I key)
    {
        float size = (float)(base_size * (1L << key.Z));
        return new Rect2(new Vector2(key.X, key.Y) * size, Vector2.One * size);
    }

    public double distance_to(Vector3I key, Vector2 point)
    {
        var rect = bounds(key);
        return point.DistanceTo(point.Clamp(rect.Position, rect.End));
    }

    public Vector3I parent(Vector3I key) => new(key.X >> 1, key.Y >> 1, key.Z + 1);

    public bool adjacent(Vector3I a, Vector3I b) => Adjacent(a, b);
    public static bool Adjacent(Vector3I a, Vector3I b)
    {
        long sa = 1L << a.Z, sb = 1L << b.Z;
        long ax = a.X * sa, az = a.Y * sa, bx = b.X * sb, bz = b.Y * sb;
        return ((ax + sa == bx || bx + sb == ax) && Math.Max(az, bz) < Math.Min(az + sa, bz + sb))
            || ((az + sa == bz || bz + sb == az) && Math.Max(ax, bx) < Math.Min(ax + sa, bx + sb));
    }

    public bool reserved(Vector3I key)
    {
        var area = bounds(key);
        foreach (var region in forced_detail_regions)
            if (area.Intersects(region)) return true;
        return false;
    }

    public GDictionary select(Vector2 point, GDictionary previous)
    {
        var ancestors = new HashSet<Vector3I>();
        foreach (var pair in previous)
        {
            var p = pair.Key.AsVector3I();
            while (p.Z < maximum_level) { p = parent(p); ancestors.Add(p); }
        }
        float size = (float)(base_size * (1L << maximum_level));
        var center = new Vector2I(Mathf.FloorToInt(point.X / size), Mathf.FloorToInt(point.Y / size));
        if (_rootCenter.X != int.MaxValue)
        {
            var retained = new Rect2((Vector2)_rootCenter * size - Vector2.One * size * .25f, Vector2.One * size * 1.5f);
            if (retained.HasPoint(point)) center = _rootCenter;
        }
        _rootCenter = center;
        var stack = new Stack<Vector3I>();
        for (int z = -1; z <= 1; z++)
            for (int x = -1; x <= 1; x++) stack.Push(new(center.X + x, center.Y + z, maximum_level));
        // Keep the planning loop in native .NET collections; marshal only the final cut.
        var leaves = new Dictionary<Vector3I, bool>();
        while (stack.TryPop(out var key))
        {
            double threshold = (ancestors.Contains(key) ? merge_ratio : split_ratio) * base_size * (1L << key.Z);
            if (key.Z > 0 && (distance_to(key, point) < threshold || reserved(key)))
                for (int i = 0; i < 4; i++) stack.Push(Child(key, i));
            else leaves[key] = true;
        }
        Span<Vector2I> probes = stackalloc Vector2I[4];
        while (true)
        {
            var splits = new Dictionary<Vector3I, bool>();
            foreach (var key in leaves.Keys)
            {
                int width = 1 << key.Z, x = key.X * width, z = key.Y * width, half = width / 2;
                probes[0] = new(x - 1, z + half); probes[1] = new(x + width, z + half);
                probes[2] = new(x + half, z - 1); probes[3] = new(x + half, z + width);
                foreach (var cell in probes)
                    for (int level = key.Z + 2; level <= maximum_level; level++)
                    {
                        var neighbor = new Vector3I(cell.X >> level, cell.Y >> level, level);
                        if (!leaves.ContainsKey(neighbor)) continue;
                        splits[neighbor] = true;
                        break;
                    }
            }
            if (splits.Count == 0) break;
            foreach (var key in splits.Keys)
            {
                leaves.Remove(key);
                for (int i = 0; i < 4; i++) leaves[Child(key, i)] = true;
            }
        }
        var result = new GDictionary();
        foreach (var key in leaves.Keys) result[key] = true;
        return result;
    }
    private static Vector3I Child(Vector3I key, int index) =>
        new(key.X * 2 + (index & 1), key.Y * 2 + (index >> 1), key.Z - 1);
}
