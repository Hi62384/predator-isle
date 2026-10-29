extends Resource
class_name TerrainSettings

## Editable terrain preset. Edit in the Inspector, then restart the game to apply.


@export_group("Biome Regions")
## Global region-size multiplier, not camera zoom. 0.05 makes regions 20x smaller.
@export_range(0.25, 8.0, 0.05, "or_less", "or_greater") var biome_size: float = 1.0
## Target region width in metres. Rounded to hierarchy levels; neighboring same-biome regions can merge.
@export_range(500.0, 20000.0, 100.0, "or_less", "or_greater") var grass_region_size: float = 5000.0
## Relative world-area coverage weight. 0 disables this biome; weights normalize together.
@export_range(0.0, 100.0, 1.0, "or_greater") var grass_coverage: float = 50.0
## Jungle relative coverage, alongside Grass and temperate Forest.
@export_range(0,100,1,"or_greater") var jungle_coverage:float=30
@export_range(500,40000,100,"or_greater") var jungle_region_size:float=7000
## Temperate Forest; zero preserves the previous Grass/Jungle layout exactly.
@export_range(0,100,1,"or_greater") var forest_coverage:float=20
@export_range(500,40000,100,"or_greater") var forest_region_size:float=8000
@export_group("Forest Terrain")
@export var forest:Resource=preload("res://config/biomes/forest_settings.tres")
@export_group("Savanna Terrain")
## Zero restores the pre-Savanna world ownership exactly.
@export_range(0,100,1,"or_greater") var savanna_coverage:float=20
@export_range(500,40000,100,"or_greater") var savanna_region_size:float=10000
@export var savanna:Resource=preload("res://config/biomes/savanna_settings.tres")
@export_group("Swamp Terrain")
## Zero preserves the previous four-biome world exactly.
@export_range(0,100,1,"or_greater") var swamp_coverage:float=20
@export_range(500,40000,100,"or_greater") var swamp_region_size:float=9000
@export var swamp:Resource=preload("res://config/biomes/swamp_settings.tres")
@export_group("Rocky Coast Terrain")
@export var rocky_coast_enabled:bool=true
@export var rocky_coast:Resource=preload("res://config/biomes/rocky_coast_settings.tres")
@export_group("Coastal Dunes and Beaches")
## Zero-cost opt-out for prior coastline presets. Saved world enables it explicitly.
@export var beaches_enabled:bool=false
@export var beach:Resource=preload("res://config/biomes/beach_settings.tres")
@export_group("Mountain Range Terrain")
## Zero restores the pre-Mountain world exactly.
@export_range(0,100,1,"or_greater") var mountain_coverage:float=20
@export_range(1000,60000,100,"or_greater") var mountain_region_size:float=16000
@export var mountain:Resource=preload("res://config/biomes/mountain_settings.tres")
@export_group("Tropical Terrain")
## Opt in explicitly: zero retains all previous ownership and mesh layouts.
@export_range(0,100,1,"or_greater") var tropical_coverage:float=0
@export_range(1000,60000,100,"or_greater") var tropical_region_size:float=14000
@export var tropical:Resource=preload("res://config/biomes/tropical_settings.tres")
@export_group("Badlands Terrain")
## Disabled by default; preserves the seven-owner world exactly.
@export_range(0,100,1,"or_greater") var badlands_coverage:float=0
@export_range(1000,60000,100,"or_greater") var badlands_region_size:float=14000
@export var badlands:Resource=preload("res://config/biomes/badlands_settings.tres")
const EXTENSION_KEYS:Array[String]=["quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"]

