extends "res://tools/preview_erosion.gd"

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var material=scene.get_node("Terrain")._terrain_material
	for mode in [0,10,11,12,13,14,15,16,17,18,19,20]:
		material.set_shader_parameter("debug_view",mode)
		await capture(scene,"surface_mask_"+str(mode),Vector3(5600,250.7541,3840),Vector3(495,145,30))
	scene.queue_free()
	await process_frame
	quit()
