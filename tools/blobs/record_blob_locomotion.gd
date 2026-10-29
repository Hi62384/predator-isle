extends SceneTree
const Lab=preload("res://scripts/blobs/blob_locomotion_lab.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1200,760)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab:=Lab.new()
	viewport.add_child(lab)
	lab.automatic=false
	DirAccess.make_dir_recursive_absolute("res://.godot/blob_motion_frames")
	for warmup in 6: await process_frame
	var started:=Time.get_ticks_usec()
	var min_separation:=INF
	var maximum_cpu:=0
	for frame in 150:
		# Ten seconds at 15 captured frames/second, with 60 Hz solver substeps.
		for substep in 4: lab.advance(1.0/60.0)
		for organism in lab.organisms: maximum_cpu=maxi(maximum_cpu,organism.last_simulation_usec)
		min_separation=minf(min_separation,lab.organisms[0].position.distance_to(lab.organisms[1].position))
		await process_frame
		await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		image.save_png("res://.godot/blob_motion_frames/%04d.png" % frame)
		if frame in [0,44,74,119,149]: image.save_png("res://data/blobs_v2/motion_%03d.png" % frame)
		if frame%30==0: print("BLOB_MOTION ",frame,"/150")
	var report: Dictionary={"seconds_simulated":10.0,"captured_frames":150,"capture_fps":15,"max_cpu_step_us":maximum_cpu,"mean_capture_frame_ms":float(Time.get_ticks_usec()-started)/150000.0,"minimum_lane_separation":min_separation,"flat_final":str(lab.organisms[0].position),"uneven_final":str(lab.organisms[1].position),"flat_collision_proxies":lab.organisms[0]._collision_nodes.size(),"uneven_collision_proxies":lab.organisms[1]._collision_nodes.size(),"rigid_body_rotation":false}
	var file:=FileAccess.open("res://data/blobs_v2/motion_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("BLOB_MOTION_COMPLETE ",report)
	quit()
