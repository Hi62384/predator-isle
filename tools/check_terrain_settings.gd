extends SceneTree

func _initialize() -> void:
	var builder_script = load("res://scripts/terrain_mesh_builder.gd")
	var base = builder_script.new()
	base.settings = load("res://terrain_settings.tres").duplicate(true)
	base._configure_noise()
	var sample := Vector2(1734, -2671)
	var original: Vector4 = base._biome_weights(sample.x, sample.y)
	assert(is_equal_approx(original.x + original.y + original.z + original.w, 1.0))
	for property in ["biome_size", "grass_region_size", "desert_region_size", "snow_region_size", "stone_region_size"]:
		var changed = builder_script.new()
		changed.settings = base.settings.duplicate(true)
		changed.settings.set(property, changed.settings.get(property) * 2.0)
		changed._configure_noise()
		var index := ["grass_region_size", "desert_region_size", "snow_region_size", "stone_region_size"].find(property)
		if index < 0:
			index = 0
		assert(is_equal_approx(changed._region_sizes[index], base._region_sizes[index] * 2.0), property + " must scale region footprints")
		assert(changed._region_levels.size() == 4, "All biome sizes must have hierarchy levels")
	var terrain = load("res://scripts/chunk_terrain.gd").new()
	terrain._configure_noise()
	for x in [-1400.0, 0.0, 750.0]:
		assert(is_equal_approx(terrain.get_height_at(Vector3(x,0,570)), base._get_height(x,570)))
	var changed = builder_script.new()
	changed.settings = base.settings.duplicate(true)
	changed.settings.height_multiplier = 2.0
	changed._configure_noise()
	assert(is_equal_approx(changed._get_height(100,200), base._get_height(100,200)*2.0))
	terrain.free()
	print("PASS: individual region sizes, normalized blends, height scaling, and worker/debug sampler parity")
	quit()
