extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var small = script.new()
	small.settings = TerrainSettings.new()
	small._configure_noise()
	var large = script.new()
	large.settings = small.settings.duplicate(true)
	large.settings.island_size = 12000.0
	large._configure_noise()
	var smooth = script.new()
	smooth.settings = large.settings.duplicate(true)
	smooth.settings.shoreline_detail_strength = 0.0
	smooth._configure_noise()
	var differences := 0
	var max_detail := 0.0
	for i in range(4000):
		var p := Vector2(i*13.17-26000.0,i*-7.31+14000.0)
		var detail: Vector2 = large._shoreline_detail_offset(p.x,p.y)
		assert(detail.is_equal_approx(small._shoreline_detail_offset(p.x,p.y)))
		max_detail = maxf(max_detail,detail.length())
		if absf(large._island_mask(p.x,p.y)-smooth._island_mask(p.x,p.y)) > 0.0001:
			differences += 1
		assert(large._biome_weights(p.x,p.y).is_equal_approx(smooth._biome_weights(p.x,p.y)))
	assert(max_detail > 10.0 and differences > 1000)
	print("PASS: fixed metre-scale shore detail at 12 km island size; affected samples=",differences," max displacement=",max_detail,"; biome field unchanged")
	quit()
