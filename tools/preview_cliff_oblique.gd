extends "res://tools/preview_erosion.gd"

func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	var focus:=Vector3(-18400,190,-2720)
	var offsets: Array[Vector3]=[Vector3(260,30,0),Vector3(160,30,480),Vector3(160,30,-480),Vector3(100,10,0)]
	var args:=OS.get_cmdline_user_args()
	var single:=int(args[0]) if not args.is_empty() else -1
	for i in range(offsets.size()):
		if single>=0 and single!=i: continue
		await capture(scene,"cliff_oblique_%d" % i,focus,offsets[i])
	if single<0 or single==4:
		scene.get_node("Terrain")._terrain_material.set_shader_parameter("debug_view",8)
		await capture(scene,"cliff_oblique_normals",focus,offsets[1])
	scene.queue_free()
	await process_frame
	quit()
