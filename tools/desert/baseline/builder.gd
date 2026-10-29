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
var _lake_cache: Dictionary = {}
var _index_templates: Dictionary = {}
var _grass_grid: Dictionary = {}
var _coast_certificates: Dictionary = {}
var _height_grid_cache: Dictionary = {}
var _height_query := false
var _last_precision := 0.0
var settings: TerrainSettings = preload("res://terrain_settings.tres")
# Hierarchical, non-overlapping regions. A large assigned region is never
# subdivided by smaller biomes. Coverage chooses whole regions at each level.
var _region_sizes := PackedFloat64Array()
var _region_enabled: Array[bool] = []
var _coverage := Vector4.ZERO
var _level_probabilities: Array[Vector4] = []
var _minimum_region_size: float
var _root_region_size: float
var _region_levels: Array[int] = []
var _label_cache: Dictionary = {}
var _biome_cell_cache: Dictionary = {}
var _warp_large := FastNoiseLite.new()
var _warp_small := FastNoiseLite.new()
var _snow_detail := FastNoiseLite.new()
var _continent_noise := FastNoiseLite.new()
var _shoreline_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
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
var last_build_profile: Dictionary = {}
var field_timings: Dictionary = {}


func _configure_noise() -> void:
	_island_cache.clear()
	_plane_cache.clear()
	_owner_cache.clear()
	_river_cache.clear()
	_river_columns.clear()
	_lake_cache.clear()
	_grass_grid.clear()
	_coast_certificates.clear()
	_height_grid_cache.clear()
	_setup_noise(_continent_noise, world_seed + 1327, 3.0 / maxf(settings.island_size, 1.0), settings.island_octaves, 0.52)
	_setup_noise(_shoreline_noise, world_seed + 1429, 1.0 / maxf(settings.shoreline_detail_size,50.0), 3, 0.45)
	_setup_noise(_detail_noise, world_seed + 307, 1.0 / maxf(settings.grass_hill_size, 1.0), settings.detail_octaves, settings.detail_gain)
	_setup_noise(_snow_detail, world_seed + 308, 1.0 / maxf(settings.snow_hill_size, 1.0), settings.detail_octaves, settings.detail_gain)
	_setup_noise(_ridge_noise, world_seed + 401, 1.0 / maxf(settings.mountain_size, 1.0), settings.detail_octaves, settings.detail_gain)
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
	var sizes := [settings.grass_region_size, settings.desert_region_size, settings.snow_region_size, settings.stone_region_size]
	_coverage = Vector4(maxf(settings.grass_coverage,0), maxf(settings.desert_coverage,0), maxf(settings.snow_coverage,0), maxf(settings.stone_coverage,0))
	var total := _coverage.x + _coverage.y + _coverage.z + _coverage.w
	if total <= 0.0:
		_coverage = Vector4(1,0,0,0)
	else:
		_coverage /= total
	_minimum_region_size = INF
	for i in range(4):
		var size: float = maxf(float(sizes[i]) * maxf(settings.biome_size,0.001), 16.0)
		_region_sizes.append(size)
		_region_enabled.append(_coverage[i] > 0.0)
		if _region_enabled[i]:
			_minimum_region_size = minf(_minimum_region_size, size)
	var top_level := 0
	for i in range(4):
		var level := maxi(0, roundi(log(_region_sizes[i] / _minimum_region_size) / log(2.0)))
		_region_levels.append(level)
		if _region_enabled[i]:
			top_level = maxi(top_level, level)
	_root_region_size = _minimum_region_size * pow(2.0,top_level)
	_level_probabilities.resize(top_level + 1)
	var remaining := 1.0
	for level in range(top_level, -1, -1):
		var probabilities := Vector4.ZERO
		var assigned := 0.0
		for i in range(4):
			if _region_levels[i] == level:
				probabilities[i] = _coverage[i] / maxf(remaining,0.000000001)
				assigned += _coverage[i]
		_level_probabilities[level] = probabilities
		remaining -= assigned
	_setup_noise(_warp_large, world_seed + 811, 1.0 / _root_region_size, 1,0.5)
	_setup_noise(_warp_small, world_seed + 919, 1.0 / _minimum_region_size, 1,0.5)
	_temperature_period = maxf(settings.temperature_region_size * maxf(settings.biome_size, 0.001), maxf(_region_sizes[1], _region_sizes[2]) * 8.0)
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
	var profile_start := Time.get_ticks_usec() if profile_build else 0
	var row_size := resolution + 1
	var sample_size := row_size + 2
	var step := chunk_size / float(resolution)
	var origin_x := coordinate.x * chunk_size
	var origin_z := coordinate.y * chunk_size
	var height_samples := PackedFloat32Array()
	height_samples.resize(sample_size * sample_size)
	var weight_samples := PackedColorArray()
	weight_samples.resize(sample_size * sample_size)
	var surface_samples := PackedVector2Array()
	surface_samples.resize(sample_size * sample_size)
	var geology_samples := PackedVector3Array()
	geology_samples.resize(sample_size * sample_size)

	# A one-vertex border gives accurate normals that match neighboring chunks.
	for sample_z in range(sample_size):
		for sample_x in range(sample_size):
			var world_x := origin_x + (sample_x - 1) * step
			var world_z := origin_z + (sample_z - 1) * step
			height_samples[sample_z * sample_size + sample_x] = _sample_grid_height(world_x, world_z)
			var w := _last_weights
			if w == Vector4.ZERO:
				w = _biome_weights(world_x,world_z)
			weight_samples[sample_z * sample_size + sample_x] = Color(w.x,w.y,w.z,w.w)
			surface_samples[sample_z * sample_size + sample_x] = _last_surface
			geology_samples[sample_z * sample_size + sample_x] = _last_geology

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
			var wx := (normal_x+nx)*normal_step
			var wz := (normal_z+nz)*normal_step
			var sx := (wx-origin_x)/step+1.0
			var sz := (wz-origin_z)/step+1.0
			if is_equal_approx(sx,roundf(sx)) and is_equal_approx(sz,roundf(sz)) and sx>=0 and sz>=0 and sx<sample_size and sz<sample_size:
				normal_heights[nz*normal_width+nx] = height_samples[roundi(sz)*sample_size+roundi(sx)]
			else:
				normal_heights[nz*normal_width+nx] = _sample_grid_height(wx,wz)
	var normal_field := PackedVector3Array()
	normal_field.resize(normal_width*normal_depth)
	var curvature_field := PackedFloat32Array()
	curvature_field.resize(normal_width*normal_depth)
	for nz in range(1,normal_depth-1):
		for nx in range(1,normal_width-1):
			var i := nz*normal_width+nx
			var left:=normal_heights[i-1];var right:=normal_heights[i+1]
			var back:=normal_heights[i-normal_width];var front:=normal_heights[i+normal_width]
			if normal_step>32.0:
				var wx: float=(normal_x+nx)*normal_step;var wz: float=(normal_z+nz)*normal_step
				left=_sample_grid_height(wx-32.0,wz);right=_sample_grid_height(wx+32.0,wz)
				back=_sample_grid_height(wx,wz-32.0);front=_sample_grid_height(wx,wz+32.0)
			normal_field[i] = Vector3(left-right,64.0,back-front).normalized()
			curvature_field[i] = (left+right+back+front-4.0*normal_heights[i])/32.0

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
	geology_colors.resize(row_size * row_size * 3)

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
			colors[vertex_index] = weight_samples[sample_index]
			var curvature := lerpf(lerpf(curvature_field[ni],curvature_field[ni+1],gx-ix),lerpf(curvature_field[ni+normal_width],curvature_field[ni+normal_width+1],gx-ix),gz-iz)
			uvs[vertex_index] = Vector2(get_water_surface_height(world_x,world_z),curvature)
			surface_uvs[vertex_index] = surface_samples[sample_index]
			var geology := geology_samples[sample_index]
			geology_colors[vertex_index*3] = geology.x
			geology_colors[vertex_index*3+1] = geology.y
			geology_colors[vertex_index*3+2] = geology.z

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
			for channel in range(3): geology_colors.append(geology_colors[vertex*3+channel])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = surface_uvs
	# Explicit RGB_FLOAT format; RGBA8 only exposed R on the tested GL backend.
	arrays[Mesh.ARRAY_CUSTOM0] = geology_colors
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


