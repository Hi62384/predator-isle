using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Biomes;
/// <summary>Worker-owned tropical geography with canonical 64m Hermite nodes.</summary>
public partial class JungleSampler : RefCounted
{
    public Resource settings { get; set; } = null!;
    public long seed_value { get; set; }
    // Transitional placement queries still read these original sampler hooks.
    public FastNoiseLite _macro { get; } = new();
    public Godot.Collections.Array<string> NAMES { get; } = new(new[] { "Lowland rainforest", "Rolling jungle", "Rugged jungle hills", "Jungle foothills", "Jungle mountains", "River rainforest", "Floodplain jungle", "Rocky jungle", "Tropical karst", "Jungle plateau", "Jungle gorge", "Humid basin", "Upland rainforest" });
    private readonly FastNoiseLite _meso = new(), _detail = new();
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
        foreach (string key in new[] { "region_metres", "lowland_frequency", "mountain_frequency", "plateau_frequency", "hill_density", "mountain_height", "ruggedness", "gully_frequency", "erosion_strength", "valley_depth", "wetness_variation" }) _parameters[key] = config.Get(key).AsDouble();
        var noises = new[] { _macro, _meso, _detail }; int[] offsets = { 9011, 9031, 9041 }; double[] frequencies = { 1.0 / 4200, 1.0 / 850, 1.0 / 2600 };
        for (int i = 0; i < 3; i++)
        { var n = noises[i]; n.Seed = unchecked((int)(world_seed + offsets[i])); n.Frequency = (float)frequencies[i]; n.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth; n.FractalType = FastNoiseLite.FractalTypeEnum.Fbm; n.FractalOctaves = i == 2 ? 1 : 2; n.FractalGain = .35f; }
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
        double closest = double.PositiveInfinity; Span<double> distances = stackalloc double[9]; Span<int> ids = stackalloc int[9]; int cursor = 0;
        ReadOnlySpan<int> others = stackalloc int[] { 1, 2, 3, 5, 6, 7, 8, 10, 11, 12 };
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = center + new Vector2I(x, z); var site = ((Vector2)q + new Vector2((float)(.15 + random(q.X, q.Y, 3) * .7), (float)(.15 + random(q.X, q.Y, 5) * .7))) * (float)span;
            double low = P("lowland_frequency"), mountain = P("mountain_frequency"), plateau = P("plateau_frequency");
            double total = Math.Max(low + mountain + plateau + .47, 1), roll = random(q.X, q.Y, 7) * total; int id;
            if (roll < low) id = 0; else if (roll < low + mountain) id = 4; else if (roll < low + mountain + plateau) id = 9;
            else { id = others[Math.Clamp((int)((roll - low - mountain - plateau) / Math.Max(total - low - mountain - plateau, .001) * 10), 0, 9)]; }
            double distance = p.DistanceTo(site); closest = Math.Min(closest, distance); distances[cursor] = distance; ids[cursor++] = id;
        }
        double totalWeight = 0;
        var result = new float[13];
        for (int i = 0; i < 9; i++) { double amount = 1 - Smooth(0, span * .20, distances[i] - closest); result[ids[i]] = (float)(result[ids[i]] + amount); totalWeight += amount; }
        for (int i = 0; i < 13; i++) result[i] = (float)(result[i] / Math.Max(totalWeight, .001));
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
    private Vector4 Raw(Vector2 p)
    {
        var w = region_weights(p); double macro = _macro.GetNoise2D(p.X, p.Y), meso = _meso.GetNoise2D(p.X, p.Y);
        var q = p.Rotated((float)(.43 + seed_value % 97 * .004)); double structure = _detail.GetNoise2D((float)(q.X * .75), (float)(q.Y * 1.4));
        double input = q.Y + Math.Sin(q.X / 4700.0) * 750 + macro * 500 + 7000; double across = input % 14000; if (across < 0) across += 14000; across -= 7000;
        double ridge = Math.Exp(-Math.Pow(Math.Abs(across) / 1500, 1.45)), hills = (.5 + meso * .65) * P("hill_density");
        double mountain = P("mountain_height") * ridge * (.7 + structure * .45);
        mountain += Math.Pow(1 - Math.Abs(structure), 4) * ridge * P("mountain_height") * .15 * P("ruggedness");
        double gully = (1 - Smooth(.025, .16, Math.Abs(meso + structure * .2))) * P("gully_frequency");
        double incision = gully * ridge * P("erosion_strength") * P("valley_depth"), karst = Math.Pow(1 - Math.Abs(structure), 5) * 330 + meso * 20;
        double plateau = Smooth(-.13, .18, macro) * 300 + meso * 9, gorge = 1 - Smooth(.04, .30, Math.Abs(structure));
        double h = w[0] * (24 + macro * 9 + meso * 1.6) + w[1] * (40 + hills * 95) + w[2] * (65 + hills * 200 + ridge * 75);
        h += w[3] * (65 + mountain * .45) + w[4] * (70 + mountain - incision) + w[5] * (15 + macro * 5 + meso * 2);
        h += w[6] * (9 + macro * 3 + meso * .6) + w[7] * (65 + mountain * .55 + structure * 35);
        h += w[8] * (45 + karst) + w[9] * (65 + plateau) + w[10] * (80 + mountain * .4 - gorge * P("valley_depth"));
        h += w[11] * (16 + macro * 5 + meso * 1.5) + w[12] * (130 + hills * 90 + ridge * 120); h = Math.Max(h, 3);
        double drain = Math.Clamp(gully * ((double)w[2] + w[3] + w[4]) + gorge * w[10] + w[5] * .4 + w[6] * .65 + w[11] * .5, 0, 1);
        double wet = Math.Clamp(.35 + (macro * .2 + meso * .1) * P("wetness_variation") + drain * .45 + ((double)w[0] + w[11]) * .15 - ridge * ((double)w[4] + w[7]) * .2, .1, .95);
        double exposed = Math.Clamp(w[7] * .7 + w[8] * .85 + w[4] * .55 + w[10] * .6 + w[9] * .45 + w[2] * .2, 0, 1);
        return new Vector4((float)h, (float)wet, (float)drain, (float)exposed);
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
            weights = region_weights(new Vector2((float)x, (float)z)); region = 0; for (int i = 1; i < 13; i++) if (weights[i] > weights[region]) region = i;
            wetness = wet; drainage = surface.X; rock = surface.Y; river = 0; lake = 0;
        }
        return h;
    }
}