@export_group("Additional Biome Regions")
@export_range(0,100,1,"or_greater") var quarry_coverage:float=0
@export_range(1000,60000,500,"or_greater") var quarry_region_size:float=14000
@export var quarry:Resource=preload("res://config/biomes/quarry_settings.tres")
@export_range(0,100,1,"or_greater") var wise_mountains_coverage:float=0
@export_range(1000,60000,500,"or_greater") var wise_mountains_region_size:float=14000
@export var wise_mountains:Resource=preload("res://config/biomes/wise_mountains_settings.tres")
@export_range(0,100,1,"or_greater") var volcanic_coverage:float=0
@export_range(1000,60000,500,"or_greater") var volcanic_region_size:float=14000
@export var volcanic:Resource=preload("res://config/biomes/volcanic_settings.tres")
@export_range(0,100,1,"or_greater") var spore_forest_coverage:float=0
@export_range(1000,60000,500,"or_greater") var spore_forest_region_size:float=14000
@export var spore_forest:Resource=preload("res://config/biomes/spore_forest_settings.tres")
@export_range(0,100,1,"or_greater") var radiation_wasteland_coverage:float=0
@export_range(1000,60000,500,"or_greater") var radiation_wasteland_region_size:float=14000
@export var radiation_wasteland:Resource=preload("res://config/biomes/radiation_wasteland_settings.tres")
@export_range(0,100,1,"or_greater") var crystal_wastes_coverage:float=0
@export_range(1000,60000,500,"or_greater") var crystal_wastes_region_size:float=14000
@export var crystal_wastes:Resource=preload("res://config/biomes/crystal_wastes_settings.tres")
@export_range(0,100,1,"or_greater") var insect_colony_coverage:float=0
@export_range(1000,60000,500,"or_greater") var insect_colony_region_size:float=14000
@export var insect_colony:Resource=preload("res://config/biomes/insect_colony_settings.tres")
@export_range(0,100,1,"or_greater") var alien_infected_coverage:float=0
@export_range(1000,60000,500,"or_greater") var alien_infected_region_size:float=14000
@export var alien_infected:Resource=preload("res://config/biomes/alien_infected_settings.tres")
@export_group("Jungle Terrain")
@export var jungle:JungleSettings=preload("res://config/biomes/jungle_settings.tres")
@export_group("Biome Blending")
## Regional weight sharpness for smoothly blending terrain heights.
@export_range(1.0, 12.0, 0.5, "or_less", "or_greater") var height_blend: float = 4.0
## Higher values shorten the visible material transition.
@export_range(1.0, 20.0, 0.5, "or_less", "or_greater") var texture_blend_sharpness: float = 4.0

@export_group("Temperature")
## Regional temperature field for diagnostics; does not select removed biomes.
@export var temperature_enabled: bool = true
## Climate wavelength in metres before global biome scaling. Automatically kept larger than hot/cold regions.
@export_range(5000.0, 200000.0, 1000.0, "or_greater") var temperature_region_size: float = 24000.0
## Overall world temperature, in degrees Celsius.
@export_range(-30.0, 40.0, 1.0) var average_temperature: float = 14.0
## Regional temperature variation around the average.
@export_range(0.0, 70.0, 1.0) var temperature_variation: float = 48.0

@export_group("Islands and Ocean Floor")
## Typical island scale in metres. Independent of biome and climate scales.
@export_range(200.0, 12000.0, 50.0, "or_less", "or_greater") var island_size: float = 1388.89
## Typical channel width at reference island size 1388.89 m; scales proportionally with Island Size. Individual gaps vary around this value.
@export_range(1.0, 5000.0, 1.0, "or_greater") var island_spacing: float = 250.0
## Random variation of each neighboring island pair's channel width. 0 is uniform, 0.75 gives 25%-175% of typical spacing.
@export_range(0.0, 0.95, 0.05) var island_spacing_variation: float = 0.75
## Variation in the areas assigned to neighboring islands.
@export_range(0.0, 0.7, 0.05) var island_size_variation: float = 0.65
## Scatter island centers to break up regular rows.
@export_range(0.0, 1.0, 0.01) var island_position_jitter: float = 1.0
## Distortion of shared coastlines to create irregular channels.
@export_range(0.0, 0.6, 0.02) var island_coast_irregularity: float = 0.3
## Local shoreline feature wavelength in metres, independent of Island Size.
@export_range(50.0, 2000.0, 10.0, "or_greater") var shoreline_detail_size: float = 350.0
## Local shoreline displacement in metres. Set 0 to disable; capped relative to detail size to limit excessive distortion.
@export_range(0.0, 300.0, 5.0, "or_greater") var shoreline_detail_strength: float = 90.0
## More octaves add coastline detail.
@export_range(1, 6) var island_octaves: int = 4
## Extra coastline erosion above 0.4. Use Island Spacing to change separation.
@export_range(0.2, 0.7, 0.01, "or_less", "or_greater") var land_threshold: float = 0.40
## Shore transition width in reference-radius units (694.445 m), independent of Island Size.
@export_range(0.02, 0.3, 0.01, "or_less", "or_greater") var coast_width: float = 0.13
## Base continental height amplitude in metres.
@export_range(0.0, 500.0, 1.0, "or_less", "or_greater") var land_height: float = 95.0
## Ocean floor depth relative to world zero.
@export_range(1.0, 200.0, 1.0, "or_less", "or_greater") var ocean_depth: float = 24.0
## Seabed roughness amplitude.
@export_range(0.0, 30.0, 0.5, "or_less", "or_greater") var seabed_relief: float = 3.0
## Scales all terrain elevations about world zero.
@export_range(0.1, 5.0, 0.05, "or_less", "or_greater") var height_multiplier: float = 1.0

