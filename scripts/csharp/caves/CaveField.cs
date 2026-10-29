using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Worker-owned sparse cave field. Sampling uses native .NET collections and doubles.</summary>
public partial class CaveField : RefCounted, ICaveField
{
    internal const double BinMetres = 16, Far = 4;
    internal readonly List<Vector2> Directions = new(), Dimensions = new();
    internal readonly List<Vector3> Begins = new(), Ends = new();
    internal readonly List<double> SpanSquared = new(), SpanLength = new(), ArchHeight = new(), ArchCenter = new(), ArchScale = new(), EndpointGrades = new();
    internal readonly List<byte> Kinds = new(), Styles = new();
    internal readonly Dictionary<Vector3I, List<int>> Bins = new(), ThermalBins = new();
    internal readonly Dictionary<string, List<Vector2>> BiomeFields = new();
    private readonly Dictionary<Vector2, double> _heightMemo = new();
    private readonly Dictionary<string, Variant> _packed = new();
    private Callable _height;
    internal long SpatialReferences;
    public D chunks { get; set; } = new();
    public D _biome_assignment { get; set; } = new();
    public D _biome_locks { get; set; } = new();
    public A _protected_shores { get; set; } = new();
    public A precise_shores { get; set; } = new();
    public D floor_relief { get; set; } = new();
    public A thermal_sources { get; set; } = new();
    public bool continuous_route_floors { get; set; } = true;
    public bool cache_height_samples { get; set; } = true;
    public bool enable_thermal_sources { get; set; } = true;
    public double maximum_depth { get; set; } = 400;
    public double minimum_roof { get; set; } = 10;
    public double opening_rock_cover { get; set; }
    public long references { get; set; }
    public long thermal_references { get; set; }
    public Callable height { get => _height; set { _height = value; _heightMemo.Clear(); } }
    public A PreciseShores => precise_shores;
    public double Sample(Vector3 p) => sample(p);
    public Vector3 Normal(Vector3 p) => normal(p);
    public bool HasChunk(Vector3I p) => has_chunk(p);
    public virtual bool HasSurfaceColumn(Vector2I column) => false;
    public virtual double SurfaceHeight(Vector2 point) => height.Call(point.X, point.Y).AsDouble();
    public virtual bool has_chunk(Vector3I key) => chunks.ContainsKey(key);
    public Vector3I cell(Vector3 p) => new((int)Math.Floor(p.X / 64.0), (int)Math.Floor(p.Y / 64.0), (int)Math.Floor(p.Z / 64.0));
    public Vector3I bin_cell(Vector3 p) => new((int)Math.Floor(p.X / BinMetres), (int)Math.Floor(p.Y / BinMetres), (int)Math.Floor(p.Z / BinMetres));

