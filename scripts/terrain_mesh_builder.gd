extends RefCounted
var _native_mesh=preload("res://scripts/csharp/terrain/TerrainMeshGeometry.cs").new()
var _native_height=preload("res://scripts/csharp/terrain/TerrainHeightField.cs").new()
var _native_grass=preload("res://scripts/csharp/terrain/GrasslandField.cs").new()
var _native_islands=preload("res://scripts/csharp/terrain/TerrainIslands.cs").new()
var _native_regions=preload("res://scripts/csharp/terrain/TerrainRegions.cs").new()
static var AlienTissueCoordinates=preload("res://scripts/csharp/biomes/AlienTissueCoordinates.cs").new()

## Worker-owned sampler: only plain mesh arrays cross back to the main thread.
var chunk_size: float = 256.0
var world_seed: int = 73921
var water_level: float = 0.0
var _island_cache: Dictionary = {}
var _plane_cache: Dictionary = {}
var _owner_cache: Dictionary = {}
var _river_cache: Dictionary = {}
var _river_columns: Dictionary = {}
var _river_cache_spacing:float=INF
var _river_column_spacing:float=INF
var _lake_cache: Dictionary = {}
var _index_templates: Dictionary = {}
var _grass_grid: Dictionary = {}
var _coast_certificates: Dictionary = {}
var _height_grid_cache: Dictionary = {}
var _normal_height_cache: Dictionary = {}
## Worker-only height memo. Coarse coastal organic footings revisit several
## support lattices; their measured workload benefits from a bounded larger
## memo. Near/unrelated tiles retain the original capacity. No payloads or
## GPU resources are stored here; the independent switch restores the limit.
var coastal_structure_height_cache_enabled:bool=true
var _normal_height_cache_capacity:int=8192
var _height_query := false
var _last_precision := 0.0
var settings: Resource = preload("res://config/world/terrain_settings.tres")
# Hierarchical, non-overlapping regions. A large assigned region is never
# subdivided by smaller biomes. Coverage chooses whole regions at each level.
var _region_sizes := PackedFloat64Array()
var _region_enabled: Array[bool] = []
var _coverage := Vector4.ZERO
var _jungle_coverage:float=0
var _mountain_coverage:float=0
var _mountain_probabilities:=PackedFloat64Array()
var _mountain_weight:float=0
var _tropical_coverage:float=0
var _tropical_probabilities:=PackedFloat64Array()
var _tropical_weight:float=0
var _tropical
var _last_tropical:=Vector3.ZERO # weight, wetness, regional material identity
var _badlands_coverage:float=0
var _badlands_probabilities:=PackedFloat64Array()
var _badlands_weight:float=0
var _badlands
var _last_badlands:=Vector3.ZERO
var _last_badlands_palette:=Vector4.ZERO
var _last_badlands_remnant:float=0
var _last_badlands_skirt:float=0
var built_badlands_palette:=PackedByteArray()
var built_badlands_palette_slot:int=-1
const EXTENSION_SCRIPTS=[preload("res://scripts/csharp/biomes/QuarrySampler.cs"),preload("res://scripts/csharp/biomes/WiseMountainsSampler.cs"),preload("res://scripts/csharp/biomes/VolcanicSampler.cs"),preload("res://scripts/csharp/biomes/SporeForestSampler.cs"),preload("res://scripts/csharp/biomes/RadiationWastelandSampler.cs"),preload("res://scripts/csharp/biomes/CrystalWastesSampler.cs"),preload("res://scripts/csharp/biomes/InsectColonySampler.cs"),preload("res://scripts/csharp/biomes/AlienInfectedSampler.cs")]
var _extras:Array=[]
var _extra_coverage:=PackedFloat64Array()
var _extra_probabilities:Array=[]
var _extra_weights:=PackedFloat64Array()
var _last_extras:=PackedVector4Array()
var built_extension_data:=PackedByteArray()
var built_alien_tissue_flow:=PackedByteArray()
var built_alien_tissue_flow_rows:int=0
var built_extension_rows:int=0
var built_extension_mask:int=0
var built_structure_arrays:Array=[]
var _extras_enabled:bool=false
var _coast
var _last_coast:=Vector4.ZERO
var _coast_limit:float=0
var _mountain
var _last_mountain:=PackedFloat32Array([0,0,0,0])
var _jungle_probabilities:=PackedFloat64Array()
var _jungle_weight:float=0
var _jungle
var _last_jungle:float=0 # exact 24-bit wet/drain/weight payload
var _forest
var _forest_neutral:=PackedFloat32Array([0,0,0,0])
var _last_forest:=_forest_neutral
var _savanna
var _last_savanna:=_forest_neutral
var _savanna_gullies:Dictionary={}
var _swamp
var _last_swamp:=_forest_neutral
var _last_swamp_water:float=0
var _level_probabilities: Array[Vector4] = []
var _minimum_region_size: float
var _root_region_size: float
var _region_levels: Array[int] = []
var _label_cache: Dictionary = {}
var _biome_cell_cache: Dictionary = {}
var _warp_large := FastNoiseLite.new()
var _warp_small := FastNoiseLite.new()
var _continent_noise := FastNoiseLite.new()
var _shoreline_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _temperature_period: float
var _temperature_phase: float
var _grass_region := FastNoiseLite.new()
var _grass_macro := FastNoiseLite.new()
var _grass_forms := FastNoiseLite.new()
var _grass_ridges := FastNoiseLite.new()
var _grass_fractal := FastNoiseLite.new()
var _grass_water_noise := FastNoiseLite.new()
var _last_weights := Vector4.ZERO
var _last_island: float = 0.0
var _last_surface := Vector2.ZERO # mountain exposure, drainage/basin influence
var _last_geology := Vector3.ZERO # talus, incised drainage, competent cliff
var profile_build := false
## Test-only reference switch; pruning changes no returned mesh channel.
var prune_unused_halo := true
## Keep sparse Badlands derivative queries beside their centre while raw nodes
## are still hot. The reference switch exists for complete-array parity tests.
var interleave_badlands_normals := true
var cache_dense_payloads := false
var last_build_profile: Dictionary = {}
var field_timings: Dictionary = {}
func _configure_noise() -> void:
	_extras.clear();_extras.resize(8);_extra_coverage.resize(8);_extra_weights.resize(8);_extra_weights.fill(0);_last_extras.resize(8);_last_extras.fill(Vector4.ZERO);_extras_enabled=false
	for i in range(8):
		var k:String=TerrainSettings.EXTENSION_KEYS[i];var config:Resource=settings.get(k)
		_extra_coverage[i]=maxf(settings.get(k+"_coverage"),0)
		if _extra_coverage[i]>0 or (i==7 and config.overlay_strength>0):
			_extras[i]=EXTENSION_SCRIPTS[i].new();_extras[i].configure(config,world_seed,self,i);_extras_enabled=true
	_badlands=null;_badlands_weight=0;_last_badlands=Vector3.ZERO
	if settings.badlands_coverage>0:
		_badlands=preload("res://scripts/csharp/biomes/BadlandsSampler.cs").new();_badlands.configure(settings.badlands,world_seed,self);_badlands.profile=profile_build
	_tropical=null;_tropical_weight=0;_last_tropical=Vector3.ZERO
	if settings.tropical_coverage>0:
		_tropical=preload("res://scripts/csharp/biomes/TropicalSampler.cs").new()
		_tropical.configure(settings.tropical,world_seed,self);_tropical.profile=profile_build
	_coast_limit=0;_last_coast=Vector4.ZERO
	if settings.rocky_coast_enabled or settings.beaches_enabled:
		_coast=preload("res://scripts/csharp/biomes/RockyCoastSampler.cs").new();_coast.configure(settings.rocky_coast,world_seed,self);_coast.profile=profile_build;_coast_limit=_coast.max_width()
		if settings.beaches_enabled:_coast_limit*=2
		if not settings.rocky_coast_enabled:_coast.settings=_coast.settings.duplicate();_coast.settings.coverage=0
	else:_coast=null
	if settings.mountain_coverage>0:
		_mountain=preload("res://scripts/csharp/biomes/MountainSampler.cs").new()
		_mountain.configure(settings.mountain if settings.mountain!=null else preload("res://scripts/csharp/biomes/MountainSettings.cs").new(),world_seed,self)
		_mountain.profile=profile_build
	else:_mountain=null
	_last_mountain=PackedFloat32Array([0,0,0,0]);_mountain_weight=0
	if settings.swamp_coverage>0:
		_swamp=preload("res://scripts/csharp/biomes/SwampSampler.cs").new()
		_swamp.configure(settings.swamp if settings.swamp!=null else preload("res://scripts/csharp/biomes/SwampSettings.cs").new(),world_seed,self)
	else:_swamp=null
	_last_swamp=_forest_neutral;_last_swamp_water=water_level
	if settings.savanna_coverage>0:
		_savanna=preload("res://scripts/csharp/biomes/SavannaSampler.cs").new()
		_savanna.configure(settings.savanna if settings.savanna!=null else preload("res://scripts/csharp/biomes/SavannaSettings.cs").new(),world_seed)
	else:_savanna=null
	_last_savanna=_forest_neutral
	_savanna_gullies.clear()
	if settings.forest_coverage>0:
		_forest=preload("res://scripts/csharp/biomes/ForestSampler.cs").new()
		_forest.configure(settings.forest if settings.forest!=null else preload("res://scripts/csharp/biomes/ForestSettings.cs").new(),world_seed)
	else:_forest=null
	_last_forest=_forest_neutral
	if settings.jungle_coverage>0:
		_jungle=preload("res://scripts/csharp/biomes/JungleSampler.cs").new()
		_jungle.configure(settings.jungle if settings.jungle!=null else JungleSettings.new(),world_seed)
	else:_jungle=null
	_last_jungle=0;_jungle_weight=0
	_island_cache.clear()
	_plane_cache.clear()
	_owner_cache.clear()
	_river_cache.clear()
	_river_columns.clear()
	_river_cache_spacing=INF;_river_column_spacing=INF
	_lake_cache.clear()
	_grass_grid.clear()
	_coast_certificates.clear()
	_height_grid_cache.clear()
	_normal_height_cache.clear()
	_normal_height_cache_capacity=8192
	_setup_noise(_continent_noise, world_seed + 1327, 3.0 / maxf(settings.island_size, 1.0), settings.island_octaves, 0.52)
	_setup_noise(_shoreline_noise, world_seed + 1429, 1.0 / maxf(settings.shoreline_detail_size,50.0), 3, 0.45)
	_native_islands.configure(settings,world_seed,_continent_noise,_shoreline_noise)
	_island_cache=_native_islands.sites_cache;_plane_cache=_native_islands.plane_cache;_owner_cache=_native_islands.owner_cache;_coast_certificates=_native_islands.coast_certificates
	_setup_noise(_detail_noise, world_seed + 307, 1.0 / maxf(settings.grass_hill_size, 1.0), settings.detail_octaves, settings.detail_gain)
	_configure_regions()
	_setup_noise(_grass_region,world_seed+2101,1.0/maxf(settings.grass_landform_size,100.0),1,0.3)
	_setup_noise(_grass_macro,world_seed+2203,1.0/maxf(settings.grass_landform_size*3.0,300.0),2,0.35)
	_setup_noise(_grass_forms,world_seed+2309,1.0/maxf(settings.grass_hill_size*5.0,40.0),2,0.4)
	_setup_noise(_grass_ridges,world_seed+2411,1.0/maxf(settings.grass_foothill_size*1.8,100.0),1,0.45)
	_setup_noise(_grass_fractal,world_seed+2539,1.0/maxf(settings.grass_fractal_size,1.0),clampi(settings.grass_fractal_octaves,1,8),clampf(settings.grass_fractal_gain,0.1,0.75))
	_grass_fractal.fractal_lacunarity = clampf(settings.grass_fractal_lacunarity,1.5,3.0)
	_setup_noise(_grass_water_noise,world_seed+2687,1.0/450.0,3,0.45)
	_native_grass.configure(settings,world_seed,_grass_region,_grass_macro,_grass_forms,_grass_ridges,_grass_fractal,_detail_noise,_grass_water_noise)
	_river_cache=_native_grass.river_cache;_river_columns=_native_grass.river_columns;_lake_cache=_native_grass.lake_cache;_grass_grid=_native_grass.grid_cache
	_native_height.configure(self)
	_height_grid_cache=_native_height.height_grid_cache;_normal_height_cache=_native_height.normal_height_cache;_savanna_gullies=_native_height.savanna_gullies


