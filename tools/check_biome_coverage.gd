extends SceneTree

func _initialize() -> void:
	var sampler = load("res://scripts/terrain_mesh_builder.gd").new()
	sampler.settings = TerrainSettings.new()
	sampler.settings.grass_coverage = 90.0
	sampler.settings.desert_coverage = 0.0
	sampler.settings.snow_coverage = 0.0
	sampler.settings.stone_coverage = 10.0
	for stone_size in [3000.0, 30000.0]:
		sampler.settings.stone_region_size = stone_size
		sampler._configure_noise()
		var rng := RandomNumberGenerator.new()
		rng.seed = 98173
		var stone_count := 0
		for i in range(12000):
			var x := rng.randf_range(-2000000.0,2000000.0)
			var z := rng.randf_range(-2000000.0,2000000.0)
			var w: Vector4 = sampler._biome_weights(x,z)
			if w.z != 0.0 or w.y != 0.0 or not is_equal_approx(w.x+w.w,1.0):
				push_error("Disabled biomes or normalization failed")
				quit(1)
				return
			if w.w > w.x:
				stone_count += 1
		print("stone_size=%.0f coverage=%.2f%% region_level=%d" % [stone_size,stone_count/120.0,sampler._region_levels[3]])
		if stone_count < 960 or stone_count > 1440:
			push_error("Rare biome coverage outside expected sampling tolerance")
			quit(1)
			return
		if stone_size == 30000.0:
			# A stone root region must have no grass islands anywhere inside it.
			var protected_regions := 0
			var span: float = sampler._root_region_size
			for cz in range(-20,21):
				for cx in range(-20,21):
					var roll: float = sampler._region_random(cx,cz,sampler._level_probabilities.size()-1,2731)
					if roll >= 0.1:
						continue
					protected_regions += 1
					for z in range(1,10):
						for x in range(1,10):
							if sampler._region_owner(Vector2((cx+x/10.0)*span,(cz+z/10.0)*span)) != 3:
								push_error("Large biome fragmented internally")
								quit(1)
								return
			print("Protected large region interiors checked: ", protected_regions)
	sampler.settings.grass_coverage = 0.0
	sampler._configure_noise()
	if not sampler._biome_weights(-100, 300).is_equal_approx(Vector4(0,0,0,1)):
		quit(1)
		return
	sampler.settings.stone_coverage = 0.0
	sampler._configure_noise()
	if not sampler._biome_weights(100, -300).is_equal_approx(Vector4(1,0,0,0)):
		quit(1)
		return
	print("PASS: size versus rarity, disabled biomes, negative coordinates and single-biome world")
	quit()