    // Retain packed snapshots for transitional callers. Repeated scalar property reads must not copy entire arrays.
    private Variant Packed<T>(string name, List<T> values, Func<T[], Variant> pack)
    {
        if (!_packed.TryGetValue(name, out var result)) _packed[name] = result = pack(values.ToArray());
        return result;
    }
    public override Variant _Get(StringName property) => property.ToString() switch
    {
        "begins" => Packed("begins", Begins, a => a), "ends" => Packed("ends", Ends, a => a),
        "directions" => Packed("directions", Directions, a => a), "dimensions" => Packed("dimensions", Dimensions, a => a),
        "span_squared" => Packed("span_squared", SpanSquared, a => a), "span_length" => Packed("span_length", SpanLength, a => a),
        "arch_height" => Packed("arch_height", ArchHeight, a => a), "arch_center" => Packed("arch_center", ArchCenter, a => a),
        "arch_scale" => Packed("arch_scale", ArchScale, a => a), "endpoint_grades" => Packed("endpoint_grades", EndpointGrades, a => a),
        "kinds" => Packed("kinds", Kinds, a => a), "styles" => Packed("styles", Styles, a => a),
        "bins" => PackedBins("bins", Bins), "thermal_bins" => PackedBins("thermal_bins", ThermalBins),
        "_biome_fields" => PackedBiomes(), _ => default
    };
    private Variant PackedBins(string key, Dictionary<Vector3I, List<int>> source)
    {
        if (_packed.TryGetValue(key, out var value)) return value;
        var result = new D(); foreach (var pair in source) result[pair.Key] = pair.Value.ToArray();
        _packed[key] = result; return result;
    }
    private Variant PackedBiomes()
    {
        if (_packed.TryGetValue("_biome_fields", out var value)) return value;
        var result = new D(); foreach (var pair in BiomeFields) result[pair.Key] = pair.Value.ToArray();
        _packed["_biome_fields"] = result; return result;
    }
    internal void InvalidatePacked() => _packed.Clear();
    public void clear()
    {
        SpatialReferences = 0; precise_shores.Clear(); floor_relief.Clear(); thermal_sources.Clear(); ThermalBins.Clear(); thermal_references = 0;
        Directions.Clear(); SpanSquared.Clear(); SpanLength.Clear(); ArchHeight.Clear(); ArchCenter.Clear(); ArchScale.Clear(); Begins.Clear(); Ends.Clear(); Dimensions.Clear(); Kinds.Clear(); Styles.Clear(); EndpointGrades.Clear(); _heightMemo.Clear(); Bins.Clear(); chunks.Clear(); references = 0;
        _biome_assignment = new(); BiomeFields.Clear(); _biome_locks = new(); _protected_shores.Clear(); InvalidatePacked();
    }
    public double ground_height(Vector3 p)
    {
        if (!cache_height_samples) return height.Call(p.X, p.Z).AsDouble();
        var key = new Vector2(p.X, p.Z);
        if (_heightMemo.TryGetValue(key, out double value)) return value;
        value = height.Call(p.X, p.Z).AsDouble();
        if (_heightMemo.Count >= 8192) _heightMemo.Clear();
        _heightMemo[key] = value; return value;
    }
    public bool protected_shore(Vector3 point, double radius, double low, double high)
    {
        foreach (var item in _protected_shores)
        {
            var shore = item.AsGodotDictionary();
            if (high <= Num(shore, "low") || low >= Num(shore, "high")) continue;
            var center = shore["center"].AsVector3(); var q = new Vector2(Math.Abs(point.X - center.X), Math.Abs(point.Z - center.Z));
            var closest = (q - Vector2.One * (float)radius).Max(Vector2.Zero); var farthest = q + Vector2.One * (float)radius;
            if (closest.Length() <= Num(shore, "outer") && farthest.Length() >= Num(shore, "inner")) return true;
        }
        return false;
    }
    public bool append_feature(Vector3 a, Vector3 b, Vector2 size, int kind, int style = 0)
    {
        if (!a.IsFinite() || !b.IsFinite() || !size.IsFinite() || size.X <= 0 || size.Y <= 0 || Begins.Count >= 65536) return false;
        var low = a.Min(b) - new Vector3(size.X + 4, 4, size.X + 4); var high = a.Max(b) + new Vector3(size.X + 4, size.Y + 4, size.X + 4);
        foreach (float component in new[] { low.X, low.Y, low.Z, high.X, high.Y, high.Z }) if (Math.Abs((double)component) > 2147483646.0 * BinMetres) return false;
        var first = bin_cell(low); var last = bin_cell(high);
        long sx = (long)last.X - first.X + 1, sy = (long)last.Y - first.Y + 1, sz = (long)last.Z - first.Z + 1;
        if (sx > 256 || sy > 256 || sz > 256 || sx * sy * sz > 256 || SpatialReferences + sx * sy * sz > 2097152) return false;
        SpatialReferences += sx * sy * sz;
        var ab = new Vector2(b.X - a.X, b.Z - a.Z); Directions.Add(ab); SpanSquared.Add(Math.Max(ab.LengthSquared(), .000001)); SpanLength.Add(ab.Length()); ArchHeight.Add(size.Y * .6); ArchCenter.Add(size.Y * .4); ArchScale.Add(Math.Min(size.X, size.Y * .6));
        int feature = Begins.Count; Begins.Add(a); Ends.Add(b); Dimensions.Add(size); Kinds.Add((byte)kind); Styles.Add((byte)Math.Clamp(style, 0, 7));
        if (continuous_route_floors) { EndpointGrades.Add(double.PositiveInfinity); EndpointGrades.Add(double.PositiveInfinity); }
        foreach (var weights in BiomeFields.Values) weights.Add(Vector2.Zero);
        var firstChunk = cell(low); var lastChunk = cell(high);
        for (int z = firstChunk.Z; z <= lastChunk.Z; z++) for (int y = firstChunk.Y; y <= lastChunk.Y; y++) for (int x = firstChunk.X; x <= lastChunk.X; x++) chunks[new Vector3I(x, y, z)] = true;
        for (int z = first.Z; z <= last.Z; z++) for (int y = first.Y; y <= last.Y; y++) for (int x = first.X; x <= last.X; x++)
        {
            var key = new Vector3I(x, y, z); if (!Bins.TryGetValue(key, out var bucket)) Bins[key] = bucket = new(); bucket.Add(feature);
        }
        InvalidatePacked(); return true;
    }
    public bool compile(A regions, Callable surface, A? extra_edges = null, D? biome_assignment = null) => CaveFieldCompiler.Compile(this, regions, surface, extra_edges ?? new(), biome_assignment ?? new());
    public void bind_feature_biomes(int feature, string from_id, string to_id, double first, double last, double length_m) => CaveFieldBiomes.Bind(this, feature, from_id, to_id, first, last, length_m);
    public A biome_ids_for_cell(Vector3I key) => CaveFieldBiomes.Ids(this, key);
    public Vector4 biome_weights_at(Vector3 point, A ids) => CaveFieldBiomes.Weights(this, point, ids);
    public double biome_admission(Vector3 point) => CaveFieldBiomes.Admission(this, point);
    public bool append_thermal_source(D source) => CaveFieldThermal.Append(this, source);
    public double source_heat(D source, Vector3 point) => CaveFieldThermal.SourceHeat(source, point);
    public double heat_at(Vector3 point) => CaveFieldThermal.HeatAt(this, point);
    public bool hot_bounds(Aabb bounds, double threshold = .08) => CaveFieldThermal.HotBounds(this, bounds, threshold);
    public double evaluate(Vector3 point, int[] features) => Evaluate(point, features);
    internal double Evaluate(Vector3 point, IEnumerable<int> features) => CaveFieldEvaluation.Evaluate(this, point, features);
    public virtual double sample(Vector3 point)
    {
        if (!SafePoint(point)) return Far;
        return Bins.TryGetValue(bin_cell(point), out var features) ? Evaluate(point, features) : Far;
    }
    internal static bool SafePoint(Vector3 point) => point.IsFinite() && Math.Abs((double)point.X) <= 2147483646.0 * BinMetres && Math.Abs((double)point.Y) <= 2147483646.0 * BinMetres && Math.Abs((double)point.Z) <= 2147483646.0 * BinMetres;
    public Vector3 normal(Vector3 point)
    {
        const float e = .125f;
        return -new Vector3((float)(sample(point + new Vector3(e, 0, 0)) - sample(point - new Vector3(e, 0, 0))),
            (float)(sample(point + new Vector3(0, e, 0)) - sample(point - new Vector3(0, e, 0))),
            (float)(sample(point + new Vector3(0, 0, e)) - sample(point - new Vector3(0, 0, e)))).Normalized();
    }
    public long numeric_bytes() => Begins.Count * (82L + BiomeFields.Count * 8) + references * 4 + EndpointGrades.Count * 8L + (_protected_shores.Count + precise_shores.Count) * 32L + floor_relief.Count * 32L + thermal_sources.Count * 64L + thermal_references * 4;
    internal static double Num(D data, string key, double fallback = 0) => data.TryGetValue(key, out var value) ? value.AsDouble() : fallback;
    internal static int Int(D data, string key, int fallback = 0) => data.TryGetValue(key, out var value) ? value.AsInt32() : fallback;
    internal static bool Flag(D data, string key) => data.TryGetValue(key, out var value) && value.AsBool();
    internal static string Text(D data, string key, string fallback = "") => data.TryGetValue(key, out var value) ? value.AsString() : fallback;
    internal static A Arr(D data, string key) => data.TryGetValue(key, out var value) ? value.AsGodotArray() : new();
    internal static D Dict(D data, string key) => data.TryGetValue(key, out var value) ? value.AsGodotDictionary() : new();
    internal static double Smooth(double a, double b, double value) { double t = Math.Clamp((value - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    internal static double Lerp(double a, double b, double t) => a + (b - a) * t;
}
