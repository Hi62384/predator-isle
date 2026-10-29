extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1280,800)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D=load("res://scenes/labs/blob_lab.tscn").instantiate()
	viewport.add_child(scene)
	var workshop: Node3D=scene.get_node("Workshop")
	var deadline:=Time.get_ticks_msec()+60000
	while workshop.worker.is_started() and Time.get_ticks_msec()<deadline: await create_timer(.1).timeout
	if not is_instance_valid(workshop.creature): push_error("Lab failed to generate"); quit(1); return
	workshop.creature.speed=0
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://data/blobs_v2/generator_interface.png")
	print("BLOB_LAB_UI_OK")
	quit()
