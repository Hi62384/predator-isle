using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Biomes;
/// <summary>Worker-owned mountain geography with a canonical 32m lattice.</summary>
public partial class MountainSampler : RefCounted
{
    public Resource settings { get; set; } = null!;
    public long seed_value { get; set; }
    private readonly FastNoiseLite _macro = new(), _meso = new(), _detail = new();
    private readonly Dictionary<Vector2I, double[]> _nodes = new();
    private readonly Dictionary<Vector2I, float[]> _regions = new();
    private readonly Dictionary<string, double> _parameters = new();
    public float[] weights { get; set; } = System.Array.Empty<float>();
    public double[] state { get; set; } = System.Array.Empty<double>();
    private WeakRef? _host;
    private double P(string key) => _parameters[key];
    private static double Lerp(double a, double b, double t) => a + (b - a) * t;
    private static double Smooth(double a, double b, double value) { double t = Math.Clamp((value - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    public void configure(Resource config, long world_seed, RefCounted host)
    {
        settings = config; seed_value = world_seed; _host = GodotObject.WeakRef(host); _parameters.Clear();
        foreach (string key in new[] { "basin_frequency", "belt_width", "branching", "cliff_frequency", "cliff_width", "erosion", "erosion_scale", "glacial_frequency", "glacial_influence", "gully_strength", "highland_frequency", "lake_frequency", "mountain_height", "peak_spacing", "region_metres", "ridge_scale", "ridge_sharpness", "ridge_width", "river_frequency", "river_width", "ruggedness", "secondary_strength", "talus_size", "valley_depth", "valley_width", "weathering" }) _parameters[key] = config.Get(key).AsDouble();
        var noises = new[] { _macro, _meso, _detail }; int[] offsets = { 21301, 21317, 21339 }; double[] frequencies = { 1.0 / 8200, 1.0 / 1400, 1.0 / P("erosion_scale") };
        for (int i = 0; i < 3; i++)
        { var n = noises[i]; n.Seed = unchecked((int)(world_seed + offsets[i])); n.Frequency = (float)frequencies[i]; n.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth; n.FractalType = FastNoiseLite.FractalTypeEnum.Fbm; n.FractalOctaves = 2; n.FractalGain = .32f; }
        _nodes.Clear(); _regions.Clear(); _carriers.Clear(); _landmarks.Clear(); timings.Clear();
    }
    public double random(long x, long z, long salt)
    {
        long h = unchecked(x * 374761393 + z * 668265263 + seed_value * 69069 + salt * 1274126177) & 0x7fffffff;
        h = unchecked((h ^ (h >> 13)) * 1274126177) & 0x7fffffff; return (double)(h ^ (h >> 16)) / 2147483647.0;
    }
    private float[] RegionNode(Vector2I cell)
    {
        if (_regions.TryGetValue(cell, out var cached)) return cached;
        var p = (Vector2)cell * 512; double span = P("region_metres"); var center = new Vector2I((int)Math.Floor(p.X / span), (int)Math.Floor(p.Y / span));
        double[] occurrence = { .2, .12, .17, P("highland_frequency"), P("glacial_frequency"), .16, .14, .13, P("highland_frequency") * .6, P("basin_frequency") * .5, .15, .12, .13, .12, .12, .13 };
        double mass = occurrence.Sum(v => Math.Max(v, 0)), closest = double.PositiveInfinity; Span<double> distances = stackalloc double[9]; Span<int> ids = stackalloc int[9]; int cursor = 0;
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = center + new Vector2I(x, z); var site = ((Vector2)q + new Vector2((float)(.15 + random(q.X, q.Y, 3) * .7), (float)(.15 + random(q.X, q.Y, 5) * .7))) * (float)span;
            double roll = random(q.X, q.Y, 7) * mass; int id = 15;
            for (int i = 0; i < 16; i++) { roll -= occurrence[i]; if (roll <= 0) { id = i; break; } }
            double distance = p.DistanceTo(site); closest = Math.Min(closest, distance); distances[cursor] = distance; ids[cursor++] = id;
        }
        var result = new float[16]; double total = 0;
        for (int i = 0; i < 9; i++) { double amount = 1 - Smooth(0, span * .17, distances[i] - closest); result[ids[i]] = (float)(result[ids[i]] + amount); total += amount; }
        for (int i = 0; i < 16; i++) result[i] = (float)(result[i] / Math.Max(total, .001));
        if (_regions.Count >= 2048) _regions.Clear(); _regions[cell] = result; return result;
    }
    public float[] region_weights(Vector2 p)
    {
        var q = p / 512; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        var a = RegionNode(cell); if (f == Vector2.Zero) return a;
        var b = RegionNode(cell + Vector2I.Right); var c = RegionNode(cell + Vector2I.Down); var d = RegionNode(cell + Vector2I.One);
        if (a.SequenceEqual(b) && a.SequenceEqual(c) && a.SequenceEqual(d)) return a;
        var result = new float[16]; for (int i = 0; i < 16; i++) result[i] = (float)Lerp(Lerp(a[i], b[i], f.X), Lerp(c[i], d[i], f.X), f.Y); return result;
    }


    public bool profile { get; set; }
    public Godot.Collections.Dictionary timings { get; set; } = new();
    private readonly Dictionary<Vector2I, Vector3> _carriers = new();
    private readonly record struct Summit(double X, double Center, double Random, double Lane);
    private readonly Dictionary<Vector2I, Summit[]> _landmarks = new();
    private double Spacing() => 4000 / Math.Max(_host!.GetRef().AsGodotObject().Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(), .1) * P("ridge_scale");
    private static double Mod(double x, double y) { double v = x % y; return v < 0 ? v + y : v; }
    private Vector3 Carrier(double x, long lane)
    {
        bool exact = x == Math.Floor(x) && Math.Abs(x) < 2000000000 && lane > -2000000000 && lane < 2000000000;
        var key = exact ? new Vector2I((int)x, (int)lane) : Vector2I.Zero; if (exact && _carriers.TryGetValue(key, out var cached)) return cached;
        var host = _host!.GetRef().AsGodotObject(); double scale = P("ridge_scale"), baseSpacing = Spacing() / scale;
        double center = host.Call("_grass_river_center", x / scale, lane, baseSpacing).AsDouble() * scale;
        double slope = (host.Call("_grass_river_center", (x + 32) / scale, lane, baseSpacing).AsDouble() - host.Call("_grass_river_center", (x - 32) / scale, lane, baseSpacing).AsDouble()) * scale / 64;
        var result = new Vector3((float)center, (float)slope, 0); if (exact) { if (_carriers.Count >= 2048) _carriers.Clear(); _carriers[key] = result; } return result;
    }
    public double water_potential(double x) => 120 + 260 * Math.Pow(Math.Sin(Mod(x + seed_value % 31 * 139.0, 18000) / 18000 * Math.PI), 2);
    private Summit[] Sites(Vector2I cell)
    {
        if (_landmarks.TryGetValue(cell, out var cached)) return cached; var sites = new Summit[3];
        for (int i = -1; i <= 1; i++)
        {
            var q = cell + new Vector2I(i, 0); double r = random(q.X, q.Y, 251), x = Math.Round((q.X + .25 + random(q.X, q.Y, 253) * .5) * P("peak_spacing") / 32, MidpointRounding.AwayFromZero) * 32;
            var lo = Carrier(x, q.Y); var hi = Carrier(x, q.Y + 1); sites[i + 1] = new Summit(x, ((double)lo.X + hi.X) * .5, r, q.Y);
        }
        if (_landmarks.Count >= 1024) _landmarks.Clear(); _landmarks[cell] = sites; return sites;
    }
    private double[] Raw(Vector2 p)
    {
        ulong tick = profile ? Time.GetTicksUsec() : 0; var w = region_weights(p); double a = _macro.GetNoise2D(p.X, p.Y), b = _meso.GetNoise2D(p.X, p.Y), c = _detail.GetNoise2D(p.X, p.Y);
        double spacing = Spacing(); long lane = (long)Math.Round(p.Y / spacing, MidpointRounding.AwayFromZero); var valleyCenter = Carrier(p.X, lane);
        for (int k = -1; k <= 1; k += 2) { var other = Carrier(p.X, lane + k); if (Math.Abs((double)p.Y - other.X) < Math.Abs((double)p.Y - valleyCenter.X)) valleyCenter = other; }
        double distance = Math.Abs((double)p.Y - valleyCenter.X) / Math.Sqrt(1 + (double)valleyCenter.Y * valleyCenter.Y);
        double glacial = Math.Clamp((w[4] + w[9] * .45 + w[14] * .65) * P("glacial_influence"), 0, 1), ridge = 0, secondary = 0, peak = 0, height = 0, cirque = 0, tarn = 0, width = P("ridge_width") * P("belt_width"), gain = 0;
        ReadOnlySpan<double> heights = stackalloc double[] { 1.05, 1.55, .9, .48, 1.15, 1.05, .85, .25, .7, .7, 1.15, .85, .85, .65, 1.15, .65 }; for (int i = 0; i < 16; i++) gain += w[i] * heights[i];
        for (int k = -1; k <= 1; k++)
        {
            long id = lane + k; var lower = Carrier(p.X, id); var upper = Carrier(p.X, id + 1); double center = ((double)lower.X + upper.X) * .5, across = p.Y - center;
            if (Math.Abs(across) > spacing * .65) continue; double shoulder = 1 - Smooth(spacing * .42, spacing * .65, Math.Abs(across));
            double localWidth = width * (1 + w[3] * .85 + w[1] * .35 + w[8] * .5 - w[14] * .4), asym = .7 + .6 * Smooth(-500, 500, across + b * 250), d = Math.Abs(across) / Math.Max(localWidth * asym, P("cliff_width"));
            double rounded = Math.Exp(-d * d * .75), sharp = Math.Exp(-Math.Pow(d, P("ridge_sharpness")) * 1.5), shape = Lerp(sharp, rounded, Math.Clamp(w[3] + w[5] * .65 + w[7] * .6 + w[8] * .5, 0, 1)) * shoulder, span = P("peak_spacing"), summits = 0;
            var cell = new Vector2I((int)Math.Floor(p.X / span), (int)id);
            foreach (var site in Sites(cell))
            {
                double dx = Math.Abs(p.X - site.X) / (span * (.23 + site.Random * .17)), prominence = Math.Exp(-Math.Pow(dx, 1.6)) * (.55 + site.Random * .65); summits = Math.Max(summits, prominence);
                if (glacial > .03 && site.Random < .62)
                {
                    double side = random((long)Math.Floor(site.X / span), id, 257) < .5 ? -1 : 1;
                    var v = new Vector2((float)((p.X - site.X) / (500 + site.Random * 450)), (float)((p.Y - center - side * localWidth * .8) / (650 + site.Random * 350)));
                    double bowl = (1 - Smooth(.35, 1.15, v.Length() + Math.Sin(v.X * 2.0) * .08)) * glacial; cirque = Math.Max(cirque, bowl); if (site.Random < P("lake_frequency")) tarn = Math.Max(tarn, bowl);
                }
            }
            double core = shape * (.55 + summits * .65), branchPhase = Mod(p.X - across * .4 + b * 160 + id * 331.0, span) / span, branchDistance = Math.Min(branchPhase, 1 - branchPhase) * span;
            double branches = Math.Exp(-Math.Pow(branchDistance / Math.Max(150, span * .11), 2)) * shoulder * (1 - Smooth(localWidth * .2, spacing * .6, Math.Abs(across)));
            branches *= P("secondary_strength") * P("branching") * (.3 + .7 * shape); double value = core * P("mountain_height") * gain; value += branches * P("mountain_height") * .22;
            double shelf = (1 - Smooth(P("cliff_width"), P("cliff_width") * 2, Math.Abs(across) - localWidth * .45)) * ((double)w[6] + w[11]) * .22; value += shelf * P("mountain_height") * P("cliff_frequency");
            height = Math.Max(height, value); ridge = Math.Max(ridge, shape); secondary = Math.Max(secondary, branches); peak = Math.Max(peak, summits * shape);
        }
        if (profile) { timings["ridge_us"] = (timings.ContainsKey("ridge_us") ? timings["ridge_us"].AsInt64() : 0) + (long)(Time.GetTicksUsec() - tick); tick = Time.GetTicksUsec(); }
        double water = water_potential(p.X), valleyWidth = P("valley_width") * (1.0 + w[15] + w[4] * .4 - w[10] * .45) * (.85 + .2 * a);
        double vshape = 1 - Smooth(valleyWidth * .2, valleyWidth * 1.45, distance), ushape = 1 - Smooth(valleyWidth * .8, valleyWidth * 1.65, distance), valley = Lerp(vshape, ushape, glacial);
        double h = water + 45 + height + (a * 18 + b * 12) * (1 - valley * .8), floorHeight = water + 8 + b * 3 + Math.Abs(c) * 2; h = Lerp(h, floorHeight, valley * P("valley_depth"));
        h += w[8] * (1 - valley) * Smooth(.1, .7, ridge) * 180; double incision = (1 - Smooth(.02, .22, Math.Abs(c + b * .25))) * ridge * (1 - peak * .5), erosion = incision * P("erosion") * P("gully_strength");
        h -= erosion * (55 + w[12] * 35.0 + w[10] * 30.0) * P("ruggedness");
        double apron = Math.Exp(-Math.Pow((distance - valleyWidth * 1.8) / Math.Max(P("talus_size"), 200), 2)) * (.35 + ridge * .65), scree = Math.Clamp(apron * (.4 + w[13] + w[4] * .4 + w[5] * .5) + erosion * .25, 0, 1);
        h += apron * P("weathering") * 35 * (w[13] + w[5] * .7 + w[11] * .5); double fan = (1 - Smooth(.05, .35, Math.Abs(b))) * apron * P("erosion"); h += fan * 28 * (1 - valley * .4);
        double cirqueFloor = water + P("mountain_height") * .32; h = Lerp(h, Math.Min(h, cirqueFloor + 8 + c * 3), cirque);
        double channel = 1 - Smooth(P("river_width") * .4, P("river_width") * 1.8, distance), wetCountry = 1 - w[12] * .95;
        if (P("river_frequency") > 0) h = Lerp(h, water - 2.5, channel * Smooth(0, .3, P("river_frequency")) * wetCountry); else channel = 0;
        double basin = 0;
        if (P("lake_frequency") > 0 && (double)w[4] + w[9] + w[15] > .1)
        {
            long segment = (long)Math.Floor(p.X / 6000.0);
            for (int j = -1; j <= 1; j++)
            {
                double r = random(segment + j, lane, 271); if (r > P("lake_frequency") * P("basin_frequency")) continue;
                double x = Math.Round((segment + j + .35 + r * .4) * 6000 / 32, MidpointRounding.AwayFromZero) * 32, cy = Carrier(x, lane).X, level = water_potential(x) + 3;
                var q = new Vector2((float)((p.X - x) / (650 + r * 1000)), (float)((p.Y - cy) / (220 + r * 450)));
                double contour = q.Length() + Math.Sin(q.X * 2.4 + r * 7) * .12 + Math.Sin(q.Y * 3.0) * .07, support = (1 - Smooth(.8, 1.25, contour)) * Math.Clamp((double)w[4] + w[9] + w[15], 0, 1), bed = 1 - Smooth(.25, .9, contour);
                h = Lerp(h, level + 12 - bed * (17 + r * 7), support); water = Lerp(water, level, support); basin = Math.Max(basin, bed * support);
            }
        }
        if (tarn > .1 && P("lake_frequency") > .1) { double bowl = Smooth(.45, .8, tarn), support = Smooth(.3, .7, tarn), level = cirqueFloor + 10; h = Lerp(h, level + 5 - bowl * 8, support); water = Lerp(water, level, support); basin = Math.Max(basin, bowl); }
        double rock = Math.Clamp(ridge * .7 + peak * .3 + erosion * .35 + ((double)w[5] + w[6] + w[11]) * .3 - valley * .25, 0, 1), wetness = Math.Clamp(valley * .45 + channel * .5 + basin * .6 + cirque * .25 - w[12] * .35, 0, 1);
        int index = 0; for (int i = 1; i < 16; i++) if (w[i] > w[index]) index = i;
        if (profile) timings["valley_water_erosion_us"] = (timings.ContainsKey("valley_water_erosion_us") ? timings["valley_water_erosion_us"].AsInt64() : 0) + (long)(Time.GetTicksUsec() - tick);
        return new[] { h, water, rock, scree, index / 15.0, glacial, valley, ridge, secondary, erosion, wetness, peak, basin, channel, cirque, fan, 1 - peak, (double)w[6] + w[11] };
    }
    private double[] Node(Vector2I cell)
    {
        if (_nodes.TryGetValue(cell, out var cached)) return cached; var value = Raw((Vector2)cell * 32); if (_nodes.Count >= 16384) _nodes.Clear(); _nodes[cell] = value; return value;
    }
    public double cubic(double a, double b, double c, double d, double t) => b + .5 * t * (c - a + t * (2 * a - 5 * b + 4 * c - d + t * (3 * (b - c) + d - a)));
    public double sample(double x, double z) => sample(x, z, true);
    public double sample(double x, double z, bool publish)
    {
        var q = new Vector2((float)x, (float)z) / 32; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        if (f == Vector2.Zero) { var value = Node(cell); if (publish) state = value; return value[0]; }
        Span<double> rows = stackalloc double[4], waters = stackalloc double[4];
        for (int j = -1; j <= 2; j++)
        { var a = Node(cell + new Vector2I(-1, j)); var b = Node(cell + new Vector2I(0, j)); var c = Node(cell + new Vector2I(1, j)); var d = Node(cell + new Vector2I(2, j)); rows[j + 1] = cubic(a[0], b[0], c[0], d[0], f.X); waters[j + 1] = cubic(a[1], b[1], c[1], d[1], f.X); }
        double h = cubic(rows[0], rows[1], rows[2], rows[3], f.Y);
        if (publish)
        {
            var a = Node(cell); var b = Node(cell + Vector2I.Right); var c = Node(cell + Vector2I.Down); var d = Node(cell + Vector2I.One); state = new double[18]; state[0] = h; state[1] = cubic(waters[0], waters[1], waters[2], waters[3], f.Y);
            for (int k = 2; k < 18; k++) state[k] = Math.Clamp(Lerp(Lerp(a[k], b[k], f.X), Lerp(c[k], d[k], f.X), f.Y), 0, 1);
        }
        return h;
    }
}



