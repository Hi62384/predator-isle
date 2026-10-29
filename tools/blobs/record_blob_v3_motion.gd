extends "res://tools/blobs/render_blob_v3_sheets.gd"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/blob_v3_frames")
	var sheet:=SubViewport.new(); sheet.size=Vector2i(1800,680); sheet.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(sheet)
	var cameras:Array[Camera3D]=[]
	var names:Array=["ROLL / material circulation","VINE / reach, grip, pull, release","LEGS / planted hinge contacts"]
	for panel in 3:
		var container:=SubViewportContainer.new(); container.position=Vector2(panel*600,0); container.size=Vector2(600,640); sheet.add_child(container)
		var viewport:=SubViewport.new(); viewport.size=Vector2i(600,640); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
		var file:=FileAccess.open("res://.godot/blob_validation_v3/model_%02d.bin"%[0,3,6][panel],FileAccess.READ); var data:Dictionary=file.get_var(false); file.close()
		_tile(viewport,data,false)
		var actor:Node3D=active_organisms[-1]; actor.travel_enabled=true; actor.set_locomotion(["roll","vine","limb"][panel]); actor.debug_contacts=panel>0
		cameras.append(viewport.get_camera_3d())
		var title:=Label.new(); title.position=Vector2(panel*600+16,625); title.text=names[panel]; title.add_theme_font_size_override("font_size",19); sheet.add_child(title)
	for i in 8: await process_frame
	var max_cpu:=0; var max_lock:=.0; var started:=Time.get_ticks_usec()
	for frame in 150:
		for step in 4:
			for i in active_organisms.size():
				var actor:Node3D=active_organisms[i]
				var before:Vector3=actor.position
				actor.speed=.6 if frame<45 else (.0 if frame<60 else (-.6 if frame<105 else .0))
				actor.simulate(1.0/60.0)
				cameras[i].position+=actor.position-before
				max_cpu=maxi(max_cpu,actor.last_simulation_usec); max_lock=maxf(max_lock,actor.contacts.maximum_lock_error)
		await process_frame; await RenderingServer.frame_post_draw
		var image:=sheet.get_texture().get_image(); image.save_png("res://.godot/blob_v3_frames/%04d.png"%frame)
		if frame in [0,44,104,149]: image.save_png("res://data/blobs_v3/motion_%03d.png"%frame)
		if frame%30==0: print("V3_MOTION ",frame," / 150")
	var report:Dictionary={"seconds_simulated":10,"capture_fps":15,"solver_hz":60,"max_step_us":max_cpu,"max_stance_error":max_lock,"capture_ms_per_frame":float(Time.get_ticks_usec()-started)/150000.0}
	var file:=FileAccess.open("res://data/blobs_v3/motion_validation.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("V3_MOTION_COMPLETE ",report); quit()
