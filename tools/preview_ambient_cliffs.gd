extends "res://tools/preview_erosion.gd"
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var terrain=scene.get_node("Terrain")
	var focus:=Vector3(-18400,220,-2720)
	for mode in range(7):
		for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("cliff_normal_debug",mode)
		await capture(scene,"ambient_cliff_mode_%d" % mode,focus,Vector3(410,130,30))
	for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("cliff_normal_debug",0)
	await capture(scene,"ambient_cliff_close",focus,Vector3(100,5,0))
	await capture(scene,"ambient_cliff_oblique",focus,Vector3(160,30,-480))
	await capture(scene,"ambient_cliff_water",Vector3(5600,247,3840),Vector3(300,75,0))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for enabled in [false,true]:
		for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("enable_ambient_cliff_normals",enabled)
		for frame in range(30): await process_frame
		var cpu:=0.0
		var gpu:=0.0
		for frame in range(180):
			await process_frame
			cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		print("Ambient enabled=",enabled," viewport CPU/GPU ms=",cpu/180.0," / ",gpu/180.0)
	scene.queue_free()
	await process_frame
	quit()
