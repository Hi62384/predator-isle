using Godot;
using System;
using System.Collections.Generic;
using PredatorIsle.Biomes;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Canonical mixed-biome height and material controls, shared by mesh and collision queries.</summary>
public partial class TerrainHeightField : RefCounted
{
    public Resource settings { get; set; } = null!;
    public double water_level { get; set; }
    public bool cache_dense_payloads { get; set; }
    public bool coastal_structure_height_cache_enabled { get; set; } = true;
    public int normal_height_cache_capacity { get; private set; } = 8192;
    public bool query_changed { get; private set; }
    public D height_grid_cache { get; private set; } = new();
    public D normal_height_cache { get; private set; } = new();
    public D savanna_gullies { get; private set; } = new();
    private TerrainRegions _regions = null!;
    private TerrainIslands _islands = null!;
    private GrasslandField _grass = null!;
    private JungleSampler? _jungle;
    private ForestSampler? _forest;
    private SavannaSampler? _savanna;
    private SwampSampler? _swamp;
    private MountainSampler? _mountain;
    private RockyCoastSampler? _coast;
    private TropicalSampler? _tropical;
    private BadlandsSampler? _badlands;
    private BiomeExtensionSampler?[] _extras = new BiomeExtensionSampler?[8];
    private bool _extrasEnabled;
    private double _coastLimit;
    public Vector4 last_weights { get; private set; }
    public Vector2 last_surface { get; private set; }
    public Vector3 last_geology { get; private set; }
    public double last_island { get; private set; }
    public double last_jungle { get; private set; }
    public float[] last_forest { get; private set; } = new float[4];
    public float[] last_savanna { get; private set; } = new float[4];
    public float[] last_swamp { get; private set; } = new float[4];
    public float[] last_mountain { get; private set; } = new float[4];
    public Vector4 last_coast { get; private set; }
    public Vector3 last_tropical { get; private set; }
    public Vector3 last_badlands { get; private set; }
    public Vector4[] last_extras { get; private set; } = new Vector4[8];
    public double last_water { get; private set; }
    public Vector4 last_badlands_palette { get; private set; }
    public double last_badlands_remnant { get; private set; }
    public double last_badlands_skirt { get; private set; }
    private static readonly float[] Neutral = new float[4];
    private readonly TerrainParameterSnapshot _parameters = new();
    private readonly TerrainHeightChanges _changes = new();
    private double P(string key) => _parameters[key];
    private readonly Dictionary<Resource,TerrainParameterSnapshot> resourceNumbers=new(ReferenceEqualityComparer.Instance);
    private double Q(Resource config,string key)
    {
        if(!resourceNumbers.TryGetValue(config,out var values)){values=new TerrainParameterSnapshot();values.Capture(config);resourceNumbers.Add(config,values);}return values[key];
    }
    private bool Water => settings.Get("water_enabled").AsBool();
    private double Random(long x, long z, int biome, int salt) => _regions.random(x, z, biome, salt);
    private static double L(double a, double b, double t) => a + (b - a) * t;
    private static double C(double x, double a = 0, double b = 1) => Math.Clamp(x, a, b);
    private static double S(double a, double b, double x) { double t = C((x - a) / (b - a)); return t * t * (3 - 2 * t); }
    private static long Round(double x) => (long)Math.Round(x, MidpointRounding.AwayFromZero);
    private static Vector2 Rotate(Vector2 v, float angle) { float s = (float)Math.Sin(angle), c = (float)Math.Cos(angle); return new Vector2(v.X * c - v.Y * s, v.X * s + v.Y * c); }
    public void set_context(Vector2 surface, Vector3 geology, double water)
    { last_surface = surface; last_geology = geology; last_water = water; }
    public void configure(RefCounted host)
    {
        settings = (Resource)host.Get("settings").AsGodotObject(); water_level = host.Get("water_level").AsDouble();
        _parameters.Capture(settings);
        resourceNumbers.Clear();
        _changes.Configure(settings is TerrainConfiguration native?native.terrain_changes:System.Array.Empty<Vector4>());
        _regions = (TerrainRegions)host.Get("_native_regions").AsGodotObject(); _islands = (TerrainIslands)host.Get("_native_islands").AsGodotObject(); _grass = (GrasslandField)host.Get("_native_grass").AsGodotObject();
        _jungle = host.Get("_jungle").AsGodotObject() as JungleSampler; _forest = host.Get("_forest").AsGodotObject() as ForestSampler;
        _savanna = host.Get("_savanna").AsGodotObject() as SavannaSampler; _swamp = host.Get("_swamp").AsGodotObject() as SwampSampler;
        _mountain = host.Get("_mountain").AsGodotObject() as MountainSampler; _coast = host.Get("_coast").AsGodotObject() as RockyCoastSampler;
        _tropical = host.Get("_tropical").AsGodotObject() as TropicalSampler; _badlands = host.Get("_badlands").AsGodotObject() as BadlandsSampler;
        var extras = host.Get("_extras").AsGodotArray(); for (int i = 0; i < 8; i++) _extras[i] = extras[i].AsGodotObject() as BiomeExtensionSampler;
        _extrasEnabled = host.Get("_extras_enabled").AsBool(); _coastLimit = host.Get("_coast_limit").AsDouble();
        height_grid_cache.Clear(); normal_height_cache.Clear(); savanna_gullies.Clear(); normal_height_cache_capacity = 8192;
        last_jungle = 0; last_forest = last_savanna = last_swamp = Neutral; last_mountain = new float[4];
        last_water = water_level; last_coast = Vector4.Zero; last_tropical = last_badlands = Vector3.Zero;
        last_extras = new Vector4[8]; last_badlands_palette = Vector4.Zero; last_badlands_remnant = last_badlands_skirt = 0;
    }
    public double pack(double a, double b, double c) => Round(C(a) * 255) + Round(C(b) * 255) * 256 + Round(C(c) * 255) * 65536;
    public Vector4 coast_payload(double[] c)
    { double sediment = c[5]; if (c.Length > 20 && c[19] > .001) sediment = -pack(c[19], c[20], 0) - 1; return new Vector4((float)c[2], (float)c[3], (float)c[4], (float)sediment); }
    public double apply_coast(double baseHeight, bool publish, double[] c)
    {
        if (_coast is null || c.Length == 0 || c[2] <= 0) return baseHeight;
        double mult = Math.Max(P("height_multiplier"), .01); last_water = L(last_water, water_level + c[1] * mult, c[2]);
        if (publish) last_coast = coast_payload(c);
        return water_level + L((baseHeight - water_level) / mult, c[0], c[2]) * mult;
    }
    public double jungle_height(double x, double z, double weight, bool publish)
    {
        var jungle = _jungle!; double h = jungle.sample(x, z, true); var config = jungle.settings; var w = jungle.weights;
        double riverCountry = (double)w[5] + w[6] + w[10] * .7, valley = 0, channel = 0, lake = 0;
        if (Q(config, "river_frequency") > 0 && P("grass_river_frequency") > 0 && Water)
        {
            double spacing = 4000 / Math.Max(P("grass_river_frequency"), .01); long lane = Round(z / spacing);
            for (int offset = -1; offset <= 1; offset++)
            {
                var carrier = _grass.river_column(x, lane + offset, spacing); double distance = Math.Abs(z - carrier.X);
                double width = Q(config, "river_width") * L(.6, 1.9, riverCountry) * (1 + carrier.Z * .3), reach = C(Q(config, "river_frequency"));
                double corridor = (1 - S(width * 2, width * 2 + Q(config, "river_valley_width"), distance)) * reach;
                double lowland = 1 - S(100, 240, h), gorge = w[10], floor = L(Math.Max(6, h - Q(config, "valley_depth")), 4, C(lowland + gorge));
                h = L(h, floor, corridor);
                double flood = (1 - S(width * 1.8, width * 5, distance)) * lowland * Q(config, "floodplain_influence");
                h = L(h, 3 + S(width * 1.2, width * 4, distance) * 4, flood);
                double wet = (1 - S(width * .4, width * 1.6, distance / Math.Sqrt(1 + (double)carrier.Y * carrier.Y))) * C(lowland + gorge) * reach;
                channel = Math.Max(channel, wet); valley = Math.Max(valley, corridor);
                if (Q(config, "stream_density") > 0 && lowland > .05)
                {
                    double span = spacing * .6; long segment = (long)Math.Floor(x / span);
                    for (int k = -1; k <= 1; k++)
                    {
                        long branch = segment + k; double r = Random(branch, lane + offset, 97, 617); if (r > Q(config, "tributary_density")) continue;
                        double t = (x - (branch + .1 + r * .3) * span) / (span * L(.5, .9, r)); if (t <= 0 || t >= 1) continue;
                        double side = Random(branch, lane + offset, 97, 619) < .5 ? -1 : 1, across = z - carrier.X - side * spacing * .24 * t * t;
                        double sw = width * L(.5, .15, t) * Q(config, "stream_density");
                        double stream = (1 - S(sw * .4, sw * 1.7, Math.Abs(across))) * (1 - S(.65, 1, t)) * lowland;
                        channel = Math.Max(channel, stream);
                    }
                }
            }
        }
        if (Q(config, "lake_frequency") > 0 && P("grass_lake_frequency") > 0 && Water && h < 100)
        {
            double pitch = Math.Max(P("grass_lake_size") * 5, 1200); var cell = new Vector2I((int)Math.Floor(x / pitch), (int)Math.Floor(z / pitch));
            foreach (var site in _grass.lake_sites(cell, pitch))
            {
                if (Random((long)Math.Floor(site.X), (long)Math.Floor(site.Y), 103, 19) > Q(config, "lake_frequency")) continue;
                var p = Rotate(new Vector2((float)x, (float)z) - new Vector2(site.X, site.Y), site.W) / (float)Math.Max(site.Z, 1);
                double contour = Math.Min(new Vector2((float)(p.X / .85), (float)(p.Y / .65)).Length(), (p - new Vector2(.48f, .25f)).Length() / .6);
                lake = Math.Max(lake, 1 - S(.65, 1.12, contour));
            }
        }
        double water = Math.Max(channel, lake); h = L(h, -Math.Max(P("grass_river_depth"), P("grass_lake_depth")), water);
        if (publish)
        {
            jungle.river = channel; jungle.lake = lake; jungle.drainage = Math.Max(jungle.drainage, valley); jungle.wetness = C(jungle.wetness + valley * .2 + water * .35);
            last_jungle = Round(jungle.wetness * 255) + Round(jungle.drainage * 255) * 256 + Round(weight * 255) * 65536;
            last_geology = last_geology.Lerp(new Vector3((float)(jungle.region / 12.0), (float)jungle.rock, (float)water), (float)weight);
        }
        return h;
    }
    public double forest_height(double x, double z, double weight, bool publish)
    {
        var forest = _forest!; double h = forest.sample(x, z, true); var config = forest.settings; var w = forest.weights;
        double valley = 0, river = 0, lake = 0, lowland = (1 - S(100, 220, h)) * C(.4 + w[0] * .35 + w[3] * .35 + w[7] * .6 + w[8]);
        if (Water && P("grass_river_frequency") > 0 && Q(config, "river_influence") > 0)
        {
            double spacing = 4000 / Math.Max(P("grass_river_frequency"), .01); long lane = Round(z / spacing);
            for (int offset = -1; offset <= 1; offset++)
            {
                var carrier = _grass.river_column(x, lane + offset, spacing); double distance = Math.Abs(z - carrier.X) / Math.Sqrt(1 + (double)carrier.Y * carrier.Y);
                double width = Q(config, "river_width") * (.65 + w[8] * .8) * (1 + carrier.Z * .25);
                double corridor = (1 - S(width * 2, width * 2 + Q(config, "river_valley_width"), distance)) * Q(config, "river_influence");
                h = L(h, Math.Max(4, h - Q(config, "ravine_depth")), corridor);
                double flood = (1 - S(width * 1.4, width * 5, distance)) * lowland; h = L(h, 3 + S(width, width * 4, distance) * 5, flood);
                valley = Math.Max(valley, corridor * lowland); river = Math.Max(river, (1 - S(width * .45, width * 1.55, distance)) * lowland * Q(config, "river_influence"));
                if (Q(config, "stream_density") > 0 && lowland > .1)
                {
                    double span = spacing * .6; long segment = (long)Math.Floor(x / span);
                    for (int k = -1; k <= 1; k++)
                    {
                        long branch = segment + k; double r = Random(branch, lane + offset, 97, 617); if (r > Q(config, "stream_density")) continue;
                        double t = (x - (branch + .1 + r * .3) * span) / (span * L(.5, .9, r)); if (t <= 0 || t >= 1) continue;
                        double side = Random(branch, lane + offset, 97, 619) < .5 ? -1 : 1, across = z - carrier.X - side * spacing * .24 * t * t;
                        double sw = width * L(.42, .12, t), reach = (1 - S(.65, 1, t)) * lowland;
                        double tributaryValley = (1 - S(sw * 1.5, sw + 80, Math.Abs(across))) * reach;
                        h = L(h, 5, tributaryValley); valley = Math.Max(valley, tributaryValley); river = Math.Max(river, (1 - S(sw * .4, sw * 1.7, Math.Abs(across))) * reach);
                    }
                }
            }
        }
        if (Water && P("grass_lake_frequency") > 0 && Q(config, "lake_frequency") > 0 && h < 100 && (double)w[3] + w[7] + w[8] > .15)
        {
            double pitch = Math.Max(P("grass_lake_size") * 5, 1200); var cell = new Vector2I((int)Math.Floor(x / pitch), (int)Math.Floor(z / pitch));
            foreach (var site in _grass.lake_sites(cell, pitch))
            {
                if (Random((long)Math.Floor(site.X), (long)Math.Floor(site.Y), 103, 19) > Q(config, "lake_frequency")) continue;
                var p = Rotate(new Vector2((float)x, (float)z) - new Vector2(site.X, site.Y), site.W) / (float)Math.Max(site.Z, 1);
                double contour = Math.Min(new Vector2((float)(p.X / .9), (float)(p.Y / .65)).Length(), Math.Min((p - new Vector2(.5f, .2f)).Length() / .6, new Vector2((float)((p.X + .55) / .6), (float)((p.Y - .2) / .3)).Length()));
                double basin = 1 - S(.65, 1.8, contour); h = L(h, 4 + S(.65, 1.5, contour) * 5, basin * lowland); lake = Math.Max(lake, (1 - S(.65, 1.1, contour)) * lowland);
            }
        }
        double water = Math.Max(river, lake); h = L(h, -Math.Max(P("grass_river_depth"), P("grass_lake_depth")), water);
        if (publish)
        {
            forest.river = river; forest.lake = lake; forest.drainage = Math.Max(forest.drainage, valley); forest.wetness = C(forest.wetness + valley * .15 + water * .3);
            last_forest = new[] { (float)(Round(forest.wetness * 255) + Round(forest.drainage * 255) * 256 + Round(weight * 255) * 65536), (float)(Round(forest.conifer * 255) + Round(forest.clearing * 255) * 256 + Round(forest.region / 9.0 * 255) * 65536), (float)forest.rock, (float)water };
        }
        return h;
    }
    public double savanna_height(double x, double z, double weight, bool publish)
    {
        var savanna = _savanna!; double h = savanna.sample(x, z, true); var c = savanna.settings; var w = savanna.weights;
        double drain = 0, channel = 0, basin = 0, water = 0;
        if (P("grass_river_frequency") > 0 && Q(c, "drainage_strength") > 0 && Q(c, "seasonal_channel_frequency") > 0)
        {
            double spacing = 4000 / Math.Max(P("grass_river_frequency"), .01); long lane = Round(z / spacing);
            for (int offset = -1; offset <= 1; offset++)
            {
                long id = lane + offset; double roll = Random(id, 0, 97, 811); if (roll > Q(c, "seasonal_channel_frequency")) continue;
                var carrier = _grass.river_column(x, id, spacing); double distance = Math.Abs(z - carrier.X) / Math.Sqrt(1 + (double)carrier.Y * carrier.Y);
                double width = (35 + w[7] * 40.0 + w[8] * 80.0) * (1 + carrier.Z * .22);
                if (distance > width * 2 + Q(c, "valley_width") && Math.Abs(z - carrier.X) > spacing * .2 + width * .4 + 55) continue;
                double valley = (1 - S(width * 2, width * 2 + Q(c, "valley_width"), distance)) * Q(c, "drainage_strength");
                double low = (1 - S(90, 190, h)) * C(.3 + w[3] * .2 + w[7] * .5 + w[8] + w[12] * .5);
                h = L(h, Math.Max(5, h - 22 - w[7] * 18.0), valley); double bed = 1 - S(width * .4, width * 1.8, distance);
                h = L(h, Math.Max(3, h - 8 - w[7] * 8.0), bed * Q(c, "drainage_strength")); channel = Math.Max(channel, bed * Q(c, "drainage_strength")); drain = Math.Max(drain, valley);
                double perennial = Q(c, "perennial_frequency") > 0 ? (1 - S(Q(c, "perennial_frequency") * .8, Q(c, "perennial_frequency") + .001, roll)) * low : 0;
                water = Math.Max(water, bed * perennial);
                if (Q(c, "gully_frequency") > 0)
                {
                    double span = spacing * .65; long segment = (long)Math.Floor(x / span);
                    for (int k = -1; k <= 1; k++)
                    {
                        long branch = segment + k; var key = new Vector2I(unchecked((int)branch), unchecked((int)id));
                        if (!savanna_gullies.ContainsKey(key))
                        {
                            if (savanna_gullies.Count >= 1024) savanna_gullies.Clear(); double rollG = Random(branch, id, 97, 817);
                            savanna_gullies[key] = new A { rollG, (branch + .1 + rollG * .3) * span, Random(branch, id, 97, 819) < .5 ? -1.0 : 1.0 };
                        }
                        var descriptor = savanna_gullies[key].AsGodotArray(); double r = descriptor[0].AsDouble(); if (r > Q(c, "gully_frequency")) continue;
                        double t = (x - descriptor[1].AsDouble()) / (span * .72); if (t <= 0 || t >= 1) continue;
                        double side = descriptor[2].AsDouble(), across = z - carrier.X - side * spacing * .2 * t * t, widthG = width * L(.4, .12, t);
                        double g = (1 - S(widthG, widthG + 55, Math.Abs(across))) * S(0, .08, t) * (1 - S(.65, 1, t)) * Q(c, "erosion_intensity");
                        h = L(h, Math.Max(3, h - 12), g); drain = Math.Max(drain, g); channel = Math.Max(channel, g * .8);
                    }
                }
            }
        }
        if (Q(c, "basin_frequency") > 0 && (double)w[8] + w[12] > .02)
        {
            double pitch = Math.Max(P("grass_lake_size") * 5, 1400); var cell = new Vector2I((int)Math.Floor(x / pitch), (int)Math.Floor(z / pitch));
            foreach (var site in _grass.lake_sites(cell, pitch))
            {
                double roll = Random((long)Math.Floor(site.X), (long)Math.Floor(site.Y), 103, 829); if (roll > Q(c, "basin_frequency") * 2) continue;
                var p = Rotate(new Vector2((float)x, (float)z) - new Vector2(site.X, site.Y), site.W) / (float)Math.Max(site.Z * 1.3, 1);
                double contour = Math.Min(new Vector2((float)(p.X / .95), (float)(p.Y / .58)).Length(), Math.Min((p - new Vector2(.6f, .2f)).Length() / .55, new Vector2((float)((p.X + .55) / .7), (float)((p.Y - .2) / .38)).Length()));
                double b = (1 - S(.5, 1.9, contour)) * C((double)w[8] + w[12]) * (1 - S(55, 100, h));
                h = L(h, 3.5 + S(.6, 1.8, contour) * 5, b); basin = Math.Max(basin, b);
                if (P("grass_lake_frequency") > 0 && roll < Q(c, "basin_water_coverage") * Q(c, "basin_frequency")) water = Math.Max(water, (1 - S(.5, 1, contour)) * b);
            }
        }
        h = L(h, -Math.Max(P("grass_river_depth"), 2), water);
        if (publish)
        {
            savanna.river = channel; savanna.lake = basin; savanna.water = water; savanna.drainage = Math.Max(savanna.drainage, drain); savanna.wetness = C(savanna.wetness + water * .4 + drain * .1);
            last_savanna = new[] { (float)pack(savanna.wetness, savanna.drainage, weight), (float)pack(savanna.rock, savanna.laterite, savanna.region / 12.0), (float)pack(channel, basin, water), (float)pack(savanna.aridity, savanna.soil, savanna.erosion) };
        }
        return h;
    }
    public double mountain_height(double x, double z, double weight, bool publish)
    {
        double h = _mountain!.sample(x, z, true); var s = _mountain.state; h = L(Math.Min(h, s[1] + 80), h, S(.05, .9, weight));
        if (publish) last_mountain = new[] { (float)pack(s[2], s[3], weight), (float)pack(s[4], s[5], s[6]), (float)pack(s[7], s[8], s[9]), (float)s[10] }; return h;
    }
    public double tropical_height(double x, double z, double weight, bool publish)
    {
        double h = _tropical!.sample(x, z, true); var s = _tropical.state;
        if (publish) { last_tropical = new Vector3((float)weight, (float)s[2], (float)s[3]); last_geology = last_geology.Lerp(new Vector3((float)s[4], (float)s[5], (float)s[6]), (float)weight); last_surface = last_surface.Lerp(new Vector2((float)s[7], (float)s[6]), (float)weight); } return h;
    }
    public double swamp_height(double x, double z, double weight, bool publish)
    {
        double h = _swamp!.sample(x, z, true); var s = _swamp.state;
        if (publish) last_swamp = new[] { (float)pack(s[2], s[3], weight), (float)pack(s[4], s[5], s[6]), (float)pack(s[7], s[8], s[9]), (float)pack(s[10], s[11], s[12]) }; return h;
    }
    public double height(double x, double z) => height(x, z, true);
    public double height(double x, double z, bool publish)
        => BaseHeight(x,z,publish)+_changes.Offset(x,z);
    private double BaseHeight(double x,double z,bool publish)
    {
        query_changed = true;
        if (_extrasEnabled) last_extras = new Vector4[8];
        last_badlands = Vector3.Zero; last_badlands_palette = Vector4.Zero; last_badlands_remnant = last_badlands_skirt = 0;
        last_tropical = Vector3.Zero; last_coast = Vector4.Zero; last_jungle = 0; last_surface = Vector2.Zero; last_geology = Vector3.Zero; last_weights = Vector4.Zero;
        if (_forest is not null) last_forest = Neutral; if (_savanna is not null) last_savanna = Neutral; if (_swamp is not null) last_swamp = Neutral;
        last_water = water_level; if (_mountain is not null) last_mountain = new float[4];
        double island = _islands.mask(x, z, true, _coastLimit); last_island = island;
        double shoreDistance = island * Math.Max(P("island_size") * .5, 8), shoreTransition = Math.Max(P("coast_width") * 694.445, .1), scale = Math.Max(P("terrain_shape_scale"), .01);
        double mult = Math.Max(P("height_multiplier"), .01); double[] coast = System.Array.Empty<double>();
        if (_coast is not null && _coast.may_affect(x, z, shoreDistance))
        {
            _coast.sample(x, z, 0, shoreDistance, true); coast = _coast.state;
            if (coast[2] == 1) { last_weights = _regions.weights(x, z); if (publish) last_coast = coast_payload(coast); last_water = water_level + coast[1] * mult; return water_level + coast[0] * mult; }
        }
        if (island <= 0)
        {
            double detail = _grass.detail.GetNoise2D((float)(x / scale), (float)(z / scale)), floor = Math.Min(-Math.Max(P("ocean_depth"), 1) + detail * P("seabed_relief"), -1);
            return apply_coast(water_level + floor * Math.Min(-shoreDistance / shoreTransition, 1) * mult, publish, coast);
        }
        last_weights = _regions.weights(x, z); double jungleWeight = _regions.jungle_weight, mountainWeight = _regions.mountain_weight, tropicalWeight = _regions.tropical_weight, land = 0;
        if (last_weights.X > 0) { var p = _grass.sample(x / scale, z / scale); last_surface = _grass.last_surface; last_geology = _grass.last_geology; land = L(Math.Max(1, p.X), p.Z, p.Y) * last_weights.X; }
        if (jungleWeight > 0) land += jungle_height(x, z, jungleWeight, publish) * jungleWeight;
        if (last_weights.Y > 0) land += forest_height(x, z, last_weights.Y, publish) * last_weights.Y;
        if (last_weights.Z > 0) land += savanna_height(x, z, last_weights.Z, publish) * last_weights.Z;
        double shore = S(0, shoreTransition, shoreDistance);
        if (last_weights.W > 0) { land += swamp_height(x, z, last_weights.W, publish) * last_weights.W; last_water = water_level + _swamp!.state[1] * last_weights.W * shore * mult; }
        if (mountainWeight > 0) { land += mountain_height(x, z, mountainWeight, publish) * mountainWeight; last_water += _mountain!.state[1] * mountainWeight * shore * mult; }
        if (tropicalWeight > 0) { land += tropical_height(x, z, tropicalWeight, publish) * tropicalWeight; last_water += _tropical!.state[1] * tropicalWeight * shore * mult; }
        if (_regions.badlands_weight > 0)
        {
            double bw = _regions.badlands_weight; land += _badlands!.sample(x, z, publish) * bw; var s = _badlands.state;
            if (publish)
            {
                last_badlands_palette = _badlands.palette_state; last_badlands_remnant = bw * s[10]; last_badlands_skirt = bw * _badlands.remnant_delta * shore * mult;
                last_water += s[1] * bw * shore * mult; last_badlands = new Vector3((float)bw, (float)s[2], (float)s[3]);
                last_geology = last_geology.Lerp(new Vector3((float)s[4], (float)s[5], (float)s[6]), (float)bw); last_surface = last_surface.Lerp(new Vector2((float)s[7], (float)s[8]), (float)bw);
            }
        }
        if (_extrasEnabled)
        {
            for (int i = 0; i < 8; i++)
            {
                double amount = _regions.extra_weights[i]; if (amount <= 0) continue; var sampler = _extras[i]!;
                land += sampler.sample(x, z, publish) * amount;
                if (publish){var e = sampler.state;last_water += e[1] * amount * shore * mult;last_extras[i] = new Vector4((float)amount, (float)e[2], (float)e[3], (float)e[4]);}
            }
            if (_extras[7] is AlienInfectedSampler alien && Q(alien.settings, "overlay_strength") > 0)
            {
                var network = alien.network(new Vector2((float)x, (float)z)); double influence = network["influence"].AsDouble() * Q(alien.settings, "overlay_strength") * (1 - _regions.extra_weights[7]);
                land += influence * Q(alien.settings, "nerve_height") * Math.Exp(-Math.Pow(network["trunk_distance"].AsDouble() / 100, 2));
                if (influence > 0 && Q(alien.settings, "nerve_fibre_height") > 0) land += influence * alien.nerve_fibre_relief(new Vector2((float)x, (float)z));
                if (publish)
                {
                    for (int i = 0; i < 7; i++) { var e = last_extras[i]; e.X = (float)(e.X * (1 - influence)); last_extras[i] = e; }
                    var previous = last_extras[7]; last_extras[7] = new Vector4((float)(previous.X + (1 - (double)previous.X) * influence), .5f, (float)C(network["age"].AsDouble()), (float)network["influence"].AsDouble());
                }
            }
        }
        return apply_coast(water_level + land * shore * mult, publish, coast);
    }
    public double water_surface_height(double x, double z)
    { if (!_extrasEnabled && _swamp is null && _mountain is null && _coast is null && _tropical is null && _badlands is null) return water_level; height(x, z); return last_water; }
    public A payload(double h) => new() { h, last_weights, last_surface, last_geology, last_island, last_jungle, last_forest, last_savanna, last_swamp, last_water, last_mountain, last_coast, last_tropical, last_badlands, last_extras, last_badlands_palette, last_badlands_remnant, last_badlands_skirt };
    private double Restore(A p)
    {
        last_weights = p[1].AsVector4(); last_surface = p[2].AsVector2(); last_geology = p[3].AsVector3(); last_island = p[4].AsDouble(); last_jungle = p[5].AsDouble();
        if (_forest is not null) last_forest = p[6].AsFloat32Array(); if (_savanna is not null) last_savanna = p[7].AsFloat32Array();
        if (_swamp is not null) last_swamp = p[8].AsFloat32Array(); if (_mountain is not null) last_mountain = p[10].AsFloat32Array();
        if (_coast is not null) last_coast = p[11].AsVector4(); if (_tropical is not null) last_tropical = p[12].AsVector3();
        if (_badlands is not null) { last_badlands = p[13].AsVector3(); last_badlands_palette = p[15].AsVector4(); last_badlands_remnant = p[16].AsDouble(); last_badlands_skirt = p[17].AsDouble(); }
        if (_extrasEnabled) last_extras = p[14].AsVector4Array();
        if (_swamp is not null || _mountain is not null || _coast is not null || _tropical is not null || _badlands is not null || _extrasEnabled) last_water = p[9].AsDouble();
        return p[0].AsDouble();
    }
    private static bool Exact(double x, double z) => Math.Abs(x) <= 2000000000 && Math.Abs(z) <= 2000000000 && x == Math.Floor(x) && z == Math.Floor(z);
    public double grid_height(double x, double z)
    {
        query_changed = true;
        if (!Exact(x, z) || (!cache_dense_payloads && (((int)x & 31) != 0 || ((int)z & 31) != 0))) return height(x, z);
        var key = new Vector2I((int)x, (int)z); if (height_grid_cache.TryGetValue(key, out var cached)) return Restore(cached.AsGodotArray());
        double h = height(x, z); if (height_grid_cache.Count >= 8192) height_grid_cache.Clear(); height_grid_cache[key] = payload(h); return h;
    }
    public void select_normal_cache_capacity(double chunkSize)
    {
        bool coastalOrganic = coastal_structure_height_cache_enabled && _coast is not null && _extras[7] is not null && chunkSize >= 8192;
        normal_height_cache_capacity = coastalOrganic ? 65536 : 8192; if (normal_height_cache.Count > normal_height_cache_capacity) normal_height_cache.Clear();
    }
    public double normal_height(double x, double z)
    {
        query_changed = false;
        if (!Exact(x, z)) return height(x, z, false); var key = new Vector2I((int)x, (int)z);
        if (height_grid_cache.TryGetValue(key, out var payload)) return payload.AsGodotArray()[0].AsDouble();
        if (normal_height_cache.TryGetValue(key, out var cached)) return cached.AsDouble();
        double h = height(x, z, false); if (normal_height_cache.Count >= normal_height_cache_capacity) normal_height_cache.Clear(); normal_height_cache[key] = h; return h;
    }
}
