extends SceneTree

func _initialize() -> void:
	var builder = load("res://scripts/terrain_mesh_builder.gd")
	var reference = builder.new()
	reference.settings = TerrainSettings.new()
	reference._configure_noise()
	var altered = builder.new()
	altered.settings = reference.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	altered.settings.island_size = 6700.0
	altered.settings.island_spacing = 1.0
	altered._configure_noise()
	for i in range(100):
		var p := Vector2(i*173.0-8000.0,i*-257.0+4000.0)
		assert(reference._biome_weights(p.x,p.y).is_equal_approx(altered._biome_weights(p.x,p.y)))
		assert(is_equal_approx(reference.get_temperature(p.x,p.y),altered.get_temperature(p.x,p.y)))
	print("PASS: island size and shoreline spacing leave biome/climate fields unchanged")
	var previous := 0.0
	for gap in [1.0,32.0,250.0,600.0]:
		var sampler = builder.new()
		sampler.settings = TerrainSettings.new()
		sampler.settings.island_spacing = gap
		sampler.settings.island_spacing_variation = 0.0
		sampler.settings.shoreline_detail_strength = 0.0
		sampler.settings.island_coast_irregularity = 0.0
		sampler._configure_noise()
		var submerged := 0
		var total := 0
		var crossing := false
		# Fine sampling across the actual height field, not reserved footprints.
		var in_water := false
		var water_start := 0.0
		var shortest := INF
		for i in range(24000):
			var x := i*0.5-6000.0
			var h: float = sampler._get_height(x,173.0)
			if h <= 0.0:
				submerged += 1
				if not in_water:
					water_start = x
					in_water = true
			elif in_water:
				if water_start > -6000.0:
					shortest = minf(shortest,x-water_start)
					crossing = true
				in_water = false
			total += 1
		var fraction := float(submerged)/total
		assert(crossing and fraction > previous)
		assert(shortest >= gap*0.9)
		if gap == 1.0:
			assert(shortest <= 2.0 and fraction < 0.02)
		previous = fraction
		print("PASS spacing=",gap," shortest sampled shoreline gap=",shortest," water fraction=",fraction)
		if gap == 1.0:
			sampler.settings.island_coast_irregularity = 0.3
			sampler._configure_noise()
			var map := Image.create(512,512,false,Image.FORMAT_RGB8)
			for y in range(512):
				for x in range(512):
					var h: float = sampler._get_height((x-256)*12.0,(y-256)*12.0)
					map.set_pixel(x,y,Color("#568740") if h>0 else Color("#168fbe"))
			map.save_png("res://tools/island_layout.png")
	quit()
