using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Biomes;
/// <summary>Worker-owned savanna geography with canonical 32m Hermite nodes.</summary>
public partial class SavannaSampler : RefCounted
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
    public double aridity { get; set; }
    public double laterite { get; set; }
    public double soil { get; set; }
    public double erosion { get; set; }
    public double water { get; set; }

    public int region { get; set; }
    public double river { get; set; }
    public double lake { get; set; }
    private double P(string key) => _parameters[key];
    private static double Lerp(double a, double b, double t) => a + (b - a) * t;
    private static double Smooth(double a, double b, double value) { double t = Math.Clamp((value - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    public void configure(Resource config, long world_seed)
    {
        settings = config; seed_value = world_seed; _parameters.Clear();
        foreach (string key in new[] { "region_metres", "plains_frequency", "rolling_frequency", "rocky_frequency", "highland_frequency", "basin_frequency", "kopje_frequency", "kopje_size", "kopje_ruggedness", "mountain_height", "ridge_intensity", "erosion_intensity", "drainage_strength" }) _parameters[key] = config.Get(key).AsDouble();
        var noises = new[] { _macro, _meso, _detail }; int[] offsets = { 17301, 17317, 17339 }; double[] frequencies = { 1.0 / 3600, 1.0 / 680, 1.0 / 180 };
        for (int i = 0; i < 3; i++)
        { var n = noises[i]; n.Seed = unchecked((int)(world_seed + offsets[i])); n.Frequency = (float)frequencies[i]; n.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth; n.FractalType = FastNoiseLite.FractalTypeEnum.Fbm; n.FractalOctaves = i == 2 ? 1 : 2; n.FractalGain = .32f; }
        _nodes.Clear(); _regions.Clear(); _kopjeCache.Clear();
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
        double[] occurrence = { P("plains_frequency"), P("rolling_frequency"), P("rocky_frequency"), .1, P("rocky_frequency") * .65, .14, P("highland_frequency"), .13, .1, .12, .12, P("highland_frequency") * .7, P("basin_frequency") };
        double mass = occurrence.Sum(v => Math.Max(v, 0)), closest = double.PositiveInfinity; Span<double> distances = stackalloc double[9]; Span<int> ids = stackalloc int[9]; int cursor = 0;
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = center + new Vector2I(x, z); var site = ((Vector2)q + new Vector2((float)(.15 + random(q.X, q.Y, 3) * .7), (float)(.15 + random(q.X, q.Y, 5) * .7))) * (float)span;
            double roll = random(q.X, q.Y, 7) * mass; int id = 12;
            for (int i = 0; i < 13; i++) { roll -= occurrence[i]; if (roll <= 0) { id = i; break; } }
            double distance = p.DistanceTo(site); closest = Math.Min(closest, distance); distances[cursor] = distance; ids[cursor++] = id;
        }
        var result = new float[13]; double total = 0;
        for (int i = 0; i < 9; i++) { double amount = 1 - Smooth(0, span * .17, distances[i] - closest); result[ids[i]] = (float)(result[ids[i]] + amount); total += amount; }
        for (int i = 0; i < 13; i++) result[i] = (float)(result[i] / Math.Max(total, .001));
        if (_regions.Count >= 2048) _regions.Clear(); _regions[cell] = result; return result;
    }
    public float[] region_weights(Vector2 p)
    {
        var q = p / 512; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        var a = RegionNode(cell); if (f == Vector2.Zero) return a;
        var b = RegionNode(cell + Vector2I.Right); var c = RegionNode(cell + Vector2I.Down); var d = RegionNode(cell + Vector2I.One);
        if (a.SequenceEqual(b) && a.SequenceEqual(c) && a.SequenceEqual(d)) return a;
        var result = new float[13]; for (int i = 0; i < 13; i++) result[i] = (float)Lerp(Lerp(a[i], b[i], f.X), Lerp(c[i], d[i], f.X), f.Y); return result;
    }
    private readonly record struct Site(Vector2 Center, double Random, double Angle, double Scale);
    private readonly Dictionary<Vector2I, Site[]> _kopjeCache = new();
    private Site[] Sites(Vector2I cell)
    {
        if (_kopjeCache.TryGetValue(cell, out var cached)) return cached;
        var sites = new List<Site>();
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = cell + new Vector2I(x, z); double r = random(q.X, q.Y, 151); if (r > P("kopje_frequency")) continue;
            var center = ((Vector2)q + new Vector2((float)(.2 + random(q.X, q.Y, 153) * .6), (float)(.2 + random(q.X, q.Y, 157) * .6))) * 1600;
            sites.Add(new Site(center, r, random(q.X, q.Y, 159) * Math.Tau, P("kopje_size") * (.7 + r)));
        }
        if (_kopjeCache.Count >= 1024) _kopjeCache.Clear(); var result = sites.ToArray(); _kopjeCache[cell] = result; return result;
    }
    private Vector3 Kopjes(Vector2 p)
    {
        if (P("kopje_frequency") <= 0) return Vector3.Zero;
        var cell = new Vector2I((int)Math.Floor(p.X / 1600.0), (int)Math.Floor(p.Y / 1600.0)); double height = 0, stone = 0, apron = 0;
        foreach (var site in Sites(cell))
        {
            double r = site.Random, scale = site.Scale; var local = (p - site.Center).Rotated((float)site.Angle); if (local.Length() > scale * 2.3) continue;
            double mass = 0;
            for (int k = 0; k < 3; k++)
            {
                double radius = scale * (.75 - k * .12) * (.9 + .18 * Math.Sin(r * 19 + k * 7));
                var offset = (k == 0 ? new Vector2(-.6f, -.18f) : k == 1 ? new Vector2(.48f, .32f) : new Vector2(.12f, -.64f)) * (float)scale;
                offset += new Vector2((float)Math.Sin(r * 39 + k * 2.7), (float)Math.Cos(r * 23 + k * 3.7)) * (float)scale * .18f;
                double d = new Vector2((float)(((double)local.X - offset.X) / radius), (float)(((double)local.Y - offset.Y) / (radius * (.65 + r * .3)))).Length();
                d += Math.Sin(local.Y / (scale * .4) + r * 19 + k) * .06;
                double cap = (1 - Smooth(.2, 1.08, d)) * (.95 + .05 * Math.Sqrt(Math.Max(1 - d * d, 0)));
                double dome = cap * (80 + r * 100) * (1 - k * .13) * (.9 + .2 * Math.Cos(r * 37 + k * 5));
                double joint = (1 - Smooth(18, 65, Math.Abs(local.X - local.Y * .28 - scale * (r - .2)))) * Smooth(.15, .65, d);
                mass = Math.Max(mass, dome * (1 - P("kopje_ruggedness") * .23 * joint));
            }
            height = Math.Max(height, mass); stone = Math.Max(stone, Smooth(8, 45, mass)); apron = Math.Max(apron, (1 - Smooth(scale, scale * 1.9, local.Length())) * .6);
        }
        return new Vector3((float)height, (float)stone, (float)apron);
    }
    private Vector4 Raw(Vector2 p)
    {
        var w = region_weights(p); double a = _macro.GetNoise2D(p.X, p.Y), b = _meso.GetNoise2D(p.X, p.Y), c = _detail.GetNoise2D(p.X, p.Y);
        var q = p.Rotated((float)(.43 + seed_value % 71 * .002));
        double input = q.X + Math.Sin(q.Y / 4300.0) * 1200 + a * 600 + 7000; double across = input % 14000; if (across < 0) across += 14000; across -= 7000;
        double belt = Math.Exp(-Math.Pow(Math.Abs(across) / 1500, 1.6)), peaks = .78 + .16 * Math.Sin(q.Y / 2200.0) + b * .22;
        double ridge = belt * P("mountain_height") * peaks, secondary = (1 - Smooth(.02, .4, Math.Abs(b))) * belt * P("ridge_intensity") * 100;
        double hollow = 1 - Smooth(.025, .24, Math.Abs(b + a * .2)), incision = hollow * belt * P("erosion_intensity") * P("drainage_strength") * 70;
        double hills = 40 + b * 90 + a * 30 + Math.Sin(q.Y / 1700.0 + a) * 13, table = Smooth(-.18, .3, a + b * .35), edge = Smooth(.1, .8, table) * (1 - Smooth(.8, 1, table));
        var kopje = (double)w[5] + w[2] + w[9] > .005 ? Kopjes(p) : Vector3.Zero;
        double h = w[0] * (24 + a * 11 + b * 3 + c * .5 - hollow * 1.8);
        h += w[1] * (35 + hills * 1.3) + w[2] * (45 + hills * .7 + Math.Abs(b) * 70 + kopje.X * .2);
        h += w[3] * (30 + a * 14 + b * 9) + w[4] * (65 + ridge * .45 + secondary - incision * .8);
        h += w[5] * (24 + a * 8 + b * 4 + kopje.X); h += w[6] * (110 + ridge + secondary - incision);
        h += w[7] * (32 + ridge * .18 - hollow * 22 * P("drainage_strength"));
        h += w[8] * (9 + a * 3 + b * .8) + w[9] * (25 + a * 18 + b * 5 + kopje.X * .12);
        h += w[10] * (48 + table * 100 + b * 14 - hollow * 18 * P("erosion_intensity"));
        h += w[11] * (45 + table * 310 + b * 18 + ridge * .2 - incision * .5); h += w[12] * (18 + a * 6 + b * 2 - hollow * 5);
        double drain = Math.Clamp(hollow * (w[0] * .28 + w[1] * .32 + w[4] * .6 + w[6] + w[7] * .8 + w[10] * .3) + w[8] * .75 + w[12] * .4, 0, 1);
        double wet = Math.Clamp(.18 + w[3] * .45 + w[8] * .4 + w[12] * .22 + drain * .45 - w[0] * a * .25 - w[9] * .14 - belt * w[6] * .08, .03, .85);
        double exposure = Math.Clamp(w[2] * .6 + w[4] * belt * .8 + (double)w[5] * kopje.Y + w[6] * belt * .9 + w[11] * edge * .95 + (double)kopje.Z * w[5] * .25, 0, 1);
        return new Vector4((float)Math.Max(h, 3), (float)wet, (float)drain, (float)exposure);
    }
    private (Vector4 Height, Vector2 Surface) Node(Vector2I cell)
    {
        if (_nodes.TryGetValue(cell, out var cached)) return cached;
        var p = (Vector2)cell * 32; var a = Raw(p);
        var result = (new Vector4(a.X, (Raw(p + new Vector2(16, 0)).X - a.X) / 16, (Raw(p + new Vector2(0, 16)).X - a.X) / 16, a.Y), new Vector2(a.Z, a.W));
        if (_nodes.Count >= 16384) _nodes.Clear(); _nodes[cell] = result; return result;
    }
    public double hermite(double a, double b, double da, double db, double t)
    { double t2 = t * t, t3 = t2 * t; return (2 * t3 - 3 * t2 + 1) * a + (t3 - 2 * t2 + t) * da + (-2 * t3 + 3 * t2) * b + (t3 - t2) * db; }
    public double sample(double x, double z) => sample(x, z, true);
    public double sample(double x, double z, bool publish)
    {
        var q = new Vector2((float)x, (float)z) / 32; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        var a = Node(cell); var av = a.Height; double h = av.X, wet = av.W; var surface = a.Surface;
        if (f != Vector2.Zero)
        {
            var b = Node(cell + Vector2I.Right); var c = Node(cell + Vector2I.Down); var d = Node(cell + Vector2I.One); var bv = b.Height; var cv = c.Height; var dv = d.Height;
            double sx = (double)f.X * f.X * (3 - 2 * (double)f.X);
            h = hermite(hermite(av.X, bv.X, av.Y * 32.0, bv.Y * 32.0, f.X), hermite(cv.X, dv.X, cv.Y * 32.0, dv.Y * 32.0, f.X), Lerp(av.Z, bv.Z, sx) * 32, Lerp(cv.Z, dv.Z, sx) * 32, f.Y);
            wet = Lerp(Lerp(av.W, bv.W, f.X), Lerp(cv.W, dv.W, f.X), f.Y); surface = a.Surface.Lerp(b.Surface, f.X).Lerp(c.Surface.Lerp(d.Surface, f.X), f.Y);
        }
        if (publish)
        {
            weights = region_weights(new Vector2((float)x, (float)z)); region = 0; for (int i = 1; i < 13; i++) if (weights[i] > weights[region]) region = i;
            wetness = wet; drainage = surface.X; rock = surface.Y; river = 0; lake = 0;
            aridity = Math.Clamp(.6 + weights[9] * .3 - weights[3] * .35 - weights[8] * .3 - weights[12] * .15 - drainage * .18, 0, 1);
            double ridgeSoil = Smooth(.05, .3, _meso.GetNoise2D((float)x, (float)z));
            laterite = Math.Clamp(weights[10] + weights[2] * .35 + weights[4] * .25 + weights[11] * .2 + weights[0] * ridgeSoil * .3, 0, 1);
            soil = Math.Clamp(.12 + laterite * .45 + weights[9] * .3 + drainage * .15 + weights[0] * ridgeSoil * .15, 0, 1);
            erosion = Math.Clamp(drainage * ((double)weights[4] + weights[6] + weights[7] + weights[10]) * .8, 0, 1);
        }
        return h;
    }
}

