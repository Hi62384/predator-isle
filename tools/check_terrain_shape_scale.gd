extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var a = script.new()
	a.settings = TerrainSettings.new()
	a.settings.island_size = 3000.0
	a._configure_noise()
	var b = script.new()
	b.settings = a.settings.duplicate(true)
	b.settings.island_size = 12000.0
	b._configure_noise()
	var compared := 0
	for i in range(4000):
		var p := Vector2(i*37.91-70000.0,i*-19.73+40000.0)
		var da: float = a._island_mask(p.x,p.y)*a.settings.island_size*0.5
		var db: float = b._island_mask(p.x,p.y)*b.settings.island_size*0.5
		if minf(da,db)>a.settings.coast_width*694.445:
			assert(is_equal_approx(a._get_height(p.x,p.y),b._get_height(p.x,p.y)))
			compared += 1
	assert(compared>100)
	print("PASS island size leaves inland heights identical across ",compared," shared interior samples")
	quit()
