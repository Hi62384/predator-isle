extends SceneTree

func _initialize() -> void:
	var builder_script = load("res://scripts/terrain_mesh_builder.gd")
	var base = builder_script.new()
	base.settings = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	base._configure_noise()
	var sample := Vector2(1734, -2671)
	var original: Vector4 = base._biome_weights(sample.x, sample.y)
	var total:float=original.x+original.y+original.z+original.w+base._jungle_weight+base._mountain_weight+base._tropical_weight+base._badlands_weight
	for weight:float in base._extra_weights:total+=weight
	assert(is_equal_approx(total,1.0))
	# These are the current sixteen owners. Desert/Snow/Stone no longer have
	# ownership settings; testing removed properties silently tested nothing.
	var owners:Array[String]=["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]
	owners.append_array(TerrainSettings.EXTENSION_KEYS)
	var fixture=builder_script.new();fixture.settings=base.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in owners:fixture.settings.set(key+"_coverage",20)
	fixture._configure_noise()
	assert(fixture._region_levels.size()==owners.size())
	for property:String in ["biome_size"]+owners.map(func(key:String)->String:return key+"_region_size"):
		var changed = builder_script.new()
		changed.settings = fixture.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		changed.settings.set(property, changed.settings.get(property) * 2.0)
		changed._configure_noise()
		var index:int=owners.find(property.trim_suffix("_region_size"))
		for owner in range(owners.size()):
			var factor:float=2 if property=="biome_size" or owner==index else 1
			assert(is_equal_approx(changed._region_sizes[owner],fixture._region_sizes[owner]*factor),property+" must scale only the requested footprints")
		assert(changed._region_levels.size()==owners.size(),"All sixteen biome sizes have hierarchy levels")
	var terrain = load("res://scripts/chunk_terrain.gd").new()
	terrain._configure_noise()
	for x in [-1400.0, 0.0, 750.0]:
		assert(is_equal_approx(terrain.get_height_at(Vector3(x,0,570)), base._get_height(x,570)))
	var changed = builder_script.new()
	changed.settings = base.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	changed.settings.height_multiplier = 2.0
	changed._configure_noise()
	assert(is_equal_approx(changed._get_height(100,200), base._get_height(100,200)*2.0))
	terrain.free()
	print("PASS: individual region sizes, normalized blends, height scaling, and worker/debug sampler parity")
	quit()