func _climate_biome(biome: int, cx: int, cz: int, span: float) -> int:
	if not settings.temperature_enabled or (biome != 1 and biome != 2):
		return biome
	var lo := cx*span*TAU/_temperature_period + _temperature_phase
	var hi := (cx+1)*span*TAU/_temperature_period + _temperature_phase
	var minimum := minf(sin(lo),sin(hi))
	var maximum := maxf(sin(lo),sin(hi))
	if ceil((lo-PI*0.5)/TAU) <= floor((hi-PI*0.5)/TAU):
		maximum = 1.0
	if ceil((lo+PI*0.5)/TAU) <= floor((hi+PI*0.5)/TAU):
		minimum = -1.0
	# Exact full-region extrema avoid over-rejecting safe snow/desert regions.
	var t0 := settings.average_temperature+settings.temperature_variation*minimum
	var t1 := settings.average_temperature+settings.temperature_variation*maximum
	var cold_limit := settings.snow_max_temperature
	var hot_limit := maxf(settings.desert_min_temperature, cold_limit + 5.0)
	if biome == 2 and maxf(t0,t1) <= cold_limit:
		return biome
	if biome == 1 and minf(t0,t1) >= hot_limit:
		return biome
	# Replace the whole unsuitable region; never cut tiny climate holes into it.
	# Grass remains the temperate safety fallback even if both neutral weights are zero.
	return 3 if not _region_enabled[0] and _region_enabled[3] else 0


