extends RefCounted
## Worker-owned canonical Desert height and material fields. No scene, GPU, time,
## camera, chunk dimensions or LOD enters this function. Metres in, metres out.
## Region descriptors are cached on a FIXED world lattice, never the mesh grid.
enum Region { SAND_SEA, ROCKY_PLAIN, CANYON, DRY_BASIN, HIGHLANDS, BADLANDS, OASIS }
const REGION_NAMES = ["Great Sand Sea", "Rocky Wasteland", "Sandstone Canyon Country", "Dry Basin", "Desert Highlands", "Badlands", "Oasis Basin"]
const REGION_COLORS = [Vector3(0.96,0.69,0.27), Vector3(0.42,0.40,0.35), Vector3(0.72,0.31,0.17), Vector3(0.89,0.88,0.75), Vector3(0.49,0.34,0.23), Vector3(0.70,0.49,0.48), Vector3(0.16,0.50,0.53)]
const REGION_GRID: float = 256.0
const CACHE_LIMIT: int = 4096
const NEIGHBORHOOD_CACHE_LIMIT: int = 128
const OCCURRENCE_CACHE_LIMIT: int = 256
var settings: DesertSettings
var seed_value: int = 73921
var _macro := FastNoiseLite.new()
var _meso := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _drainage_graph = preload("res://scripts/desert_drainage.gd").new()
var _region_cache: Dictionary = {}
var _site_cache: Dictionary = {}
# Adjacent fixed-lattice nodes usually visit the same nine sites. Keep their
# immutable descriptors together instead of dispatching nine cache lookups per
# node. Scratch distances never escape this worker-owned sampler.
var _site_neighborhoods: Dictionary = {}
var _candidate_distances := PackedFloat32Array()
var _last_site_center := Vector2i(2147483647, 2147483647)
var _last_sites: Array[Vector4] = []
var _region_span: float
var _region_blend_width: float
var _rock_style_min: float
var _rock_style_span: float
var _wind_x: float
var _wind_z: float
# Optional field occupancy is cached by a fixed world-space cell and feature salt.
# Defaults bypass this path; the cache is private to this configured sampler.
var _occurrence_cache: Dictionary = {}
var _dune_occurrence: float = 1.0
var _dry_lake_occurrence: float = 1.0
var _dune_occurrence_span: float = 3000.0
var _dry_lake_occurrence_span: float = 6000.0
var _dune_cache: Dictionary = {}
var _dune_subset_cache: Dictionary = {}
var _rotation: float
var _dune_width: float
var _dune_spacing: float
var _dune_crest: float
var _dune_cap: float
var _dune_secondary_ratio: float
var _mega_dune_width: float
var _wind_strength: float
var _wind_phase: float
var _bedding_frame := Vector4(0.009, 0.0, 24.0, 0.0)
var _last_cell := Vector2i(2147483647, 2147483647)
var _corners: Array = []
var _constant_region: bool = false
# Compact mesh channels: region RGB + dune coverage; rock/drainage/basin/sand;
# signed wind XY + salt + supported wetness. Existing Grass CUSTOM0 is untouched.
var control_region := Vector4.ZERO
var control_surface := Vector4.ZERO
var control_wind := Vector4.ZERO
## CUSTOM2: canonical pre-shelf bed coordinate, two packed dune-field triples,
## upstream shelter. None of these values depend on mesh spacing or the camera.
var control_detail := Vector4.ZERO
var last_family_weights := Vector4.ZERO
var last_irregular_weight: float = 0.0
var last_obstacle_shelter: float = 0.0
var last_bedding_coordinate: float = 0.0
var last_family: int = 0
var last_region: int = 0
var last_fan: float = 0.0
var last_crest: float = 0.0
var last_weights := PackedFloat32Array()

func configure(config: DesertSettings, world_seed: int) -> void:
	settings = config
	seed_value = world_seed
	_rotation = deg_to_rad(settings.wind_direction_degrees)
	_wind_x = cos(_rotation)
	_wind_z = sin(_rotation)
	_region_span = maxf(settings.region_size, 3000.0)
	_region_blend_width = _region_span * 0.22
	# Site style stores the original selection value, so rocky sites occupy
	# only their probability interval. Normalize that interval for cap geology.
	var sandy_share: float = clampf(settings.sandy_frequency, 0.05, 0.65)
	_rock_style_min = clampf(settings.oasis_frequency, 0.0, 0.06) + sandy_share
	_rock_style_span = clampf(settings.rocky_frequency, 0.02, 0.5) * (1.0 - sandy_share)
	var minimum_width: float = maxf(200.0, minf(settings.dune_width_range.x, settings.dune_width_range.y))
	_dune_width = maxf(minimum_width, maxf(settings.dune_width_range.x, settings.dune_width_range.y))
	_dune_spacing = maxf(settings.dune_spacing, 0.65)
	_dune_occurrence = clampf(settings.dune_occurrence, 0.0, 1.0)
	_dry_lake_occurrence = clampf(settings.dry_lake_occurrence, 0.0, 1.0)
	_dune_occurrence_span = maxf(_dune_width * _dune_spacing * 4.0, 3000.0)
	_dry_lake_occurrence_span = maxf(settings.basin_size * 3.0, 6000.0)
	_dune_crest = clampf(settings.dune_asymmetry, 0.55, 0.82)
	var lee_fraction: float = 1.0 - _dune_crest
	var slip_derivative: float = 1.5 - 0.5 * clampf(settings.slip_face_sharpness, 0.0, 1.0)
	var effective_width: float = _dune_width * _dune_spacing * 0.65
	_dune_cap = effective_width * lee_fraction * 0.52 / (slip_derivative * 1.8)
	_dune_secondary_ratio = _dune_width / minimum_width
	_mega_dune_width = maxf(7000.0, _dune_width * 8.0)
	_wind_strength = settings.wind_variation * 1600.0
	_wind_phase = float(seed_value % 10007) * 0.013
	_bedding_frame = settings.bedding_parameters(world_seed)
	_setup(_macro, world_seed + 7013, 1.0 / 2200.0, 2)
	_setup(_meso, world_seed + 7039, 1.0 / 540.0, 2)
	_setup(_detail, world_seed + 7069, 1.0 / 95.0, 2)
	_drainage_graph.configure(config, world_seed)
	_region_cache.clear()
	_occurrence_cache.clear()
	_site_cache.clear()
	_site_neighborhoods.clear()
	_last_site_center = Vector2i(2147483647, 2147483647)
	_last_sites.clear()
	_candidate_distances.resize(9)
	_dune_cache.clear()
	_dune_subset_cache.clear()
	_last_cell = Vector2i(2147483647, 2147483647)

