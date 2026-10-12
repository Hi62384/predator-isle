extends SceneTree

func _initialize() -> void:
	var sampler = load("res://scripts/terrain_mesh_builder.gd").new()
	sampler.settings = TerrainSettings.new()
	sampler._configure_noise()
	var counts := [0,0,0,0]
	var previous := PackedInt32Array()
	previous.resize(300)
	previous.fill(-1)
	for z in range(300):
		var left := -1
		for x in range(300):
			var p := Vector2((x-150)*800.0,(z-150)*800.0)
			var biome: int = sampler._region_owner(p)
			var temperature: float = sampler._temperature_at_region(p)
			counts[biome] += 1
			if (biome == 2 and temperature > sampler.settings.snow_max_temperature) or (biome == 1 and temperature < sampler.settings.desert_min_temperature):
				push_error("Biome outside eligible temperature")
				quit(1)
				return
			if (biome == 1 and (left == 2 or previous[x] == 2)) or (biome == 2 and (left == 1 or previous[x] == 1)):
				push_error("Hot/cold adjacency in climate sample")
				quit(1)
				return
			left = biome
			previous[x] = biome
	if counts[1] < 9000 or counts[2] < 9000:
		push_error("Climate removed all deserts or snow")
		quit(1)
		return
	print("PASS: 90,000 samples, eligible temperatures, no snow/desert adjacency; counts=", counts)
	quit()
