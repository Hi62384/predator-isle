using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Biomes;
/// <summary>Worker-owned wetland geography with a canonical 16m lattice.</summary>
public partial class SwampSampler : RefCounted
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
        foreach (string key in new[] { "region_metres", "floodplain_frequency", "island_density", "basin_frequency", "raised_frequency", "pool_frequency", "water_coverage", "terrain_relief", "island_height", "hummock_amplitude", "hollow_frequency", "channel_frequency", "channel_width", "floodplain_connectivity", "depth_variation", "levee_height", "erosion_intensity", "sediment_deposition", "water_table_influence" }) _parameters[key] = config.Get(key).AsDouble();
        var noises = new[] { _macro, _meso, _detail }; int[] offsets = { 19701, 19717, 19739 }; double[] frequencies = { 1.0 / 7000, 1.0 / 460, 1.0 / 95 };
        for (int i = 0; i < 3; i++)
        { var n = noises[i]; n.Seed = unchecked((int)(world_seed + offsets[i])); n.Frequency = (float)frequencies[i]; n.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth; n.FractalType = FastNoiseLite.FractalTypeEnum.Fbm; n.FractalOctaves = i == 2 ? 1 : 2; n.FractalGain = .32f; }
        _nodes.Clear(); _regions.Clear(); _pools.Clear();
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
        double[] occurrence = { .25, .2, .16, P("floodplain_frequency"), .15, .2, P("island_density") * .3, .2, P("basin_frequency"), P("raised_frequency") * .4, .1, P("basin_frequency") * .6, .08, .08, P("raised_frequency") * .3 };
        double mass = occurrence.Sum(v => Math.Max(v, 0)), closest = double.PositiveInfinity; Span<double> distances = stackalloc double[9]; Span<int> ids = stackalloc int[9]; int cursor = 0;
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = center + new Vector2I(x, z); var site = ((Vector2)q + new Vector2((float)(.15 + random(q.X, q.Y, 3) * .7), (float)(.15 + random(q.X, q.Y, 5) * .7))) * (float)span;
            double roll = random(q.X, q.Y, 7) * mass; int id = 14;
            for (int i = 0; i < 15; i++) { roll -= occurrence[i]; if (roll <= 0) { id = i; break; } }
            double distance = p.DistanceTo(site); closest = Math.Min(closest, distance); distances[cursor] = distance; ids[cursor++] = id;
        }
        var result = new float[15]; double total = 0;
        for (int i = 0; i < 9; i++) { double amount = 1 - Smooth(0, span * .17, distances[i] - closest); result[ids[i]] = (float)(result[ids[i]] + amount); total += amount; }
        for (int i = 0; i < 15; i++) result[i] = (float)(result[i] / Math.Max(total, .001));
        if (_regions.Count >= 2048) _regions.Clear(); _regions[cell] = result; return result;
    }
    public float[] region_weights(Vector2 p)
    {
        var q = p / 512; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        var a = RegionNode(cell); if (f == Vector2.Zero) return a;
        var b = RegionNode(cell + Vector2I.Right); var c = RegionNode(cell + Vector2I.Down); var d = RegionNode(cell + Vector2I.One);
        if (a.SequenceEqual(b) && a.SequenceEqual(c) && a.SequenceEqual(d)) return a;
        var result = new float[15]; for (int i = 0; i < 15; i++) result[i] = (float)Lerp(Lerp(a[i], b[i], f.X), Lerp(c[i], d[i], f.X), f.Y); return result;
    }

    private readonly record struct Pool(Vector2 Center, double Radius, double Aspect, double Angle, double Level, double Random);
    private readonly Dictionary<Vector2I, Pool[]> _pools = new();
    public double water_table(Vector2 p) => 7 + _macro.GetNoise2D(p.X, p.Y) * 4.0 + Math.Sin(p.X / 18000.0 + seed_value % 31) * .8;
    private Pool[] Pools(Vector2I cell)
    {
        if (_pools.TryGetValue(cell, out var cached)) return cached; var result = new List<Pool>();
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
        {
            var q = cell + new Vector2I(x, z); double r = random(q.X, q.Y, 211); if (r > P("pool_frequency")) continue;
            var center = ((Vector2)q + new Vector2((float)(.25 + random(q.X, q.Y, 213) * .5), (float)(.25 + random(q.X, q.Y, 217) * .5))) * 1800;
            result.Add(new Pool(center, 170 + r * 420, .5 + random(q.X, q.Y, 219) * .55, random(q.X, q.Y, 223) * Math.Tau, water_table(center) + .7 + r * 2.5, r));
        }
        if (_pools.Count >= 512) _pools.Clear(); var sites = result.ToArray(); _pools[cell] = sites; return sites;
    }
    private static double Mod(double x, double y) { double v = x % y; return v < 0 ? v + y : v; }
    private double[] Raw(Vector2 p)
    {
        var w = region_weights(p); double a = _macro.GetNoise2D(p.X, p.Y), b = _meso.GetNoise2D(p.X, p.Y), c = _detail.GetNoise2D(p.X, p.Y), table = water_table(p);
        double raised = Smooth(-.18, .22, b + a * .2), ridge = 1 - Smooth(.03, .18, Math.Abs(b + c * .15));
        double offset = w[0] * -.5 + w[1] * -.9 + w[2] * .65 + w[3] * .3 + w[4] * -.3 + w[5] * .7 + w[6] * -.6 + w[7] * .25 + w[8] * .15 + w[9] * .6 - w[10] * 1.7 - w[11] * 1.2 + w[12] * 2.5 + w[13] * -.2 + w[14] * 5.0;
        offset += (.55 - P("water_coverage")) * 4; double land = offset + (b * 2.2 + a * .6) * P("terrain_relief");
        land += raised * P("island_height") * P("island_density") * (w[0] * .8 + w[1] * .6 + w[6] * 1.8 + w[10] * .7 + w[11] * .5 + w[13]);
        land += ridge * P("island_height") * P("raised_frequency") * ((double)w[3] + w[6] + w[7] + w[9]);
        land += c * P("hummock_amplitude") * (w[5] + w[9] * 1.7 + w[14] * .4);
        double hollow = 1 - Smooth(.025, .15, Math.Abs(c + b * .2)); land -= hollow * P("hollow_frequency") * (w[5] * .7 + w[9] + w[8] * .4);
        double channel = 0, flood = 0, levee = 0, basin = 0, deposition = 0, abandoned = 0;
        var host = _host!.GetRef().AsGodotObject(); double spacing = 4000 / Math.Max(host.Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(), .01);
        if (P("channel_frequency") > 0)
        {
            long lane = (long)Math.Round(p.Y / spacing, MidpointRounding.AwayFromZero);
            for (int j = -1; j <= 1; j++)
            {
                var carrier = host.Call("_river_column", p.X, lane + j, spacing).AsVector3();
                double d = Math.Abs((double)p.Y - carrier.X) / Math.Sqrt(1 + (double)carrier.Y * carrier.Y);
                double width = P("channel_width") * (.8 + .25 * Math.Sin(p.X / 700.0 + (lane + j) * 1.7)) * (.65 + w[3] + w[7] * .8 + w[4] * .3);
                if (d > width + 1100) continue; double country = P("channel_frequency") * (.4 + w[3] * .6 + w[7] * .6 + w[4] * .4);
                double bed = (1 - Smooth(width * .35, width, d)) * Smooth(0, .25, P("channel_frequency"));
                double fp = (1 - Smooth(width, width + 650, d)) * P("floodplain_connectivity");
                double bank = Math.Exp(-Math.Pow((d - width * 1.4) / Math.Max(width * .8, 30), 2)), back = Math.Exp(-Math.Pow((d - width * 3) / Math.Max(width * 1.3, 60), 2));
                land = Lerp(land, -P("depth_variation") * (.65 + w[7] * .4), bed); land += bank * P("levee_height") * (w[3] + w[7] * .6); land -= back * ((double)w[3] + w[10] + w[4] * .5) * .9;
                channel = Math.Max(channel, bed); flood = Math.Max(flood, fp); levee = Math.Max(levee, bank);
                double phase = Mod(p.X + (lane + j) * 713.0, 3200) / 3200, split = Math.Pow(Math.Sin(phase * Math.PI), 2) * 380, side = carrier.X + split * ((lane + j) % 2 == 0 ? 1 : -1), sd = Math.Abs(p.Y - side);
                double sidebed = (1 - Smooth(22, 65, sd)) * Smooth(0, .15, phase) * (1 - Smooth(.85, 1, phase)) * country * ((double)w[6] + w[7] + w[3] * .6);
                land = Lerp(land, -P("depth_variation") * .55, Math.Clamp(sidebed, 0, 1)); channel = Math.Max(channel, sidebed);
                long segment = (long)Math.Floor((p.X + (lane + j) * 713.0) / 3200);
                if (random(segment, lane + j, 229) < .28)
                {
                    var ox = new Vector2((float)((phase - .52) * 3200 / 340), (float)(((double)p.Y - carrier.X - 430) / 210)); double od = Math.Abs(ox.Length() - 1.0), neck = Smooth(-.8, -.2, ox.X);
                    double oxbow = (1 - Smooth(.12, .33, od)) * neck * ((double)w[3] + w[7] + w[10]) * .9; land = Lerp(land, -P("depth_variation") * .6, Math.Clamp(oxbow, 0, 1)); basin = Math.Max(basin, oxbow); abandoned = Math.Max(abandoned, oxbow);
                }
                deposition = Math.Max(deposition, fp * (.45 + .3 * Math.Sin(p.X / 500.0 + carrier.Z * 2.0)) * (1 - bed * .4));
            }
        }
        if ((double)w[8] + w[11] + w[2] + w[9] > .08)
        foreach (var site in Pools(new Vector2I((int)Math.Floor(p.X / 1800.0), (int)Math.Floor(p.Y / 1800.0))))
        {
            var v = (p - site.Center).Rotated((float)site.Angle); double radius = site.Radius; if (v.Length() > radius * 1.4) continue;
            var q = new Vector2((float)(v.X / radius), (float)(v.Y / (radius * site.Aspect))); double contour = q.Length() + Math.Sin(q.X * 3.0 + site.Random * 9) * .11 + Math.Sin(q.Y * 4.0) * .06;
            double support = 1 - Smooth(.82, 1.25, contour), bed = 1 - Smooth(.3, .85, contour), bowl = site.Level + 2.4 - bed * (2.4 + P("depth_variation") * .55);
            double eligible = Math.Clamp((double)w[8] + w[11] + w[2] * .45 + w[9] * .25, 0, 1) * (1 - channel), absoluteGround = Lerp(table + land, bowl, support * eligible);
            table = Lerp(table, site.Level, support * eligible); land = absoluteGround - table; basin = Math.Max(basin, bed * eligible); deposition = Math.Max(deposition, bed * eligible * .8);
        }
        double rock = w[12] * Smooth(-.05, .35, b) * .85; land += rock * (3 + Math.Abs(b) * 9) * (1 - channel); land -= P("erosion_intensity") * channel * Math.Max(c, 0) * .4; land += deposition * P("sediment_deposition") * .18;
        double wet = Math.Clamp((1 - Smooth(-.3, 2.8, land)) * P("water_table_influence") + flood * .12, 0, 1), peat = Math.Clamp((w[5] * .9 + w[4] * .6 + w[9] * .5 + w[10] * .4) * (1 - deposition * .5), 0, 1), sediment = Math.Clamp(deposition + w[2] * .6 + w[8] * .5 + w[11] * .4, 0, 1);
        int id = 0; for (int i = 1; i < 15; i++) if (w[i] > w[id]) id = i;
        return new[] { table + land, table, wet, peat, sediment, channel, basin, levee, raised, rock, id / 14.0, Math.Clamp(w[4] + w[5] * .7 + w[10] * .6, 0, 1), abandoned, flood };
    }
    private double[] Node(Vector2I cell)
    {
        if (_nodes.TryGetValue(cell, out var cached)) return cached; var value = Raw((Vector2)cell * 16); if (_nodes.Count >= 16384) _nodes.Clear(); _nodes[cell] = value; return value;
    }
    public double cubic(double a, double b, double c, double d, double t) => b + .5 * t * (c - a + t * (2 * a - 5 * b + 4 * c - d + t * (3 * (b - c) + d - a)));
    public double sample(double x, double z) => sample(x, z, true);
    public double sample(double x, double z, bool publish)
    {
        var q = new Vector2((float)x, (float)z) / 16; var cell = new Vector2I((int)Math.Floor(q.X), (int)Math.Floor(q.Y)); var f = q - (Vector2)cell;
        if (f == Vector2.Zero) { var value = Node(cell); if (publish) state = value; return value[0]; }
        Span<double> rows = stackalloc double[4], waters = stackalloc double[4];
        for (int j = -1; j <= 2; j++)
        { var a = Node(cell + new Vector2I(-1, j)); var b = Node(cell + new Vector2I(0, j)); var c = Node(cell + new Vector2I(1, j)); var d = Node(cell + new Vector2I(2, j)); rows[j + 1] = cubic(a[0], b[0], c[0], d[0], f.X); waters[j + 1] = cubic(a[1], b[1], c[1], d[1], f.X); }
        double h = cubic(rows[0], rows[1], rows[2], rows[3], f.Y);
        if (publish)
        {
            var a = Node(cell); var b = Node(cell + Vector2I.Right); var c = Node(cell + Vector2I.Down); var d = Node(cell + Vector2I.One); state = new double[14]; state[0] = h; state[1] = cubic(waters[0], waters[1], waters[2], waters[3], f.Y);
            for (int k = 2; k < 14; k++) state[k] = Math.Clamp(Lerp(Lerp(a[k], b[k], f.X), Lerp(c[k], d[k], f.X), f.Y), 0, 1);
            state[2] = Math.Clamp((1 - Smooth(-.3, 2.8, h - state[1])) * P("water_table_influence") + state[5] * .12, 0, 1);
        }
        return h;
    }
}
