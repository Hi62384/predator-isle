extends "res://tools/preview_erosion.gd"

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	var terrain = scene.get_node("Terrain")
	terrain.grass_preview = true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var b = terrain._sampler
	var p := Vector3(1800, 0, 1200)
	p.y = b._get_height(p.x, p.z)
	await capture(scene, "ground_new_aerial", p, Vector3(1000, 850, 1100))
	await capture(scene, "ground_new_hill", p, Vector3(170, 100, 220))
	var near := Vector3(0, 0, 230)
	near.y = b._get_height(near.x, near.z)
	await capture(scene, "ground_new_close", near+Vector3(0,0.7,0), Vector3(-5,1.1,-7))
	var shore := Vector3.ZERO
	var found := false
	for z in range(-20,21):
		for x in range(-20,21):
			var h: float = b._get_height(x*100.0,z*100.0)
			if h>0.5 and h<2.0:
				shore=Vector3(x*100.0,h,z*100.0)
				found=true
				break
		if found: break
	assert(found)
	await capture(scene, "ground_new_shore", shore, Vector3(150,120,170))
	for mode in [2,3,4,5,8,9,10,11,12,13]:
		terrain.ground_material_settings.debug_mode=mode
		terrain._refresh_ground_settings()
		await capture(scene, "ground_mask_%d"%mode, shore if mode>=4 else p, Vector3(300,350,300))
	terrain.ground_material_settings.debug_mode=0
	terrain._refresh_ground_settings()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for frame in range(30): await process_frame
	var gpu := 0.0
	for frame in range(120):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	print("Ground refinement viewport GPU ms: ",gpu/120.0)
	# Every streamed LOD receives the same stable world-scale settings.
	for material: ShaderMaterial in terrain._lod_materials.values():
		assert(material.get_shader_parameter("ground_patch_size")==48.0)
		assert(material.get_shader_parameter("ground_debug")==0)
	# Persist/reload just like the Inspector, without touching the user's preset.
	var saved = terrain.ground_material_settings.duplicate()
	var test_path := "user://ground_settings_test.tres"
	saved.dirt_coverage = 0.17
	assert(ResourceSaver.save(saved,test_path)==OK)
	var file := FileAccess.open(test_path,FileAccess.READ)
	assert(file.get_length()<8192)
	file.close()
	terrain.ground_material_settings=load(test_path)
	terrain._refresh_ground_settings(true)
	saved.path_coverage=0.12
	assert(ResourceSaver.save(saved,test_path)==OK)
	terrain._ground_file_time=0
	terrain._refresh_ground_settings()
	for material: ShaderMaterial in terrain._lod_materials.values():
		assert(is_equal_approx(material.get_shader_parameter("ground_path_coverage"),0.12))
		assert(is_equal_approx(material.get_shader_parameter("ground_dirt_coverage"),0.17))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("PASS compact ground settings, saved reload, all LOD uniforms")
	scene.queue_free()
	await process_frame
	quit()
