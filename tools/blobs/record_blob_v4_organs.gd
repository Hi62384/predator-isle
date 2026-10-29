extends "res://tools/blobs/render_blob_v4_sheets.gd"
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
func _run()->void:
	DirAccess.make_dir_recursive_absolute("res://.godot/blob_v4_organ_frames")
	var sheet:=SubViewport.new();sheet.size=Vector2i(1440,720);sheet.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(sheet)
	var meshes:Array[Dictionary]=[];var cameras:Array[Camera3D]=[];var centers:Array[Vector3]=[]
	for panel in 2:
		var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%[3,4][panel],FileAccess.READ);var data:Dictionary=f.get_var(false);f.close()
		var container:=SubViewportContainer.new();container.position=Vector2(panel*720,0);container.size=Vector2(720,670);sheet.add_child(container)
		var viewport:=SubViewport.new();viewport.size=Vector2i(720,670);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport);_tile(viewport,data,panel==0)
		var actor:Node3D=active_organisms[-1];actor.speed=0
		var selected:Dictionary={}
		for item:Dictionary in data.appendages:
			if item.feature.feature_type==("supported_membrane" if panel==0 else "sensory_bulb"):selected=item;break
		if selected.is_empty():push_error("Missing inspection feature");quit(1);return
		meshes.append(selected.mesh)
		var pose:=Oracle.mesh_pose(selected.mesh,actor);var bounds:=AABB(pose.vertices[0],Vector3.ZERO)
		for p:Vector3 in pose.vertices:bounds=bounds.expand(p)
		bounds.position+=Vector3.UP*actor.solver.height;var center:=bounds.get_center();centers.append(center)
		var camera:=viewport.get_camera_3d();var view:=Vector3(.5,.7,1).normalized()
		if panel==0:
			var feature:Dictionary=selected.feature
			var a:Dictionary=actor.contacts.chains[data.rig.chain_ids[feature.support_ids[0]]];var b:Dictionary=actor.contacts.chains[data.rig.chain_ids[feature.support_ids[1]]]
			view=(Frames.point(b.points,.35)-Frames.point(a.points,.35)).cross(Frames.tangent(a.points,.35)+Frames.tangent(b.points,.35)).normalized()
			if view.dot(center-Vector3.UP*actor.solver.height)<0:view=-view
			view=(view+Vector3.UP*.2).normalized()
		else:
			var parent_id:int=selected.feature.parent
			var chain:Dictionary=actor.contacts.chains[data.rig.chain_ids[parent_id]]
			view=(Frames.tangent(chain.points,1.0)+Vector3(.18,.12,.08)).normalized()
		camera.position=center+view*5;camera.look_at(center);camera.size=maxf(bounds.size[bounds.size.max_axis_index()]*1.65,.6);cameras.append(camera)
		var title:=Label.new();title.position=Vector2(panel*720+16,675);title.text="WEB / thick closed shell, coupled supports" if panel==0 else "SENSORY ORGAN / hollow ribs and attached neck";title.add_theme_font_size_override("font_size",18);sheet.add_child(title)
	for i in 8:await process_frame
	var inverted:=0;var stretch:=.0;var minimum:=INF
	for frame in 90:
		for step in 4:
			for actor:Node3D in active_organisms:
				actor.direction=Vector3.FORWARD.rotated(Vector3.UP,float(frame)/15*.10);actor.simulate(1.0/60)
		for panel in 2:
			var actor:Node3D=active_organisms[panel];var pose:=Oracle.mesh_pose(meshes[panel],actor)
			var bounds:=AABB(pose.vertices[0],Vector3.ZERO)
			for p:Vector3 in pose.vertices:bounds=bounds.expand(p)
			var center:Vector3=bounds.get_center()+actor.global_position+Vector3.UP*actor.solver.height
			cameras[panel].position+=center-centers[panel];centers[panel]=center
			var report:=Integrity.strain(meshes[panel],pose.vertices,pose.reference_faces);stretch=maxf(stretch,report.maximum_edge_stretch);minimum=minf(minimum,report.minimum_area_ratio)
			inverted+=Oracle.confirmed_inversions(meshes[panel],pose,actor,report.suspect_faces)
		await process_frame;await RenderingServer.frame_post_draw
		var image:=sheet.get_texture().get_image();image.save_png("res://.godot/blob_v4_organ_frames/%04d.png"%frame)
		if frame in [0,44,89]:image.save_png("res://data/blobs_v4/organs_%03d.png"%frame)
	var f:=FileAccess.open("res://data/blobs_v4/organ_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify({"seconds":6,"frames":90,"inverted_triangles":inverted,"maximum_edge_stretch":stretch,"minimum_area_ratio":minimum},"\t"));f.close()
	print("V4_ORGANS_COMPLETE inverted=",inverted," stretch=",stretch," min_area=",minimum);quit(0 if inverted==0 and minimum>.1 else 1)