@export_group("Grass Terrain")
## Large geographic provinces inside Grass, independent of biome/island sizes.
@export_range(6000.0, 80000.0, 1000.0) var grass_geographic_scale: float = 18000.0
## 0 preserves the earlier landform distribution; 1 gives distinct provinces.
@export_range(0.0, 1.0, 0.05) var grass_geographic_variety: float = 1.0
## Horizontal scale of terrain landforms across all biomes, independent of island size and biome coverage. 2 makes hills, mountains and drainage twice as wide.
@export_range(0.25, 8.0, 0.05, "or_greater") var terrain_shape_scale: float = 1.0
## Broad landform-control wavelength, independent of biome and island sizes.
@export_range(1000.0, 20000.0, 100.0) var grass_landform_size: float = 5000.0
@export_range(0.0, 1.0, 0.05) var grass_plains_frequency: float = 0.35
## 1 suppresses almost all local relief on plains, not regional elevation drift.
@export_range(0.0, 1.0, 0.05) var grass_plains_flatness: float = 0.95
@export_range(0.0, 150.0, 1.0) var grass_rolling_strength: float = 35.0
@export_range(0.0, 1.0, 0.05) var grass_hill_frequency: float = 0.55
@export_range(0.0, 1.0, 0.05) var grass_mountain_frequency: float = 0.28
@export_range(0.0, 2000.0, 10.0) var grass_mountain_height: float = 650.0
@export_range(0.0, 1.0, 0.05) var grass_mountain_ruggedness: float = 0.55
@export_range(0.0, 1.0, 0.05) var grass_ridge_strength: float = 0.7
## Broad drainage grooves on mountain flanks; preserves crests and plains.
@export_range(0.0, 1.0, 0.05) var grass_erosion_strength: float = 0.45
## Sharpen plateau margins while retaining smooth tops and blended foothills.
@export_range(0.0, 1.0, 0.05) var grass_escarpment_strength: float = 0.6
@export_range(200.0, 4000.0, 50.0) var grass_foothill_size: float = 1400.0
@export_range(0.0, 1.0, 0.05) var grass_valley_strength: float = 0.8
@export_range(0.0, 1.0, 0.05) var grass_plateau_frequency: float = 0.18
@export_range(0.0, 800.0, 5.0) var grass_plateau_height: float = 240.0
## Horizontal width of the steep wall, independently of the plateau footprint.
@export_range(24.0, 180.0, 2.0) var grass_cliff_width: float = 48.0
## Width of the sloping debris apron below plateau walls.
@export_range(60.0, 600.0, 10.0) var grass_talus_width: float = 240.0
## Sparse drainage cuts through plateau margins. Does not add elevated water.
@export_range(0.0, 1.0, 0.05) var grass_plateau_erosion: float = 0.9
## Depositional relief below cliffs and at drainage exits.
@export_range(0.0, 40.0, 1.0) var grass_talus_relief: float = 16.0
## Canonical structural lattice spacing. Shared by every LOD; larger values trade accuracy for speed.
@export_range(1.0, 8.0, 1.0) var grass_field_spacing: float = 4.0
@export_range(0.0, 200.0, 5.0) var grass_macro_height: float = 75.0
@export_range(0.0, 8.0, 0.1) var grass_local_detail: float = 1.5
## World-scale fractal relief layered onto landforms, not the broad region masks.
@export_range(1, 8) var grass_fractal_octaves: int = 5
## Amplitude retained by each finer octave.
@export_range(0.1, 0.75, 0.05) var grass_fractal_gain: float = 0.5
## Frequency multiplier between successive octaves.
@export_range(1.5, 3.0, 0.1) var grass_fractal_lacunarity: float = 2.0
## Largest detail wavelength before Terrain Shape Scale is applied.
@export_range(50.0, 1500.0, 10.0) var grass_fractal_size: float = 300.0
## Relief amplitude in metres; reduced on plains and plateau tops, amplified on mountains. 0 disables.
@export_range(0.0, 60.0, 1.0) var grass_fractal_strength: float = 12.0
## 0 disables channels; 1 uses a main drainage corridor roughly every 4 km.
@export_range(0.0, 3.0, 0.05) var grass_river_frequency: float = 1.0
@export_range(4.0, 200.0, 1.0) var grass_river_width: float = 32.0
@export_range(1.0, 40.0, 0.5) var grass_river_depth: float = 6.0
@export_range(0.0, 1.0, 0.05) var grass_lake_frequency: float = 0.35
@export_range(30.0, 900.0, 10.0) var grass_lake_size: float = 260.0
@export_range(1.0, 100.0, 1.0) var grass_lake_depth: float = 16.0
## Hill wavelength in metres.
@export_range(20.0, 2000.0, 5.0, "or_less", "or_greater") var grass_hill_size: float = 117.65
## Hill height amplitude.
@export_range(0.0, 100.0, 1.0, "or_less", "or_greater") var grass_hill_height: float = 12.0

