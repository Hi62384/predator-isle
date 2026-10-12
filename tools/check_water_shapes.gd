extends SceneTree

func _initialize() -> void:
	var sampler = load("res://scripts/terrain_mesh_builder.gd").new()
	sampler.settings = TerrainSettings.new()
	sampler.settings.grass_mountain_frequency = 0.0
	sampler.settings.grass_lake_frequency = 0.8
	sampler._configure_noise()
	var center: float = sampler._grass_river_center(0.0,0,4000.0)
	var turns := 0
	var previous_slope := 0.0
	for i in range(-100,100):
		var x := i*100.0
		var slope: float = sampler._grass_river_center(x+100,0,4000)-sampler._grass_river_center(x,0,4000)
		if slope*previous_slope < 0:
			turns += 1
		previous_slope = slope
	assert(turns > 10)
	var map := Image.create(768,768,false,Image.FORMAT_RGB8)
	for z in range(768):
		for x in range(768):
			var p := Vector2((x-384)*6.0,(z-384)*6.0+center)
			var v: Vector3 = sampler._grass_sample(p.x,p.y)
			var height := lerpf(maxf(v.x,1.0),v.z,v.y)
			var color := Color(0.18,0.4+clampf(height/150,0,1)*0.3,0.13) if height>0 else Color(0.03,0.4,0.75)
			map.set_pixel(x,z,color)
	map.save_png("res://tools/water_shapes.png")
	print("PASS noise-driven river turns=",turns,"; wrote actual-height water map")
	quit()