func _configure_regions() -> void:
	_native_regions.configure(settings,world_seed,_extras_enabled,_extra_coverage)
	_region_sizes=_native_regions.sizes;_region_enabled=_native_regions.enabled;_region_levels=_native_regions.levels;_level_probabilities=_native_regions.probabilities
	_coverage=_native_regions.coverage;_jungle_coverage=_native_regions.jungle_coverage;_mountain_coverage=_native_regions.mountain_coverage;_tropical_coverage=_native_regions.tropical_coverage;_badlands_coverage=_native_regions.badlands_coverage;_extra_coverage=_native_regions.extra_coverage
	_jungle_probabilities=_native_regions.jungle_probabilities;_mountain_probabilities=_native_regions.mountain_probabilities;_tropical_probabilities=_native_regions.tropical_probabilities;_badlands_probabilities=_native_regions.badlands_probabilities;_extra_probabilities=_native_regions.extra_probabilities
	_minimum_region_size=_native_regions.minimum_size;_root_region_size=_native_regions.root_size;_temperature_period=_native_regions.temperature_period;_temperature_phase=_native_regions.temperature_phase
	_warp_large=_native_regions.warp_large;_warp_small=_native_regions.warp_small;_label_cache=_native_regions.label_cache;_biome_cell_cache=_native_regions.cell_cache

