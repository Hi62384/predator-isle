extends SceneTree

func _initialize() -> void:
	var script = load("res://scripts/terrain_mesh_builder.gd")
	var layered = script.new()
	layered.settings = TerrainSettings.new()
	layered._configure_noise()
	var single = script.new()
	single.settings = layered.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	single.settings.grass_fractal_octaves = 1
	single._configure_noise()
	var disabled = script.new()
	disabled.settings = layered.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	disabled.settings.grass_fractal_strength = 0.0
	disabled._configure_noise()
	var curvature := Vector2.ZERO
	var changed := 0
	for i in range(4000):
		var x := i*7.3-15000.0
		var z := i*-3.1+3000.0
		for j in range(2):
			var noise: FastNoiseLite = layered._grass_fractal if j == 0 else single._grass_fractal
			curvature[j] += absf(noise.get_noise_2d(x-4,z)+noise.get_noise_2d(x+4,z)-2.0*noise.get_noise_2d(x,z))
		var a: Vector3 = layered._grass_sample(x,z)
		var b: Vector3 = disabled._grass_sample(x,z)
		assert(is_equal_approx(a.y,b.y) and is_equal_approx(a.z,b.z))
		if absf(a.x-b.x)>0.1:
			changed += 1
	assert(curvature.x > curvature.y*2.0 and changed>1000)
	print("PASS five-octave local curvature / one-octave=",curvature.x/curvature.y,"; changed landform samples=",changed,"; water masks/beds unchanged")
	quit()
