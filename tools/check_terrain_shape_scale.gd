extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var a = script.new()
	a.settings = TerrainSettings.new()
	# This regression isolates inland landforms. The later shore-distance
	# overlay intentionally covers most small islands and has its own tests.
	a.settings.rocky_coast_enabled=false;a.settings.beaches_enabled=false
	a.settings.island_size = 3000.0
	a._configure_noise()
	var b = script.new()
	b.settings = a.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	b.settings.island_size = 12000.0
	b._configure_noise()
	var compared := 0
	for i in range(4000):
		var p := Vector2(i*37.91-70000.0,i*-19.73+40000.0)
		var da: float = a._island_mask(p.x,p.y)*a.settings.island_size*0.5
		var db: float = b._island_mask(p.x,p.y)*b.settings.island_size*0.5
		# Coastal landforms intentionally follow shore distance. Compare true
		# interior points beyond both the old shore blend and the coast overlay.
		var interior:float=maxf(a.settings.coast_width*694.445,maxf(a._coast_limit,b._coast_limit))+1
		if minf(da,db)>interior:
			assert(is_equal_approx(a._get_height(p.x,p.y),b._get_height(p.x,p.y)))
			compared += 1
	assert(compared>100)
	print("PASS island size leaves inland heights identical across ",compared," shared interior samples; coast overlay isolated")
	quit()