func _setup_noise(
	noise: FastNoiseLite,
	noise_seed: int,
	frequency: float,
	octaves: int,
	gain: float
) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = gain


func build(coordinate: Vector2i, resolution: int) -> Array:
	_prepare_height_query()
	_select_normal_height_cache_capacity()
	built_structure_arrays=[]
	var arrays:Array=_native_mesh.build(self,coordinate,resolution)
	built_badlands_palette=_native_mesh.built_badlands_palette;built_badlands_palette_slot=_native_mesh.built_badlands_palette_slot
	built_extension_data=_native_mesh.built_extension_data;built_extension_rows=_native_mesh.built_extension_rows;built_extension_mask=_native_mesh.built_extension_mask
	built_alien_tissue_flow=_native_mesh.built_alien_tissue_flow;built_alien_tissue_flow_rows=_native_mesh.built_alien_tissue_flow_rows
	if profile_build:last_build_profile=_native_mesh.last_build_profile
	_index_templates=_native_mesh.index_templates
	_publish_height_state()
	return arrays

func _indices_for(resolution: int) -> PackedInt32Array:
	var indices:PackedInt32Array=_native_mesh.indices_for(resolution)
	_index_templates=_native_mesh.index_templates
	return indices


func _region_random(x: int, z: int, biome: int, salt: int) -> float:
	return _native_regions.random(x,z,biome,salt,world_seed)

