extends "res://tools/blobs/render_blob_v4_sheets.gd"
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
func _run()->void:
	DirAccess.make_dir_recursive_absolute("res://.godot/blob_v4_motion_frames")
	var sheet:=SubViewport.new();sheet.size=Vector2i(1440,1080);sheet.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(sheet)
	var cameras:Array[Camera3D]=[];var captions:Array[Label]=[];var models:Array[Dictionary]=[];var distances:Array[float]=[0,0,0,0]
	var titles:Array=["ROLL / coherent soft tissue","VINES / planted pulling","LEGS / stance and recovery","IDLE / localized sac inflation"]
	for panel in 4:
		var index:int=[0,1,2,0][panel]
		var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%index,FileAccess.READ);var data:Dictionary=f.get_var(false);f.close();models.append(data)
		var container:=SubViewportContainer.new();container.position=Vector2((panel%2)*720,(panel/2)*540);container.size=Vector2(720,500);sheet.add_child(container)
		var viewport:=SubViewport.new();viewport.size=Vector2i(720,500);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
		_tile(viewport,data,false)
		var actor:Node3D=active_organisms[-1];actor.travel_enabled=panel<3;actor.set_locomotion(["roll","vine","limb","roll"][panel]);actor.debug_contacts=panel in [1,2]
		var camera:=viewport.get_camera_3d();camera.size*=1.12;cameras.append(camera)
		if panel==3:
			var sac:Dictionary={};var count:=0
			for feature:Dictionary in data.features:
				if feature.feature_type!="inflated_sac":continue
				var visible:=0
				for id:int in data.body.feature_ids:
					if id==feature.id:visible+=1
				if visible>count:sac=feature;count=visible
			var focus:Vector3=actor.attachment_position(sac.id)
			camera.position=focus+(sac.direction+Vector3.UP*.3).normalized()*5;camera.look_at(focus);camera.size=sac.radii.length()*2.0
		var caption:=Label.new();caption.position=container.position+Vector2(12,503);caption.add_theme_font_size_override("font_size",18);sheet.add_child(caption);captions.append(caption)
	for frame in 8:await process_frame
	var maximum:=0;var inverted:=0;var maximum_stretch:=.0;var lock:=.0;var started:=Time.get_ticks_usec()
	for frame in 180:
		for substep in 4:
			for panel in 4:
				var actor:Node3D=active_organisms[panel];var before:Vector3=actor.position
				actor.speed=(.9 if frame<45 else (0 if frame<60 else (.8 if frame<120 else (-.7 if frame<150 else 0)))) if panel<3 else 0
				if frame>=60 and frame<105 and panel<3:actor.direction=Vector3.FORWARD.rotated(Vector3.UP,float(frame-60)/45*.6)
				actor.simulate(1.0/60);distances[panel]+=actor.position.distance_to(before)
				if panel<3:cameras[panel].position+=actor.position-before
				maximum=maxi(maximum,actor.last_simulation_usec);lock=maxf(lock,actor.contacts.maximum_lock_error)
		for panel in 4:
			var actor:Node3D=active_organisms[panel];var phases:Dictionary={}
			for c:Dictionary in actor.contacts.chains:
				if c.active:phases[c.motion_phase]=true
			captions[panel].text=titles[panel]+" · %.1f s · %.2f m"%[float(frame)/15,distances[panel]]
			if panel in [1,2]:captions[panel].text+="\n"+", ".join(phases.keys())
		if frame in [0,44,89,134,179]:
			for panel in 4:
				var meshes:Array=[models[panel].body]
				for item:Dictionary in models[panel].appendages:meshes.append(item.mesh)
				for mesh:Dictionary in meshes:
					var pose:=Oracle.mesh_pose(mesh,active_organisms[panel]);var report:=Integrity.strain(mesh,pose.vertices,pose.reference_faces)
					inverted+=Oracle.confirmed_inversions(mesh,pose,active_organisms[panel],report.suspect_faces);maximum_stretch=maxf(maximum_stretch,report.maximum_edge_stretch)
		await process_frame;await RenderingServer.frame_post_draw
		var image:=sheet.get_texture().get_image();image.save_png("res://.godot/blob_v4_motion_frames/%04d.png"%frame)
		if frame in [0,44,89,134,179]:image.save_png("res://data/blobs_v4/motion_%03d.png"%frame)
		if frame%30==0:print("V4_CAPTURE ",frame," /180")
	var report:Dictionary={"simulated_seconds":12,"capture_fps":15,"solver_hz":60,"world_distances":distances,"inverted_triangles_in_sampled_capture_poses":inverted,"maximum_edge_stretch":maximum_stretch,"maximum_stance_error":lock,"max_simulation_step_us":maximum,"capture_ms_per_frame":float(Time.get_ticks_usec()-started)/180000}
	var f:=FileAccess.open("res://data/blobs_v4/capture_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("V4_CAPTURE_COMPLETE ",report);quit(0 if inverted==0 else 1)
