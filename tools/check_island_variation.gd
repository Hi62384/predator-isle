extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var base = script.new()
	base.settings = TerrainSettings.new()
	base.settings.island_spacing = 80.0
	# Macro layout scales proportionally; optional local shore detail deliberately does not.
	base.settings.shoreline_detail_strength = 0.0
	base._configure_noise()
	var large = script.new()
	large.settings = base.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	large.settings.island_size *= 2.0
	large._configure_noise()
	for i in range(1000):
		var p := Vector2(i*71.37-35000.0,i*-13.91+7000.0)
		assert(absf(base._island_mask(p.x,p.y)-large._island_mask(p.x*2,p.y*2))<0.0001)
		assert(base._biome_weights(p.x,p.y).is_equal_approx(large._biome_weights(p.x,p.y)))
	base.settings.island_coast_irregularity = 0.0
	base._configure_noise()
	var widths: Array[float] = []
	var start := -INF
	for i in range(160000):
		var x := i*0.5-40000.0
		var h: float = base._get_height(x,173.0)
		if h <= 0.0 and start == -INF:
			start = x
		elif h > 0.0 and start != -INF:
			if start > -40000.0:
				widths.append(x-start)
			start = -INF
	widths.sort()
	assert(widths.size()>30 and widths[-1]>widths[0]*2.0)
	print("PASS proportional island/spacing scaling and independent biomes; sampled shoreline widths=",widths[0]," to ",widths[-1]," m across ",widths.size()," channels")
	quit()
