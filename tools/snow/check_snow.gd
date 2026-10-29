extends SceneTree
func _initialize()->void:
	var sampler=preload("res://scripts/snow_sampler.gd").new()
	sampler.configure(SnowSettings.new(),73921)
	for p in [Vector2.ZERO,Vector2(-30000,18000),Vector2(64,64)]:
		print(p," ",sampler.sample(p.x,p.y)," ",sampler.pack())
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new()
	builder.settings=preload("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.grass_coverage=0;builder.settings.desert_coverage=0;builder.settings.snow_coverage=100;builder.settings.stone_coverage=0
	builder.settings.temperature_enabled=false
	builder._configure_noise()
	var arrays=builder.build(Vector2i.ZERO,16)
	print("SNOW_ARRAYS ",arrays[Mesh.ARRAY_VERTEX].size()," ",arrays[Mesh.ARRAY_CUSTOM3].size())
	quit()
