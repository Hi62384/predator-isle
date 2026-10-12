extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var river = script.new()
	river.settings = TerrainSettings.new()
	river.settings.grass_lake_frequency = 0
	river._configure_noise()
	var dry = script.new()
	dry.settings = river.settings.duplicate(true)
	dry.settings.grass_river_frequency = 0
	dry._configure_noise()
	var curvature := 0.0
	var samples := 0
	var large_jumps := 0
	for z in [700.0,1000.0,1300.0,1700.0,2300.0]:
		var last := 0.0
		var previous := 0.0
		for i in range(600):
			var x := (i-300)*16.0
			var wet: Vector3 = river._grass_sample(x,z)
			var base: Vector3 = dry._grass_sample(x,z)
			var cut := wet.x-base.x
			if i>1:
				var change := absf(cut-2.0*last+previous)
				curvature += change
				if change>5.0:
					large_jumps += 1
				samples += 1
			previous = last
			last = cut
	print("RIVER_CUT curvature=",curvature/samples," repeated sharp changes=",large_jumps," samples=",samples)
	assert(curvature/samples<0.1 and large_jumps<10,"River valley fan/comb regression")
	quit()
