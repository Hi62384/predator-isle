extends RefCounted

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
var settings: TerrainSettings = preload("res://config/world/terrain_settings.tres")
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
const EXTENSION_SCRIPTS=[preload("res://scripts/quarry_sampler.gd"),preload("res://scripts/wise_mountains_sampler.gd"),preload("res://scripts/volcanic_sampler.gd"),preload("res://scripts/spore_forest_sampler.gd"),preload("res://scripts/radiation_wasteland_sampler.gd"),preload("res://scripts/crystal_wastes_sampler.gd"),preload("res://scripts/insect_colony_sampler.gd"),preload("res://scripts/alien_infected_sampler.gd")]
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
		_badlands=preload("res://scripts/badlands_sampler.gd").new();_badlands.configure(settings.badlands,world_seed,self);_badlands.profile=profile_build
	_tropical=null;_tropical_weight=0;_last_tropical=Vector3.ZERO
	if settings.tropical_coverage>0:
		_tropical=preload("res://scripts/tropical_sampler.gd").new()
		_tropical.configure(settings.tropical,world_seed,self);_tropical.profile=profile_build
	_coast_limit=0;_last_coast=Vector4.ZERO
	if settings.rocky_coast_enabled or settings.beaches_enabled:
		_coast=preload("res://scripts/rocky_coast_sampler.gd").new();_coast.configure(settings.rocky_coast,world_seed,self);_coast.profile=profile_build;_coast_limit=_coast.max_width()
		if settings.beaches_enabled:_coast_limit*=2
		if not settings.rocky_coast_enabled:_coast.settings=_coast.settings.duplicate();_coast.settings.coverage=0
	else:_coast=null
	if settings.mountain_coverage>0:
		_mountain=preload("res://scripts/mountain_sampler.gd").new()
		_mountain.configure(settings.mountain if settings.mountain!=null else preload("res://scripts/mountain_settings.gd").new(),world_seed,self)
		_mountain.profile=profile_build
	else:_mountain=null
	_last_mountain=PackedFloat32Array([0,0,0,0]);_mountain_weight=0
	if settings.swamp_coverage>0:
		_swamp=preload("res://scripts/swamp_sampler.gd").new()
		_swamp.configure(settings.swamp if settings.swamp!=null else preload("res://scripts/swamp_settings.gd").new(),world_seed,self)
	else:_swamp=null
	_last_swamp=_forest_neutral;_last_swamp_water=water_level
	if settings.savanna_coverage>0:
		_savanna=preload("res://scripts/savanna_sampler.gd").new()
		_savanna.configure(settings.savanna if settings.savanna!=null else preload("res://scripts/savanna_settings.gd").new(),world_seed)
	else:_savanna=null
	_last_savanna=_forest_neutral
	_savanna_gullies.clear()
	if settings.forest_coverage>0:
		_forest=preload("res://scripts/forest_sampler.gd").new()
		_forest.configure(settings.forest if settings.forest!=null else preload("res://scripts/forest_settings.gd").new(),world_seed)
	else:_forest=null
	_last_forest=_forest_neutral
	if settings.jungle_coverage>0:
		_jungle=preload("res://scripts/jungle_sampler.gd").new()
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
	_setup_noise(_detail_noise, world_seed + 307, 1.0 / maxf(settings.grass_hill_size, 1.0), settings.detail_octaves, settings.detail_gain)
	_configure_regions()
	_setup_noise(_grass_region,world_seed+2101,1.0/maxf(settings.grass_landform_size,100.0),1,0.3)
	_setup_noise(_grass_macro,world_seed+2203,1.0/maxf(settings.grass_landform_size*3.0,300.0),2,0.35)
	_setup_noise(_grass_forms,world_seed+2309,1.0/maxf(settings.grass_hill_size*5.0,40.0),2,0.4)
	_setup_noise(_grass_ridges,world_seed+2411,1.0/maxf(settings.grass_foothill_size*1.8,100.0),1,0.45)
	_setup_noise(_grass_fractal,world_seed+2539,1.0/maxf(settings.grass_fractal_size,1.0),clampi(settings.grass_fractal_octaves,1,8),clampf(settings.grass_fractal_gain,0.1,0.75))
	_grass_fractal.fractal_lacunarity = clampf(settings.grass_fractal_lacunarity,1.5,3.0)
	_setup_noise(_grass_water_noise,world_seed+2687,1.0/450.0,3,0.45)


