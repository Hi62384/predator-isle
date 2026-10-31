using Godot;

namespace PredatorIsle.Terrain;

/// <summary>Editable world preset; streaming workers receive independent deep snapshots.</summary>
[Tool, GlobalClass]
public partial class TerrainConfiguration : Resource
{
    [ExportGroup("Canonical terrain changes")]
    // Each entry is (world X, world Z, radius in metres, signed height delta).
    // Replicate the same ordered snapshot to every peer; restart/reconfigure generation to apply it.
    [Export] public Vector4[] terrain_changes{get;set;}=System.Array.Empty<Vector4>();
    public Godot.Collections.Array<string> EXTENSION_KEYS { get; } = new(TerrainBiomeCatalog.ExtensionKeys);
    // Editable terrain preset. Edit in the Inspector, then restart the game to apply.
    [ExportGroup("Biome Regions")]
    // Global region-size multiplier, not camera zoom. 0.05 makes regions 20x smaller.
    [Export(PropertyHint.Range,"0.25,8.0,0.05,or_less,or_greater")]
    public double biome_size { get; set; } = 1.0;
    // Target region width in metres. Rounded to hierarchy levels; neighboring same-biome regions can merge.
    [Export(PropertyHint.Range,"500.0,20000.0,100.0,or_less,or_greater")]
    public double grass_region_size { get; set; } = 5000.0;
    // Relative world-area coverage weight. 0 disables this biome; weights normalize together.
    [Export(PropertyHint.Range,"0.0,100.0,1.0,or_greater")]
    public double grass_coverage { get; set; } = 50.0;
    // Jungle relative coverage, alongside Grass and temperate Forest.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double jungle_coverage { get; set; } = 30;
    [Export(PropertyHint.Range,"500,40000,100,or_greater")]
    public double jungle_region_size { get; set; } = 7000;
    // Temperate Forest; zero preserves the previous Grass/Jungle layout exactly.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double forest_coverage { get; set; } = 20;
    [Export(PropertyHint.Range,"500,40000,100,or_greater")]
    public double forest_region_size { get; set; } = 8000;
    [ExportGroup("Forest Terrain")]
    [Export]
    public Resource forest { get; set; } = GD.Load<Resource>("res://config/biomes/forest_settings.tres");
    [ExportGroup("Savanna Terrain")]
    // Zero restores the pre-Savanna world ownership exactly.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double savanna_coverage { get; set; } = 20;
    [Export(PropertyHint.Range,"500,40000,100,or_greater")]
    public double savanna_region_size { get; set; } = 10000;
    [Export]
    public Resource savanna { get; set; } = GD.Load<Resource>("res://config/biomes/savanna_settings.tres");
    [ExportGroup("Swamp Terrain")]
    // Zero preserves the previous four-biome world exactly.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double swamp_coverage { get; set; } = 20;
    [Export(PropertyHint.Range,"500,40000,100,or_greater")]
    public double swamp_region_size { get; set; } = 9000;
    [Export]
    public Resource swamp { get; set; } = GD.Load<Resource>("res://config/biomes/swamp_settings.tres");
    [ExportGroup("Rocky Coast Terrain")]
    [Export]
    public bool rocky_coast_enabled { get; set; } = true;
    [Export]
    public Resource rocky_coast { get; set; } = GD.Load<Resource>("res://config/biomes/rocky_coast_settings.tres");
    [ExportGroup("Coastal Dunes and Beaches")]
    // Zero-cost opt-out for prior coastline presets. Saved world enables it explicitly.
    [Export]
    public bool beaches_enabled { get; set; } = false;
    [Export]
    public Resource beach { get; set; } = GD.Load<Resource>("res://config/biomes/beach_settings.tres");
    [ExportGroup("Mountain Range Terrain")]
    // Zero restores the pre-Mountain world exactly.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double mountain_coverage { get; set; } = 20;
    [Export(PropertyHint.Range,"1000,60000,100,or_greater")]
    public double mountain_region_size { get; set; } = 16000;
    [Export]
    public Resource mountain { get; set; } = GD.Load<Resource>("res://config/biomes/mountain_settings.tres");
    [ExportGroup("Tropical Terrain")]
    // Opt in explicitly: zero retains all previous ownership and mesh layouts.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double tropical_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,100,or_greater")]
    public double tropical_region_size { get; set; } = 14000;
    [Export]
    public Resource tropical { get; set; } = GD.Load<Resource>("res://config/biomes/tropical_settings.tres");
    [ExportGroup("Badlands Terrain")]
    // Disabled by default; preserves the seven-owner world exactly.
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double badlands_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,100,or_greater")]
    public double badlands_region_size { get; set; } = 14000;
    [Export]
    public Resource badlands { get; set; } = GD.Load<Resource>("res://config/biomes/badlands_settings.tres");
    [ExportGroup("Additional Biome Regions")]
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double quarry_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double quarry_region_size { get; set; } = 14000;
    [Export]
    public Resource quarry { get; set; } = GD.Load<Resource>("res://config/biomes/quarry_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double wise_mountains_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double wise_mountains_region_size { get; set; } = 14000;
    [Export]
    public Resource wise_mountains { get; set; } = GD.Load<Resource>("res://config/biomes/wise_mountains_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double volcanic_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double volcanic_region_size { get; set; } = 14000;
    [Export]
    public Resource volcanic { get; set; } = GD.Load<Resource>("res://config/biomes/volcanic_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double spore_forest_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double spore_forest_region_size { get; set; } = 14000;
    [Export]
    public Resource spore_forest { get; set; } = GD.Load<Resource>("res://config/biomes/spore_forest_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double radiation_wasteland_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double radiation_wasteland_region_size { get; set; } = 14000;
    [Export]
    public Resource radiation_wasteland { get; set; } = GD.Load<Resource>("res://config/biomes/radiation_wasteland_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double crystal_wastes_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double crystal_wastes_region_size { get; set; } = 14000;
    [Export]
    public Resource crystal_wastes { get; set; } = GD.Load<Resource>("res://config/biomes/crystal_wastes_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double insect_colony_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double insect_colony_region_size { get; set; } = 14000;
    [Export]
    public Resource insect_colony { get; set; } = GD.Load<Resource>("res://config/biomes/insect_colony_settings.tres");
    [Export(PropertyHint.Range,"0,100,1,or_greater")]
    public double alien_infected_coverage { get; set; } = 0;
    [Export(PropertyHint.Range,"1000,60000,500,or_greater")]
    public double alien_infected_region_size { get; set; } = 14000;
    [Export]
    public Resource alien_infected { get; set; } = GD.Load<Resource>("res://config/biomes/alien_infected_settings.tres");
    [ExportGroup("Jungle Terrain")]
    [Export]
    public PredatorIsle.Biomes.JungleSettings jungle { get; set; } = GD.Load<PredatorIsle.Biomes.JungleSettings>("res://config/biomes/jungle_settings.tres");
    [ExportGroup("Biome Blending")]
    // Regional weight sharpness for smoothly blending terrain heights.
    [Export(PropertyHint.Range,"1.0,12.0,0.5,or_less,or_greater")]
    public double height_blend { get; set; } = 4.0;
    // Higher values shorten the visible material transition.
    [Export(PropertyHint.Range,"1.0,20.0,0.5,or_less,or_greater")]
    public double texture_blend_sharpness { get; set; } = 4.0;
    [ExportGroup("Temperature")]
    // Regional temperature field for diagnostics; does not select removed biomes.
    [Export]
    public bool temperature_enabled { get; set; } = true;
    // Climate wavelength in metres before global biome scaling. Automatically kept larger than hot/cold regions.
    [Export(PropertyHint.Range,"5000.0,200000.0,1000.0,or_greater")]
    public double temperature_region_size { get; set; } = 24000.0;
    // Overall world temperature, in degrees Celsius.
    [Export(PropertyHint.Range,"-30.0,40.0,1.0")]
    public double average_temperature { get; set; } = 14.0;
    // Regional temperature variation around the average.
    [Export(PropertyHint.Range,"0.0,70.0,1.0")]
    public double temperature_variation { get; set; } = 48.0;
    [ExportGroup("Islands and Ocean Floor")]
    // Typical island scale in metres. Independent of biome and climate scales.
    [Export(PropertyHint.Range,"200.0,12000.0,50.0,or_less,or_greater")]
    public double island_size { get; set; } = 1388.89;
    // Typical channel width at reference island size 1388.89 m; scales proportionally with Island Size. Individual gaps vary around this value.
    [Export(PropertyHint.Range,"1.0,5000.0,1.0,or_greater")]
    public double island_spacing { get; set; } = 250.0;
    // Random variation of each neighboring island pair's channel width. 0 is uniform, 0.75 gives 25%-175% of typical spacing.
    [Export(PropertyHint.Range,"0.0,0.95,0.05")]
    public double island_spacing_variation { get; set; } = 0.75;
    // Variation in the areas assigned to neighboring islands.
    [Export(PropertyHint.Range,"0.0,0.7,0.05")]
    public double island_size_variation { get; set; } = 0.65;
    // Scatter island centers to break up regular rows.
    [Export(PropertyHint.Range,"0.0,1.0,0.01")]
    public double island_position_jitter { get; set; } = 1.0;
    // Distortion of shared coastlines to create irregular channels.
    [Export(PropertyHint.Range,"0.0,0.6,0.02")]
    public double island_coast_irregularity { get; set; } = 0.3;
    // Local shoreline feature wavelength in metres, independent of Island Size.
    [Export(PropertyHint.Range,"50.0,2000.0,10.0,or_greater")]
    public double shoreline_detail_size { get; set; } = 350.0;
    // Local shoreline displacement in metres. Set 0 to disable; capped relative to detail size to limit excessive distortion.
    [Export(PropertyHint.Range,"0.0,300.0,5.0,or_greater")]
    public double shoreline_detail_strength { get; set; } = 90.0;
    // More octaves add coastline detail.
    [Export(PropertyHint.Range,"1,6")]
    public int island_octaves { get; set; } = 4;
    // Extra coastline erosion above 0.4. Use Island Spacing to change separation.
    [Export(PropertyHint.Range,"0.2,0.7,0.01,or_less,or_greater")]
    public double land_threshold { get; set; } = 0.40;
    // Shore transition width in reference-radius units (694.445 m), independent of Island Size.
    [Export(PropertyHint.Range,"0.02,0.3,0.01,or_less,or_greater")]
    public double coast_width { get; set; } = 0.13;
    // Base continental height amplitude in metres.
    [Export(PropertyHint.Range,"0.0,500.0,1.0,or_less,or_greater")]
    public double land_height { get; set; } = 95.0;
    // Ocean floor depth relative to world zero.
    [Export(PropertyHint.Range,"1.0,200.0,1.0,or_less,or_greater")]
    public double ocean_depth { get; set; } = 24.0;
    // Seabed roughness amplitude.
    [Export(PropertyHint.Range,"0.0,30.0,0.5,or_less,or_greater")]
    public double seabed_relief { get; set; } = 3.0;
    // Scales all terrain elevations about world zero.
    [Export(PropertyHint.Range,"0.1,5.0,0.05,or_less,or_greater")]
    public double height_multiplier { get; set; } = 1.0;
    [ExportGroup("Grass Terrain")]
    // Large geographic provinces inside Grass, independent of biome/island sizes.
    [Export(PropertyHint.Range,"6000.0,80000.0,1000.0")]
    public double grass_geographic_scale { get; set; } = 18000.0;
    // 0 preserves the earlier landform distribution; 1 gives distinct provinces.
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_geographic_variety { get; set; } = 1.0;
    // Horizontal scale of terrain landforms across all biomes, independent of island size and biome coverage. 2 makes hills, mountains and drainage twice as wide.
    [Export(PropertyHint.Range,"0.25,8.0,0.05,or_greater")]
    public double terrain_shape_scale { get; set; } = 1.0;
    // Broad landform-control wavelength, independent of biome and island sizes.
    [Export(PropertyHint.Range,"1000.0,20000.0,100.0")]
    public double grass_landform_size { get; set; } = 5000.0;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_plains_frequency { get; set; } = 0.35;
    // 1 suppresses almost all local relief on plains, not regional elevation drift.
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_plains_flatness { get; set; } = 0.95;
    [Export(PropertyHint.Range,"0.0,150.0,1.0")]
    public double grass_rolling_strength { get; set; } = 35.0;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_hill_frequency { get; set; } = 0.55;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_mountain_frequency { get; set; } = 0.28;
    [Export(PropertyHint.Range,"0.0,2000.0,10.0")]
    public double grass_mountain_height { get; set; } = 650.0;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_mountain_ruggedness { get; set; } = 0.55;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_ridge_strength { get; set; } = 0.7;
    // Broad drainage grooves on mountain flanks; preserves crests and plains.
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_erosion_strength { get; set; } = 0.45;
    // Sharpen plateau margins while retaining smooth tops and blended foothills.
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_escarpment_strength { get; set; } = 0.6;
    [Export(PropertyHint.Range,"200.0,4000.0,50.0")]
    public double grass_foothill_size { get; set; } = 1400.0;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_valley_strength { get; set; } = 0.8;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_plateau_frequency { get; set; } = 0.18;
    [Export(PropertyHint.Range,"0.0,800.0,5.0")]
    public double grass_plateau_height { get; set; } = 240.0;
    // Horizontal width of the steep wall, independently of the plateau footprint.
    [Export(PropertyHint.Range,"24.0,180.0,2.0")]
    public double grass_cliff_width { get; set; } = 48.0;
    // Width of the sloping debris apron below plateau walls.
    [Export(PropertyHint.Range,"60.0,600.0,10.0")]
    public double grass_talus_width { get; set; } = 240.0;
    // Sparse drainage cuts through plateau margins. Does not add elevated water.
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_plateau_erosion { get; set; } = 0.9;
    // Depositional relief below cliffs and at drainage exits.
    [Export(PropertyHint.Range,"0.0,40.0,1.0")]
    public double grass_talus_relief { get; set; } = 16.0;
    // Canonical structural lattice spacing. Shared by every LOD; larger values trade accuracy for speed.
    [Export(PropertyHint.Range,"1.0,8.0,1.0")]
    public double grass_field_spacing { get; set; } = 4.0;
    [Export(PropertyHint.Range,"0.0,200.0,5.0")]
    public double grass_macro_height { get; set; } = 75.0;
    [Export(PropertyHint.Range,"0.0,8.0,0.1")]
    public double grass_local_detail { get; set; } = 1.5;
    // World-scale fractal relief layered onto landforms, not the broad region masks.
    [Export(PropertyHint.Range,"1,8")]
    public int grass_fractal_octaves { get; set; } = 5;
    // Amplitude retained by each finer octave.
    [Export(PropertyHint.Range,"0.1,0.75,0.05")]
    public double grass_fractal_gain { get; set; } = 0.5;
    // Frequency multiplier between successive octaves.
    [Export(PropertyHint.Range,"1.5,3.0,0.1")]
    public double grass_fractal_lacunarity { get; set; } = 2.0;
    // Largest detail wavelength before Terrain Shape Scale is applied.
    [Export(PropertyHint.Range,"50.0,1500.0,10.0")]
    public double grass_fractal_size { get; set; } = 300.0;
    // Relief amplitude in metres; reduced on plains and plateau tops, amplified on mountains. 0 disables.
    [Export(PropertyHint.Range,"0.0,60.0,1.0")]
    public double grass_fractal_strength { get; set; } = 12.0;
    // 0 disables channels; 1 uses a main drainage corridor roughly every 4 km.
    [Export(PropertyHint.Range,"0.0,3.0,0.05")]
    public double grass_river_frequency { get; set; } = 1.0;
    [Export(PropertyHint.Range,"4.0,200.0,1.0")]
    public double grass_river_width { get; set; } = 32.0;
    [Export(PropertyHint.Range,"1.0,40.0,0.5")]
    public double grass_river_depth { get; set; } = 6.0;
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_lake_frequency { get; set; } = 0.35;
    [Export(PropertyHint.Range,"30.0,900.0,10.0")]
    public double grass_lake_size { get; set; } = 260.0;
    [Export(PropertyHint.Range,"1.0,100.0,1.0")]
    public double grass_lake_depth { get; set; } = 16.0;
    // Hill wavelength in metres.
    [Export(PropertyHint.Range,"20.0,2000.0,5.0,or_less,or_greater")]
    public double grass_hill_size { get; set; } = 117.65;
    // Hill height amplitude.
    [Export(PropertyHint.Range,"0.0,100.0,1.0,or_less,or_greater")]
    public double grass_hill_height { get; set; } = 12.0;
    [ExportGroup("Terrain Detail")]
    // Height detail layers.
    [Export(PropertyHint.Range,"1,6")]
    public int detail_octaves { get; set; } = 4;
    // Strength of successive height detail layers.
    [Export(PropertyHint.Range,"0.1,0.8,0.01,or_less,or_greater")]
    public double detail_gain { get; set; } = 0.48;
    [ExportGroup("Surface Materials")]
    // Shared surface tiling: X grass, Y beach/path sand, Z reserved, W exposed rock.
    [Export]
    public Vector4 texture_tile_metres { get; set; } = new Vector4((float)(1.4),(float)(3.5),(float)(3.0),(float)(4.0));
    // Multiplies the ambientCG sand color.
    [Export]
    public Color sand_tint { get; set; } = new Color((float)(1.0),(float)(0.82),(float)(0.46));
    // Surface normal strength.
    [Export(PropertyHint.Range,"0.0,2.0,0.05,or_less,or_greater")]
    public double normal_strength { get; set; } = 0.75;
    // Normal/roughness textures fade out by this distance.
    [Export(PropertyHint.Range,"20.0,1000.0,10.0,or_less,or_greater")]
    public double detail_distance { get; set; } = 180.0;
    // Vertical sand band around sea level.
    [Export(PropertyHint.Range,"0.1,10.0,0.1,or_less,or_greater")]
    public double shore_width { get; set; } = 1.5;
    // Beach sand blend strength.
    [Export(PropertyHint.Range,"0.0,1.0,0.05,or_less,or_greater")]
    public double shore_strength { get; set; } = 0.75;
    // Slope threshold where exposed rock starts; 0 flat, 1 vertical.
    [Export(PropertyHint.Range,"0.0,0.9,0.01,or_less,or_greater")]
    public double slope_rock_start { get; set; } = 0.08;
    // Slope threshold for full exposed rock.
    [Export(PropertyHint.Range,"0.01,1.0,0.01,or_less,or_greater")]
    public double slope_rock_end { get; set; } = 0.30;
    // Dry grass roughness floor, including distant grass.
    [Export(PropertyHint.Range,"0.5,1.0,0.01")]
    public double grass_roughness_floor { get; set; } = 0.94;
    [Export(PropertyHint.Range,"0.0,0.5,0.01")]
    public double grass_specular { get; set; } = 0.06;
    // Reduce the grass normal-map relief without weakening cliff rock normals.
    [Export(PropertyHint.Range,"0.0,1.0,0.05")]
    public double grass_normal_scale { get; set; } = 0.4;
    [ExportGroup("Water")]
    // Show or hide the ocean surface.
    [Export]
    public bool water_enabled { get; set; } = true;
    // Wave amplitude multiplier.
    [Export(PropertyHint.Range,"0.0,5.0,0.1,or_less,or_greater")]
    public double wave_height { get; set; } = 1.0;
    // Wave animation speed multiplier.
    [Export(PropertyHint.Range,"0.0,5.0,0.1,or_less,or_greater")]
    public double wave_speed { get; set; } = 1.0;
    // Ocean surface roughness.
    [Export(PropertyHint.Range,"0.02,1.0,0.01,or_less,or_greater")]
    public double water_roughness { get; set; } = 0.32;
    // Water base color.
    [Export]
    public Color shallow_color { get; set; } = new Color((float)(0.055),(float)(0.19),(float)(0.17));
    // Water grazing-angle color.
    [Export]
    public Color deep_color { get; set; } = new Color((float)(0.025),(float)(0.075),(float)(0.10));
}