func _setup(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.4

func _hash(x: int, z: int, salt: int) -> float:
	# Integer-only bounded hash; no global RNG and no per-chunk seed.
	var h: int = (x * 374761393 + z * 668265263 + seed_value * 69069 + salt * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / 2147483647.0

func _patch_occurrence(p: Vector2, span: float, probability: float, salt: int) -> float:
	# Select sites, not amplitudes: retained cores are exactly 1, omitted cores 0.
	# A wide C1 transition avoids introducing height steps at field boundaries.
	# Neither a chunk key, LOD, camera nor query order enters this construction.
	if probability <= 0.0: return 0.0
	if probability >= 1.0: return 1.0
	var lattice: Vector2 = p / span
	var cell := Vector2i(floori(lattice.x), floori(lattice.y))
	var key := Vector3i(cell.x, cell.y, salt)
	var sites: Vector4
	if _occurrence_cache.has(key):
		sites = _occurrence_cache[key]
	else:
		sites = Vector4(
			1.0 if _hash(cell.x, cell.y, salt) < probability else 0.0,
			1.0 if _hash(cell.x + 1, cell.y, salt) < probability else 0.0,
			1.0 if _hash(cell.x, cell.y + 1, salt) < probability else 0.0,
			1.0 if _hash(cell.x + 1, cell.y + 1, salt) < probability else 0.0)
		if _occurrence_cache.size() >= OCCURRENCE_CACHE_LIMIT:
			_occurrence_cache.clear()
		_occurrence_cache[key] = sites
	var t: Vector2 = lattice - Vector2(cell)
	t = Vector2(smoothstep(0.15, 0.85, t.x), smoothstep(0.15, 0.85, t.y))
	return lerpf(lerpf(sites.x, sites.y, t.x), lerpf(sites.z, sites.w, t.x), t.y)

func _site(cell: Vector2i) -> Vector4:
	if _site_cache.has(cell): return _site_cache[cell]
	var span: float = _region_span
	var random: float = _hash(cell.x, cell.y, 7)
	var sandy: float = clampf(settings.sandy_frequency, 0.05, 0.65)
	var rocky: float = clampf(settings.rocky_frequency, 0.02, 0.5) * (1.0 - sandy)
	var oasis: float = clampf(settings.oasis_frequency, 0.0, 0.06)
	var id: int
	if random < oasis: id = Region.OASIS
	elif random < oasis + sandy: id = Region.SAND_SEA
	elif random < oasis + sandy + rocky: id = Region.ROCKY_PLAIN
	else:
		var t: float = (random - oasis - sandy - rocky) / maxf(1.0 - oasis - sandy - rocky, 0.01)
		id = [Region.CANYON, Region.DRY_BASIN, Region.HIGHLANDS, Region.BADLANDS][clampi(int(t * 4.0), 0, 3)]
	var result := Vector4((cell.x + 0.2 + _hash(cell.x, cell.y, 11) * 0.6) * span,
		(cell.y + 0.2 + _hash(cell.x, cell.y, 13) * 0.6) * span, float(id), random)
	if _site_cache.size() >= CACHE_LIMIT: _site_cache.clear()
	_site_cache[cell] = result
	return result

func _region_node(cell: Vector2i) -> PackedFloat32Array:
	if _region_cache.has(cell): return _region_cache[cell]
	var p := Vector2(cell) * REGION_GRID
	var span: float = _region_span
	# A bounded domain warp removes straight Voronoi borders.
	var q := p + Vector2(_macro.get_noise_2d(p.x * 0.24, p.y * 0.24), _macro.get_noise_2d(p.x * 0.24 + 9713.0, p.y * 0.24 - 3811.0)) * span * 0.16
	var center := Vector2i(floori(q.x / span), floori(q.y / span))
	if center != _last_site_center:
		if _site_neighborhoods.has(center):
			_last_sites = _site_neighborhoods[center]
		else:
			var sites: Array[Vector4] = []
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					sites.append(_site(center + Vector2i(dx, dz)))
			if _site_neighborhoods.size() >= NEIGHBORHOOD_CACHE_LIMIT:
				_site_neighborhoods.clear()
			_site_neighborhoods[center] = sites
			_last_sites = sites
		_last_site_center = center
	var nearest: float = INF
	for i in range(9):
		var site: Vector4 = _last_sites[i]
		var distance: float = q.distance_to(Vector2(site.x, site.y))
		# Preserve the old Vector4 candidate's float32 distance rounding.
		_candidate_distances[i] = distance
		nearest = minf(nearest, distance)
	var result := PackedFloat32Array()
	result.resize(11)
	var total: float = 0.0
	for i in range(9):
		var site: Vector4 = _last_sites[i]
		var weight: float = 1.0 - smoothstep(0.0, _region_blend_width, _candidate_distances[i] - nearest)
		# Exact zero adds no contribution; keep all positive terms in their
		# original order and retain float32 rounding after every addition.
		if weight == 0.0: continue
		result[int(site.z)] += weight
		result[7] += site.w * weight
		total += weight
	for i in range(8): result[i] /= maxf(total, 0.0001)
	# Exact derivative of the bounded wind phase avoids four extra phase calls.
	var phase: float=_wind_phase
	var strength: float=_wind_strength
	var wx: float=_wind_x+cos(p.x/9100.0+phase)*cos(p.y/11700.0-phase*0.71)*strength/9100.0
	var wz: float=_wind_z-sin(p.x/9100.0+phase)*sin(p.y/11700.0-phase*0.71)*strength/11700.0
	var direction:=Vector2(wx,wz).normalized()
	result[8] = direction.x
	result[9] = direction.y
	# Two upwind probes per cached 256 m node, never recursive terrain samples
	# per vertex. This uncarved bedrock envelope is deliberately approximate;
	# the same fixed field is used regardless of chunk size, LOD or cache order.
	var rock_country: float = clampf(result[2] + result[4] + result[5] * 0.6 + result[1] * 0.3, 0.0, 1.0)
	if rock_country > 0.0 and settings.wind_shelter_strength > 0.0:
		var base: float = _obstacle_envelope(p)
		var near_obstacle: float = _obstacle_envelope(p - direction * 96.0) - base
		var far_obstacle: float = _obstacle_envelope(p - direction * 288.0) - base
		result[10] = maxf(smoothstep(2.0, 26.0, near_obstacle), smoothstep(6.0, 60.0, far_obstacle)) * rock_country
	if _region_cache.size() >= CACHE_LIMIT: _region_cache.clear()
	_region_cache[cell] = result
	return result

func _obstacle_envelope(p: Vector2) -> float:
	var ridge: float = 1.0 - absf(_macro.get_noise_2d(p.x * 1.2 + 3173.0, p.y * 1.2 - 991.0))
	var flank: float = maxf(0.0, 0.5 + _macro.get_noise_2d(p.x, p.y))
	return (ridge * ridge * ridge * 0.65 + flank * flank * 0.35) * maxf(settings.highland_height, 100.0)

func region_weights(x: float, z: float) -> PackedFloat32Array:
	var p := Vector2(x, z) / REGION_GRID
	var cell := Vector2i(floori(p.x), floori(p.y))
	var t := p - Vector2(cell)
	t = t * t * (Vector2.ONE * 3.0 - 2.0 * t)
	if t.x == 0.0 and t.y == 0.0:
		return _region_node(cell).duplicate()
	if t.x == 0.0 or t.y == 0.0:
		var a: PackedFloat32Array = _region_node(cell)
		var b: PackedFloat32Array = _region_node(cell + (Vector2i.DOWN if t.x == 0.0 else Vector2i.RIGHT))
		var blend: float = t.y if t.x == 0.0 else t.x
		var result := PackedFloat32Array()
		result.resize(11)
		for i in range(11): result[i] = lerpf(a[i], b[i], blend)
		return result
	if cell != _last_cell:
		_corners = [_region_node(cell), _region_node(cell + Vector2i.RIGHT), _region_node(cell + Vector2i.DOWN), _region_node(cell + Vector2i.ONE)]
		_last_cell = cell
		_constant_region = true
		for k in range(1, 4):
			for i in range(8):
				if _corners[k][i] != _corners[0][i]:
					_constant_region = false
					break
	var a: PackedFloat32Array = _corners[0]
	var b: PackedFloat32Array = _corners[1]
	var c: PackedFloat32Array = _corners[2]
	var d: PackedFloat32Array = _corners[3]
	var result: PackedFloat32Array
	if _constant_region:
		# Allocate only the returned copy; wind and cached shelter still vary.
		result = a.duplicate()
		for i in range(8, 11): result[i] = lerpf(lerpf(a[i],b[i],t.x),lerpf(c[i],d[i],t.x),t.y)
	else:
		result = PackedFloat32Array()
		result.resize(11)
		for i in range(11): result[i] = lerpf(lerpf(a[i],b[i],t.x),lerpf(c[i],d[i],t.x),t.y)
	return result

func wind_coordinates(x: float, z: float) -> Vector2:
	# Bounded displacement of a GLOBAL phase, not dot(position, a varying angle).
	# The latter's derivatives explode far from the origin and move dune crests.
	var p := Vector2(x, z).rotated(-_rotation)
	var strength: float = _wind_strength
	var phase: float = _wind_phase
	var a: float = sin(x / 9100.0 + phase) * cos(z / 11700.0 - phase * 0.71)
	var b: float = cos(x / 13700.0 - phase * 0.43) * sin(z / 8300.0 + phase)
	return p + Vector2(a, b) * strength

func _asymmetric(phase: float) -> float:
	var t: float = fposmod(phase, 1.0)
	var crest: float = _dune_crest
	if t < crest:
		var u: float = t / crest
		return u * u * (3.0 - 2.0 * u)
	var u: float = (1.0 - t) / (1.0 - crest)
	return lerpf(u * u * (3.0 - 2.0 * u), u, settings.slip_face_sharpness)

func _dune_sites(cell: Vector2i) -> Array[Vector4]:
	if _dune_cache.has(cell): return _dune_cache[cell]
	var result: Array[Vector4] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := cell + Vector2i(dx, dz)
			var random: float = _hash(c.x, c.y, 103)
			if random > 0.80: continue
			result.append(Vector4((c.x + 0.22 + _hash(c.x, c.y, 107) * 0.56),
				(c.y + 0.22 + _hash(c.x, c.y, 109) * 0.56), 0.62 + random * 0.55, _hash(c.x, c.y, 113)))
	if _dune_cache.size() >= 512: _dune_cache.clear()
	_dune_cache[cell] = result
	return result

func _near_dune_sites(q: Vector2, pitch: float, width: float, family: int) -> Array[Vector4]:
	# Conservative subcell culling only: every retained dune still uses the
	# identical analytic profile. Unlike interpolated height caches this cannot
	# move crests, alter slopes, or introduce LOD-dependent geography.
	var span: float=pitch/8.0
	var subcell:=Vector2i(floori(q.x/span),floori(q.y/span))
	var key:=Vector3i(subcell.x,subcell.y,family)
	if _dune_subset_cache.has(key):return _dune_subset_cache[key]
	var bounds:=Rect2(Vector2(subcell)*span,Vector2.ONE*span).grow(0.1)
	var sites: Array[Vector4]=[]
	var cell:=Vector2i(floori(q.x/pitch),floori(q.y/pitch))
	for site: Vector4 in _dune_sites(cell):
		var extent:=Vector2(1.2,0.85 if family==3 else 0.8)*width*site.z
		if Rect2(Vector2(site.x,site.y)*pitch-extent,extent*2.0).intersects(bounds,true):sites.append(site)
	if _dune_subset_cache.size()>=1024:_dune_subset_cache.clear()
	_dune_subset_cache[key]=sites
	return sites

func _isolated_dunes(q: Vector2, width: float, family: int) -> float:
	var pitch: float = width * _dune_spacing * 1.65
	var height: float = 0.0
	# Star arms fade to zero at radius 0.85. The crescent's narrower box
	# clipped those arms at |y| = 0.8 before their radial fade could finish.
	var cross_limit: float = 0.85 if family == 3 else 0.8
	for site: Vector4 in _near_dune_sites(q,pitch,width,family):
		var p := (q - Vector2(site.x, site.y) * pitch) / (width * site.z)
		if absf(p.x) > 1.2 or absf(p.y) > cross_limit: continue
		var profile: float = 0.0
		if family == 3:
			# Three finite arms meet at a central massif. No conical noise spikes.
			var radius: float = p.length()
			if radius > 0.85: continue
			for arm in range(3):
				var a := p.rotated(float(arm) * TAU / 3.0 + site.w)
				# Each arm has a broad stoss side and a shorter lee face. Smooth
				# finite shoulders avoid the old symmetric triangular pyramid.
				var longitudinal: float = 1.0 - smoothstep(0.0, 0.85, absf(a.x))
				var face: float = smoothstep(-0.36, 0.0, a.y) if a.y < 0.0 else 1.0 - smoothstep(0.0, 0.18, a.y)
				profile = maxf(profile, face * longitudinal)
			profile *= 1.0 - smoothstep(0.65, 0.85, radius)
		else:
			# A bowed crest and downwind tapered horns create a crescent footprint.
			var cross: float = absf(p.y) / 0.64
			if cross >= 1.0: continue
			var bow: float = cross * cross * 0.52
			if family == 4: bow = -bow # stabilized upwind arms in sheltered margins
			var distance: float = p.x - bow
			var stoss: float = 0.66
			var lee: float = 0.23
			if distance < -stoss or distance > lee: continue
			if distance < 0.0:
				profile = smoothstep(-stoss, 0.0, distance)
			else:
				profile = (1.0 - distance / lee)
			profile *= smoothstep(0.0, 0.85, 1.0 - cross)
		# Angle-of-repose bound tied to width, even with extreme Inspector values.
		var amplitude: float = minf(settings.dune_max_height * site.z * 0.72, width * site.z * 0.07)
		height = maxf(height, profile * amplitude)
	return height

func _dunes(q: Vector2, x: float, z: float, supply: float, style: float) -> float:
	if supply < 0.001 or settings.dune_frequency <= 0.0 or settings.dune_max_height <= 0.0:
		last_family = 0
		last_crest = 0.0
		last_family_weights = Vector4.ZERO
		last_irregular_weight = 0.0
		return 0.0
	var width: float = _dune_width
	var family_field: float = _macro.get_noise_2d(x * 0.32 + 38173.0, z * 0.32 - 12913.0) * 0.5 + 0.5
	# Selector overlaps prevent height steps at dune-family boundaries.
	var first_blend: float = smoothstep(0.37, 0.41, family_field)
	var transverse: float = 1.0 - first_blend
	var second_blend: float = smoothstep(0.53, 0.57, family_field)
	var longitudinal: float = first_blend * (1.0 - second_blend)
	var barchan: float = second_blend * (1.0 - smoothstep(0.65, 0.69, family_field))
	var star: float = smoothstep(0.74, 0.79, family_field)
	var irregular: float = maxf(0.0, 1.0 - transverse - longitudinal - barchan - star)
	last_family_weights = Vector4(transverse, longitudinal, barchan, star)
	last_irregular_weight = irregular
	last_family = 0
	var strongest: float = transverse
	# Retain float32 selector rounding from the old Vector2 array.
	var family_weights := Vector4(longitudinal, barchan, star, irregular)
	if family_weights.x > strongest: strongest = family_weights.x; last_family = 1
	if family_weights.y > strongest: strongest = family_weights.y; last_family = 2
	if family_weights.z > strongest: strongest = family_weights.z; last_family = 3
	if family_weights.w > strongest: last_family = 4
	var warp: float = _meso.get_noise_2d(x * 0.20, z * 0.20)
	var height: float = 0.0
	# Repose cap includes minimum spacing, longitudinal compression, smooth
	# slip-face derivative, secondary harmonics and a conservative warp budget.
	var amplitude: float = minf(settings.dune_max_height * lerpf(0.35, 0.7, style), _dune_cap)
	var secondary_ratio: float = _dune_secondary_ratio
	if transverse > 0.001:
		var phase: float = q.x / (width * _dune_spacing) + warp * 0.30
		var crest_bend: float = _meso.get_noise_2d(q.x * 0.15 + 9103.0, q.y * 0.18) * 0.26
		var primary: float = _asymmetric(phase + crest_bend)
		var secondary: float = _asymmetric(phase * secondary_ratio + q.y / (width * 4.0)) * (0.18 / secondary_ratio)
		# The existing bend field also grades crest height and opens occasional
		# gaps. No extra noise query, cell boundary, or LOD-specific phase.
		var continuity: float = smoothstep(-0.25, -0.12, crest_bend)
		var relief: float = lerpf(0.72, 1.0, smoothstep(-0.12, 0.20, crest_bend))
		height += (primary + secondary) * amplitude * transverse * continuity * relief
	if longitudinal > 0.001:
		var phase: float = q.y / (width * 0.65 * _dune_spacing) + warp * 0.28
		var bifurcate: float = _meso.get_noise_2d(q.x * 0.22, q.y * 0.16)
		var ridge: float = _asymmetric(phase + bifurcate * 0.5)
		var shoulder: float = _asymmetric(phase * secondary_ratio + bifurcate * 0.7) * smoothstep(0.05, 0.45, bifurcate) * (0.18 / secondary_ratio)
		var continuity: float = smoothstep(-0.58, -0.24, bifurcate)
		var relief: float = lerpf(0.72, 1.0, smoothstep(-0.24, 0.45, bifurcate))
		height += (ridge + shoulder) * amplitude * 0.75 * longitudinal * continuity * relief
	if barchan > 0.001: height += _isolated_dunes(q, width, 2) * barchan
	if star > 0.001: height += _isolated_dunes(q, width * 1.45, 3) * star
	if irregular > 0.001: height += _isolated_dunes(q, width * 0.8, 4) * irregular
	# Kilometre-scale compound dunes survive 1024 m far-grid sampling. These
	# coexist with local crests at every LOD; never a separate coarse-height law.
	var mega_width: float = _mega_dune_width
	var mega_phase: float = q.x / mega_width + _macro.get_noise_2d(x * 0.20, z * 0.20) * 0.45
	height += _asymmetric(mega_phase) * settings.dune_max_height * 0.5 * lerpf(0.55,1.0,smoothstep(0.15,0.85,family_field))
	last_crest = clampf(height / maxf(amplitude, 1.0), 0.0, 1.0)
	return height * supply * settings.dune_frequency

func _strata_phase(uniform_bed: float) -> float:
	# Shared with desert_strata_phase in the shader. A monotone vertical warp
	# varies successive layer thickness without random per-chunk rotations.
	# Derivative stays in [0.7867, 1.2133], so bed order cannot reverse.
	return uniform_bed + sin(uniform_bed * 0.73 + _bedding_frame.w * 0.41) * 0.18 + sin(uniform_bed * 1.17 - _bedding_frame.w * 0.29) * 0.07

func _strata_hardness(bed: float) -> float:
	# Continuous resistant/softer intervals: stronger shelves in hard beds,
	# gentler weathered intervals in soft beds. No additional height samples.
	return 0.5 + sin(bed * 0.91 + _bedding_frame.w * 0.23) * 0.5

func _uniform_bed_coordinate(height: float, x: float, z: float) -> float:
	var offset: float = x * _bedding_frame.x + z * _bedding_frame.y
	offset += sin(x / 7300.0 + z / 9100.0 + _bedding_frame.w) * 7.0
	return (height + offset) / _bedding_frame.z

func _pack_detail() -> void:
	var a: int = roundi(clampf(last_family_weights.x, 0.0, 1.0) * 255.0)
	var b: int = roundi(clampf(last_family_weights.y, 0.0, 1.0) * 255.0)
	var c: int = roundi(clampf(last_family_weights.z, 0.0, 1.0) * 255.0)
	var d: int = roundi(clampf(last_family_weights.w, 0.0, 1.0) * 255.0)
	var e: int = roundi(clampf(last_irregular_weight, 0.0, 1.0) * 255.0)
	var f: int = roundi(clampf(last_crest, 0.0, 1.0) * 255.0)
	control_detail = Vector4(last_bedding_coordinate, float(a + b * 256 + c * 65536),
		float(d + e * 256 + f * 65536), last_obstacle_shelter)

func _sedimentary_relief(height: float, x: float, z: float, exposure: float, uniform_bed: float = INF) -> float:
	# The same seeded tilted/folded frame is used by desert_bedding_coordinate
	# in the material shader. Bed phase depends on absolute elevation, not each
	# region's unblended relief, so adjoining sandstone formations share strata.
	# One bounded kilometre-scale fold; no extra noise or neighborhood searches.
	var bed_height: float = _bedding_frame.z
	var bed: float = _strata_phase(_uniform_bed_coordinate(height, x, z) if is_inf(uniform_bed) else uniform_bed)
	var terraced: float = floorf(bed) + smoothstep(0.0, 0.78, fposmod(bed, 1.0))
	var strength: float = clampf(settings.ruggedness, 0.0, 1.0) * 0.22 * exposure
	strength *= lerpf(0.55, 1.0, _strata_hardness(bed))
	# Warp the bed phase, never the base elevation: only the bounded shelf
	# displacement is added. Every integer bed remains fixed and continuous.
	# Including phase and hardness derivatives gives a conservative vertical
	# derivative > .678 for exposure in [0,1]; no reversed/vertical height steps.
	return height + (terraced - bed) * bed_height * strength

func sample(x: float, z: float, water_supported: bool = true, publish_controls: bool = true) -> float:
	var weights: PackedFloat32Array = region_weights(x, z)
	last_weights = weights
	last_region = 0
	last_obstacle_shelter = weights[10] * clampf(settings.wind_shelter_strength, 0.0, 1.0)
	# Drainage exposure and the mesh control use the same normalized field.
	# Compute it once; normalization does not depend on any landform branch.
	var direction := Vector2(weights[8], weights[9]).normalized()
	# Exact inactive-field fast path, independent of camera/chunk/LOD. Require a
	# truly pure sand region, not an epsilon that could move transition geometry.
	if weights[0] == 1.0 and weights[1] == 0.0 and weights[2] == 0.0 and weights[3] == 0.0 and weights[4] == 0.0 and weights[5] == 0.0 and weights[6] == 0.0:
		var sand_macro: float = _macro.get_noise_2d(x, z)
		var supply: float = lerpf(0.35, 1.0, smoothstep(-0.25, 0.20, sand_macro))
		var q: Vector2 = wind_coordinates(x, z)
		if _dune_occurrence < 1.0:
			supply *= _patch_occurrence(q, _dune_occurrence_span, _dune_occurrence, 811)
		var height: float = 13.0 + sand_macro * 7.0
		height += _dunes(q, x, z, supply, weights[7])
		last_fan = 0.0
		_drainage_graph.reset_sample()
		var color: Vector3 = REGION_COLORS[0]
		control_region = Vector4(color.x, color.y, color.z, supply)
		control_surface = Vector4.ZERO
		control_wind = Vector4(direction.x, direction.y, 0.0, 0.0)
		# No rock beds exist in an exactly pure sand province.
		last_bedding_coordinate = 0.0
		if publish_controls: _pack_detail()
		return height
	var region_color := Vector3.ZERO
	if publish_controls:
		var strongest_region: float = weights[0]
		for i in range(7):
			var weight: float = weights[i]
			if weight != 0.0:
				region_color += REGION_COLORS[i] * weight
				if weight > strongest_region: strongest_region = weight; last_region = i
	var style: float = weights[7]
	var macro: float = _macro.get_noise_2d(x, z)
	var meso: float = _meso.get_noise_2d(x, z)
	var q: Vector2 = wind_coordinates(x, z)
	var ridges: float = pow(1.0 - absf(_macro.get_noise_2d(x * 1.2 + 3173.0, z * 1.2 - 991.0)), 3.0)
	var mountains: float = weights[Region.HIGHLANDS]
	var badlands: float = weights[Region.BADLANDS]
	var canyon: float = weights[Region.CANYON]
	var basin_country: float = weights[Region.DRY_BASIN] + weights[Region.OASIS]
	var drainage: Vector4 = Vector4(0.0,0.0,10000.0,0.0)
	if weights[Region.SAND_SEA] < 0.999:
		drainage = _drainage_graph.sample(Vector2(x,z), self, direction)
	else:
		_drainage_graph.reset_sample()
	var incision: float = clampf(settings.canyon_frequency * (canyon + mountains * 0.65 + badlands * 0.85), 0.0, 1.0)
	var rock_plain: float = weights[Region.ROCKY_PLAIN]
	var rock_mass: float = clampf(mountains + canyon + badlands * 0.6 + rock_plain * 0.3, 0.0, 1.0)
	# Plains are deliberately calm; separate geological constructions supply relief.
	var height: float = 13.0 + macro * 7.0
	var mountain_height: float = maxf(settings.highland_height, 100.0)
	if mountains > 0.001:
		var spine: float = ridges * (0.65 + meso * 0.2)
		var flank: float = pow(maxf(0.0, 0.5 + macro), 1.7)
		# Only some geological provinces retain resistant caps. Broad smooth
		# shoulders/flat tops distinguish mesas from fractured ridge country.
		var cap_country: float = smoothstep(0.62, 0.85, style)
		# Resistant caps have finite but narrower escarpments. The previous
		# half-range ramp rounded mesa shoulders into generic rolling hills.
		var cap: float = smoothstep(0.43, 0.65, ridges) * 0.70 + flank * 0.18
		var relief: float = mountain_height * lerpf(spine * 0.8 + flank * 0.35, cap, cap_country)
		height += mountains * relief * (1.0 - drainage.x * 0.68)
	if canyon > 0.001:
		# Finite-width walls, shelves and apron. Never vertical steps or overhangs.
		var wall: float = smoothstep(150.0, 390.0, drainage.z)
		var shelf: float = smoothstep(350.0, 650.0, drainage.z) * 0.15
		var plateau: float = minf(settings.canyon_depth, 380.0) * (lerpf(1.0, wall, settings.canyon_frequency) * 0.85 + shelf)
		height += canyon * plateau * (0.82 + macro * 0.20)
		height += canyon * meso * 10.0 * wall
	if rock_plain > 0.001:
		var outcrop: float = smoothstep(0.38, 0.74, ridges) * maxf(0.0, meso + 0.16)
		var mesa: float = smoothstep(0.40, 0.78, ridges) * smoothstep(0.04, 0.34, meso) * 0.28
		var rock_style: float = clampf((style - _rock_style_min) / _rock_style_span, 0.0, 1.0)
		outcrop = lerpf(outcrop, mesa, smoothstep(0.66, 0.88, rock_style))
		height += rock_plain * (meso * 3.0 + outcrop * mountain_height * 0.8)
	if badlands > 0.001:
		var ribs: float = 1.0 - absf(_meso.get_noise_2d(x * 1.8 + 1311.0, z * 1.8))
		var gullies: float = smoothstep(0.15, 0.75, ribs) * (1.0 - drainage.x * 0.75)
		height += badlands * (55.0 + gullies * 130.0 + meso * 18.0) * (0.55 + settings.ruggedness * 0.45)
		# Fine tributaries are descriptor curves rooted on the existing hierarchy.
		# Their short finite catchment envelopes leave broad unincised slopes.
		var fine_cut: float = _drainage_graph.last_gully * badlands * settings.erosion_intensity
		height = lerpf(height, minf(height, _drainage_graph.last_gully_floor), fine_cut * 0.62)
	var dry_drain: float = drainage.y * (1.0 - smoothstep(0.85, 0.999, weights[Region.SAND_SEA]))
	var valley: float = drainage.x * incision
	height = lerpf(height, _drainage_graph.last_floor + (1.0 - drainage.y) * 8.0, valley * 0.65)
	height -= dry_drain * settings.erosion_intensity * (2.0 + rock_mass * 5.0)
	# Irregular regional lowlands; distance-free shape avoids round crater basins.
	var basin_scale: float = 2400.0 / maxf(settings.basin_size, 600.0)
	var basin_noise: float = _macro.get_noise_2d(x * basin_scale, z * basin_scale) if basin_country > 0.001 else macro
	var basin: float = basin_country * (1.0 - smoothstep(-0.16, 0.30, basin_noise + meso * 0.10))
	var lakebed: float = basin * settings.dry_lake_frequency
	if _dry_lake_occurrence < 1.0 and lakebed > 0.0:
		# The existing basin shape still determines eligibility and outline.
		# Low-frequency domain bending keeps occupancy boundaries off straight axes.
		var lake_coordinates := Vector2(x, z) + Vector2(macro, meso) * (_dry_lake_occurrence_span * 0.12)
		lakebed *= _patch_occurrence(lake_coordinates, _dry_lake_occurrence_span, _dry_lake_occurrence, 821)
	height = lerpf(height, 3.5 + macro * 0.3 + meso * 0.15, lakebed)
	var rim: float = basin_country * smoothstep(0.03, 0.30, macro) * ridges
	height += rim * mountain_height * 0.4
	# Terrace assembled bedrock once, including basin rims. Flat gravel plains
	# and dry lake floors remain calm; sand/alluvium are deposited afterwards.
	# The final connected channel floor and supported oasis carve still win.
	var bedrock: float = clampf(mountains + canyon + badlands * 0.6 + rim + rock_plain * smoothstep(0.38, 0.74, ridges), 0.0, 1.0) * (1.0 - lakebed)
	if bedrock > 0.02 and settings.fracture_strength > 0.0:
		# Independent, finite-width geological joints reshape bedrock before
		# shelving. Two crossed irregular fields form recesses, not black decals.
		var joint_a: float = absf(_detail.get_noise_2d(x * 0.43, z * 0.43))
		var joint_b: float = absf(_detail.get_noise_2d(x * 0.23 + 3711.0, z * 0.31 - 851.0))
		var recess: float = (1.0 - smoothstep(0.025, 0.17, joint_a)) * smoothstep(0.03, 0.30, joint_b)
		height -= recess * bedrock * smoothstep(0.02,0.06,bedrock) * settings.fracture_strength * 40.0 * (1.0 - drainage.y)
	last_bedding_coordinate = _uniform_bed_coordinate(height, x, z)
	if bedrock > 0.0 and settings.ruggedness > 0.0:
		height = _sedimentary_relief(height, x, z, bedrock, last_bedding_coordinate)
	# Valley mouths grade into basin margins and carry diverging sediment traces.
	var fan: float = drainage.w * smoothstep(0.08, 0.36, basin_country) * (1.0 - basin) * (1.0 - drainage.y * 0.35)
	var fan_ground: float=1.0-smoothstep(35.0,140.0,height)
	fan *= fan_ground
	last_fan = fan
	# Deposition adds a shallow apron. Do not carve a low absolute plane into
	# a high basin rim: that creates artificial triangular trenches.
	var fan_deposit: float = _drainage_graph.last_fan_lift * fan_ground * smoothstep(0.08,0.36,basin_country) * (1.0-basin) * (0.7+settings.sediment_variation*0.3)
	# Wind affects deposits on actual drainage flanks, rather than painting
	# parallel wind bands across unrelated rock. No extra upstream height probes.
	var lee_deposit: float = lerpf(0.65, 1.25, _drainage_graph.last_lee)
	var obstacle_deposit: float = last_obstacle_shelter * (1.0 - lakebed) * (1.0 - drainage.y)
	var shelter: float = clampf(drainage.x * rock_mass * 0.55 * lee_deposit + basin * 0.45 + (1.0 - ridges) * rock_mass * 0.2 + obstacle_deposit * 0.65, 0.0, 1.0)
	height += obstacle_deposit * (2.0 + maxf(0.0, meso) * 6.0)
	var sand: float = clampf(weights[Region.SAND_SEA] + shelter * 0.55 + rock_plain * 0.15, 0.0, 1.0)
	var dunes: float = sand * (1.0 - lakebed) * (1.0 - dry_drain * 0.8)
	dunes *= lerpf(0.35, 1.0, smoothstep(-0.25, 0.20, macro))
	if _dune_occurrence < 1.0 and dunes > 0.0:
		dunes *= _patch_occurrence(q, _dune_occurrence_span, _dune_occurrence, 811)
	height += _dunes(q, x, z, dunes, style)
	# Small local relief occurs on rock, never as centimetre-scale vertex ripples.
	if rock_mass > 0.02:
		height += _detail.get_noise_2d(x, z) * settings.ruggedness * settings.rock_relief_metres * rock_mass * (1.0 - lakebed) * (1.0 - drainage.y)
	# Connected graph floors must actually govern dry channel beds, otherwise
	# regional relief can leave tall uphill barriers on a nominal tributary.
	# The broad valley envelope grades cut/fill into plains as well as rock.
	# A low basin may receive shallow alluvium; leaving arbitrary pits would dam flow.
	# Keep the visible dry channel graded while sand cover begins to hide it;
	# only bury the geometric bed deeper inside the erg transition.
	# Grade the actual channel bed, not the entire kilometre-wide catchment.
	# Flattening the broad valley envelope erased canyon walls into sand ramps.
	var bed_envelope: float = smoothstep(0.30, 0.98, drainage.y) * (1.0 - smoothstep(0.90, 0.999, weights[Region.SAND_SEA])) * smoothstep(0.0, 0.25, settings.canyon_frequency)
	height = lerpf(height, _drainage_graph.last_floor, bed_envelope)
	# Deposits build the apron beside the channel, never dam the shared bed.
	height += fan_deposit * (1.0 - drainage.y)
	var wet: float = 0.0
	if weights[Region.OASIS] > 0.001 and water_supported:
		# Only rare low basin cores reach the existing, connected sea-level plane.
		# Broad lowland then damp bank then pool, never a floating lake on a dune.
		wet = weights[Region.OASIS] * (1.0 - smoothstep(-0.39, -0.23, macro)) * (1.0 - smoothstep(-0.15, 0.08, meso))
		height = lerpf(height, -3.0 + meso * 0.4, wet)
	# Derivative/normal probes consume only the height. All preceding geography,
	# including water, drainage and deposition, is identical; avoid packing GPU
	# payloads which will never become vertices. No camera/LOD approximation.
	if not publish_controls: return height
	var salt: float = lakebed * smoothstep(0.28, 0.74, style) * (1.0 - wet)
	var exposed: float = clampf(rock_mass * settings.rock_exposure * (1.0 - shelter * 0.7) + rim * 0.6, 0.0, 1.0)
	control_region = Vector4(region_color.x, region_color.y, region_color.z, dunes)
	var deposited_channels: float = _drainage_graph.last_fan_channels * fan_ground * smoothstep(0.08, 0.36, basin_country) * (1.0 - basin)
	control_surface = Vector4(exposed, maxf(maxf(dry_drain, deposited_channels * 0.65), _drainage_graph.last_gully * badlands * settings.erosion_intensity), lakebed, clampf(shelter + fan * 0.6, 0.0, 1.0))
	control_wind = Vector4(direction.x, direction.y, salt, wet)
	_pack_detail()
	return height
