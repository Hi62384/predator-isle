using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Biomes;
/// <summary>Worker-owned temperate geography with canonical 64m Hermite nodes.</summary>
public partial class ForestSampler : RefCounted
{
    public Resource settings { get; set; } = null!;
    public long seed_value { get; set; }
    private readonly FastNoiseLite _macro = new(), _meso = new(), _detail = new();
    private readonly Dictionary<Vector2I, (Vector4 Height, Vector2 Surface)> _nodes = new();
    private readonly Dictionary<Vector2I, float[]> _regions = new();
    private readonly Dictionary<string, double> _parameters = new();
    public float[] weights { get; set; } = System.Array.Empty<float>();
    public double wetness { get; set; }
    public double drainage { get; set; }
    public double rock { get; set; }
    public double clearing { get; set; }
    public double conifer { get; set; }
    public int region { get; set; }
    public double river { get; set; }
    public double lake { get; set; }
    private double P(string key) => _parameters[key];
    private static double Lerp(double a, double b, double t) => a + (b - a) * t;
    private static double Smooth(double a, double b, double value) { double t = Math.Clamp((value - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    public void configure(Resource config, long world_seed)
    {
        settings = config; seed_value = world_seed; _parameters.Clear();
        foreach (string key in new[] { "region_metres", "deciduous_frequency", "conifer_frequency", "mixed_frequency", "old_growth_frequency", "mountain_frequency", "valley_scale", "mountain_height", "lowland_frequency", "hill_frequency", "ruggedness", "ravine_depth", "erosion_strength", "wetness", "clearing_frequency" }) _parameters[key] = config.Get(key).AsDouble();
        var noises = new[] { _macro, _meso, _detail }; int[] offsets = { 11301, 11317, 11339 }; double[] frequencies = { 1.0 / 3600, 1.0 / 680, 1.0 / 180 };
        for (int i = 0; i < 3; i++)
        { var n = noises[i]; n.Seed = unchecked((int)(world_seed + offsets[i])); n.Frequency = (float)frequencies[i]; n.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth; n.FractalType = FastNoiseLite.FractalTypeEnum.Fbm; n.FractalOctaves = i == 2 ? 1 : 2; n.FractalGain = .32f; }
        _nodes.Clear(); _regions.Clear();
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
        double[] occurrence = { P("deciduous_frequency"), P("conifer_frequency"), P("mixed_frequency"), P("old_growth_frequency"), .16, .12, P("mountain_frequency"), .12, .12, .12 };
        double mass = occurrence.Sum(v => Math.Max(v, 0)), closest = double.PositiveInfinity; Span<double> distances = stackalloc double[9]; Span<int> ids = stackalloc int[9]; int cursor = 0;
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = center + new Vector2I(x, z); var site = ((Vector2)q + new Vector2((float)(.15 + random(q.X, q.Y, 3) * .7), (float)(.15 + random(q.X, q.Y, 5) * .7))) * (float)span;
            double roll = random(q.X, q.Y, 7) * mass; int id = 9;
            for (int i = 0; i < 10; i++) { roll -= occurrence[i]; if (roll <= 0) { id = i; break; } }
            double distance = p.DistanceTo(site); closest = Math.Min(closest, distance); distances[cursor] = distance; ids[cursor++] = id;
        }
        var result = new float[10]; double total = 0;
        for (int i = 0; i < 9; i++) { double amount = 1 - Smooth(0, span * .17, distances[i] - closest); result[ids[i]] = (float)(result[ids[i]] + amount); total += amount; }
        for (int i = 0; i < 10; i++) result[i] = (float)(result[i] / Math.Max(total, .001));
        if (_regions.Count >= 2048) _regions.Clear(); _regions[cell] = result; return result;
    }
    public float[] region_weights(Vector2 p)
    {
        var q = p / 512; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        var a = RegionNode(cell); if (f == Vector2.Zero) return a;
        var b = RegionNode(cell + Vector2I.Right); var c = RegionNode(cell + Vector2I.Down); var d = RegionNode(cell + Vector2I.One);
        if (a.SequenceEqual(b) && a.SequenceEqual(c) && a.SequenceEqual(d)) return a;
        var result = new float[10]; for (int i = 0; i < 10; i++) result[i] = (float)Lerp(Lerp(a[i], b[i], f.X), Lerp(c[i], d[i], f.X), f.Y); return result;
    }
    private Vector4 Raw(Vector2 p)
    {
        var w = region_weights(p); double a = _macro.GetNoise2D(p.X, p.Y), b = _meso.GetNoise2D(p.X, p.Y), c = _detail.GetNoise2D(p.X, p.Y);
        var q = p.Rotated((float)(-.61 + seed_value % 73 * .002));
        double input = q.X + Math.Sin(q.Y / 3900.0) * 950 + a * 480 + 6500; double across = input % 13000; if (across < 0) across += 13000; across -= 6500;
        double ridge = Math.Exp(-Math.Pow(Math.Abs(across) / Math.Max(P("valley_scale") * .5, 400), 1.65));
        double saddles = .75 + .15 * Math.Sin(q.Y / 1800.0) + b * .25, mountain = P("mountain_height") * ridge * saddles;
        double hollow = 1 - Smooth(.03, .24, Math.Abs(b + a * .3)), low = 1 - P("lowland_frequency") * .6, rolling = (35 + b * 65 + a * 20) * P("hill_frequency");
        double h = w[0] * (22 + a * 12 + b * 5) * low + w[1] * (65 + rolling * 1.3 + ridge * 130);
        h += w[2] * (35 + rolling + a * 10) + w[3] * (28 + a * 10 + b * 4 + c * 1.5);
        h += w[4] * (55 + rolling * 2.5 + ridge * 65) + w[5] * (55 + ridge * 240 + Math.Abs(b) * 100 + c * 8 * P("ruggedness"));
        h += w[6] * (80 + mountain - hollow * ridge * P("ravine_depth") * P("erosion_strength"));
        h += w[7] * (40 + mountain * .35 - hollow * P("ravine_depth") * .4) + w[8] * (12 + a * 4 + b * 1.2) + w[9] * (25 + a * 12 + b * 3);
        double drain = Math.Clamp(hollow * (w[5] * .3 + w[6] * .65 + w[7]) + w[8] * .7 + w[3] * .25, 0, 1);
        double wet = Math.Clamp(.2 + P("wetness") * .35 + a * .1 + drain * .3 + w[3] * .12 - ridge * w[6] * .12, .05, .9);
        double exposure = Math.Clamp(w[5] * .85 + w[6] * ridge * .7 + w[7] * .45 + w[1] * .18, 0, 1);
        return new Vector4((float)Math.Max(h, 4), (float)wet, (float)drain, (float)exposure);
    }
    private (Vector4 Height, Vector2 Surface) Node(Vector2I cell)
    {
        if (_nodes.TryGetValue(cell, out var cached)) return cached;
        var p = (Vector2)cell * 64; var a = Raw(p);
        var result = (new Vector4(a.X, (Raw(p + new Vector2(16, 0)).X - a.X) / 16, (Raw(p + new Vector2(0, 16)).X - a.X) / 16, a.Y), new Vector2(a.Z, a.W));
        if (_nodes.Count >= 16384) _nodes.Clear(); _nodes[cell] = result; return result;
    }
    public double hermite(double a, double b, double da, double db, double t)
    { double t2 = t * t, t3 = t2 * t; return (2 * t3 - 3 * t2 + 1) * a + (t3 - 2 * t2 + t) * da + (-2 * t3 + 3 * t2) * b + (t3 - t2) * db; }
    public double sample(double x, double z) => sample(x, z, true);
    public double sample(double x, double z, bool publish)
    {
        var q = new Vector2((float)x, (float)z) / 64; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        var a = Node(cell); var av = a.Height; double h = av.X, wet = av.W; var surface = a.Surface;
        if (f != Vector2.Zero)
        {
            var b = Node(cell + Vector2I.Right); var c = Node(cell + Vector2I.Down); var d = Node(cell + Vector2I.One); var bv = b.Height; var cv = c.Height; var dv = d.Height;
            double sx = (double)f.X * f.X * (3 - 2 * (double)f.X);
            h = hermite(hermite(av.X, bv.X, av.Y * 64.0, bv.Y * 64.0, f.X), hermite(cv.X, dv.X, cv.Y * 64.0, dv.Y * 64.0, f.X), Lerp(av.Z, bv.Z, sx) * 64, Lerp(cv.Z, dv.Z, sx) * 64, f.Y);
            wet = Lerp(Lerp(av.W, bv.W, f.X), Lerp(cv.W, dv.W, f.X), f.Y); surface = a.Surface.Lerp(b.Surface, f.X).Lerp(c.Surface.Lerp(d.Surface, f.X), f.Y);
        }
        if (publish)
        {
            weights = region_weights(new Vector2((float)x, (float)z)); region = 0; for (int i = 1; i < 10; i++) if (weights[i] > weights[region]) region = i;
            wetness = wet; drainage = surface.X; rock = surface.Y; river = 0; lake = 0;
            conifer = Math.Clamp(weights[1] + weights[2] * .45 + weights[6] * .5, 0, 1);
            double gap = Math.Clamp(_macro.GetNoise2D((float)(x * 1.9 + 2391), (float)(z * 1.9 - 971)) * .9 + .5, 0, 1);
            clearing = Math.Clamp(weights[9] + (1 - (double)weights[9]) * Smooth(.55, .85, gap) * P("clearing_frequency") * 2, 0, 1);
        }
        return h;
    }
}