func _configure_regions() -> void:
	_region_sizes.clear()
	_region_enabled.clear()
	_region_levels.clear()
	_level_probabilities.clear()
	_label_cache.clear()
	_biome_cell_cache.clear()
	var sizes := [settings.grass_region_size,settings.forest_region_size if settings.forest_coverage>0 else settings.grass_region_size,settings.savanna_region_size if settings.savanna_coverage>0 else settings.grass_region_size,settings.swamp_region_size if settings.swamp_coverage>0 else settings.grass_region_size]
	_coverage = Vector4(maxf(settings.grass_coverage,0),maxf(settings.forest_coverage,0),maxf(settings.savanna_coverage,0),maxf(settings.swamp_coverage,0))
	var total := _coverage.x + _coverage.y + _coverage.z + _coverage.w
	_jungle_coverage=maxf(settings.jungle_coverage,0)
	_mountain_coverage=maxf(settings.mountain_coverage,0)
	_tropical_coverage=maxf(settings.tropical_coverage,0)
	_badlands_coverage=maxf(settings.badlands_coverage,0)
	total+=_jungle_coverage+_mountain_coverage+_tropical_coverage+_badlands_coverage
	for amount:float in _extra_coverage:total+=amount
	if total <= 0.0:
		_coverage = Vector4(1,0,0,0)
	else:
		_coverage /= total
		_jungle_coverage/=total
		_mountain_coverage/=total
		_tropical_coverage/=total
		_badlands_coverage/=total
		for i in range(8):_extra_coverage[i]/=total
	if _jungle_coverage>0 or _mountain_coverage>0 or _tropical_coverage>0 or _badlands_coverage>0:sizes.append(settings.jungle_region_size if _jungle_coverage>0 else settings.grass_region_size)
	if _mountain_coverage>0 or _tropical_coverage>0 or _badlands_coverage>0:sizes.append(settings.mountain_region_size if _mountain_coverage>0 else settings.grass_region_size)
	if _tropical_coverage>0 or _badlands_coverage>0:sizes.append(settings.tropical_region_size if _tropical_coverage>0 else settings.grass_region_size)
	if _badlands_coverage>0:sizes.append(settings.badlands_region_size)
	if _extras_enabled:
		while sizes.size()<8:sizes.append(settings.grass_region_size)
		for k:String in TerrainSettings.EXTENSION_KEYS:sizes.append(settings.get(k+"_region_size"))
	var biome_count:int=sizes.size()
	_minimum_region_size = INF
	for i in range(biome_count):
		var size: float = maxf(float(sizes[i]) * maxf(settings.biome_size,0.001), 16.0)
		_region_sizes.append(size)
		_region_enabled.append((_coverage[i] if i<4 else (_jungle_coverage if i==4 else (_mountain_coverage if i==5 else (_tropical_coverage if i==6 else (_badlands_coverage if i==7 else _extra_coverage[i-8])))))>0)
		if _region_enabled[i]:
			_minimum_region_size = minf(_minimum_region_size, size)
	var top_level := 0
	for i in range(biome_count):
		var level := maxi(0, roundi(log(_region_sizes[i] / _minimum_region_size) / log(2.0)))
		_region_levels.append(level)
		if _region_enabled[i]:
			top_level = maxi(top_level, level)
	_root_region_size = _minimum_region_size * pow(2.0,top_level)
	_level_probabilities.resize(top_level + 1)
	_jungle_probabilities.resize(top_level+1);_jungle_probabilities.fill(0)
	_mountain_probabilities.resize(top_level+1);_mountain_probabilities.fill(0)
	_tropical_probabilities.resize(top_level+1);_tropical_probabilities.fill(0)
	_badlands_probabilities.resize(top_level+1);_badlands_probabilities.fill(0)
	_extra_probabilities.clear()
	for i in range(8):
		var probabilities:=PackedFloat64Array();probabilities.resize(top_level+1);probabilities.fill(0);_extra_probabilities.append(probabilities)
	var remaining := 1.0
	for level in range(top_level, -1, -1):
		var probabilities := Vector4.ZERO
		var assigned := 0.0
		for i in range(4):
			if _region_levels[i] == level:
				probabilities[i] = _coverage[i] / maxf(remaining,0.000000001)
				assigned += _coverage[i]
		if biome_count>=5 and _region_levels[4]==level:
			_jungle_probabilities[level]=_jungle_coverage/maxf(remaining,.000000001);assigned+=_jungle_coverage
		if biome_count>=6 and _region_levels[5]==level:
			_mountain_probabilities[level]=_mountain_coverage/maxf(remaining,.000000001);assigned+=_mountain_coverage
		if biome_count>=7 and _region_levels[6]==level:
			_tropical_probabilities[level]=_tropical_coverage/maxf(remaining,.000000001);assigned+=_tropical_coverage
		if biome_count>=8 and _region_levels[7]==level:
			_badlands_probabilities[level]=_badlands_coverage/maxf(remaining,.000000001);assigned+=_badlands_coverage
		if _extras_enabled:
			for i in range(8):
				if _region_levels[8+i]==level:_extra_probabilities[i][level]=_extra_coverage[i]/maxf(remaining,.000000001);assigned+=_extra_coverage[i]
		_level_probabilities[level] = probabilities
		remaining -= assigned
	_setup_noise(_warp_large, world_seed + 811, 1.0 / _root_region_size, 1,0.5)
	_setup_noise(_warp_small, world_seed + 919, 1.0 / _minimum_region_size, 1,0.5)
	_temperature_period = maxf(settings.temperature_region_size * maxf(settings.biome_size, 0.001), _root_region_size * 8.0)
	_temperature_phase = _region_random(0,0,0,9371) * TAU


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
	_select_normal_height_cache_capacity()
	built_badlands_palette=PackedByteArray()
	built_badlands_palette_slot=-1
	built_extension_data=PackedByteArray();built_extension_rows=0;built_extension_mask=0;built_structure_arrays=[]
	built_alien_tissue_flow=PackedByteArray();built_alien_tissue_flow_rows=0
	var profile_start := Time.get_ticks_usec() if profile_build else 0
	var row_size := resolution + 1
	var sample_size := row_size + 2
	var step := chunk_size / float(resolution)
	var origin_x := coordinate.x * chunk_size
	var origin_z := coordinate.y * chunk_size
	var inline_normal_pairs:Dictionary={}
	var use_inline_normals:bool=interleave_badlands_normals and _badlands!=null and step>32.0
	var height_samples := PackedFloat32Array()
	height_samples.resize(sample_size * sample_size)
	var weight_samples := PackedColorArray()
	weight_samples.resize(sample_size * sample_size)
	var surface_samples := PackedVector2Array()
	surface_samples.resize(sample_size * sample_size)
	var geology_samples := PackedVector3Array()
	geology_samples.resize(sample_size * sample_size)
	var jungle_samples:=PackedFloat32Array();var has_jungle:bool=false
	if _jungle!=null:jungle_samples.resize(sample_size*sample_size)
	var forest_samples:Array[PackedFloat32Array]=[];var has_forest:bool=false
	if _forest!=null:forest_samples.resize(sample_size*sample_size)
	var savanna_samples:Array[PackedFloat32Array]=[];var has_savanna:bool=false
	if _savanna!=null:savanna_samples.resize(sample_size*sample_size)
	var swamp_samples:Array[PackedFloat32Array]=[];var has_swamp:bool=false
	var swamp_water:=PackedFloat32Array()
	if _swamp!=null:swamp_samples.resize(sample_size*sample_size);swamp_water.resize(sample_size*sample_size)

	var coast_samples:=PackedVector4Array();var has_coast:bool=false
	if _coast!=null:coast_samples.resize(sample_size*sample_size)
	var mountain_samples:Array[PackedFloat32Array]=[];var has_mountain:bool=false
	if _mountain!=null:mountain_samples.resize(sample_size*sample_size)
	var tropical_samples:=PackedVector3Array();var has_tropical:bool=false
	if _tropical!=null:tropical_samples.resize(sample_size*sample_size)
	var extra_samples:Array[PackedVector4Array]=[]
	if _extras_enabled:extra_samples.resize(sample_size*sample_size)
	var badlands_samples:=PackedVector3Array();var has_badlands:bool=false
	var badlands_palette:=PackedVector4Array()
	var badlands_remnants:=PackedFloat32Array()
	var badlands_skirts:=PackedFloat32Array()
	if _badlands!=null:badlands_samples.resize(sample_size*sample_size);badlands_palette.resize(sample_size*sample_size);badlands_remnants.resize(sample_size*sample_size);badlands_skirts.resize(sample_size*sample_size)
	if _swamp==null and (_mountain!=null or _coast!=null or _tropical!=null or _badlands!=null or _extras_enabled):swamp_water.resize(sample_size*sample_size)
	# A one-vertex border gives accurate normals that match neighboring chunks.
	for sample_z in range(sample_size):
		for sample_x in range(sample_size):
			var world_x := origin_x + (sample_x - 1) * step
			var world_z := origin_z + (sample_z - 1) * step
			if prune_unused_halo and step > 32.0 and (sample_x == 0 or sample_z == 0 or sample_x == sample_size-1 or sample_z == sample_size-1):
				# Sparse normals use +/-32 m probes, NEVER the +/-mesh-step halo.
				continue
			height_samples[sample_z * sample_size + sample_x] = _sample_grid_height(world_x, world_z)
			var w := _last_weights
			if w == Vector4.ZERO:
				w = _biome_weights(world_x,world_z)
			weight_samples[sample_z * sample_size + sample_x] = Color(w.x,w.y,w.z,w.w)
			surface_samples[sample_z * sample_size + sample_x] = _last_surface
			geology_samples[sample_z * sample_size + sample_x] = _last_geology
			if _jungle!=null:
				jungle_samples[sample_z*sample_size+sample_x]=_last_jungle
				if _last_jungle>=65536:has_jungle=true
			if _forest!=null:
				forest_samples[sample_z*sample_size+sample_x]=_last_forest
				if _last_forest[0]>=65536:has_forest=true
			if _savanna!=null:
				savanna_samples[sample_z*sample_size+sample_x]=_last_savanna
				if _last_savanna[0]>=65536:has_savanna=true
			if _swamp!=null:
				swamp_samples[sample_z*sample_size+sample_x]=_last_swamp
				swamp_water[sample_z*sample_size+sample_x]=_last_swamp_water
				if _last_swamp[0]>=65536:has_swamp=true
			if _coast!=null:
				coast_samples[sample_z*sample_size+sample_x]=_last_coast;swamp_water[sample_z*sample_size+sample_x]=_last_swamp_water
				if _last_coast.x>1.0/255:has_coast=true
			if _mountain!=null:
				mountain_samples[sample_z*sample_size+sample_x]=_last_mountain
				swamp_water[sample_z*sample_size+sample_x]=_last_swamp_water
				if _last_mountain[0]>=65536:has_mountain=true
			if _tropical!=null:
				tropical_samples[sample_z*sample_size+sample_x]=_last_tropical
				swamp_water[sample_z*sample_size+sample_x]=_last_swamp_water
				if _last_tropical.x>1.0/255:has_tropical=true
			if _badlands!=null:
				badlands_samples[sample_z*sample_size+sample_x]=_last_badlands
				badlands_palette[sample_z*sample_size+sample_x]=_last_badlands_palette
				badlands_remnants[sample_z*sample_size+sample_x]=_last_badlands_remnant
				badlands_skirts[sample_z*sample_size+sample_x]=_last_badlands_skirt
				swamp_water[sample_z*sample_size+sample_x]=_last_swamp_water
				if _last_badlands.x>0:has_badlands=true
			if _extras_enabled:
				extra_samples[sample_z*sample_size+sample_x]=_last_extras
				swamp_water[sample_z*sample_size+sample_x]=_last_swamp_water
			# Capture every mutable surface control above before height-only probes.
			# Float64 preserves the original sparse derivative arithmetic exactly.
			if use_inline_normals and sample_x>0 and sample_z>0 and sample_x<sample_size-1 and sample_z<sample_size-1:
				inline_normal_pairs[Vector2i(sample_x-1,sample_z-1)]=PackedFloat64Array([_sample_normal_height(world_x-32.0,world_z),_sample_normal_height(world_x+32.0,world_z),_sample_normal_height(world_x,world_z-32.0),_sample_normal_height(world_x,world_z+32.0)])
	# One world-anchored normal field for all vertices/LODs, not a different
	# derivative just along chunk edges (which produced visible border stripes).
	# Reuse height samples at grid intersections; only the outer halo needs extra
	# samples on dense chunks. Cache lives for this build only.
	var profile_heights := Time.get_ticks_usec() if profile_build else 0
	# Sparse parent chunks must not allocate a 32 m grid over kilometres.
	# Evaluate the SAME 32 m derivative only at their actual grid vertices.
	var normal_step := maxf(32.0,step)
	var normal_x := floori(origin_x/normal_step)-1
	var normal_z := floori(origin_z/normal_step)-1
	var normal_width := ceili((origin_x+chunk_size)/normal_step)-normal_x+2
	var normal_depth := ceili((origin_z+chunk_size)/normal_step)-normal_z+2
	var normal_heights := PackedFloat32Array()
	normal_heights.resize(normal_width*normal_depth)
	for nz in range(normal_depth):
		for nx in range(normal_width):
			if prune_unused_halo and normal_step>32.0 and (nx==0 or nz==0 or nx==normal_width-1 or nz==normal_depth-1):
				continue
			var wx := (normal_x+nx)*normal_step
			var wz := (normal_z+nz)*normal_step
			var sx := (wx-origin_x)/step+1.0
			var sz := (wz-origin_z)/step+1.0
			if is_equal_approx(sx,roundf(sx)) and is_equal_approx(sz,roundf(sz)) and sx>=0 and sz>=0 and sx<sample_size and sz<sample_size:
				normal_heights[nz*normal_width+nx] = height_samples[roundi(sz)*sample_size+roundi(sx)]
			else:
				normal_heights[nz*normal_width+nx] = _sample_normal_height(wx,wz)
	var normal_field := PackedVector3Array()
	normal_field.resize(normal_width*normal_depth)
	var curvature_field := PackedFloat32Array()
	curvature_field.resize(normal_width*normal_depth)
	for nz in range(1,normal_depth-1):
		for nx in range(1,normal_width-1):
			var i := nz*normal_width+nx
			var wx: float=(normal_x+nx)*normal_step;var wz: float=(normal_z+nz)*normal_step
			var center: float=normal_heights[i]
			var normal_blend:float=0.0
			var left:=normal_heights[i-1];var right:=normal_heights[i+1]
			var back:=normal_heights[i-normal_width];var front:=normal_heights[i+normal_width]
			if normal_step>32.0:
				var local_index:=Vector2i(roundi((wx-origin_x)/step),roundi((wz-origin_z)/step))
				if use_inline_normals and inline_normal_pairs.has(local_index):
					var pair:PackedFloat64Array=inline_normal_pairs[local_index]
					left=pair[0];right=pair[1];back=pair[2];front=pair[3]
				else:
					right=_sample_normal_height(wx+32.0,wz);front=_sample_normal_height(wx,wz+32.0)
					left=_sample_normal_height(wx-32.0,wz);back=_sample_normal_height(wx,wz-32.0)
				if normal_blend>=1.0:left=center;back=center
			var central_normal:=Vector3(left-right,64.0,back-front)
			if normal_blend>0.0:
				# Match float32 storage of the dense 32 m normal lattice at shared
				# coordinates, including sparse parent chunks.
				var positive:=Vector2(right,front)
				var forward_normal:=Vector3((center-positive.x)*2.0,64.0,(center-positive.y)*2.0)
				central_normal=central_normal.lerp(forward_normal,normal_blend)
			normal_field[i] = central_normal.normalized()
			# Desert no longer thresholds this stencil into its material masks.
			# Fade it out with the derivative transition rather than inventing
			# one-sided "curvature" from a first derivative.
			curvature_field[i] = (left+right+back+front-4.0*center)/32.0*(1.0-normal_blend)

	var profile_normals := Time.get_ticks_usec() if profile_build else 0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var surface_uvs := PackedVector2Array()
	var geology_colors := PackedFloat32Array()
	var indices := _indices_for(resolution)
	vertices.resize(row_size * row_size)
	normals.resize(row_size * row_size)
	colors.resize(row_size * row_size)
	uvs.resize(row_size * row_size)
	surface_uvs.resize(row_size * row_size)
	var geology_stride:int=4 if has_jungle or has_badlands else 3
	geology_colors.resize(row_size * row_size * geology_stride)
	var forest_controls:=PackedFloat32Array()
	if has_forest or has_coast or has_tropical:forest_controls.resize(row_size*row_size*4)
	var savanna_controls:=PackedFloat32Array()
	if has_savanna or has_tropical:savanna_controls.resize(row_size*row_size*4)
	var swamp_controls:=PackedFloat32Array()
	if has_swamp or has_tropical:swamp_controls.resize(row_size*row_size*4)

	for z_index in range(row_size):
		for x_index in range(row_size):
			var vertex_index := z_index * row_size + x_index
			var sample_index := (z_index + 1) * sample_size + x_index + 1
			var world_x := origin_x + x_index * step
			var world_z := origin_z + z_index * step
			var height := height_samples[sample_index]
			vertices[vertex_index] = Vector3(x_index * step, height, z_index * step)
			var gx := world_x/normal_step-normal_x
			var gz := world_z/normal_step-normal_z
			var ix := mini(floori(gx),normal_width-3)
			var iz := mini(floori(gz),normal_depth-3)
			var ni := iz*normal_width+ix
			normals[vertex_index] = normal_field[ni].lerp(normal_field[ni+1],gx-ix).lerp(normal_field[ni+normal_width].lerp(normal_field[ni+normal_width+1],gx-ix),gz-iz).normalized()
			if _badlands!=null and badlands_remnants[sample_index]>.000001:
				# The shared 32m background stencil cannot shade a compact column.
				# Exact world-anchored +/-2m probes apply only where the analytic
				# feature actually changes terrain. Shared LOD vertices still agree.
				var local_normal:=Vector3(_sample_normal_height(world_x-2,world_z)-_sample_normal_height(world_x+2,world_z),4,_sample_normal_height(world_x,world_z-2)-_sample_normal_height(world_x,world_z+2)).normalized()
				normals[vertex_index]=normals[vertex_index].lerp(local_normal,smoothstep(0,.15,badlands_remnants[sample_index])).normalized()
			colors[vertex_index] = weight_samples[sample_index]
			var curvature := lerpf(lerpf(curvature_field[ni],curvature_field[ni+1],gx-ix),lerpf(curvature_field[ni+normal_width],curvature_field[ni+normal_width+1],gx-ix),gz-iz)
			uvs[vertex_index] = Vector2(swamp_water[sample_index] if _swamp!=null or _mountain!=null or _coast!=null or _tropical!=null or _badlands!=null or _extras_enabled else water_level,curvature)
			surface_uvs[vertex_index] = surface_samples[sample_index]
			var geology := geology_samples[sample_index]
			geology_colors[vertex_index*geology_stride] = geology.x
			geology_colors[vertex_index*geology_stride+1] = geology.y
			geology_colors[vertex_index*geology_stride+2] = geology.z
			if has_jungle:geology_colors[vertex_index*4+3]=jungle_samples[sample_index]
			if has_forest:
				var f:PackedFloat32Array=forest_samples[sample_index]
				if f.size()==4:
					for channel in range(4):forest_controls[vertex_index*4+channel]=f[channel]
			if has_savanna:
				var s:PackedFloat32Array=savanna_samples[sample_index]
				if s.size()==4:
					for channel in range(4):savanna_controls[vertex_index*4+channel]=s[channel]
			if has_swamp:
				var s:PackedFloat32Array=swamp_samples[sample_index]
				if s.size()==4:
					for channel in range(4):swamp_controls[vertex_index*4+channel]=s[channel]
			if has_mountain:
				var m:PackedFloat32Array=mountain_samples[sample_index]
				# A negative sentinel enables the extended layout at this vertex.
				# Decode BEFORE raster interpolation. Mountain-disabled arrays stay exact.
				geology_colors[vertex_index*geology_stride]=-_pack_savanna(geology.x,geology.y,geology.z)-1
				geology_colors[vertex_index*geology_stride+1]=m[0]
				geology_colors[vertex_index*geology_stride+2]=m[1]
				var q:int=int(m[2])
				surface_uvs[vertex_index]=Vector2(_pack_savanna(surface_uvs[vertex_index].x,surface_uvs[vertex_index].y,float(q&255)/255),_pack_savanna(float((q>>8)&255)/255,float((q>>16)&255)/255,m[3]))
			if has_coast:
				var coast:Vector4=coast_samples[sample_index]
				var forest_water:float=forest_controls[vertex_index*4+3]
				forest_controls[vertex_index*4+2]=-_pack_savanna(forest_controls[vertex_index*4+2],coast.x,coast.y)-1
				forest_controls[vertex_index*4+3]=_pack_savanna(forest_controls[vertex_index*4+3],coast.z,coast.w)
				if coast.w<0:
					var sand:int=int(-coast.w-1)
					# Signed extension preserves the existing Forest water byte.
					forest_controls[vertex_index*4+3]=-_pack_savanna(forest_water,float(sand&255)/255,float((sand>>8)&255)/255)-1
			if has_tropical:
				# Reclaim only redundant ownership bytes (already in COLOR.gba).
				# All old ecological bytes and all four banks survive mixed vertices.
				var t:Vector3=tropical_samples[sample_index]
				var fi:int=int(forest_controls[vertex_index*4]);var si:int=int(savanna_controls[vertex_index*4]);var wi:int=int(swamp_controls[vertex_index*4])
				forest_controls[vertex_index*4]=-float((fi&65535)+roundi(t.z*255)*65536)-1
				savanna_controls[vertex_index*4]=-float((si&65535)+roundi(t.x*255)*65536)-1
				swamp_controls[vertex_index*4]=-float((wi&65535)+roundi(t.y*255)*65536)-1
			if has_badlands:
				# Preserve the complete Jungle payload in a signed wrapper. Only
				# Grass curvature (already saturated beyond +/- .35) is quantized.
				var b:Vector3=badlands_samples[sample_index]
				var curvature_byte:int=roundi(clampf(curvature,-.5,.5)*254)+127
				uvs[vertex_index].y=float(roundi(b.x*255)+roundi(b.z*255)*256+curvature_byte*65536)
				geology_colors[vertex_index*4+3]=-(jungle_samples[sample_index] if has_jungle else 0)-1
	if has_badlands:
		built_badlands_palette.resize(row_size*row_size*4)
		for z in range(row_size):
			for x in range(row_size):
				var index:int=(z+1)*sample_size+x+1;var palette:Vector4=badlands_palette[index]
				# Controls remain meaningful on the other side of an ownership
				# transition. Ownership is blended separately, not divided out of
				# a material palette using a differently interpolated scalar.
				if badlands_samples[index].x<=0:palette=_badlands.material_palette(Vector2(origin_x+x*step,origin_z+z*step))
				for channel in range(4):built_badlands_palette[(z*row_size+x)*4+channel]=roundi(clampf(palette[channel],0,1)*255)
	if _extras_enabled:
		var any_influence:bool=false
		built_extension_data.resize(row_size*row_size*8*4);built_extension_rows=row_size
		for z in range(row_size):
			for x in range(row_size):
				var sample_index:int=(z+1)*sample_size+x+1;var payload:PackedVector4Array=extra_samples[sample_index]
				if payload.size()!=8:continue
				for i in range(8):
					var e:Vector4=payload[i];var offset:int=(z*row_size*8+i*row_size+x)*4
					built_extension_data[offset]=roundi(clampf(e.x,0,1)*255)
					if built_extension_data[offset]>0:built_extension_mask|=1<<i
					built_extension_data[offset+1]=roundi(clampf(e.z*e.x,0,1)*255)
					built_extension_data[offset+2]=roundi(clampf(e.y*e.x,0,1)*255)
					built_extension_data[offset+3]=roundi(clampf(e.w*e.x,0,1)*255)
					any_influence=any_influence or e.x>.5/255
		if not any_influence:built_extension_data=PackedByteArray();built_extension_rows=0;built_extension_mask=0
	if has_badlands:
		if built_extension_data.is_empty():
			built_extension_data=built_badlands_palette;built_extension_rows=row_size;built_badlands_palette_slot=0
		else:
			var combined:=PackedByteArray()
			for z in range(row_size):
				combined.append_array(built_extension_data.slice(z*row_size*8*4,(z+1)*row_size*8*4))
				combined.append_array(built_badlands_palette.slice(z*row_size*4,(z+1)*row_size*4))
			built_extension_data=combined;built_badlands_palette_slot=8
	if (built_extension_mask & 128)!=0 and settings.alien_infected.nerve_flow_texturing:
		var flow:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").atlas(_extras[7],Vector2(origin_x,origin_z),chunk_size,resolution)
		built_alien_tissue_flow=flow.data;built_alien_tissue_flow_rows=flow.rows
	# Vertical skirts cover gaps where neighboring LOD grids have different spacing.
	var boundary: Array[int] = []
	for i in range(row_size):
		boundary.append(i)
	for i in range(1, row_size):
		boundary.append(i * row_size + resolution)
	for i in range(resolution - 1, -1, -1):
		boundary.append(resolution * row_size + i)
	for i in range(resolution - 1, 0, -1):
		boundary.append(i * row_size)
	for i in range(boundary.size()):
		var a := boundary[i]
		var b := boundary[(i + 1) % boundary.size()]
		var skirt_depth:=maxf(32.0,step*4.0)
		if _badlands!=null:
			# A narrow column can be higher than the neighbouring coarse edge's
			# chord. Extend only its visual skirt by its actual added height.
			# Original terrain, vertex count and collision remain unchanged.
			var sample_a:int=(a/row_size+1)*sample_size+a%row_size+1
			var sample_b:int=(b/row_size+1)*sample_size+b%row_size+1
			skirt_depth+=maxf(badlands_skirts[sample_a],badlands_skirts[sample_b])
		vertices.append(vertices[a] - Vector3.UP * skirt_depth)
		vertices.append(vertices[b] - Vector3.UP * skirt_depth)
		normals.append(normals[a])
		normals.append(normals[b])
		colors.append(colors[a])
		colors.append(colors[b])
		uvs.append(uvs[a])
		uvs.append(uvs[b])
		surface_uvs.append(surface_uvs[a])
		surface_uvs.append(surface_uvs[b])
		for vertex in [a,b]:
			for channel in range(geology_stride): geology_colors.append(geology_colors[vertex*geology_stride+channel])
			if has_forest or has_coast or has_tropical:
				for channel in range(4):forest_controls.append(forest_controls[vertex*4+channel])
			if has_savanna or has_tropical:
				for channel in range(4):savanna_controls.append(savanna_controls[vertex*4+channel])
			if has_swamp or has_tropical:
				for channel in range(4):swamp_controls.append(swamp_controls[vertex*4+channel])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = surface_uvs
	# Explicit RGB_FLOAT format; RGBA8 only exposed R on the tested GL backend.
	arrays[Mesh.ARRAY_CUSTOM0] = geology_colors
	if has_forest or has_coast or has_tropical:arrays[Mesh.ARRAY_CUSTOM1]=forest_controls
	if has_savanna or has_tropical:arrays[Mesh.ARRAY_CUSTOM2]=savanna_controls
	if has_swamp or has_tropical:arrays[Mesh.ARRAY_CUSTOM3]=swamp_controls
	arrays[Mesh.ARRAY_INDEX] = indices

	if profile_build:
		last_build_profile = {"height_and_noise_ms": (profile_heights-profile_start)/1000.0, "normal_field_ms": (profile_normals-profile_heights)/1000.0, "mesh_arrays_ms": (Time.get_ticks_usec()-profile_normals)/1000.0}
	return arrays


