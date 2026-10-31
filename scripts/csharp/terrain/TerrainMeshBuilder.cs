using Godot;
using System;
using PredatorIsle.Biomes;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Worker-owned terrain builder. Scene objects and GPU resources stay on the main thread.</summary>
public partial class TerrainMeshBuilder : RefCounted
{
    public TerrainHeightField _native_height { get; } = new();
    public GrasslandField _native_grass { get; } = new();
    public TerrainIslands _native_islands { get; } = new();
    public TerrainRegions _native_regions { get; } = new();
    public TerrainMeshGeometry _native_mesh { get; } = new();
    public double chunk_size { get; set; } = 256;
    public long world_seed { get; set; } = 73921;
    public double water_level { get; set; }
    public Resource settings { get; set; } = GD.Load<Resource>("res://config/world/terrain_settings.tres");
    public bool profile_build { get; set; }
    public bool prune_unused_halo { get; set; } = true;
    public bool interleave_badlands_normals { get; set; } = true;
    public bool cache_dense_payloads { get; set; }
    public bool coastal_structure_height_cache_enabled { get; set; } = true;
    public bool _height_query { get; set; }
    internal Func<Vector2,bool>? RingOwns;
    internal void PrepareRing()=>Prepare();
    public bool _extras_enabled { get; set; }
    public double _coast_limit { get; set; }
    public A _extras { get; set; } = new();
    public JungleSampler? _jungle { get; set; }
    public ForestSampler? _forest { get; set; }
    public SavannaSampler? _savanna { get; set; }
    public SwampSampler? _swamp { get; set; }
    public MountainSampler? _mountain { get; set; }
    public RockyCoastSampler? _coast { get; set; }
    public TropicalSampler? _tropical { get; set; }
    public BadlandsSampler? _badlands { get; set; }
    public FastNoiseLite _continent_noise { get; } = new();
    public FastNoiseLite _shoreline_noise { get; } = new();
    public FastNoiseLite _detail_noise { get; } = new();
    public FastNoiseLite _grass_region { get; } = new();
    public FastNoiseLite _grass_macro { get; } = new();
    public FastNoiseLite _grass_forms { get; } = new();
    public FastNoiseLite _grass_ridges { get; } = new();
    public FastNoiseLite _grass_fractal { get; } = new();
    public FastNoiseLite _grass_water_noise { get; } = new();
    public FastNoiseLite _warp_large => _native_regions.warp_large;
    public FastNoiseLite _warp_small => _native_regions.warp_small;
    public D field_timings { get; set; } = new();
    public D last_build_profile => _native_mesh.last_build_profile;
    public A built_structure_arrays { get; set; } = new();
    public byte[] built_badlands_palette => _native_mesh.built_badlands_palette;
    public int built_badlands_palette_slot => _native_mesh.built_badlands_palette_slot;
    public byte[] built_extension_data => _native_mesh.built_extension_data;
    public int built_extension_rows => _native_mesh.built_extension_rows;
    public int built_extension_mask => _native_mesh.built_extension_mask;
    public byte[] built_alien_tissue_flow => _native_mesh.built_alien_tissue_flow;
    public int built_alien_tissue_flow_rows => _native_mesh.built_alien_tissue_flow_rows;
    public D _island_cache => _native_islands.sites_cache;
    public D _plane_cache => _native_islands.plane_cache;
    public D _owner_cache => _native_islands.owner_cache;
    public D _coast_certificates => _native_islands.coast_certificates;
    public D _river_cache => _native_grass.river_cache;
    public D _river_columns => _native_grass.river_columns;
    public D _lake_cache => _native_grass.lake_cache;
    public D _grass_grid => _native_grass.grid_cache;
    public D _height_grid_cache => _native_height.height_grid_cache;
    public D _normal_height_cache => _native_height.normal_height_cache;
    public D _savanna_gullies => _native_height.savanna_gullies;
    public D _index_templates => _native_mesh.index_templates;
    public D _label_cache => _native_regions.label_cache;
    public D _biome_cell_cache => _native_regions.cell_cache;
    public double _river_cache_spacing { get => _native_grass.river_cache_spacing; set => _native_grass.river_cache_spacing = value; }
    public double _river_column_spacing { get => _native_grass.river_column_spacing; set => _native_grass.river_column_spacing = value; }
    public int _normal_height_cache_capacity => _native_height.normal_height_cache_capacity;
    public double _last_precision => _native_grass.last_precision;
    public Vector4 _last_weights => _native_height.last_weights;
    public Vector2 _last_surface => _native_height.last_surface;
    public Vector3 _last_geology => _native_height.last_geology;
    public double _last_island => _native_height.last_island;
    public double _last_jungle => _native_height.last_jungle;
    public float[] _forest_neutral { get; } = new float[4];
    public float[] _last_forest => _native_height.last_forest;
    public float[] _last_savanna => _native_height.last_savanna;
    public float[] _last_swamp => _native_height.last_swamp;
    public float[] _last_mountain => _native_height.last_mountain;
    public Vector4 _last_coast => _native_height.last_coast;
    public Vector3 _last_tropical => _native_height.last_tropical;
    public Vector3 _last_badlands => _native_height.last_badlands;
    public Vector4 _last_badlands_palette => _native_height.last_badlands_palette;
    public double _last_badlands_remnant => _native_height.last_badlands_remnant;
    public double _last_badlands_skirt => _native_height.last_badlands_skirt;
    public double _last_swamp_water => _native_height.last_water;
    public Vector4[] _last_extras => _native_height.last_extras;
    public double[] _region_sizes => _native_regions.sizes;
    public Godot.Collections.Array<bool> _region_enabled => _native_regions.enabled;
    public Godot.Collections.Array<int> _region_levels => _native_regions.levels;
    public Godot.Collections.Array<Vector4> _level_probabilities => _native_regions.probabilities;
    public Vector4 _coverage => _native_regions.coverage;
    public double _minimum_region_size => _native_regions.minimum_size;
    public double _root_region_size => _native_regions.root_size;
    public double _temperature_period => _native_regions.temperature_period;
    public double _temperature_phase => _native_regions.temperature_phase;
    public double _jungle_coverage => _native_regions.jungle_coverage;
    public double _mountain_coverage => _native_regions.mountain_coverage;
    public double _tropical_coverage => _native_regions.tropical_coverage;
    public double _badlands_coverage => _native_regions.badlands_coverage;
    public double[] _extra_coverage { get; set; } = new double[8];
    public double[] _jungle_probabilities => _native_regions.jungle_probabilities;
    public double[] _mountain_probabilities => _native_regions.mountain_probabilities;
    public double[] _tropical_probabilities => _native_regions.tropical_probabilities;
    public double[] _badlands_probabilities => _native_regions.badlands_probabilities;
    public A _extra_probabilities => _native_regions.extra_probabilities;
    public double _jungle_weight => _native_regions.jungle_weight;
    public double _mountain_weight => _native_regions.mountain_weight;
    public double _tropical_weight => _native_regions.tropical_weight;
    public double _badlands_weight => _native_regions.badlands_weight;
    public double[] _extra_weights => _native_regions.extra_weights;
    private double P(string key) => settings.Get(key).AsDouble();
    private bool B(string key) => settings.Get(key).AsBool();
    private Resource R(string key) => settings.Get(key).AsGodotObject() as Resource ?? key switch
    {
        "mountain" => new MountainSettings(), "forest" => new ForestSettings(), "savanna" => new SavannaSettings(),
        "swamp" => new SwampSettings(), "rocky_coast" => new RockyCoastSettings(), "beach" => new BeachSettings(),
        "tropical" => new TropicalSettings(), "badlands" => new BadlandsSettings(),
        "jungle" => new JungleSettings(),
        _ => new BiomeExtensionSettings()
    };
    public void _setup_noise(FastNoiseLite noise, long seed, double frequency, int octaves, double gain)
    {
        noise.Seed = unchecked((int)seed); noise.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth; noise.Frequency = (float)frequency;
        noise.FractalType = FastNoiseLite.FractalTypeEnum.Fbm; noise.FractalOctaves = octaves; noise.FractalGain = (float)gain;
    }
    public void _configure_regions()
    { _native_regions.configure(settings, world_seed, _extras_enabled, _extra_coverage); _extra_coverage = _native_regions.extra_coverage; }
    public void _configure_noise()
    {
        _extras.Clear(); _extras.Resize(8); _extra_coverage = new double[8]; _extras_enabled = false;
        for (int i = 0; i < 8; i++)
        {
            string key = TerrainBiomeCatalog.ExtensionKeys[i]; var config = R(key); _extra_coverage[i] = Math.Max(P(key + "_coverage"), 0);
            if (_extra_coverage[i] <= 0 && !(i == 7 && config.Get("overlay_strength").AsDouble() > 0)) continue;
            BiomeExtensionSampler sampler = i switch { 0 => new QuarrySampler(), 1 => new WiseMountainsSampler(), 2 => new VolcanicSampler(), 3 => new SporeForestSampler(), 4 => new RadiationWastelandSampler(), 5 => new CrystalWastesSampler(), 6 => new InsectColonySampler(), _ => new AlienInfectedSampler() };
            sampler.configure(config, world_seed, this, i); _extras[i] = sampler; _extras_enabled = true;
        }
        _badlands = null; if (P("badlands_coverage") > 0) { _badlands = new BadlandsSampler(); _badlands.configure(R("badlands"), world_seed, this); _badlands.profile = profile_build; }
        _tropical = null; if (P("tropical_coverage") > 0) { _tropical = new TropicalSampler(); _tropical.configure(R("tropical"), world_seed, this); _tropical.profile = profile_build; }
        _coast = null; _coast_limit = 0;
        if (B("rocky_coast_enabled") || B("beaches_enabled"))
        {
            var coastSettings=R("rocky_coast");
            if(!B("rocky_coast_enabled")){coastSettings=coastSettings.Duplicate();coastSettings.Set("coverage",0);}
            _coast = new RockyCoastSampler(); _coast.configure(coastSettings, world_seed, this); _coast.profile = profile_build; _coast_limit = _coast.max_width();
            if (B("beaches_enabled")) _coast_limit *= 2;
        }
        _mountain = null; if (P("mountain_coverage") > 0) { _mountain = new MountainSampler(); _mountain.configure(R("mountain"), world_seed, this); _mountain.profile = profile_build; }
        _swamp = null; if (P("swamp_coverage") > 0) { _swamp = new SwampSampler(); _swamp.configure(R("swamp"), world_seed, this); }
        _savanna = null; if (P("savanna_coverage") > 0) { _savanna = new SavannaSampler(); _savanna.configure(R("savanna"), world_seed); }
        _forest = null; if (P("forest_coverage") > 0) { _forest = new ForestSampler(); _forest.configure(R("forest"), world_seed); }
        _jungle = null; if (P("jungle_coverage") > 0) { _jungle = new JungleSampler(); _jungle.configure(R("jungle"), world_seed); }
        _setup_noise(_continent_noise, world_seed + 1327, 3 / Math.Max(P("island_size"), 1), (int)P("island_octaves"), .52);
        _setup_noise(_shoreline_noise, world_seed + 1429, 1 / Math.Max(P("shoreline_detail_size"), 50), 3, .45);
        _native_islands.configure(settings, world_seed, _continent_noise, _shoreline_noise);
        _setup_noise(_detail_noise, world_seed + 307, 1 / Math.Max(P("grass_hill_size"), 1), (int)P("detail_octaves"), P("detail_gain"));
        _configure_regions();
        _setup_noise(_grass_region, world_seed + 2101, 1 / Math.Max(P("grass_landform_size"), 100), 1, .3);
        _setup_noise(_grass_macro, world_seed + 2203, 1 / Math.Max(P("grass_landform_size") * 3, 300), 2, .35);
        _setup_noise(_grass_forms, world_seed + 2309, 1 / Math.Max(P("grass_hill_size") * 5, 40), 2, .4);
        _setup_noise(_grass_ridges, world_seed + 2411, 1 / Math.Max(P("grass_foothill_size") * 1.8, 100), 1, .45);
        _setup_noise(_grass_fractal, world_seed + 2539, 1 / Math.Max(P("grass_fractal_size"), 1), Math.Clamp((int)P("grass_fractal_octaves"), 1, 8), Math.Clamp(P("grass_fractal_gain"), .1, .75));
        _grass_fractal.FractalLacunarity = (float)Math.Clamp(P("grass_fractal_lacunarity"), 1.5, 3);
        _setup_noise(_grass_water_noise, world_seed + 2687, 1.0 / 450, 3, .45);
        _native_grass.configure(settings, world_seed, _grass_region, _grass_macro, _grass_forms, _grass_ridges, _grass_fractal, _detail_noise, _grass_water_noise);
        _native_height.configure(this);
    }
    private void Prepare()
    {
        _native_height.water_level = water_level; _native_height.cache_dense_payloads = cache_dense_payloads;
        _native_height.coastal_structure_height_cache_enabled = coastal_structure_height_cache_enabled;
        _native_grass.profile = profile_build; _native_grass.field_timings = field_timings;
    }
    public A build(Vector2I coordinate, int resolution) { Prepare(); built_structure_arrays = new A(); return _native_mesh.build(this, coordinate, resolution); }
    public A build_swamp_water(A arrays, int resolution) => _native_mesh.build_water(this, arrays, resolution);
    public int[] _indices_for(int resolution) => _native_mesh.indices_for(resolution);
    public double _region_random(long x, long z, long biome, long salt) => _native_regions.random(x, z, biome, salt, world_seed);
    public Vector2 _warp_region_point(double x, double z) => _native_regions.warp_point(x, z);
    public double _temperature_at_region(Vector2 p) => _native_regions.temperature(p);
    public double get_temperature(double x, double z) => _native_regions.get_temperature(x, z);
    public int _region_owner(Vector2 p) => _native_regions.owner(p);
    public int _grid_owner(long x, long z, double step) => _native_regions.grid_owner(x, z, step);
    public bool is_pure_jungle_rect(Rect2 b) => _native_regions.pure_rect(b, 4);
    public bool is_pure_forest_rect(Rect2 b) => _native_regions.pure_rect(b, 1);
    public bool is_pure_savanna_rect(Rect2 b) => _native_regions.pure_rect(b, 2);
    public bool is_pure_swamp_rect(Rect2 b) => _native_regions.pure_rect(b, 3);
    public bool is_pure_mountain_rect(Rect2 b) => _native_regions.pure_rect(b, 5);
    public bool is_pure_tropical_rect(Rect2 b) => _native_regions.pure_rect(b, 6);
    public bool is_pure_badlands_rect(Rect2 b) => _native_regions.pure_rect(b, 7);
    public int pure_extension_rect(Rect2 b) => _native_regions.pure_extension_rect(b);
    public Vector4 _biome_weights(double x, double z) => _native_regions.weights(x, z);
    public double _island_pitch() => _native_islands.pitch();
    public double _island_gap() => _native_islands.gap();
    public double[] _island_candidate(Vector2I cell) => _native_islands.candidate(cell);
    public Vector2 _shoreline_detail_offset(double x, double z) => _native_islands.shoreline_offset(x, z);
    public double _island_mask(double x, double z) => _native_islands.mask(x, z, _height_query, _coast_limit);
    public void _remember_coast(Vector2I cell, Vector2 p, double distance) => _native_islands.remember_coast(cell, p, distance);
    public double _grass_river_center(double x, long lane, double spacing) => _native_grass.river_center(x, lane, spacing);
    public Godot.Collections.Array<Vector4> _lake_sites(Vector2I cell, double pitch) => _native_grass.lake_sites(cell, pitch);
    public Vector3 _river_column(double x, long lane, double spacing) => _native_grass.river_column(x, lane, spacing);
    public Vector3 _grass_sample(double x, double z) { Prepare(); var p = _native_grass.sample(x, z); _native_height.set_context(_native_grass.last_surface, _native_grass.last_geology, _last_swamp_water); return p; }
    public Vector3 _grass_sample_raw(double x, double z) { Prepare(); var p = _native_grass.sample_raw(x, z); _native_height.set_context(_native_grass.last_surface, _native_grass.last_geology, _last_swamp_water); return p; }
    public A _grass_grid_sample(Vector2I cell, double step) { Prepare(); return _native_grass.grid_sample(cell, step); }
    public Vector2 geographic_identity(double x, double z) => _native_grass.geographic_identity(x, z);
    public double _sample_grid_height(double x, double z) { Prepare(); return _native_height.grid_height(x, z); }
    public void _select_normal_height_cache_capacity() { Prepare(); _native_height.select_normal_cache_capacity(chunk_size); }
    public double _sample_normal_height(double x, double z) { Prepare(); return _native_height.normal_height(x, z); }
    public double _get_height(double x, double z) => _get_height(x, z, true);
    public double _get_height(double x, double z, bool publish) { Prepare(); return _native_height.height(x, z, publish); }
    public double _apply_coast(double x, double z, double h, double distance, bool publish, double[] c) { Prepare(); return _native_height.apply_coast(h, publish, c); }
    public Vector4 _coast_payload(double[] c) => _native_height.coast_payload(c);
    public double _jungle_height(double x, double z, double w, bool publish) => _native_height.jungle_height(x, z, w, publish);
    public double _forest_height(double x, double z, double w, bool publish) => _native_height.forest_height(x, z, w, publish);
    public double _savanna_height(double x, double z, double w, bool publish) => _native_height.savanna_height(x, z, w, publish);
    public double _mountain_height(double x, double z, double w, bool publish) => _native_height.mountain_height(x, z, w, publish);
    public double _tropical_height(double x, double z, double w, bool publish) => _native_height.tropical_height(x, z, w, publish);
    public double _swamp_height(double x, double z, double w, bool publish) => _native_height.swamp_height(x, z, w, publish);
    public double _pack_savanna(double a, double b, double c) => _native_height.pack(a, b, c);
    public double get_water_surface_height(double x, double z) { Prepare(); return _native_height.water_surface_height(x, z); }
    public double _normalized_noise(FastNoiseLite noise, double x, double z) => noise.GetNoise2D((float)x, (float)z) * .5 + .5;
}