func _region_owner(p: Vector2) -> int:
	# Search from large to small; once claimed, the entire region is protected.
	for level in range(_level_probabilities.size()-1, -1, -1):
		var span := _minimum_region_size * pow(2.0,level)
		var cx := floori(p.x / span)
		var cz := floori(p.y / span)
		var roll := _region_random(cx,cz,level,2731)
		var cumulative := 0.0
		var probabilities := _level_probabilities[level]
		if settings.temperature_enabled:
			var original_mass := probabilities.x + probabilities.y + probabilities.z + probabilities.w
			for special in [1,2]:
				if _climate_biome(special,cx,cz,span) != special:
					probabilities[special] = 0.0
				else:
					probabilities[special] *= maxf(settings.climate_biome_preference,1.0)
			var eligible_mass := probabilities.x + probabilities.y + probabilities.z + probabilities.w
			if eligible_mass > 0.0:
				probabilities *= original_mass / eligible_mass
			elif roll < original_mass:
				return 3 if not _region_enabled[0] and _region_enabled[3] else 0
		for i in range(4):
			cumulative += probabilities[i]
			if roll < cumulative and _region_enabled[i]:
				return _climate_biome(i,cx,cz,span)
	# Rounding at a cumulative probability of one.
	for i in range(4):
		if _region_enabled[i]:
			return _climate_biome(i, floori(p.x / _minimum_region_size), floori(p.y / _minimum_region_size), _minimum_region_size)
	return 0


func _grid_owner(x: int, z: int, step: float) -> int:
	var key := Vector2i(x,z)
	if not _label_cache.has(key):
		if _label_cache.size() >= 4096:
			_label_cache.clear()
		_label_cache[key] = _region_owner(_warp_region_point(x * step,z * step))
	return _label_cache[key]