func _indices_for(resolution: int) -> PackedInt32Array:
	if _index_templates.has(resolution): return _index_templates[resolution]
	var row := resolution+1
	var indices := PackedInt32Array()
	indices.resize(resolution*resolution*6+resolution*24)
	var cursor := 0
	for z in range(resolution):
		for x in range(resolution):
			var a:=z*row+x
			indices[cursor]=a; indices[cursor+1]=a+1; indices[cursor+2]=a+row
			indices[cursor+3]=a+1; indices[cursor+4]=a+row+1; indices[cursor+5]=a+row
			cursor+=6
	var boundary: Array[int]=[]
	for i in range(row): boundary.append(i)
	for i in range(1,row): boundary.append(i*row+resolution)
	for i in range(resolution-1,-1,-1): boundary.append(resolution*row+i)
	for i in range(resolution-1,0,-1): boundary.append(i*row)
	for i in range(boundary.size()):
		var a:=boundary[i]
		var b:=boundary[(i+1)%boundary.size()]
		var bottom:=row*row+i*2
		indices[cursor]=a; indices[cursor+1]=bottom; indices[cursor+2]=b
		indices[cursor+3]=b; indices[cursor+4]=bottom; indices[cursor+5]=bottom+1
		cursor+=6
	if _index_templates.size()>=16: _index_templates.clear()
	_index_templates[resolution]=indices
	return indices


func _region_random(x: int, z: int, biome: int, salt: int) -> float:
	var h: int = (x * 73856093 ^ z * 19349663 ^ world_seed * 83492791 ^ biome * 2654435761 ^ salt) & 0xffffffff
	h = ((h ^ (h >> 16)) * 73244475) & 0xffffffff
	h = ((h ^ (h >> 16)) * 73244475) & 0xffffffff
	h = (h ^ (h >> 16)) & 0xffffffff
	return float(h) / 4294967296.0


func _warp_region_point(x: float, z: float) -> Vector2:
	# Rotation and successive shears are invertible and area-preserving:
	# borders become organic without changing coverage or breaking regions up.
	var p := Vector2(x * 0.932327 - z * 0.361615, x * 0.361615 + z * 0.932327)
	p.x += _warp_large.get_noise_1d(p.y) * _root_region_size * 0.16 + _warp_small.get_noise_1d(p.y) * _minimum_region_size * 0.18
	p.y += _warp_large.get_noise_1d(p.x + 713.0) * _root_region_size * 0.16 + _warp_small.get_noise_1d(p.x + 317.0) * _minimum_region_size * 0.18
	return p


func _temperature_at_region(p: Vector2) -> float:
	# One full-range climate cycle instead of cancelling noise layers. Existing
	# world-to-region warping bends these broad climate zones organically.
	var climate := sin(p.x * TAU / _temperature_period + _temperature_phase)
	return settings.average_temperature + settings.temperature_variation * climate


func get_temperature(x: float, z: float) -> float:
	return _temperature_at_region(_warp_region_point(x,z))


func _region_owner(p: Vector2) -> int:
	# Search from large to small; once claimed, the entire region is protected.
	for level in range(_level_probabilities.size()-1, -1, -1):
		var span := _minimum_region_size * pow(2.0,level)
		var cx := floori(p.x / span)
		var cz := floori(p.y / span)
		var roll := _region_random(cx,cz,level,2731)
		var cumulative := 0.0
		var probabilities := _level_probabilities[level]
		var jungle_probability:float=_jungle_probabilities[level]
		for i in range(4):
			cumulative += probabilities[i]
			if roll < cumulative and _region_enabled[i]:
				return i
		if jungle_probability>0 and roll<cumulative+jungle_probability:return 4
		cumulative+=jungle_probability
		if _mountain_probabilities[level]>0 and roll<cumulative+_mountain_probabilities[level]:return 5
		cumulative+=_mountain_probabilities[level]
		if _tropical_probabilities[level]>0 and roll<cumulative+_tropical_probabilities[level]:return 6
		cumulative+=_tropical_probabilities[level]
		if _badlands_probabilities[level]>0 and roll<cumulative+_badlands_probabilities[level]:return 7
		cumulative+=_badlands_probabilities[level]
		if _extras_enabled:
			for i in range(8):
				cumulative+=_extra_probabilities[i][level]
				if _extra_probabilities[i][level]>0 and roll<cumulative:return 8+i
	# Rounding at a cumulative probability of one.
	for i in range(4):
		if _region_enabled[i]:
			return i
	if _jungle_coverage>0:return 4
	if _mountain_coverage>0:return 5
	if _tropical_coverage>0:return 6
	if _badlands_coverage>0:return 7
	for i in range(8):
		if _extra_coverage[i]>0:return 8+i
	return 0


func _grid_owner(x: int, z: int, step: float) -> int:
	var key := Vector2i(x,z)
	if not _label_cache.has(key):
		if _label_cache.size() >= 4096:
			_label_cache.clear()
		_label_cache[key] = _region_owner(_warp_region_point(x * step,z * step))
	return _label_cache[key]


func is_pure_jungle_rect(bounds:Rect2)->bool:
	if _jungle_coverage<=0:return false
	if _jungle_coverage==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step))
	var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=4:return false
	return true


func is_pure_forest_rect(bounds:Rect2)->bool:
	if _coverage.y<=0:return false
	if _coverage.y==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step))
	var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=1:return false
	return true


func is_pure_savanna_rect(bounds:Rect2)->bool:
	if _coverage.z<=0:return false
	if _coverage.z==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step))
	var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=2:return false
	return true


func is_pure_swamp_rect(bounds:Rect2)->bool:
	if _coverage.w<=0:return false
	if _coverage.w==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step))
	var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=3:return false
	return true

func is_pure_mountain_rect(bounds:Rect2)->bool:
	if _mountain_coverage<=0:return false
	if _mountain_coverage==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step))
	var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=5:return false
	return true

func is_pure_tropical_rect(bounds:Rect2)->bool:
	if _tropical_coverage<=0:return false
	if _tropical_coverage==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step))
	var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=6:return false
	return true

func is_pure_badlands_rect(bounds:Rect2)->bool:
	if _badlands_coverage<=0:return false
	if _badlands_coverage==1:return true
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step));var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return false
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=7:return false
	return true

func pure_extension_rect(bounds:Rect2)->int:
	if not _extras_enabled:return -1
	for i in range(8):
		if _extra_coverage[i]==1:return i
	var step:float=maxf(_minimum_region_size/(maxf(settings.height_blend,.1)*4),1)
	var first:=Vector2i(floori(bounds.position.x/step),floori(bounds.position.y/step));var last:=Vector2i(ceili(bounds.end.x/step),ceili(bounds.end.y/step))
	if (last.x-first.x+1)*(last.y-first.y+1)>256:return -1
	var owner:int=_grid_owner(first.x,first.y,step)
	if owner<8:return -1
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if _grid_owner(x,z,step)!=owner:return -1
	return owner-8

