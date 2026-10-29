extends SceneTree

func _initialize() -> void:
	var builder_script = load("res://scripts/terrain_mesh_builder.gd")
	var palette := [Color("#568740"),Color("#dbc36b"),Color("#e9eff5"),Color("#6e7278")]
	var image := Image.create(768,256,false,Image.FORMAT_RGB8)
	# Left: saved settings, 4 km view. Middle: 90/10 grass/stone.
	# Right: same coverage with 10x larger stone regions, same 300 km view.
	for panel in range(3):
		var sampler = builder_script.new()
		sampler.settings = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) if panel == 0 else TerrainSettings.new()
		var span := 4096.0 if panel == 0 else 300000.0
		if panel > 0:
			sampler.settings.grass_coverage = 90
			sampler.settings.desert_coverage = 0
			sampler.settings.snow_coverage = 0
			sampler.settings.stone_coverage = 10
			sampler.settings.stone_region_size = 3000 if panel == 1 else 30000
		sampler._configure_noise()
		for y in range(256):
			for x in range(256):
				var w: Vector4 = sampler._biome_weights((x/256.0-0.5)*span,(y/256.0-0.5)*span)
				var color := Color(0,0,0,1)
				for i in range(4):
					color += palette[i] * w[i]
				image.set_pixel(panel*256+x,y,color)
	image.save_png("res://tools/biome_regions.png")
	print("Saved tools/biome_regions.png")
	quit()