func _warp_region_point(x: float, z: float) -> Vector2:
	return _native_regions.warp_point(x,z)

func _temperature_at_region(p: Vector2) -> float:
	return _native_regions.temperature(p)

func get_temperature(x: float, z: float) -> float:
	return _native_regions.get_temperature(x,z)

func _region_owner(p: Vector2) -> int:
	return _native_regions.owner(p)

func _grid_owner(x: int, z: int, step: float) -> int:
	return _native_regions.grid_owner(x,z,step)

func is_pure_jungle_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,4)

func is_pure_forest_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,1)

func is_pure_savanna_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,2)

func is_pure_swamp_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,3)

func is_pure_mountain_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,5)

func is_pure_tropical_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,6)

func is_pure_badlands_rect(bounds:Rect2)->bool:
	return _native_regions.pure_rect(bounds,7)

func pure_extension_rect(bounds:Rect2)->int:
	return _native_regions.pure_extension_rect(bounds)

func _biome_weights(x: float, z: float) -> Vector4:
	var result:Vector4=_native_regions.weights(x,z)
	_jungle_weight=_native_regions.jungle_weight;_mountain_weight=_native_regions.mountain_weight;_tropical_weight=_native_regions.tropical_weight;_badlands_weight=_native_regions.badlands_weight;_extra_weights=_native_regions.extra_weights
	return result