func _biome_weights(x: float, z: float) -> Vector4:
	_extra_weights.fill(0)
	for i in range(8):
		if _extra_coverage[i]==1:
			_jungle_weight=0;_mountain_weight=0;_tropical_weight=0;_badlands_weight=0;_extra_weights[i]=1;return Vector4.ZERO
	_jungle_weight=0;_mountain_weight=0;_tropical_weight=0;_badlands_weight=0
	if _badlands_coverage==1:_badlands_weight=1;return Vector4.ZERO
	if _tropical_coverage==1:_tropical_weight=1;return Vector4.ZERO
	if _mountain_coverage==1:_mountain_weight=1;return Vector4.ZERO
	if _jungle_coverage==1:
		_jungle_weight=1;return Vector4.ZERO
	if _coverage.y==1:return _coverage
	if _coverage.z==1:return _coverage
	if _coverage.w==1:return _coverage
	# A fine global grid gives continuous, chunk-independent boundary blending.
	# Region interiors stay exactly one biome; there is no distance-score contest.
	var step := maxf(_minimum_region_size / (maxf(settings.height_blend,0.1) * 4.0), 1.0)
	var px := x / step
	var pz := z / step
	var ix := floori(px)
	var iz := floori(pz)
	var cell:=Vector2i(ix,iz)
	if not _biome_cell_cache.has(cell):
		if _biome_cell_cache.size()>=4096: _biome_cell_cache.clear()
		_biome_cell_cache[cell]=Vector4i(_grid_owner(ix,iz,step),_grid_owner(ix+1,iz,step),_grid_owner(ix,iz+1,step),_grid_owner(ix+1,iz+1,step))
	var labels: Vector4i=_biome_cell_cache[cell]
	if labels.x==labels.y and labels.x==labels.z and labels.x==labels.w:
		var pure:=Vector4.ZERO
		if labels.x==4:_jungle_weight=1
		elif labels.x==5:_mountain_weight=1
		elif labels.x==6:_tropical_weight=1
		elif labels.x==7:_badlands_weight=1
		elif labels.x>=8:_extra_weights[labels.x-8]=1
		else:pure[labels.x]=1.0
		return pure
	var fx := smoothstep(0.0,1.0,px-ix)
	var fz := smoothstep(0.0,1.0,pz-iz)
	var weights := Vector4.ZERO
	if not _extras_enabled and _jungle_coverage==0 and _mountain_coverage==0 and _tropical_coverage==0 and _badlands_coverage==0:
		weights[labels.x] += (1.0-fx)*(1.0-fz)
		weights[labels.y] += fx*(1.0-fz)
		weights[labels.z] += (1.0-fx)*fz
		weights[labels.w] += fx*fz
	else:
		var contributions:=Vector4((1-fx)*(1-fz),fx*(1-fz),(1-fx)*fz,fx*fz)
		for i in range(4):
			if labels[i]==4:_jungle_weight+=contributions[i]
			elif labels[i]==5:_mountain_weight+=contributions[i]
			elif labels[i]==6:_tropical_weight+=contributions[i]
			elif labels[i]==7:_badlands_weight+=contributions[i]
			elif labels[i]>=8:_extra_weights[labels[i]-8]+=contributions[i]
			else:weights[labels[i]]+=contributions[i]
	return weights


func _island_pitch() -> float:
	return maxf(settings.island_size,16.0)*0.65 + _island_gap()


func _island_gap() -> float:
	return maxf(settings.island_spacing,1.0)*maxf(settings.island_size,16.0)/1388.89


func _island_candidate(cell: Vector2i) -> PackedFloat64Array:
	var pitch := _island_pitch()
	var center := Vector2(cell)*pitch + Vector2(
		_region_random(cell.x,cell.y,71,211)-0.5,
		_region_random(cell.x,cell.y,71,313)-0.5)*pitch*0.8*clampf(settings.island_position_jitter,0,1)
	var weight := _region_random(cell.x,cell.y,71,419)*pitch*pitch*0.25*clampf(settings.island_size_variation,0,0.7)
	return PackedFloat64Array([center.x,center.y,weight,_region_random(cell.x,cell.y,71,859)])


func _shoreline_detail_offset(x: float, z: float) -> Vector2:
	# Fixed-world-scale detail survives when the broad island shape grows.
	var strength := minf(maxf(settings.shoreline_detail_strength,0.0),maxf(settings.shoreline_detail_size,50.0)*0.3)
	return Vector2(_shoreline_noise.get_noise_2d(x,z),_shoreline_noise.get_noise_2d(x+9371.0,z-3517.0))*strength


func _island_mask(x: float, z: float) -> float:
	# Warped power cells share shore boundaries, rather than reserving empty
	# circles around small shapes. Eroding both sides opens the requested strait.
	var pitch := _island_pitch()
	var warp := maxf(settings.island_size,16.0)*clampf(settings.island_coast_irregularity,0,0.6)*0.55
	var point := Vector2(x,z)
	point.x += _continent_noise.get_noise_2d(x,z)*warp
	var size_scale := maxf(settings.island_size,16.0)/1388.89
	point.y += _continent_noise.get_noise_2d(x+7139.0*size_scale,z-4193.0*size_scale)*warp
	# Both neighboring shores share this warp, preserving the channel instead
	# of independently perturbing their heights and accidentally connecting land.
	point += _shoreline_detail_offset(x,z)
	var cell := Vector2i(floori(point.x/pitch+0.5),floori(point.y/pitch+0.5))
	# Distance to fixed power-cell half planes is 1-Lipschitz in warped space.
	# Certify a fully inland height query without rescanning all 24 planes.
	# Public mask queries remain exact; only saturated coastal blends use this.
	if _height_query and _coast_certificates.has(cell):
		var certificate: Vector3=_coast_certificates[cell]
		if certificate.z-point.distance_to(Vector2(certificate.x,certificate.y))>maxf(maxf(settings.coast_width*694.445,0.1),_coast_limit)+1.0:
			return maxf(1.0,(maxf(maxf(settings.coast_width*694.445,0.1),_coast_limit)+1.0)/maxf(settings.island_size*0.5,8.0))
	if not _island_cache.has(cell):
		var sites: Array[PackedFloat64Array] = []
		for dz in range(-2,3):
			for dx in range(-2,3):
				sites.append(_island_candidate(cell+Vector2i(dx,dz)))
		if _island_cache.size() > 512:
			_island_cache.clear()
		_island_cache[cell] = sites
	var candidates: Array = _island_cache[cell]
	if _owner_cache.has(cell):
		var previous: int = _owner_cache[cell]
		var previous_key := Vector3i(cell.x,cell.y,previous)
		if _plane_cache.has(previous_key):
			var old_owner: PackedFloat64Array = candidates[previous]
			var old_relative := Vector3(point.x-old_owner[0],point.y-old_owner[1],1.0)
			var interior := INF
			for plane: Vector3 in _plane_cache[previous_key]:
				interior = minf(interior,plane.dot(old_relative))
			# Positive eroded half-planes certify ownership; otherwise do the
			# full power-cell search. Exact predicate, not coarse coast sampling.
			if interior>0.0:
				var distance:=interior-maxf(settings.land_threshold-0.4,0.0)*settings.island_size*0.25
				_remember_coast(cell,point,distance)
				return distance/maxf(settings.island_size*0.5,8.0)
	var best := INF
	var winner := 0
	for i in range(candidates.size()):
		var site: PackedFloat64Array = candidates[i]
		var score := point.distance_squared_to(Vector2(site[0],site[1]))-site[2]
		if score < best:
			best = score
			winner = i
	var owner: PackedFloat64Array = candidates[winner]
	if _owner_cache.size()>=512: _owner_cache.clear()
	_owner_cache[cell] = winner
	var plane_key := Vector3i(cell.x,cell.y,winner)
	if not _plane_cache.has(plane_key):
		var planes := PackedVector3Array()
		for i in range(candidates.size()):
			if i == winner: continue
			var site: PackedFloat64Array = candidates[i]
			var delta := Vector2(site[0]-owner[0],site[1]-owner[1])
			var length := delta.length()
			var pair_random := fposmod((site[3]+owner[3])*43758.5453,1.0)
			var variation := clampf(settings.island_spacing_variation,0.0,0.95)
			var gap := _island_gap()*lerpf(1.0-variation,1.0+variation,pair_random)
			planes.append(Vector3(-delta.x/length,-delta.y/length,(delta.length_squared()+owner[2]-site[2])/(2.0*length)-gap*0.5))
		if _plane_cache.size()>=128: _plane_cache.clear()
		_plane_cache[plane_key] = planes
	var boundary := INF
	var relative := Vector3(point.x-owner[0],point.y-owner[1],1.0)
	for plane: Vector3 in _plane_cache[plane_key]:
		boundary = minf(boundary,plane.dot(relative))
	var erosion := maxf(settings.land_threshold-0.4,0.0)*settings.island_size*0.25
	_remember_coast(cell,point,boundary-erosion)
	return (boundary-erosion)/maxf(settings.island_size*0.5,8.0)


func _remember_coast(cell: Vector2i, point: Vector2, distance: float) -> void:
	if _coast_certificates.size()>=512: _coast_certificates.clear()
	_coast_certificates[cell]=Vector3(point.x,point.y,distance)


func _grass_river_center(x: float, lane: int, spacing: float) -> float:
	# Match the existing exact-lattice height-cache policy. A Vector2 key
	# rounded double-X tree anchors to float32; rounded/fractional callers can
	# share that key but have different uncached values. Never quantize them.
	var exact:bool=x==floorf(x) and absf(x)<2000000000.0 and lane>-2000000000 and lane<2000000000 and is_finite(spacing)
	var key:=Vector2i.ZERO
	if exact:
		key=Vector2i(int(x),lane)
		# Different samplers legitimately request different spacing in the
		# same world. One active namespace avoids larger/per-query array keys.
		if spacing!=_river_cache_spacing:_river_cache.clear();_river_cache_spacing=spacing
		if _river_cache.has(key):return _river_cache[key]
	var seed_value := _region_random(lane,0,93,541)
	var broad := _grass_water_noise.get_noise_2d(x*0.3,lane*7919.0)
	var bends := _grass_water_noise.get_noise_2d(x*1.15+3171.0,lane*7919.0+137.0)
	var value := lane*spacing+(seed_value-0.5)*spacing*0.3 + broad*spacing*0.32 + bends*spacing*0.075
	if exact:
		if _river_cache.size()>=4096:_river_cache.clear()
		_river_cache[key]=value
	return value


func _lake_sites(cell: Vector2i, pitch: float) -> Array[Vector4]:
	if _lake_cache.has(cell): return _lake_cache[cell]
	var sites: Array[Vector4] = []
	for dz in range(-1,2):
		for dx in range(-1,2):
			var site := cell+Vector2i(dx,dz)
			var chance := _region_random(site.x,site.y,91,131)
			if chance>settings.grass_lake_frequency: continue
			var center := (Vector2(site)+Vector2(0.2+_region_random(site.x,site.y,91,227)*0.6,0.2+_region_random(site.x,site.y,91,229)*0.6))*pitch
			if settings.grass_river_frequency>0 and chance<settings.grass_lake_frequency*0.5:
				var spacing := 4000.0/maxf(settings.grass_river_frequency,0.01)
				var river_z := _grass_river_center(center.x,roundi(center.y/spacing),spacing)
				if absf(river_z-center.y)<pitch*0.3: center.y=river_z
			var radius := settings.grass_lake_size*lerpf(0.15,1.0,_region_random(site.x,site.y,91,337))
			sites.append(Vector4(center.x,center.y,radius,chance*TAU))
	if _lake_cache.size()>=256: _lake_cache.clear()
	_lake_cache[cell] = sites
	return sites


func _river_column(x: float, lane: int, spacing: float) -> Vector3:
	var exact:bool=x==floorf(x) and absf(x)<2000000000.0 and lane>-2000000000 and lane<2000000000 and is_finite(spacing)
	var key:=Vector2i.ZERO
	if exact:
		key=Vector2i(int(x),lane)
		if spacing!=_river_column_spacing:_river_columns.clear();_river_column_spacing=spacing
		if _river_columns.has(key):return _river_columns[key]
	var value:=Vector3(_grass_river_center(x,lane,spacing),(_grass_river_center(x+8.0,lane,spacing)-_grass_river_center(x-8.0,lane,spacing))/16.0,_grass_water_noise.get_noise_2d(x*0.6,lane*711.0))
	if exact:
		if _river_columns.size()>=2048:_river_columns.clear()
		_river_columns[key]=value
	return value


func _grass_sample(x: float, z: float) -> Vector3:
	# One canonical world-anchored structural lattice for EVERY LOD, not a
	# different shape per mesh. Narrow user-configured channels use a finer lattice.
	var step:=minf(settings.grass_field_spacing,maxf(1.0,settings.grass_river_width*0.25))
	var p:=Vector2(x,z)/step
	var cell:=Vector2i(floori(p.x),floori(p.y))
	var f:=p-Vector2(cell)
	var a: Array=_grass_grid_sample(cell,step)
	if f.x<0.000001 and f.y<0.000001:
		_last_surface=a[1]
		_last_geology=a[3]
		return a[0]
	# Dense mesh samples often lie exactly on a lattice row or column. The
	# opposite corners have zero interpolation weight: do not generate them.
	# Use exact equality here so near-edge, nonzero weights retain all samples.
	var b: Array=a if f.x==0.0 else _grass_grid_sample(cell+Vector2i(1,0),step)
	var c: Array=a if f.y==0.0 else _grass_grid_sample(cell+Vector2i(0,1),step)
	var d: Array=c if f.x==0.0 else (b if f.y==0.0 else _grass_grid_sample(cell+Vector2i(1,1),step))
	var surface: Vector2=(a[1] as Vector2).lerp(b[1],f.x).lerp((c[1] as Vector2).lerp(d[1],f.x),f.y)
	var profile: Vector3=(a[0] as Vector3).lerp(b[0],f.x).lerp((c[0] as Vector3).lerp(d[0],f.x),f.y)
	var geology: Vector3=(a[3] as Vector3).lerp(b[3],f.x).lerp((c[3] as Vector3).lerp(d[3],f.x),f.y)
	# Shared node flags interpolate continuously across lattice cells. Sharp
	# walls, crests and active banks retain exact sampling, not coarse averaging.
	var precision:=lerpf(lerpf(a[2],b[2],f.x),lerpf(c[2],d[2],f.x),f.y)
	if precision>0.001:
		profile=profile.lerp(_grass_sample_raw(x,z),precision)
		surface=surface.lerp(_last_surface,precision)
		geology=geology.lerp(_last_geology,precision)
	_last_surface=surface
	_last_geology=geology
	return profile


