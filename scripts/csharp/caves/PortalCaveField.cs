using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

public partial class PortalCaveField : CaveField
{
    public D surface_columns { get; set; } = new();
    public D surface_limits { get; set; } = new();
    public Callable top_height { get; set; }
    public bool include_surface_air { get; set; } = true;
    public double cave_sample(Vector3 point) => base.sample(point);
    public double surface_height(Vector2 point) => SurfaceHeight(point);
    public override bool HasSurfaceColumn(Vector2I column) => surface_columns.ContainsKey(column);
    public override double SurfaceHeight(Vector2 point)
    {
        bool valid = top_height.Delegate != null || (GodotObject.IsInstanceValid(top_height.Target) && top_height.Target!.HasMethod(top_height.Method));
        return (valid ? top_height : height).Call(point.X, point.Y).AsDouble();
    }
    public override double sample(Vector3 point)
    {
        if (!include_surface_air) return base.sample(point);
        if (!SafePoint(point)) return Far;
        double terrain = SurfaceHeight(new Vector2(point.X, point.Z)); if (!double.IsFinite(terrain)) return Far;
        return Math.Min(base.sample(point), terrain - point.Y);
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