func _island_pitch() -> float:
	return _native_islands.pitch()

func _island_gap() -> float:
	return _native_islands.gap()

func _island_candidate(cell: Vector2i) -> PackedFloat64Array:
	return _native_islands.candidate(cell)

func _shoreline_detail_offset(x: float, z: float) -> Vector2:
	return _native_islands.shoreline_offset(x,z)

func _island_mask(x: float, z: float) -> float:
	return _native_islands.mask(x,z,_height_query,_coast_limit)

func _remember_coast(cell: Vector2i, point: Vector2, distance: float) -> void:
	_native_islands.remember_coast(cell,point,distance)


func _grass_river_center(x: float, lane: int, spacing: float) -> float:
	_native_grass.river_cache_spacing=_river_cache_spacing
	var value:float=_native_grass.river_center(x,lane,spacing)
	_river_cache_spacing=_native_grass.river_cache_spacing
	return value

func _lake_sites(cell: Vector2i, pitch: float) -> Array[Vector4]:
	var value:Array[Vector4]=_native_grass.lake_sites(cell,pitch)
	_river_cache_spacing=_native_grass.river_cache_spacing
	return value

func _river_column(x: float, lane: int, spacing: float) -> Vector3:
	_native_grass.river_cache_spacing=_river_cache_spacing;_native_grass.river_column_spacing=_river_column_spacing
	var value:Vector3=_native_grass.river_column(x,lane,spacing)
	_river_cache_spacing=_native_grass.river_cache_spacing;_river_column_spacing=_native_grass.river_column_spacing
	return value

func _publish_grass_state() -> void:
	_last_surface=_native_grass.last_surface;_last_geology=_native_grass.last_geology;_last_precision=_native_grass.last_precision
	_river_cache_spacing=_native_grass.river_cache_spacing;_river_column_spacing=_native_grass.river_column_spacing

func _grass_sample(x: float, z: float) -> Vector3:
	_native_grass.profile=profile_build;_native_grass.field_timings=field_timings
	var value:Vector3=_native_grass.sample(x,z)
	_publish_grass_state()
	return value

func _grass_grid_sample(cell: Vector2i, step: float) -> Array:
	_native_grass.profile=profile_build;_native_grass.field_timings=field_timings
	var value:Array=_native_grass.grid_sample(cell,step)
	_publish_grass_state()
	return value

func _grass_sample_raw(x: float, z: float) -> Vector3:
	_native_grass.profile=profile_build;_native_grass.field_timings=field_timings
	var value:Vector3=_native_grass.sample_raw(x,z)
	_publish_grass_state()
	return value

func geographic_identity(x: float,z: float) -> Vector2:
	return _native_grass.geographic_identity(x,z)


func _prepare_height_query() -> void:
	_native_height.water_level=water_level;_native_height.cache_dense_payloads=cache_dense_payloads
	_native_grass.profile=profile_build;_native_grass.field_timings=field_timings