func _grass_grid_sample(cell: Vector2i, step: float) -> Array:
	if _grass_grid.has(cell): return _grass_grid[cell]
	var profile:=_grass_sample_raw(cell.x*step,cell.y*step)
	var entry: Array=[profile,_last_surface,_last_precision,_last_geology]
	if _grass_grid.size()>=8192: _grass_grid.clear()
	_grass_grid[cell]=entry
	return entry


func _grass_sample_raw(x: float, z: float) -> Vector3:
	# X: relief; Y: hydrology blend; Z: bed elevation relative to water.
	# All fields are absolute-world functions, with no chunk/resolution state.
	var timer:=Time.get_ticks_usec() if profile_build else 0
	var region := _grass_region.get_noise_2d(x,z)*0.5+0.5
	var geology := _grass_region.get_noise_2d(x+17391.0,z-9137.0)*0.5+0.5
	# Independent kilometre-scale uplift/sedimentary provinces. These select
	# different profiles (folds, basins, shelves), not another roughness octave.
	var province:=geographic_identity(x,z)
	var calm: float=(1.0-smoothstep(0.34,0.49,province.x))*settings.grass_geographic_variety
	var folded: float=smoothstep(0.48,0.65,province.x)*settings.grass_geographic_variety
	var basin_country: float=(1.0-smoothstep(0.40,0.56,province.x))*smoothstep(0.45,0.64,province.y)*settings.grass_geographic_variety
	var canyon_country: float=smoothstep(0.50,0.65,province.x)*(1.0-smoothstep(0.44,0.60,province.y))*settings.grass_geographic_variety
	# Catchment provinces, not a universal blue network across all lowlands.
	# Smooth transitions retain a single world-space definition at every LOD.
	var humid: float=smoothstep(0.46,0.59,province.y)
	var water_country: float=lerpf(1.0,humid,settings.grass_geographic_variety)
	var plains := 1.0-smoothstep(settings.grass_plains_frequency-0.08,settings.grass_plains_frequency+0.14,region) if settings.grass_plains_frequency>0 else 0.0
	var hills := smoothstep(1.0-settings.grass_hill_frequency-0.2,1.0-settings.grass_hill_frequency+0.1,region)*(1.0-plains) if settings.grass_hill_frequency>0 else 0.0
	var mountains := smoothstep(1.0-settings.grass_mountain_frequency-0.28,1.0-settings.grass_mountain_frequency+0.12,region) if settings.grass_mountain_frequency>0 else 0.0
	plains=maxf(plains,calm)
	hills*=1.0-calm
	mountains*=lerpf(1.0,0.3+folded*1.4,settings.grass_geographic_variety)*(1.0-calm)
	mountains=clampf(mountains,0,1)
	# Uplift belts must survive local hill masks: otherwise even mountain
	# provinces become scattered domes wherever the old region mask is weak.
	mountains=maxf(mountains,folded*smoothstep(0.28,0.52,region)*0.9)
	# Signed geological footprint, not a broad height blend that never reaches 1.
	var plateau_distance := ((geology*2.0-1.0)-(0.42-settings.grass_plateau_frequency*0.9))*settings.grass_landform_size*0.6
	plateau_distance-=(1.0-smoothstep(0.46,0.65,province.y))*settings.grass_landform_size*0.65*settings.grass_geographic_variety
	var plateau := 0.0
	var wall_precision:=0.0
	var talus:=0.0
	var incision:=0.0
	var cliff_control:=0.0
	var crest := 0.0
	var macro := _grass_macro.get_noise_2d(x,z)
	var roll := _grass_forms.get_noise_2d(x,z*0.7)
	# Shared intermediate-scale structure: elongated divides and their valleys.
	var structure := _grass_ridges.get_noise_2d(x*3.8+917.0,z*2.1-371.0)
	plateau_distance += structure*90.0+roll*65.0
	# Skip geology where no plateau apron or mountain can contribute.
	var needs_geology: bool=mountains>0.001 or (settings.grass_plateau_frequency>0 and plateau_distance > -settings.grass_talus_width*3.6-100.0)
	var lithology := _grass_forms.get_noise_2d(x*0.22+7103.0,z*0.22-2911.0) if needs_geology else 0.0
	var drainage_axis := _grass_forms.get_noise_2d(x*0.45-3191.0,z*0.45+7319.0) if needs_geology else 0.0
	if settings.grass_plateau_frequency>0.0:
		if absf(plateau_distance)<maxf(settings.grass_talus_width,settings.grass_cliff_width*3.0)+100.0:
			# Headlands and buttresses deform the wall, not the calm cap surface.
			plateau_distance += _grass_forms.get_noise_2d(x*1.5,z*1.5)*90.0
		plateau=smoothstep(-settings.grass_talus_width,0.0,plateau_distance)
		mountains *= 1.0-plateau
	hills*=1.0-mountains*0.85
	var divide := 1.0-sqrt(structure*structure+0.0064)
	var flatness := plains*clampf(settings.grass_plains_flatness,0,1)
	var relief := 10.0+(macro*0.5+0.5)*settings.grass_macro_height*(1.0-flatness*0.95)
	relief += roll*settings.grass_rolling_strength*(1.0-flatness)
	relief += (roll*roll*2.0+roll)*settings.grass_hill_height*5.0*hills
	relief += (divide*divide-0.55)*settings.grass_hill_height*3.0*hills
	relief += (roll*1.6+(divide-0.65)*2.0)*plains
	# Folded hill chains contrast with broad rolling lowlands. Basin districts
	# instead collect broad shallow depressions; neither modifies island masks.
	relief+=folded*hills*(divide*divide*divide-0.45)*settings.grass_hill_height*4.0
	relief=lerpf(relief,6.0+roll*3.0,basin_country*(1.0-mountains)*0.8)
	if profile_build:
		field_timings["regional_fields_us"]=field_timings.get("regional_fields_us",0)+Time.get_ticks_usec()-timer
		timer=Time.get_ticks_usec()
	if mountains > 0.001:
		var warp := _grass_forms.get_noise_2d(x+7113,z-3719)*settings.grass_foothill_size*0.12
		var ridge_noise := _grass_ridges.get_noise_2d((x+warp)*1.15,(z+x*0.26)*0.42)
		# Narrow rounded crest, broad traversable shoulders. Do not smoothstep
		# the ridge height: that saturated the backbone into inflated plateaus.
		var crest_width := lerpf(0.009,0.04,smoothstep(-0.4,0.4,structure))
		var ridge := clampf(1.0-(sqrt(ridge_noise*ridge_noise+crest_width*crest_width)-crest_width)/(sqrt(1.0+crest_width*crest_width)-crest_width),0.0,1.0)
		crest = (1.0-smoothstep(0.04,0.22,absf(ridge_noise)))*mountains
		var peak_variation := 0.74+lithology*0.38+drainage_axis*0.22
		# Different cross-sections on opposite sides of a connected spine.
		var backbone := pow(ridge,lerpf(1.3,3.4,smoothstep(-0.10,0.14,ridge_noise)))*peak_variation
		var mass := lerpf(0.3+roll*0.12,backbone,settings.grass_ridge_strength)
		var flank := smoothstep(0.02,0.16,absf(ridge_noise))*(1.0-smoothstep(0.6,0.95,absf(ridge_noise)))
		# Tributary divides bend with the parent ridge field. The finer cut
		# inherits this domain so it subdivides flanks instead of striping them.
		var branch := _grass_forms.get_noise_2d(x*0.55+warp,z*0.45+ridge_noise*400.0)
		var branch_ridge := 1.0-sqrt(branch*branch+0.0064)
		var tributary := _grass_forms.get_noise_2d(x*2.1+branch*130.0,z*1.6+ridge_noise*650.0)
		var drainage := pow(1.0-branch_ridge,1.3)*flank*0.3
		drainage += pow(1.0-absf(tributary),6.0)*flank*lerpf(0.035,0.11,smoothstep(0.18,0.4,absf(ridge_noise)))
		# Coherent drainage catchments leave clean faces between eroded sectors.
		drainage *= smoothstep(-0.35,0.25,structure)*0.85+0.15
		mass += (branch_ridge*branch_ridge-0.5)*flank*0.18*settings.grass_mountain_ruggedness
		mass -= drainage*settings.grass_erosion_strength
		mass *= 1.0+ridge_noise*0.22 # different lee and windward faces
		mass = maxf(mass,0.015)
		relief += mountains*settings.grass_mountain_height*mass
	if profile_build:
		field_timings["ridge_valley_us"]=field_timings.get("ridge_valley_us",0)+Time.get_ticks_usec()-timer
		timer=Time.get_ticks_usec()
	# Cap relief is shared by the saturated interior and wall blend. Keep
	# buildable benches while shallow divides drain toward broken margins.
	var cap_relief:=macro*28.0+roll*7.0
	if plateau>0.0:
		cap_relief+=roll*roll*18.0-(1.0-smoothstep(0.02,0.16,absf(drainage_axis)))*12.0
	if settings.grass_plateau_frequency>0.0 and plateau_distance>maxf(600.0,settings.grass_talus_width*2.0):
		# Saturated cap: exactly the same result, without computing wall/cut/fan terms.
		relief=settings.grass_plateau_height*(1.0+lithology*0.42)+cap_relief
		plateau=1.0
	elif settings.grass_plateau_frequency>0.0 and plateau_distance > -settings.grass_talus_width*3.6:
		var competence:=smoothstep(-0.28,0.25,lithology+structure*0.22)
		var apron_width:=settings.grass_talus_width*lerpf(0.7,1.8,clampf(lithology+0.5,0,1))
		var width:=settings.grass_cliff_width*lerpf(2.5,1.0,settings.grass_escarpment_strength)
		width=lerpf(apron_width*1.8,width,competence)
		# Canonical finite wall width, shared by every LOD. No per-LOD geography
		# change or near-vertical one-sample step. Far grids still use skirts.
		width=maxf(width,96.0)
		wall_precision=1.0-smoothstep(width+16.0,width+80.0,absf(plateau_distance))
		var wall:=smoothstep(-width*0.5,width*0.5,plateau_distance)
		var ledge_height:=clampf(0.5+structure*0.6,0.28,0.72)
		var ledged:=smoothstep(-width*0.95,-width*0.30,plateau_distance)*ledge_height+smoothstep(width*0.08,width*0.65,plateau_distance)*(1.0-ledge_height)
		wall=lerpf(wall,ledged,competence*smoothstep(-0.1,0.3,drainage_axis)*0.8)
		var apron:=smoothstep(-apron_width,width*0.2,plateau_distance)
		var shelf:=apron*0.32+wall*0.68
		var top:=settings.grass_plateau_height*(1.0+lithology*0.42)+cap_relief
		var foot:=relief
		relief=lerpf(relief,top,shelf)
		# Drainage corridors widen into fans below the edge. Inward they shallow
		# gradually: an elevated catchment, not a sea-level slot through the cap.
		var fan_width:=lerpf(0.032,0.13,1.0-smoothstep(-apron_width,0.0,plateau_distance))
		var corridor:=1.0-smoothstep(fan_width,fan_width+0.055,absf(drainage_axis))
		corridor*=smoothstep(-0.18,0.18,lithology)
		incision=corridor*(1.0-smoothstep(30.0,600.0,maxf(plateau_distance,0.0)))
		incision*=smoothstep(-apron_width*2.0,-apron_width*0.65,plateau_distance)*settings.grass_plateau_erosion
		var channel_floor:=lerpf(maxf(foot*0.2,5.0),top-12.0,smoothstep(-apron_width,550.0,plateau_distance))
		relief=lerpf(relief,minf(relief,channel_floor),incision)
		talus=apron*(1.0-wall)*competence*clampf((top-foot)/180.0,0,1)
		talus*=clampf(0.65+structure*0.7+corridor*0.6,0,1)
		talus=maxf(talus,corridor*apron*(1.0-wall)*0.8)
		relief+=talus*settings.grass_talus_relief*(1.0-incision*0.7)
		cliff_control=4.0*wall*(1.0-wall)*competence*(1.0-incision)
		plateau=shelf
	if profile_build:
		field_timings["plateau_cliff_talus_us"]=field_timings.get("plateau_cliff_talus_us",0)+Time.get_ticks_usec()-timer
		timer=Time.get_ticks_usec()
	var local := _detail_noise.get_noise_2d(x,z)
	relief += local*settings.grass_local_detail*(1.0-flatness*0.98)*(1.0-plateau*0.8)*(1.0-crest*0.9)
	if settings.grass_fractal_strength > 0.0:
		# Nested world-space frequencies break up smooth landforms without
		# fragmenting regional masks or moving the drainage network. Apply before
		# valley/basin shaping so their floors remain smoother than hillsides.
		var detail_mask := (1.0-flatness*0.99)*(1.0-plateau*0.85)*(1.0-crest*0.92)
		var ruggedness := (0.55+hills*0.65)*(1.0-mountains*0.55)
		relief += _grass_fractal.get_noise_2d(x,z)*settings.grass_fractal_strength*detail_mask*ruggedness
	if profile_build:
		field_timings["fractal_detail_us"]=field_timings.get("fractal_detail_us",0)+Time.get_ticks_usec()-timer
		timer=Time.get_ticks_usec()
	var wet := 0.0
	var drainage_influence := incision*0.65
	var bed := -settings.grass_river_depth
	if settings.grass_river_frequency > 0.0 and water_country>0.001:
		var spacing := 4000.0/maxf(settings.grass_river_frequency,0.01)
		# Main channels run through broad, meandering valleys. Tributaries join
		# these trunks rather than appearing as disconnected per-chunk lines.
		var lane := roundi(z/spacing)
		var nearest_lane := lane
		var across := INF
		var river_column := Vector3.ZERO
		for offset in range(-1,2):
			var column := _river_column(x,lane+offset,spacing)
			var delta := z-column.x
			if absf(delta) < absf(across):
				across = delta
				nearest_lane = lane+offset
				river_column=column
		# Approximate perpendicular distance, so steep bends do not pinch to a
		# thread merely because the centerline is represented as z(x).
		var river_slope := river_column.y
		var distance := absf(across)/sqrt(1.0+river_slope*river_slope)
		var bank_noise := _grass_water_noise.get_noise_2d(x*2.0,z*2.0)
		var width := maxf(settings.grass_river_width,1.0)*(1.0+bank_noise*0.55+river_column.z*0.35)
		# Tangent-based distance is only a local bank approximation. Applying
		# it hundreds of metres away magnified every meander derivative into
		# a repeated fan-shaped trench across hillsides (the comb/stripe bug).
		var valley_distance := absf(across)
		width*=lerpf(1.0,1.7,basin_country)*lerpf(1.0,0.65,canyon_country)
		var valley := 1.0-smoothstep(width*2.0,width*2.0+settings.grass_foothill_size*lerpf(0.65,0.12,canyon_country),valley_distance)
		var lowland_water := 1.0-smoothstep(0.05,0.4,maxf(mountains,plateau*0.7))
		lowland_water=maxf(lowland_water,canyon_country*(1.0-plateau))
		lowland_water*=water_country
		drainage_influence = maxf(drainage_influence,valley*lowland_water)
		# Mountain valleys retain an elevated floor instead of slicing every
		# range down to the sea-level plane in a repeated canal pattern.
		var valley_floor := lerpf(relief-minf(35.0,relief*0.1),4.0+roll*2.0,lowland_water)
		relief = lerpf(relief,valley_floor,valley*settings.grass_valley_strength)
		# A broad floodplain and low irregular terrace above the active banks.
		# Use stable across-distance here, never the local tangent correction.
		var floodplain := (1.0-smoothstep(width*2.2,width*lerpf(5.0,9.0,clampf(roll+0.5,0,1)),valley_distance))*lowland_water
		var terrace := smoothstep(width*1.6,width*3.0,valley_distance)
		relief = lerpf(relief,3.0+terrace*(2.0+bank_noise)+roll,floodplain*settings.grass_valley_strength)
		if floodplain>0.0:
			# Shallow abandoned-bank swales inside a wider lowland floodplain.
			var swale:=1.0-smoothstep(width*0.2,width*0.8,absf(valley_distance-width*(3.2+river_column.z)))
			relief-=swale*floodplain*0.75
		wet = 1.0-smoothstep(width*0.35,width*1.7,distance)
		wet *= lowland_water
		bed *= 0.65+0.35*(1.0-clampf(distance/width,0,1))
		# One-sided tributaries join tangentially, not perpendicular grid lines
		# crossing the main channel and continuing through the opposite bank.
		if lowland_water > 0.0:
			var segment_size := spacing*0.6
			var segment := floori(x/segment_size)
			for k in range(-1,2):
				var branch := segment+k
				var random := _region_random(branch,nearest_lane,97,617)
				if random > 0.7:
					continue
				var start := (branch+0.1+random*0.3)*segment_size
				var t := (x-start)/(segment_size*lerpf(0.5,0.9,random))
				if t < 0.0 or t > 1.0:
					continue
				var side := -1.0 if _region_random(branch,nearest_lane,97,619)<0.5 else 1.0
				var offset := side*spacing*0.24*t*t
				offset += _grass_water_noise.get_noise_2d(x*1.8,branch*931.0)*spacing*0.045*t*t
				var branch_slope := river_slope+side*spacing*0.48*t/(segment_size*lerpf(0.5,0.9,random))
				var tributary := absf(across-offset)/sqrt(1.0+branch_slope*branch_slope)
				var reach := 1.0-smoothstep(0.65,1.0,t)
				var stream_width := width*lerpf(0.65,0.18,t)
				var stream := (1.0-smoothstep(stream_width*0.4,stream_width*1.7,tributary))*reach
				var stream_valley := (1.0-smoothstep(stream_width,stream_width+80.0,absf(across-offset)))*reach
				relief = lerpf(relief,5.0,stream_valley*settings.grass_valley_strength*lowland_water)
				wet = maxf(wet,stream*lowland_water)
				drainage_influence = maxf(drainage_influence,stream_valley*lowland_water)
	# Sparse bounded lake sites; no growing cache or neighboring chunk queries.
	# Lakes favor low regional relief; larger basins share drainage corridors.
	if settings.grass_lake_frequency > 0.0 and mountains < 0.4 and plateau<0.4 and basin_country>0.05:
		var lake_pitch := maxf(settings.grass_lake_size*5.0,1200.0)
		var cell := Vector2i(floori(x/lake_pitch),floori(z/lake_pitch))
		for descriptor in _lake_sites(cell,lake_pitch):
			var center := Vector2(descriptor.x,descriptor.y)
			var radius := descriptor.z
			var p := Vector2(x,z)-center
			if p.length_squared() > radius*radius*9.0:
				continue
			p = p.rotated(descriptor.w)
			p /= maxf(radius,1.0)
			# Unequal connected lobes plus shoreline-scale distortion create
			# coves/headlands rather than an ellipse with a tiny noisy edge.
			p += Vector2(_grass_water_noise.get_noise_2d(x*2,z*2),_grass_water_noise.get_noise_2d(x*2+3187,z*2-971))*0.3
			var main := Vector2(p.x/0.85,p.y/0.65).length()
			var lobe := (p-Vector2(0.48,0.25)).length()/0.6
			var arm := Vector2((p.x+0.55)/0.65,(p.y-0.25)/0.28).length()
			var contour := minf(main,minf(lobe,arm))
			var lowland := 1.0-smoothstep(0.1,0.4,maxf(mountains,plateau))
			lowland*=lerpf(1.0,basin_country,settings.grass_geographic_variety)
			# A broader depositional shore on one side, a tighter bedrock margin
			# on the other; the existing local descriptor gives a stable orientation.
			var basin_extent:=1.6+clampf(p.x*0.2+roll*0.25,-0.25,0.45)
			var basin := (1.0-smoothstep(0.7,basin_extent,contour))*lowland
			drainage_influence = maxf(drainage_influence,basin)
			relief = lerpf(relief,2.0+smoothstep(1.0,basin_extent,contour)*(4.0+roll*2.0),basin)
			var lake := (1.0-smoothstep(0.65,1.12,contour))*lowland
			var lake_bed := -settings.grass_lake_depth*(0.3+0.7*(1.0-clampf(contour,0,1)))+local*0.3
			bed = lerpf(bed,lake_bed,lake)
			wet = maxf(wet,lake)
	_last_surface = Vector2(maxf(mountains,plateau),maxf(drainage_influence,wet))
	if profile_build:
		field_timings["water_and_bank_us"]=field_timings.get("water_and_bank_us",0)+Time.get_ticks_usec()-timer
	_last_geology = Vector3(talus,incision,cliff_control)
	# Broad damp valleys do not need exact re-evaluation between 4 m nodes.
	# Preserve exact narrow banks, wall transitions and crests instead.
	_last_precision=maxf(wall_precision,maxf(smoothstep(0.0,0.03,wet*(1.0-wet)),crest))
	return Vector3(relief,wet,bed)


