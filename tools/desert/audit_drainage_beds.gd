extends SceneTree
## Samples actual canonical final terrain, not only graph endpoint metadata.
## A finite diagnostic, not a global hydraulic proof or live erosion simulation.
const Builder = preload("res://scripts/terrain_mesh_builder.gd")

func audit(seed_number: int, water_supported: bool) -> Dictionary:
	var b = Builder.new()
	b.settings = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	b.settings.grass_coverage = 0.0
	b.settings.desert_coverage = 100.0
	b.settings.snow_coverage = 0.0
	b.settings.stone_coverage = 0.0
	b.settings.temperature_enabled = false
	b.settings.water_enabled = water_supported
	b.world_seed = seed_number
	b._configure_noise()
	var graph = b._desert._drainage_graph
	var pairs: int = 0
	var dry_pairs: int = 0
	var dry_uphill: int = 0
	var all_uphill: int = 0
	var worst_dry: float = 0.0
	var worst_all: float = 0.0
	var worst_record: Dictionary = {}
	for z in range(-2, 3):
		for x in range(-2, 3):
			var descriptor: Array = graph._catchment(Vector2i(x, z), b._desert)
			for edge: Array in descriptor[0]:
				var previous: float = 0.0
				var valid: bool = false
				var previous_dry: bool = false
				var count: int = clampi(ceili(Vector2(edge[7]).length() / 25.0), 16, 256)
				for j in range(count + 1):
					var t: float = float(j) / count
					var p: Vector2 = edge[0] + edge[7] * t + edge[6] * (4.0 * t * (1.0 - t))
					var h: float = b._get_height(p.x, p.y)
					var current: bool = b._last_island > 0.05 and b._last_desert_surface.y > 0.95 and h > 0.0
					var dry: bool = b._last_desert_wind.w < 0.01
					if valid and current:
						pairs += 1
						# Descriptor order is downstream to upstream, hence previous-h.
						var rise: float = previous - h
						worst_all = maxf(worst_all, rise)
						if rise > 2.0: all_uphill += 1
						if dry and previous_dry:
							dry_pairs += 1
							if rise > 2.0: dry_uphill += 1
							if rise > worst_dry:
								worst_dry = rise
								worst_record = {"x": p.x, "z": p.y, "previous_h": previous, "h": h, "catchment": str(Vector2i(x,z)), "floor": graph.last_floor, "region": str(b._desert.last_weights), "surface": str(b._desert.control_surface), "nominal": lerpf(edge[2],edge[3],t)}
					valid = current
					previous = h
					previous_dry = dry
	return {"seed": seed_number, "water_supported": water_supported, "tested_centerline_steps": pairs, "dry_steps": dry_pairs, "dry_downstream_uphill_steps_over_2m": dry_uphill, "all_downstream_uphill_steps_over_2m": all_uphill, "worst_dry_downstream_rise_m": worst_dry, "worst_all_downstream_rise_m": worst_all, "worst_dry": worst_record}

func _initialize() -> void:
	var results: Array = []
	var failed: bool = false
	for seed_number in [73921, 12345, 90317]:
		for water_supported in [true, false]:
			var result: Dictionary = audit(seed_number, water_supported)
			results.append(result)
			failed = failed or result.dry_downstream_uphill_steps_over_2m > 0
			print(JSON.stringify(result))
	var report := {"note": "Finite final-height probes, 25 catchments per configuration, approximately 25m spacing, inland active channels. Dry excludes oasis shore wetness >=0.01. Wet shore/pool intersections are reported separately, not hidden as dry passes. Not an exhaustive proof.", "results": results}
	FileAccess.open("res://tools/desert/drainage_bed_audit.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	quit(1 if failed else 0)
