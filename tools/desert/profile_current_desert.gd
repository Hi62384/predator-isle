extends SceneTree
## Locate current CPU work without changing terrain algorithms.
## Nested timers overlap and add overhead; only uninstrumented runs measure cost.
const Desert = preload("res://scripts/desert_sampler.gd")
const Builder = preload("res://scripts/terrain_mesh_builder.gd")

class ProfiledDesert extends "res://scripts/desert_sampler.gd":
	var elapsed: Dictionary = {}
	var calls: Dictionary = {}
	func add_time(stage: String, started: int) -> void:
		elapsed[stage] = int(elapsed.get(stage, 0)) + Time.get_ticks_usec() - started
		calls[stage] = int(calls.get(stage, 0)) + 1
	func region_weights(x: float, z: float) -> PackedFloat32Array:
		var started := Time.get_ticks_usec()
		var result := super.region_weights(x, z)
		add_time("region_weights_including_nested_descriptors", started)
		return result
	func _region_node(cell: Vector2i) -> PackedFloat32Array:
		var cached: bool = _region_cache.has(cell)
		var started := Time.get_ticks_usec()
		var result := super._region_node(cell)
		add_time("region_node_hit" if cached else "region_node_miss", started)
		return result
	func wind_coordinates(x: float, z: float) -> Vector2:
		var started := Time.get_ticks_usec()
		var result := super.wind_coordinates(x, z)
		add_time("wind_coordinates", started)
		return result
	func _dunes(q: Vector2, x: float, z: float, supply: float, style: float) -> float:
		var started := Time.get_ticks_usec()
		var result := super._dunes(q, x, z, supply, style)
		add_time("dunes_including_isolated_candidates", started)
		return result
	func _isolated_dunes(q: Vector2, width: float, family: int) -> float:
		var started := Time.get_ticks_usec()
		var result := super._isolated_dunes(q, width, family)
		add_time("isolated_dunes_nested_in_dunes", started)
		return result

class ProfiledDrainage extends "res://scripts/desert_drainage.gd":
	var elapsed: Dictionary = {}
	var calls: Dictionary = {}
	func add_time(stage: String, started: int) -> void:
		elapsed[stage] = int(elapsed.get(stage, 0)) + Time.get_ticks_usec() - started
		calls[stage] = int(calls.get(stage, 0)) + 1
	func sample(p: Vector2, source: RefCounted, wind: Vector2 = Vector2.ZERO) -> Vector4:
		var started := Time.get_ticks_usec()
		var result := super.sample(p, source, wind)
		add_time("drainage_sample_including_descriptors", started)
		return result
	func _nearby(tile: Vector2i, source: RefCounted) -> Array:
		var cached: bool = _tiles.has(tile)
		var started := Time.get_ticks_usec()
		var result := super._nearby(tile, source)
		add_time("tile_hit" if cached else "tile_miss_including_catchments", started)
		return result
	func _catchment(cell: Vector2i, source: RefCounted) -> Array:
		var cached: bool = _catchments.has(cell)
		var started := Time.get_ticks_usec()
		var result := super._catchment(cell, source)
		add_time("catchment_hit" if cached else "catchment_miss_including_region_queries", started)
		return result

func sweep(sampler: RefCounted, origin: Vector2, count: int, step: float) -> Dictionary:
	var checksum: float = 0.0
	var started := Time.get_ticks_usec()
	for z in range(count):
		for x in range(count):
			checksum += sampler.sample(origin.x + x * step, origin.y + z * step)
	return {"elapsed_us":Time.get_ticks_usec()-started, "checksum":checksum}

func _initialize() -> void:
	var rows: Array = []
	var failures: Array[String] = []
	var locations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/desert/preview_locations.json"))
	var cases: Array[Dictionary] = []
	for feature in ["sand_sea", "barchan_dunes", "longitudinal_dunes", "major_canyon", "sandstone_highlands", "badlands", "alluvial_fan"]:
		if not locations.features.has(feature):
			failures.append("Missing discovered location: " + feature)
			continue
		var location: Dictionary = locations.features[feature]
		cases.append({"feature":feature, "origin":Vector2(location.x,location.z), "count":65, "step":4.0})
	cases.append({"feature":"far_1024m_step", "origin":Vector2(0.0,16384.0), "count":17, "step":1024.0})
	for item in cases:
		var ordinary = Desert.new()
		ordinary.configure(DesertSettings.new(), int(locations.seed))
		var reference: Array = []
		for warm in [false, true]:
			var measurement := sweep(ordinary, item.origin, item.count, item.step)
			reference.append(measurement)
		var sampler := ProfiledDesert.new()
		var drainage := ProfiledDrainage.new()
		sampler._drainage_graph = drainage
		sampler.configure(DesertSettings.new(), int(locations.seed))
		for pass_index in range(2):
			sampler.elapsed.clear()
			sampler.calls.clear()
			drainage.elapsed.clear()
			drainage.calls.clear()
			var measured := sweep(sampler, item.origin, item.count, item.step)
			if measured.checksum != reference[pass_index].checksum:
				failures.append("Instrumentation changed checksum: " + str(item.feature))
			rows.append({"feature":item.feature, "origin":[item.origin.x,item.origin.y],
				"warm":pass_index==1, "queries":item.count*item.count, "step_m":item.step,
				"uninstrumented_us":reference[pass_index].elapsed_us,
				"instrumented_us":measured.elapsed_us, "checksum":measured.checksum,
				"sampler_nested_stage_us":sampler.elapsed.duplicate(), "sampler_calls":sampler.calls.duplicate(),
				"drainage_nested_stage_us":drainage.elapsed.duplicate(), "drainage_calls":drainage.calls.duplicate(),
				"cache_sizes":{"regions":sampler._region_cache.size(), "sites":sampler._site_cache.size(),
					"catchments":drainage._catchments.size(), "tiles":drainage._tiles.size()}})
	# Existing builder timers separate actual mesh work from height/normal queries.
	# These one-shot diagnostic rows are not a baseline/performance acceptance gate.
	var meshes: Array = []
	for item in [[Vector2i(-18,35),256.0,64], [Vector2i(72,115),256.0,64], [Vector2i(0,1),16384.0,16]]:
		var builder = Builder.new()
		builder.settings = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		builder.settings.grass_coverage=0.0
		builder.settings.desert_coverage=100.0
		builder.settings.snow_coverage=0.0
		builder.settings.stone_coverage=0.0
		builder.settings.temperature_enabled=false
		builder.world_seed=int(locations.seed)
		builder.chunk_size=item[1]
		builder.profile_build=true
		builder._configure_noise()
		var arrays: Array = builder.build(item[0],item[2])
		meshes.append({"coordinate":str(item[0]), "chunk_size_m":item[1], "resolution":item[2],
			"vertices":arrays[Mesh.ARRAY_VERTEX].size(), "stage_ms":builder.last_build_profile.duplicate()})
	var report := {"engine":Engine.get_version_info().string, "os":OS.get_name(), "seed":locations.seed,
		"note":"Nested instrumented times overlap and include timer overhead. Uninstrumented rows are single diagnostic sweeps, not baseline acceptance or a speedup claim.",
		"rows":rows, "meshes":meshes, "failures":failures}
	FileAccess.open("res://tools/desert/current_stage_profile.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