func geographic_identity(x: float,z: float) -> Vector2:
	var scale:=settings.grass_landform_size/maxf(settings.grass_geographic_scale,1000.0)
	return Vector2(_grass_region.get_noise_2d(x*scale+51371,z*scale-21319),_grass_region.get_noise_2d(x*scale-19871,z*scale+89131))*0.5+Vector2.ONE*0.5


func _sample_grid_height(x: float,z: float) -> float:
	# Exact shared mesh/halo positions only. Nonintegral or very distant queries
	# bypass this cache instead of rounding keys and changing the height function.
	if absf(x)>2000000000.0 or absf(z)>2000000000.0 or x!=floorf(x) or z!=floorf(z):
		return _get_height(x,z)
	# Fine interior points are almost never shared with another tile. Caching
	# nine Variants for each one churned the bounded cache before coarser LODs
	# could reuse its canonical 32 m nodes. Keep exact heights; skip only memo
	# allocation for non-node positions, never interpolate or round a key.
	if not cache_dense_payloads and ((int(x)&31)!=0 or (int(z)&31)!=0):return _get_height(x,z)
	var key:=Vector2i(int(x),int(z))
	if _height_grid_cache.has(key):
		var entry: Array=_height_grid_cache[key]
		_last_jungle=entry[5]
		if _forest!=null:_last_forest=entry[6] if entry.size()>6 else _forest_neutral
		if _savanna!=null:_last_savanna=entry[7] if entry.size()>7 else _forest_neutral
		if _swamp!=null:_last_swamp=entry[8];_last_swamp_water=entry[9]
		if _mountain!=null:_last_mountain=entry[10];_last_swamp_water=entry[9]
		if _coast!=null:_last_coast=entry[11];_last_swamp_water=entry[9]
		if _tropical!=null:_last_tropical=entry[12];_last_swamp_water=entry[9]
		if _badlands!=null:_last_badlands=entry[13];_last_swamp_water=entry[9]
		if _badlands!=null:_last_badlands_palette=entry[15] if entry.size()>15 else Vector4.ZERO
		if _badlands!=null:_last_badlands_remnant=entry[16] if entry.size()>16 else 0
		if _badlands!=null:_last_badlands_skirt=entry[17] if entry.size()>17 else 0
		if _extras_enabled:_last_extras=entry[14];_last_swamp_water=entry[9]
		_last_weights=entry[1];_last_surface=entry[2];_last_geology=entry[3];_last_island=entry[4]
		return entry[0]
	var height:=_get_height(x,z)
	if _height_grid_cache.size()>=8192: _height_grid_cache.clear()
	var entry:Array=[height,_last_weights,_last_surface,_last_geology,_last_island,_last_jungle]
	if _forest!=null or _savanna!=null or _swamp!=null or _mountain!=null or _coast!=null or _tropical!=null or _badlands!=null:entry.append(_last_forest)
	if _savanna!=null or _swamp!=null or _mountain!=null or _coast!=null or _tropical!=null or _badlands!=null:entry.append(_last_savanna)
	if _swamp!=null or _mountain!=null or _coast!=null or _tropical!=null or _badlands!=null:entry.append(_last_swamp);entry.append(_last_swamp_water)
	if _mountain!=null or _coast!=null or _tropical!=null or _badlands!=null:entry.append(_last_mountain)
	if _coast!=null or _tropical!=null or _badlands!=null:entry.append(_last_coast)
	if _tropical!=null or _badlands!=null:entry.append(_last_tropical)
	if _badlands!=null:entry.append(_last_badlands)
	if _extras_enabled:
		while entry.size()<14:entry.append(null)
		entry[6]=_last_forest;entry[7]=_last_savanna;entry[8]=_last_swamp;entry[9]=_last_swamp_water;entry[10]=_last_mountain;entry[11]=_last_coast;entry[12]=_last_tropical;entry[13]=_last_badlands;entry.append(_last_extras)
	if _badlands!=null:
		while entry.size()<18:entry.append(null)
		entry[15]=_last_badlands_palette
		entry[16]=_last_badlands_remnant
		entry[17]=_last_badlands_skirt
	_height_grid_cache[key]=entry
	return height


func _select_normal_height_cache_capacity()->void:
	var coastal_organic:bool=coastal_structure_height_cache_enabled and _coast!=null and _extras.size()>7 and _extras[7]!=null and chunk_size>=8192
	_normal_height_cache_capacity=65536 if coastal_organic else 8192
	# A worker may build a fine tile immediately after a coarse tile. Shrinking
	# cannot leave a formerly large memo retained until the next cache miss.
	if _normal_height_cache.size()>_normal_height_cache_capacity:_normal_height_cache.clear()

func _sample_normal_height(x: float, z: float) -> float:
	# Never insert height-only entries into the full vertex-payload cache.
	# Integer keys are exact, as in _sample_grid_height; distant/fractional
	# queries bypass caching rather than rounding canonical coordinates.
	if absf(x)>2000000000.0 or absf(z)>2000000000.0 or x!=floorf(x) or z!=floorf(z):
		return _get_height(x,z,false)
	var key:=Vector2i(int(x),int(z))
	if _height_grid_cache.has(key): return _height_grid_cache[key][0]
	if _normal_height_cache.has(key): return _normal_height_cache[key]
	var height:=_get_height(x,z,false)
	if _normal_height_cache.size()>=_normal_height_cache_capacity: _normal_height_cache.clear()
	_normal_height_cache[key]=height
	return height