func _biome_weights(x: float, z: float) -> Vector4:
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
		pure[labels.x]=1.0
		return pure
	var fx := smoothstep(0.0,1.0,px-ix)
	var fz := smoothstep(0.0,1.0,pz-iz)
	var weights := Vector4.ZERO
	weights[labels.x] += (1.0-fx)*(1.0-fz)
	weights[labels.y] += fx*(1.0-fz)
	weights[labels.z] += (1.0-fx)*fz
	weights[labels.w] += fx*fz
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
		if certificate.z-point.distance_to(Vector2(certificate.x,certificate.y))>maxf(settings.coast_width*694.445,0.1)+1.0:
			return maxf(1.0,(maxf(settings.coast_width*694.445,0.1)+1.0)/maxf(settings.island_size*0.5,8.0))
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
	var key := Vector2(x,lane)
	if _river_cache.has(key): return _river_cache[key]
	var seed_value := _region_random(lane,0,93,541)
	var broad := _grass_water_noise.get_noise_2d(x*0.3,lane*7919.0)
	var bends := _grass_water_noise.get_noise_2d(x*1.15+3171.0,lane*7919.0+137.0)
	var value := lane*spacing+(seed_value-0.5)*spacing*0.3 + broad*spacing*0.32 + bends*spacing*0.075
	if _river_cache.size()>=4096: _river_cache.clear()
	_river_cache[key] = value
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
	var key:=Vector2(x,lane)
	if _river_columns.has(key): return _river_columns[key]
	var value:=Vector3(_grass_river_center(x,lane,spacing),(_grass_river_center(x+8.0,lane,spacing)-_grass_river_center(x-8.0,lane,spacing))/16.0,_grass_water_noise.get_noise_2d(x*0.6,lane*711.0))
	if _river_columns.size()>=2048: _river_columns.clear()
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
	var key:=Vector2i(int(x),int(z))
	if _height_grid_cache.has(key):
		var entry: Array=_height_grid_cache[key]
		_last_weights=entry[1];_last_surface=entry[2];_last_geology=entry[3];_last_island=entry[4]
		return entry[0]
	var height:=_get_height(x,z)
	if _height_grid_cache.size()>=8192: _height_grid_cache.clear()
	_height_grid_cache[key]=[height,_last_weights,_last_surface,_last_geology,_last_island]
	return height


func _get_height(world_x: float, world_z: float) -> float:
	_height_query=true
	var island := _island_mask(world_x,world_z)
	_height_query=false
	_last_island = island
	_last_weights = Vector4.ZERO
	_last_surface = Vector2.ZERO
	_last_geology = Vector3.ZERO
	# Only the coastline mask knows island dimensions. Inland topography is
	# sampled in an independent coordinate system, including its coastal fade.
	var shape_scale := maxf(settings.terrain_shape_scale,0.01)
	var terrain_x := world_x/shape_scale
	var terrain_z := world_z/shape_scale
	var shore_distance := island*maxf(settings.island_size*0.5,8.0)
	var shore_transition := maxf(settings.coast_width*694.445,0.1)
	if island>0.0:
		_last_weights=_biome_weights(world_x,world_z)
		if _last_weights.x==1.0:
			var profile:=_grass_sample(terrain_x,terrain_z)
			var grass_height:=lerpf(maxf(1.0,profile.x),profile.z,profile.y)
			return water_level+grass_height*smoothstep(0.0,shore_transition,shore_distance)*maxf(settings.height_multiplier,0.01)
	var detail := _detail_noise.get_noise_2d(terrain_x, terrain_z)
	var floor_height := minf(-maxf(settings.ocean_depth,1.0)+detail*settings.seabed_relief,-1.0)
	if island <= 0.0:
		return water_level + floor_height * minf(-shore_distance/shore_transition,1.0) * maxf(settings.height_multiplier,0.01)
	var ridge := absf(_ridge_noise.get_noise_2d(terrain_x, terrain_z))
	var snow_detail := _snow_detail.get_noise_2d(terrain_x, terrain_z)
	var weights := _last_weights
	_last_weights = weights
	var grass_profile := _grass_sample(terrain_x,terrain_z) if weights.x > 0.0001 else Vector3.ZERO
	var grass := grass_profile.x
	var desert := sin(terrain_x * TAU / maxf(settings.dune_size, 1.0) + detail * settings.dune_warp) * settings.dune_height + detail * settings.desert_roughness
	var snow := snow_detail * settings.snow_hill_height + ridge * settings.snow_ridge_height
	var stone := pow(ridge, settings.mountain_sharpness) * settings.mountain_height + detail * settings.stone_roughness
	var land := maxf(1.0,settings.land_height*0.2*(1.0-weights.x) + weights.dot(Vector4(grass,desert,snow,stone)))
	# Carve only Grass contributions. The existing water plane fills these
	# lowland channels/basins; no new mesh or thread architecture is introduced.
	land = lerpf(land,grass_profile.z,grass_profile.y*weights.x)
	var blend := smoothstep(0.0,shore_transition,shore_distance)
	return water_level + land*blend*maxf(settings.height_multiplier,0.01)


func get_water_surface_height(_x: float, _z: float) -> float:
	# All water currently rendered by this project is connected sea-level water.
	# Keep this query explicit for future local water surfaces; no fake high lakes.
	return water_level


func _normalized_noise(noise: FastNoiseLite, x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * 0.5 + 0.5

