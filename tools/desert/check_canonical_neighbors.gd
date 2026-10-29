extends SceneTree
## Low-memory actual builder height queries. No meshes, GPU or SceneTree terrain.
const Builder = preload("res://scripts/terrain_mesh_builder.gd")
const Baseline = preload("res://tools/desert/baseline/builder.gd")
const TerrainSettings = preload("res://scripts/terrain_settings.gd")
var failures: Array[String] = []
var comparisons: int = 0
var grass_neighbors: int = 0
var shared_coordinates: int = 0

func check(ok: bool, label: String) -> void:
	comparisons += 1
	if not ok:
		failures.append(label)
		if failures.size() < 10: push_error(label)

func make_builder(script: Script, config, seed_value: int, size: float):
	var builder = script.new()
	builder.settings = config.duplicate(true)
	builder.world_seed = seed_value
	builder.chunk_size = size
	builder._configure_noise()
	return builder

func _initialize() -> void:
	var started := Time.get_ticks_usec()
	for seed_value in [73921, 12345, 90317]:
		var grass = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		grass.temperature_enabled = false
		grass.grass_coverage = 100.0
		grass.desert_coverage = 0.0
		grass.snow_coverage = 0.0
		grass.stone_coverage = 0.0
		var changed = grass.duplicate(true)
		changed.desert.dune_occurrence = 0.0
		changed.desert.canyon_occurrence = 0.0
		changed.desert.dry_lake_occurrence = 0.0
		changed.desert.dune_max_height = 180.0
		changed.desert.highland_height = 900.0
		changed.desert.wind_direction_degrees = -147.0
		var old = make_builder(Baseline, grass, seed_value, 256.0)
		var current = make_builder(Builder, changed, seed_value, 256.0)
		for i in range(512):
			var point := Vector2((i * 3793 % 211) * 737.0 - 77553.0, (i * 1913 % 227) * 641.0 - 70291.0)
			var expected: float = old._get_height(point.x, point.y)
			check(current._get_height(point.x, point.y) == expected, "Pure Grass canonical height changed")
			check(current._last_geology == old._last_geology, "Pure Grass geology changed")
		var mixed = grass.duplicate(true)
		mixed.grass_coverage = 50.0
		mixed.desert_coverage = 50.0
		mixed.grass_region_size = 24000.0
		mixed.desert_region_size = 24000.0
		mixed.biome_size = 1.0
		var mixed_old = make_builder(Baseline, mixed, seed_value, 256.0)
		var mixed_new = make_builder(Builder, mixed, seed_value, 256.0)
		for i in range(1024):
			var point := Vector2((i * 1543 % 397) * 1024.0 - 201728.0, (i * 2357 % 401) * 1024.0 - 201728.0)
			if mixed_new._biome_weights(point.x, point.y) != Vector4(1, 0, 0, 0): continue
			grass_neighbors += 1
			var expected: float = mixed_old._get_height(point.x, point.y)
			check(mixed_new._get_height(point.x, point.y) == expected, "Grass neighbor height changed in mixed world")
			check(mixed_new._last_geology == mixed_old._last_geology, "Grass neighbor geology changed")
		var desert = grass.duplicate(true)
		desert.grass_coverage = 0.0
		desert.desert_coverage = 100.0
		var workers: Array = []
		for size in [128.0, 256.0, 512.0, 16384.0]:
			workers.append(make_builder(Builder, desert, seed_value, size))
		for i in range(256):
			# Same exact world point expressed as a fine tile vertex, parent tile
			# vertex and a different worker query. Geometry isn't constructed.
			var gx: int = i * 37 % 128 - 64
			var gz: int = i * 71 % 128 - 64
			var point := Vector2(gx * 8.0, gz * 8.0) + Vector2(-4608, 8960)
			var expected: float = workers[0]._get_height(point.x, point.y)
			var fields: Array = [workers[0]._last_desert_region, workers[0]._last_desert_surface, workers[0]._last_desert_wind,workers[0]._last_desert_detail]
			for index in range(1, workers.size()):
				var worker = workers[index]
				var cell := Vector2(floorf(point.x / worker.chunk_size), floorf(point.y / worker.chunk_size))
				var local: Vector2 = point - cell * worker.chunk_size
				var reconstructed: Vector2 = cell * worker.chunk_size + local
				check(reconstructed == point, "World coordinate reconstruction changed")
				check(worker._get_height(reconstructed.x, reconstructed.y) == expected, "Canonical query depends on chunk span")
				check([worker._last_desert_region, worker._last_desert_surface, worker._last_desert_wind,worker._last_desert_detail] == fields, "Canonical controls depend on chunk span")
				shared_coordinates += 1
	check(grass_neighbors > 100, "Insufficient pure Grass neighbor coverage")
	var report := {"engine":Engine.get_version_info().string, "os":OS.get_name(),
		"scope":"Actual copied builder canonical sampling only; no mesh seam, rendered LOD, shader or visual claim.",
		"comparisons":comparisons, "grass_neighbors":grass_neighbors, "shared_coordinates":shared_coordinates,
		"duration_s":(Time.get_ticks_usec() - started) / 1000000.0, "failures":failures}
	FileAccess.open("res://tools/diagnostics/artifacts/canonical_neighbors.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
