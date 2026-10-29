extends "res://tools/preview_erosion.gd"
const IDS=["Rock064","Rock058","Rock051","Rock060","Rock030","Rock061","Rock050","Rocks007","Rocks011"]
func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var terrain=scene.get_node("Terrain")
	var focus:=Vector3(-18400,190,-2720)
	for i in range(9):
		for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("cliff_force_layer",i)
		await capture(scene,"normal_source_"+IDS[i],focus,Vector3(100,10,0))
	for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("cliff_force_layer",-1)
	await capture(scene,"normal_sources_combined",focus,Vector3(100,10,0))
	for material: ShaderMaterial in terrain._lod_materials.values(): material.set_shader_parameter("cliff_normal_debug",4)
	await capture(scene,"normal_bright_coverage",Vector3(-5760,261.325,17920),Vector3(30,100,410))
	scene.queue_free()
	await process_frame
	quit()