func _publish_height_state() -> void:
	var p:Array=_native_height.payload(0)
	_last_weights=p[1];_last_surface=p[2];_last_geology=p[3];_last_island=p[4];_last_jungle=p[5]
	_last_forest=p[6];_last_savanna=p[7];_last_swamp=p[8];_last_swamp_water=p[9];_last_mountain=p[10]
	_last_coast=p[11];_last_tropical=p[12];_last_badlands=p[13];_last_extras=p[14]
	_last_badlands_palette=p[15];_last_badlands_remnant=p[16];_last_badlands_skirt=p[17]
	_jungle_weight=_native_regions.jungle_weight;_mountain_weight=_native_regions.mountain_weight;_tropical_weight=_native_regions.tropical_weight;_badlands_weight=_native_regions.badlands_weight;_extra_weights=_native_regions.extra_weights
	_last_precision=_native_grass.last_precision;_river_cache_spacing=_native_grass.river_cache_spacing;_river_column_spacing=_native_grass.river_column_spacing

func _sample_grid_height(x: float,z: float) -> float:
	_prepare_height_query()
	var h:float=_native_height.grid_height(x,z)
	_publish_height_state()
	return h

func _select_normal_height_cache_capacity()->void:
	_native_height.coastal_structure_height_cache_enabled=coastal_structure_height_cache_enabled
	_native_height.select_normal_cache_capacity(chunk_size)
	_normal_height_cache_capacity=_native_height.normal_height_cache_capacity

func _sample_normal_height(x: float,z: float) -> float:
	_prepare_height_query()
	var h:float=_native_height.normal_height(x,z)
	if _native_height.query_changed:_publish_height_state()
	return h

func _get_height(world_x:float,world_z:float,publish_controls:bool=true)->float:
	_prepare_height_query()
	var h:float=_native_height.height(world_x,world_z,publish_controls)
	_publish_height_state()
	return h

func _apply_coast(_x:float,_z:float,base:float,_distance:float,publish:bool,c:PackedFloat64Array)->float:
	_native_height.water_level=water_level
	_native_height.set_context(_last_surface,_last_geology,_last_swamp_water)
	var h:float=_native_height.apply_coast(base,publish,c)
	_last_swamp_water=_native_height.last_water
	if publish:_last_coast=_native_height.last_coast
	return h

func _coast_payload(c:PackedFloat64Array)->Vector4:
	return _native_height.coast_payload(c)

func _jungle_height(x:float,z:float,weight:float,publish:bool)->float:
	_native_height.set_context(_last_surface,_last_geology,_last_swamp_water)
	var h:float=_native_height.jungle_height(x,z,weight,publish)
	if publish:_last_jungle=_native_height.last_jungle;_last_geology=_native_height.last_geology
	return h

func _forest_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_native_height.forest_height(x,z,weight,publish)
	if publish:_last_forest=_native_height.last_forest
	return h

func _savanna_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_native_height.savanna_height(x,z,weight,publish)
	if publish:_last_savanna=_native_height.last_savanna
	return h

func _pack_savanna(a:float,b:float,c:float)->float:
	return _native_height.pack(a,b,c)

func _mountain_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_native_height.mountain_height(x,z,weight,publish)
	if publish:_last_mountain=_native_height.last_mountain
	return h

func _tropical_height(x:float,z:float,weight:float,publish:bool)->float:
	_native_height.set_context(_last_surface,_last_geology,_last_swamp_water)
	var h:float=_native_height.tropical_height(x,z,weight,publish)
	if publish:_last_tropical=_native_height.last_tropical;_last_geology=_native_height.last_geology;_last_surface=_native_height.last_surface
	return h

func _swamp_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_native_height.swamp_height(x,z,weight,publish)
	if publish:_last_swamp=_native_height.last_swamp
	return h

func get_water_surface_height(x:float,z:float)->float:
	if not _extras_enabled and _swamp==null and _mountain==null and _coast==null and _tropical==null and _badlands==null:return water_level
	_get_height(x,z)
	return _last_swamp_water

## Worker-only numerical surface; shared indices align water clipping with land.
func build_swamp_water(arrays:Array,resolution:int)->Array:
	return _native_mesh.build_water(self,arrays,resolution)


func _normalized_noise(noise: FastNoiseLite, x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 0.5 + 0.5
