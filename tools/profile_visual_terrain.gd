extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sampler = load("res://scripts/terrain_mesh_builder.gd").new()
	sampler.settings = load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	sampler.settings.grass_coverage = 100
	sampler.settings.desert_coverage = 0
	sampler.settings.snow_coverage = 0
	sampler.settings.stone_coverage = 0
	sampler._configure_noise()
	sampler.profile_build = true
	var noise_start := Time.get_ticks_usec()
	var noise_sum := 0.0
	for i in range(100000):
		noise_sum += sampler._grass_fractal.get_noise_2d(float(i%1000)*13.7,float(i/1000)*17.1)
	print("NOISE_MICROBENCH five_octave_calls=100000 ms=",(Time.get_ticks_usec()-noise_start)/1000.0," checksum=",noise_sum)
	print("Collision generation: none (freecam terrain has no collision meshes).")
	for resolution in [8,16,64]:
		var start := Time.get_ticks_usec()
		var arrays: Array = sampler.build(Vector2i.ZERO,resolution)
		var built := Time.get_ticks_usec()
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var uploaded := Time.get_ticks_usec()
		print("PROFILE resolution=",resolution," worker_arrays_ms=",(built-start)/1000.0," main_mesh_submit_ms=",(uploaded-built)/1000.0)
		print("STAGES ",sampler.last_build_profile)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").settings = sampler.settings
	root.add_child(scene)
	if OS.get_cmdline_user_args().has("debug"):
		scene.get_node("Terrain")._terrain_material.set_shader_parameter("debug_view",3)
	var camera: Camera3D = scene.get_node("FreeCamera")
	camera.set_process(false)
	var peak := Vector3.ZERO
	for z in range(-4,5):
		for x in range(-4,5):
			var h: float = sampler._get_height(x*600.0,z*600.0)
			if h>peak.y:
				peak = Vector3(x*600.0,h,z*600.0)
	# Fixed position/target for meaningful before/after comparisons.
	camera.position = Vector3(3200,1194.558,2900)
	camera.look_at(Vector3(1800,444.558,1200))
	scene.get_node("Interface").hide()
	var start := Time.get_ticks_msec()
	while scene.get_node("Terrain").committed_revision!=scene.get_node("Terrain").partition_revision and Time.get_ticks_msec()-start<45000:
		await process_frame
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "after" if OS.get_cmdline_user_args().has("after") else "before"
	if OS.get_cmdline_user_args().has("debug"): suffix="albedo"
	_capture("res://tools/terrain_reference_"+suffix+".png")
	print("VISUAL peak=",peak," capture=",suffix)
	if OS.get_cmdline_user_args().has("views"):
		for mode in range(1,5):
			scene.get_node("Terrain")._terrain_material.set_shader_parameter("debug_view",mode)
			await process_frame
			await RenderingServer.frame_post_draw
			_capture("res://tools/terrain_debug_"+str(mode)+".png")
		scene.get_node("Terrain")._terrain_material.set_shader_parameter("debug_view",0)
		root.debug_draw=Viewport.DEBUG_DRAW_WIREFRAME
		await process_frame
		await RenderingServer.frame_post_draw
		_capture("res://tools/terrain_debug_5.png")
		root.debug_draw=Viewport.DEBUG_DRAW_DISABLED
	if OS.get_cmdline_user_args().has("close"):
		camera.position = peak+Vector3(200,130,240)
		camera.look_at(peak-Vector3(0,30,0))
		for frame in range(240):
			await process_frame
		await RenderingServer.frame_post_draw
		_capture("res://tools/terrain_reference_close.png")
		# Isolate lighting artifacts from texture repetition at identical geometry.
		var sun=scene.get_node("Sun")
		print("SHADOW_BIAS depth=",sun.shadow_bias," normal=",sun.shadow_normal_bias)
		sun.shadow_enabled=false
		await process_frame
		await RenderingServer.frame_post_draw
		_capture("res://tools/terrain_reference_close_noshadow.png")
		sun.shadow_enabled=true
		var water_target := Vector3.ZERO
		var water_score := INF
		for z in range(-30,31):
			for x in range(-30,31):
				var p := Vector3(x*80.0,0,z*80.0)
				var h: float = sampler._get_height(p.x,p.z)
				if h>-6.0 and h<0.0 and sampler._last_surface.y>0.8 and sampler._last_island>0.01:
					var score := p.distance_squared_to(peak)
					if score<water_score:
						water_target = p
						water_score = score
		if water_score<INF:
			camera.position = water_target+Vector3(190,150,260)
			camera.look_at(water_target)
			var wait_start := Time.get_ticks_msec()
			for frame in range(30):
				await process_frame
			while scene.get_node("Terrain").committed_revision!=scene.get_node("Terrain").partition_revision and Time.get_ticks_msec()-wait_start<20000:
				await process_frame
			await RenderingServer.frame_post_draw
			_capture("res://tools/terrain_reference_water.png")
			print("WATER_VIEW ",water_target)
		# Ground-level check retains physical-scale material detail.
		var ground := water_target+Vector3(120,0,120)
		ground.y = sampler._get_height(ground.x,ground.z)+3.0
		camera.position=ground
		camera.look_at(ground+Vector3(30,-1,20))
		for frame in range(120): await process_frame
		await RenderingServer.frame_post_draw
		_capture("res://tools/terrain_reference_ground.png")
		print("GROUND_VIEW ",ground)
		# Static render A/B includes scene CPU+GPU and swap, not isolated GPU time.
		var detailed_ms: float = await _frame_time()
		var simple := StandardMaterial3D.new()
		simple.albedo_color = Color(0.3,0.4,0.2)
		for child in scene.get_node("Terrain").get_children():
			if child is MeshInstance3D:
				child.material_override = simple
		for frame in range(30):
			await process_frame
		var simple_ms: float = await _frame_time()
		print("STATIC_RENDER detailed_frame_ms=",detailed_ms," simple_frame_ms=",simple_ms," (whole frame A/B, not GPU timestamps)")
	scene.queue_free()
	await process_frame
	quit()

func _frame_time() -> float:
	var start := Time.get_ticks_usec()
	for frame in range(180):
		await process_frame
	return (Time.get_ticks_usec()-start)/180000.0

func _capture(path: String) -> void:
	var frame:=root.get_texture().get_image()
	frame.resize(1280,roundi(1280.0*frame.get_height()/frame.get_width()),Image.INTERPOLATE_LANCZOS)
	frame.save_png(path)