func _get_height(world_x:float,world_z:float,publish_controls:bool=true)->float:
	if _extras_enabled:_last_extras=PackedVector4Array();_last_extras.resize(8);_last_extras.fill(Vector4.ZERO)
	_last_badlands=Vector3.ZERO
	_last_badlands_palette=Vector4.ZERO
	_last_badlands_remnant=0
	_last_badlands_skirt=0
	_last_tropical=Vector3.ZERO
	_last_coast=Vector4.ZERO
	_last_jungle=0;_last_surface=Vector2.ZERO;_last_geology=Vector3.ZERO;_last_weights=Vector4.ZERO
	if _forest!=null:_last_forest=_forest_neutral
	if _savanna!=null:_last_savanna=_forest_neutral
	if _swamp!=null:_last_swamp=_forest_neutral
	_last_swamp_water=water_level
	if _mountain!=null:_last_mountain=PackedFloat32Array([0,0,0,0])
	_height_query=true
	var island:float=_island_mask(world_x,world_z)
	_height_query=false;_last_island=island
	var shore_distance:float=island*maxf(settings.island_size*.5,8)
	var shore_transition:float=maxf(settings.coast_width*694.445,.1)
	var shape_scale:float=maxf(settings.terrain_shape_scale,.01)
	var coast_state:=PackedFloat64Array()
	if _coast!=null and _coast.may_affect(world_x,world_z,shore_distance):
		_coast.sample(world_x,world_z,0,shore_distance,true);coast_state=_coast.state
		if coast_state[2]==1:
			# Fully replaced coastal vertices need no hidden inland landforms.
			# Keep ownership canonical, but do not calculate invisible material banks.
			_last_weights=_biome_weights(world_x,world_z)
			if publish_controls:_last_coast=_coast_payload(coast_state)
			_last_swamp_water=water_level+coast_state[1]*maxf(settings.height_multiplier,.01)
			return water_level+coast_state[0]*maxf(settings.height_multiplier,.01)
	if island<=0:
		var detail:float=_detail_noise.get_noise_2d(world_x/shape_scale,world_z/shape_scale)
		var floor_height:float=minf(-maxf(settings.ocean_depth,1)+detail*settings.seabed_relief,-1)
		return _apply_coast(world_x,world_z,water_level+floor_height*minf(-shore_distance/shore_transition,1)*maxf(settings.height_multiplier,.01),shore_distance,publish_controls,coast_state)
	_last_weights=_biome_weights(world_x,world_z)
	var jungle_weight:float=_jungle_weight;var mountain_weight:float=_mountain_weight;var tropical_weight:float=_tropical_weight
	var land:float=0
	if _last_weights.x>0:
		var profile:Vector3=_grass_sample(world_x/shape_scale,world_z/shape_scale)
		land=lerpf(maxf(1,profile.x),profile.z,profile.y)*_last_weights.x
	if jungle_weight>0:land+=_jungle_height(world_x,world_z,jungle_weight,publish_controls)*jungle_weight
	if _last_weights.y>0:land+=_forest_height(world_x,world_z,_last_weights.y,publish_controls)*_last_weights.y
	if _last_weights.z>0:land+=_savanna_height(world_x,world_z,_last_weights.z,publish_controls)*_last_weights.z
	if _last_weights.w>0:
		land+=_swamp_height(world_x,world_z,_last_weights.w,publish_controls)*_last_weights.w
		_last_swamp_water=water_level+_swamp.state[1]*_last_weights.w*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
	if mountain_weight>0:
		land+=_mountain_height(world_x,world_z,mountain_weight,publish_controls)*mountain_weight
		_last_swamp_water+=_mountain.state[1]*mountain_weight*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
	if tropical_weight>0:
		land+=_tropical_height(world_x,world_z,tropical_weight,publish_controls)*tropical_weight
		_last_swamp_water+=_tropical.state[1]*tropical_weight*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
	if _badlands_weight>0:
		var bw:float=_badlands_weight
		land+=_badlands.sample(world_x,world_z,publish_controls)*bw
		var s:PackedFloat64Array=_badlands.state
		if publish_controls:
			_last_badlands_palette=_badlands.palette_state
			_last_badlands_remnant=bw*s[10]
			_last_badlands_skirt=bw*_badlands.remnant_delta*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
			_last_swamp_water+=s[1]*bw*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
			_last_badlands=Vector3(bw,s[2],s[3])
			_last_geology=_last_geology.lerp(Vector3(s[4],s[5],s[6]),bw)
			_last_surface=_last_surface.lerp(Vector2(s[7],s[8]),bw)
	if _extras_enabled:
		for i in range(8):
			var amount:float=_extra_weights[i]
			if amount<=0:continue
			land+=_extras[i].sample(world_x,world_z,true)*amount
			var e:PackedFloat64Array=_extras[i].state
			_last_swamp_water+=e[1]*amount*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01)
			if publish_controls:_last_extras[i]=Vector4(amount,e[2],e[3],e[4])
		if _extras[7]!=null and settings.alien_infected.overlay_strength>0:
			var network:Dictionary=_extras[7].network(Vector2(world_x,world_z));var influence:float=network.influence*settings.alien_infected.overlay_strength*(1-_extra_weights[7])
			land+=influence*settings.alien_infected.nerve_height*exp(-pow(network.trunk_distance/100,2))
			if influence>0 and settings.alien_infected.nerve_fibre_height>0:
				land+=influence*_extras[7].nerve_fibre_relief(Vector2(world_x,world_z))
			if publish_controls:
				for i in range(7):_last_extras[i].x*=1-influence
				var previous:Vector4=_last_extras[7];_last_extras[7]=Vector4(previous.x+(1-previous.x)*influence,.5,clampf(network.age,0,1),network.influence)
	return _apply_coast(world_x,world_z,water_level+land*smoothstep(0,shore_transition,shore_distance)*maxf(settings.height_multiplier,.01),shore_distance,publish_controls,coast_state)


func _apply_coast(_x:float,_z:float,base:float,_distance:float,publish:bool,c:PackedFloat64Array)->float:
	if _coast==null or c.is_empty() or c[2]<=0:return base
	var mult:float=maxf(settings.height_multiplier,.01)
	_last_swamp_water=lerpf(_last_swamp_water,water_level+c[1]*mult,c[2])
	if publish:_last_coast=_coast_payload(c)
	return water_level+lerpf((base-water_level)/mult,c[0],c[2])*mult

func _coast_payload(c:PackedFloat64Array)->Vector4:
	var sediment:float=c[5]
	if c.size()>20 and c[19]>.001:sediment=-_pack_savanna(c[19],c[20],0)-1
	return Vector4(c[2],c[3],c[4],sediment)


func _jungle_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_jungle.sample(x,z,true);var config:JungleSettings=_jungle.settings
	var region_weights:PackedFloat32Array=_jungle.weights
	var river_country:float=region_weights[5]+region_weights[6]+region_weights[10]*.7
	var valley:float=0;var channel:float=0;var lake:float=0
	if config.river_frequency>0 and settings.grass_river_frequency>0 and settings.water_enabled:
		# Use the EXISTING world carriers and spacing, also in mixed Grass/Snow
		# terrain. New widths/terraces do not introduce a second river network.
		var spacing:float=4000.0/maxf(settings.grass_river_frequency,.01)
		var lane:int=roundi(z/spacing)
		for offset in range(-1,2):
			var carrier:Vector3=_river_column(x,lane+offset,spacing)
			var distance:float=absf(z-carrier.x)
			var width:float=config.river_width*lerpf(.6,1.9,river_country)*(1+carrier.z*.3)
			var reach:float=clampf(config.river_frequency,0,1)
			var corridor:float=(1-smoothstep(width*2,width*2+config.river_valley_width,distance))*reach
			var lowland:float=1-smoothstep(100,240,h)
			var gorge:float=region_weights[10]
			var floor_height:float=lerpf(maxf(6,h-config.valley_depth),4,clampf(lowland+gorge,0,1))
			h=lerpf(h,floor_height,corridor)
			var flood:float=(1-smoothstep(width*1.8,width*5,distance))*lowland*config.floodplain_influence
			h=lerpf(h,3+smoothstep(width*1.2,width*4,distance)*4,flood)
			var wet:float=(1-smoothstep(width*.4,width*1.6,distance/sqrt(1+carrier.y*carrier.y)))*clampf(lowland+gorge,0,1)*reach
			channel=maxf(channel,wet);valley=maxf(valley,corridor)
			# Existing one-sided tributary construction; tangent join, finite reach.
			if config.stream_density>0 and lowland>.05:
				var span:float=spacing*.6;var segment:int=floori(x/span)
				for k in range(-1,2):
					var branch:int=segment+k;var r:float=_region_random(branch,lane+offset,97,617)
					if r>config.tributary_density:continue
					var t:float=(x-(branch+.1+r*.3)*span)/(span*lerpf(.5,.9,r))
					if t<=0 or t>=1:continue
					var side:float=-1 if _region_random(branch,lane+offset,97,619)<.5 else 1
					var across:float=z-carrier.x-side*spacing*.24*t*t
					var sw:float=width*lerpf(.5,.15,t)*config.stream_density
					var stream:float=(1-smoothstep(sw*.4,sw*1.7,absf(across)))*(1-smoothstep(.65,1,t))*lowland
					channel=maxf(channel,stream)
	if config.lake_frequency>0 and settings.grass_lake_frequency>0 and settings.water_enabled and h<100:
		var pitch:float=maxf(settings.grass_lake_size*5,1200);var cell:=Vector2i(floori(x/pitch),floori(z/pitch))
		for site:Vector4 in _lake_sites(cell,pitch):
			if _region_random(floori(site.x),floori(site.y),103,19)>config.lake_frequency:continue
			var p:Vector2=(Vector2(x,z)-Vector2(site.x,site.y)).rotated(site.w)/maxf(site.z,1)
			var contour:float=minf(Vector2(p.x/.85,p.y/.65).length(),(p-Vector2(.48,.25)).length()/.6)
			lake=maxf(lake,1-smoothstep(.65,1.12,contour))
	var water:float=maxf(channel,lake)
	h=lerpf(h,-maxf(settings.grass_river_depth,settings.grass_lake_depth),water)
	if publish:
		_jungle.river=channel;_jungle.lake=lake
		_jungle.drainage=maxf(_jungle.drainage,valley)
		_jungle.wetness=clampf(_jungle.wetness+valley*.2+water*.35,0,1)
		_last_jungle=roundi(_jungle.wetness*255)+roundi(_jungle.drainage*255)*256+roundi(weight*255)*65536
		_last_geology=_last_geology.lerp(Vector3(float(_jungle.region)/12.0,_jungle.rock,water),weight)
	return h


func _forest_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_forest.sample(x,z,true);var config:Resource=_forest.settings
	var w:PackedFloat32Array=_forest.weights
	var valley:float=0;var river:float=0;var lake:float=0
	var lowland:float=(1-smoothstep(100,220,h))*clampf(.4+w[0]*.35+w[3]*.35+w[7]*.6+w[8],0,1)
	if settings.water_enabled and settings.grass_river_frequency>0 and config.river_influence>0:
		var spacing:float=4000/maxf(settings.grass_river_frequency,.01);var lane:int=roundi(z/spacing)
		for offset in range(-1,2):
			var carrier:Vector3=_river_column(x,lane+offset,spacing)
			var distance:float=absf(z-carrier.x)/sqrt(1+carrier.y*carrier.y)
			var width:float=config.river_width*(.65+w[8]*.8)*(1+carrier.z*.25)
			var corridor:float=(1-smoothstep(width*2,width*2+config.river_valley_width,distance))*config.river_influence
			h=lerpf(h,maxf(4,h-config.ravine_depth),corridor)
			var flood:float=(1-smoothstep(width*1.4,width*5,distance))*lowland
			h=lerpf(h,3+smoothstep(width,width*4,distance)*5,flood)
			valley=maxf(valley,corridor*lowland)
			river=maxf(river,(1-smoothstep(width*.45,width*1.55,distance))*lowland*config.river_influence)
			if config.stream_density>0 and lowland>.1:
				var span:float=spacing*.6;var segment:int=floori(x/span)
				for k in range(-1,2):
					var branch:int=segment+k;var r:float=_region_random(branch,lane+offset,97,617)
					if r>config.stream_density:continue
					var t:float=(x-(branch+.1+r*.3)*span)/(span*lerpf(.5,.9,r))
					if t<=0 or t>=1:continue
					var side:float=-1 if _region_random(branch,lane+offset,97,619)<.5 else 1
					var across:float=z-carrier.x-side*spacing*.24*t*t
					var sw:float=width*lerpf(.42,.12,t)
					var reach:float=(1-smoothstep(.65,1,t))*lowland
					var tributary_valley:float=(1-smoothstep(sw*1.5,sw+80,absf(across)))*reach
					h=lerpf(h,5,tributary_valley);valley=maxf(valley,tributary_valley)
					river=maxf(river,(1-smoothstep(sw*.4,sw*1.7,absf(across)))*reach)
	if settings.water_enabled and settings.grass_lake_frequency>0 and config.lake_frequency>0 and h<100 and w[3]+w[7]+w[8]>.15:
		var pitch:float=maxf(settings.grass_lake_size*5,1200);var cell:=Vector2i(floori(x/pitch),floori(z/pitch))
		for site:Vector4 in _lake_sites(cell,pitch):
			if _region_random(floori(site.x),floori(site.y),103,19)>config.lake_frequency:continue
			var p:Vector2=(Vector2(x,z)-Vector2(site.x,site.y)).rotated(site.w)/maxf(site.z,1)
			var contour:float=minf(Vector2(p.x/.9,p.y/.65).length(),minf((p-Vector2(.5,.2)).length()/.6,Vector2((p.x+.55)/.6,(p.y-.2)/.3).length()))
			var basin:float=1-smoothstep(.65,1.8,contour)
			h=lerpf(h,4+smoothstep(.65,1.5,contour)*5,basin*lowland)
			lake=maxf(lake,(1-smoothstep(.65,1.1,contour))*lowland)
	var water:float=maxf(river,lake);h=lerpf(h,-maxf(settings.grass_river_depth,settings.grass_lake_depth),water)
	if publish:
		_forest.river=river;_forest.lake=lake;_forest.drainage=maxf(_forest.drainage,valley)
		_forest.wetness=clampf(_forest.wetness+valley*.15+water*.3,0,1)
		_last_forest=PackedFloat32Array([roundi(_forest.wetness*255)+roundi(_forest.drainage*255)*256+roundi(weight*255)*65536,roundi(_forest.conifer*255)+roundi(_forest.clearing*255)*256+roundi(float(_forest.region)/9*255)*65536,_forest.rock,water])
	return h


