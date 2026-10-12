extends "res://tools/preview_erosion.gd"

func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var terrain=scene.get_node("Terrain")
	var focus:=Vector3(-18400,220,-2720)
	var offset:=Vector3(410,130,30)
	for mode in range(6):
		for material: ShaderMaterial in terrain._lod_materials.values():
			material.set_shader_parameter("cliff_layer_isolation",mode)
		await capture(scene,"cliff_composition_%d" % mode,focus,offset)
	for material: ShaderMaterial in terrain._lod_materials.values():
		material.set_shader_parameter("cliff_layer_isolation",0)
	terrain._terrain_material.set_shader_parameter("debug_view",28)
	await capture(scene,"cliff_composition_regions",focus,offset)
	scene.queue_free()
	await process_frame
	quit()
