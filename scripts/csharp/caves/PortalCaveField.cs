using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

public partial class PortalCaveField : CaveField
{
    public D surface_columns { get; set; } = new();
    public D surface_limits { get; set; } = new();
    private Callable _topHeight;
    private Func<double,double,double>? _sampleTopHeight;
    public Callable top_height { get=>_topHeight; set { _topHeight=value;_sampleTopHeight=value.Delegate != null || GodotObject.IsInstanceValid(value.Target) && value.Target!.HasMethod(value.Method) ? CaveHeightSampler.Bind(value) : null; } }
    public bool include_surface_air { get; set; } = true;
    internal const double EntranceFillet = 2.0;
    internal bool RoundEntrance { get; set; }
    public double cave_sample(Vector3 point) => base.sample(point);
    public double surface_height(Vector2 point) => SurfaceHeight(point);
    public override bool HasSurfaceColumn(Vector2I column) => surface_columns.ContainsKey(column);
    public override double SurfaceHeight(Vector2 point)
    {
        return _sampleTopHeight is not null?_sampleTopHeight(point.X,point.Y):base.SurfaceHeight(point);
    }
    public override double sample(Vector3 point)
    {
        if (!include_surface_air) return base.sample(point);
        if (!SafePoint(point)) return Far;
        // The ordinary point API stays unchanged. Cave mesh lattice workers
        // can reuse this identical surface value along a vertical X/Z column.
        return SampleWithSurfaceHeight(point,SurfaceHeight(new Vector2(point.X,point.Z)));
    }
    internal double SampleWithSurfaceHeight(Vector3 point,double terrain)
    {
        if (!SafePoint(point)||!double.IsFinite(terrain)) return Far;
        double cave = base.sample(point);
        double surface = terrain - point.Y;
        double distance = Math.Min(cave, surface);
        if (!RoundEntrance) return distance;
        // Round only the join between the passage and daylight. Where the
        // terrain stands alone, or the cave is buried, preserve its surface.
        double fillet = Math.Max(EntranceFillet - Math.Abs(cave - surface), 0);
        return distance - fillet * fillet / (4 * EntranceFillet);
    }
    public override bool has_chunk(Vector3I key)
    {
        if (base.has_chunk(key)) return true;
        var column = new Vector2I(key.X, key.Z);
        if (!surface_columns.ContainsKey(column) || !surface_limits.TryGetValue(column, out var value)) return false;
        var limits = value.AsVector2(); return key.Y >= Math.Floor(limits.X / 64.0) && key.Y <= Math.Floor(limits.Y / 64.0);
    }
    public bool measure_surface(D columns)
    {
        surface_columns = columns.Duplicate(); surface_limits.Clear();
        foreach (var pair in surface_columns)
        {
            var key = pair.Key.AsVector2I(); double minimum = double.PositiveInfinity, maximum = double.NegativeInfinity;
            for (int z = 0; z < 33; z++) for (int x = 0; x < 33; x++)
            {
                double h = SurfaceHeight((Vector2)key * 64 + new Vector2(x, z) * 2);
                if (!double.IsFinite(h)) { surface_columns.Clear(); surface_limits.Clear(); return false; }
                minimum = Math.Min(minimum, h); maximum = Math.Max(maximum, h);
            }
            surface_limits[key] = new Vector2((float)(minimum - 2), (float)(maximum + 2));
        }
        return true;
    }
}