func _savanna_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_savanna.sample(x,z,true);var c:Resource=_savanna.settings
	var w:PackedFloat32Array=_savanna.weights
	var drain:float=0;var channel:float=0;var basin:float=0;var water:float=0
	# Same meandering carriers as all active biomes, not a separate river graph.
	# Dry beds remain geometric even with the water renderer switched off.
	if settings.grass_river_frequency>0 and c.drainage_strength>0 and c.seasonal_channel_frequency>0:
		var spacing:float=4000/maxf(settings.grass_river_frequency,.01);var lane:int=roundi(z/spacing)
		for offset in range(-1,2):
			var id:int=lane+offset;var roll:float=_region_random(id,0,97,811)
			if roll>c.seasonal_channel_frequency:continue
			var carrier:Vector3=_river_column(x,id,spacing)
			var distance:float=absf(z-carrier.x)/sqrt(1+carrier.y*carrier.y)
			var width:float=(35+w[7]*40+w[8]*80)*(1+carrier.z*.22)
			# Conservative support bounds: distant carriers and their finite
			# tributaries cannot affect this sample. No approximation of height.
			if distance>width*2+c.valley_width and absf(z-carrier.x)>spacing*.2+width*.4+55:continue
			var valley:float=(1-smoothstep(width*2,width*2+c.valley_width,distance))*c.drainage_strength
			var low:float=(1-smoothstep(90,190,h))*clampf(.3+w[3]*.2+w[7]*.5+w[8]+w[12]*.5,0,1)
			h=lerpf(h,maxf(5,h-22-w[7]*18),valley)
			var bed:float=1-smoothstep(width*.4,width*1.8,distance)
			h=lerpf(h,maxf(3,h-8-w[7]*8),bed*c.drainage_strength)
			channel=maxf(channel,bed*c.drainage_strength);drain=maxf(drain,valley)
			# Whole carrier selection preserves a coherent perennial reach.
			var perennial:float=0
			if c.perennial_frequency>0:perennial=(1-smoothstep(c.perennial_frequency*.8,c.perennial_frequency+.001,roll))*low
			water=maxf(water,bed*perennial)
			if c.gully_frequency>0:
				var span:float=spacing*.65;var segment:int=floori(x/span)
				for k in range(-1,2):
					var branch:int=segment+k;var key:=Vector2i(branch,id)
					if not _savanna_gullies.has(key):
						if _savanna_gullies.size()>=1024:_savanna_gullies.clear()
						var roll_g:float=_region_random(branch,id,97,817)
						_savanna_gullies[key]=[roll_g,(branch+.1+roll_g*.3)*span,-1.0 if _region_random(branch,id,97,819)<.5 else 1.0]
					var descriptor:Array=_savanna_gullies[key];var r:float=descriptor[0]
					if r>c.gully_frequency:continue
					var t:float=(x-float(descriptor[1]))/(span*.72)
					if t<=0 or t>=1:continue
					var side:float=descriptor[2]
					var across:float=z-carrier.x-side*spacing*.2*t*t
					var width_g:float=width*lerpf(.4,.12,t)
					var g:float=(1-smoothstep(width_g,width_g+55,absf(across)))*smoothstep(0,.08,t)*(1-smoothstep(.65,1,t))*c.erosion_intensity
					h=lerpf(h,maxf(3,h-12),g);drain=maxf(drain,g);channel=maxf(channel,g*.8)
	if c.basin_frequency>0 and w[8]+w[12]>.02:
		var pitch:float=maxf(settings.grass_lake_size*5,1400);var cell:=Vector2i(floori(x/pitch),floori(z/pitch))
		for site:Vector4 in _lake_sites(cell,pitch):
			var roll:float=_region_random(floori(site.x),floori(site.y),103,829)
			if roll>c.basin_frequency*2:continue
			var p:Vector2=(Vector2(x,z)-Vector2(site.x,site.y)).rotated(site.w)/maxf(site.z*1.3,1)
			var contour:float=minf(Vector2(p.x/.95,p.y/.58).length(),minf((p-Vector2(.6,.2)).length()/.55,Vector2((p.x+.55)/.7,(p.y-.2)/.38).length()))
			var b:float=(1-smoothstep(.5,1.9,contour))*clampf(w[8]+w[12],0,1)*(1-smoothstep(55,100,h))
			h=lerpf(h,3.5+smoothstep(.6,1.8,contour)*5,b);basin=maxf(basin,b)
			if settings.grass_lake_frequency>0 and roll<c.basin_water_coverage*c.basin_frequency:water=maxf(water,(1-smoothstep(.5,1,contour))*b)
	h=lerpf(h,-maxf(settings.grass_river_depth,2),water)
	if publish:
		_savanna.river=channel;_savanna.lake=basin;_savanna.water=water;_savanna.drainage=maxf(_savanna.drainage,drain)
		_savanna.wetness=clampf(_savanna.wetness+water*.4+drain*.1,0,1)
		_last_savanna=PackedFloat32Array([_pack_savanna(_savanna.wetness,_savanna.drainage,weight),_pack_savanna(_savanna.rock,_savanna.laterite,float(_savanna.region)/12),_pack_savanna(channel,basin,water),_pack_savanna(_savanna.aridity,_savanna.soil,_savanna.erosion)])
	return h


func _pack_savanna(a:float,b:float,c:float)->float:
	return roundi(clampf(a,0,1)*255)+roundi(clampf(b,0,1)*255)*256+roundi(clampf(c,0,1)*255)*65536



func _mountain_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_mountain.sample(x,z,true);var s:PackedFloat64Array=_mountain.state
	h=lerpf(minf(h,s[1]+80),h,smoothstep(.05,.9,weight))
	if publish:
		_last_mountain=PackedFloat32Array([_pack_savanna(s[2],s[3],weight),_pack_savanna(s[4],s[5],s[6]),_pack_savanna(s[7],s[8],s[9]),s[10]])
	return h

func _tropical_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_tropical.sample(x,z,true);var s:PackedFloat64Array=_tropical.state
	if publish:
		_last_tropical=Vector3(weight,s[2],s[3])
		# Reuse the legacy geological environmental field, including its existing
		# Mountain extension wrapper. No additional bank or per-chunk texture.
		_last_geology=_last_geology.lerp(Vector3(s[4],s[5],s[6]),weight)
		_last_surface=_last_surface.lerp(Vector2(s[7],s[6]),weight)
	return h

func _swamp_height(x:float,z:float,weight:float,publish:bool)->float:
	var h:float=_swamp.sample(x,z,true)
	if publish:
		var s:PackedFloat64Array=_swamp.state
		_last_swamp=PackedFloat32Array([_pack_savanna(s[2],s[3],weight),_pack_savanna(s[4],s[5],s[6]),_pack_savanna(s[7],s[8],s[9]),_pack_savanna(s[10],s[11],s[12])])
	return h

func get_water_surface_height(x:float,z:float)->float:
	if not _extras_enabled and _swamp==null and _mountain==null and _coast==null and _tropical==null and _badlands==null:return water_level
	_get_height(x,z)
	return _last_swamp_water

## Worker-only numerical surface; shared indices align water clipping with land.
func build_swamp_water(arrays:Array,resolution:int)->Array:
	var result:Array=[]
	if not settings.water_enabled:return result
	var mountain:bool=false
	if _mountain!=null:
		for v:float in arrays[Mesh.ARRAY_CUSTOM0]:
			if v<0:mountain=true;break
	var coastal:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1] if arrays[Mesh.ARRAY_CUSTOM1]!=null else PackedFloat32Array()
	if arrays[Mesh.ARRAY_CUSTOM3]==null and not mountain and coastal.is_empty() and _badlands==null and not _extras_enabled:return result
	var count:int=(resolution+1)*(resolution+1)
	var terrain:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var controls:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM3] if arrays[Mesh.ARRAY_CUSTOM3]!=null else PackedFloat32Array()
	var tropical_controls:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM2] if arrays[Mesh.ARRAY_CUSTOM2]!=null else PackedFloat32Array()
	var mountain_controls:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
	var mountain_stride:int=mountain_controls.size()/terrain.size()
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uvs:=PackedVector2Array();var classes:=PackedVector2Array()
	vertices.resize(count);normals.resize(count);colors.resize(count);uvs.resize(count);classes.resize(count)
	var wet:=PackedByteArray();wet.resize(count)
	var marine:=PackedByteArray();marine.resize(count)
	for i in range(count):
		var weight:float=floorf(controls[i*4]/65536)/255 if not controls.is_empty() else 0
		if not controls.is_empty() and controls[i*4]<0:weight=arrays[Mesh.ARRAY_COLOR][i].a
		var tw:float=float((int(-tropical_controls[i*4]-1)>>16)&255)/255 if not tropical_controls.is_empty() and tropical_controls[i*4]<0 else 0
		# Badlands UV wrapper is orthogonal to every existing custom bank.
		if mountain_stride==4 and mountain_controls[i*4+3]<0:tw+=float(int(uv[i].y)&255)/255
		if built_extension_mask!=0 and not built_extension_data.is_empty():
			var ex:float=0;var row:int=resolution+1;var width:int=built_extension_data.size()/(row*4)
			for family_id in range(8):
				if (built_extension_mask & (1<<family_id))==0:continue
				ex+=float(built_extension_data[((i/row)*width+family_id*row+i%row)*4])/255
			tw+=ex
		var sediment:float=float(int(controls[i*4+1])&255)/255 if not controls.is_empty() else 0
		var organic:float=float((int(controls[i*4+3])>>8)&255)/255 if not controls.is_empty() else 0
		var basin:float=float((int(controls[i*4+1])>>16)&255)/255 if not controls.is_empty() else 0
		var mw:float=floorf(mountain_controls[i*mountain_stride+1]/65536)/255 if mountain and mountain_controls[i*mountain_stride]<0 else 0
		var cw:float=float((int(-coastal[i*4+2]-1)>>8)&255)/255 if not coastal.is_empty() and coastal[i*4+2]<0 else 0
		# The global ocean owns marine water. Only retained, elevated coastal
		# pools need this local grid; a sea-level duplicate causes wave z-fighting.
		var coast_influence:float=cw
		mw*=1-coast_influence
		tw*=1-coast_influence
		if coast_influence>.01 and uv[i].x<=water_level+.2:
			cw=0;mw=0;weight=0;tw=0
			if settings.beaches_enabled:marine[i]=1
		if mw>0:
			sediment=lerpf(sediment,float((int(mountain_controls[i*mountain_stride+1])>>8)&255)/255,mw);organic*=1-mw
		if tw>0:sediment=lerpf(sediment,.45,tw);organic*=1-tw
		if cw>0:
			weight*=1-cw;sediment=lerpf(sediment,float((int(coastal[i*4+3])>>16)&255)/255,cw);organic*=1-cw
		vertices[i]=Vector3(terrain[i].x,uv[i].x,terrain[i].z);normals[i]=Vector3.UP
		colors[i]=Color(sediment,organic,weight,basin);uvs[i]=Vector2(terrain[i].y,uv[i].x)
		classes[i]=Vector2(float((int(controls[i*4+1])>>8)&255)/255,float((int(controls[i*4+3])>>16)&255)/255) if not controls.is_empty() else Vector2.ZERO
		if mw+cw+tw>0:classes[i].y=-maxf(maxf(mw,cw),tw)
		if cw>0:classes[i].x=-cw
		if weight+mw+cw+tw>.01 and uv[i].x+weight>terrain[i].y:wet[i]=1
	var indices:=PackedInt32Array();var source:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for i in range(0,resolution*resolution*6,3):
		var a:int=source[i];var b:int=source[i+1];var c:int=source[i+2]
		if wet[a]+wet[b]+wet[c]>0 and marine[a]+marine[b]+marine[c]==0:indices.append_array(PackedInt32Array([a,b,c]))
	if indices.is_empty():return result
	result.resize(Mesh.ARRAY_MAX);result[Mesh.ARRAY_VERTEX]=vertices;result[Mesh.ARRAY_NORMAL]=normals;result[Mesh.ARRAY_COLOR]=colors;result[Mesh.ARRAY_TEX_UV]=uvs;result[Mesh.ARRAY_TEX_UV2]=classes;result[Mesh.ARRAY_INDEX]=indices
	return result


func _normalized_noise(noise: FastNoiseLite, x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 0.5 + 0.5