@export_group("Terrain Detail")
## Height detail layers.
@export_range(1, 6) var detail_octaves: int = 4
## Strength of successive height detail layers.
@export_range(0.1, 0.8, 0.01, "or_less", "or_greater") var detail_gain: float = 0.48

@export_group("Surface Materials")
## Shared surface tiling: X grass, Y beach/path sand, Z reserved, W exposed rock.
@export var texture_tile_metres: Vector4 = Vector4(1.4, 3.5, 3.0, 4.0)
## Multiplies the ambientCG sand color.
@export var sand_tint: Color = Color(1.0, 0.82, 0.46)
## Surface normal strength.
@export_range(0.0, 2.0, 0.05, "or_less", "or_greater") var normal_strength: float = 0.75
## Normal/roughness textures fade out by this distance.
@export_range(20.0, 1000.0, 10.0, "or_less", "or_greater") var detail_distance: float = 180.0
## Vertical sand band around sea level.
@export_range(0.1, 10.0, 0.1, "or_less", "or_greater") var shore_width: float = 1.5
## Beach sand blend strength.
@export_range(0.0, 1.0, 0.05, "or_less", "or_greater") var shore_strength: float = 0.75
## Slope threshold where exposed rock starts; 0 flat, 1 vertical.
@export_range(0.0, 0.9, 0.01, "or_less", "or_greater") var slope_rock_start: float = 0.08
## Slope threshold for full exposed rock.
@export_range(0.01, 1.0, 0.01, "or_less", "or_greater") var slope_rock_end: float = 0.30
## Dry grass roughness floor, including distant grass.
@export_range(0.5, 1.0, 0.01) var grass_roughness_floor: float = 0.94
@export_range(0.0, 0.5, 0.01) var grass_specular: float = 0.06
## Reduce the grass normal-map relief without weakening cliff rock normals.
@export_range(0.0, 1.0, 0.05) var grass_normal_scale: float = 0.4

@export_group("Water")
## Show or hide the ocean surface.
@export var water_enabled: bool = true
## Wave amplitude multiplier.
@export_range(0.0, 5.0, 0.1, "or_less", "or_greater") var wave_height: float = 1.0
## Wave animation speed multiplier.
@export_range(0.0, 5.0, 0.1, "or_less", "or_greater") var wave_speed: float = 1.0
## Ocean surface roughness.
@export_range(0.02, 1.0, 0.01, "or_less", "or_greater") var water_roughness: float = 0.32
## Water base color.
@export var shallow_color: Color = Color(0.055, 0.19, 0.17)
## Water grazing-angle color.
@export var deep_color: Color = Color(0.025, 0.075, 0.10)
