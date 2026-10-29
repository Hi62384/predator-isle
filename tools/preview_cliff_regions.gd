extends "res://tools/preview_erosion.gd"

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var terrain=scene.get_node("Terrain")
	var focus:=Vector3(-18400,220,-2720)
	await capture(scene,"regions_combined",focus,Vector3(410,130,30))
	await capture(scene,"regions_close",focus,Vector3(160,30,480))
	for mode in [32,33,34]:
		for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("debug_view",mode)
		await capture(scene,"regions_debug_%d" % mode,focus,Vector3(410,130,30))
	for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("debug_view",0)
	await capture(scene,"regions_second",Vector3(5120,247,3840),Vector3(410,130,30))
	scene.queue_free()
	await process_frame
	quit()
