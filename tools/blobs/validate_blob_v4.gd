extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
const INPUT="res://.godot/blob_validation_v4_release"
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run()->void:
	var deadline:=Time.get_ticks_msec()+180000
	while not FileAccess.file_exists(INPUT.path_join("model_23.bin")) and Time.get_ticks_msec()<deadline:await create_timer(.3).timeout
	var rows:Array=[]
	for index in 24:
		var path:String=INPUT.path_join("model_%02d.bin"%index)
		if not FileAccess.file_exists(path):check(false,"Missing model "+str(index));continue
		var file:=FileAccess.open(path,FileAccess.READ);var data:Dictionary=file.get_var(false);file.close()
		check(data.mesh_integrity.boundary_edges==0,"Closed body "+str(index))
		var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false;actor.travel_enabled=true;actor.speed=.8
		var start:=actor.position;var path_length:=.0;var maximum:=.0;var minimum_area:=INF;var inverted:=0;var collapsed:=0;var lock:=.0;var time_sum:=0;var max_time:=0
		for frame in 180:
			actor.speed=.8 if frame<80 else (0.0 if frame<105 else -.6)
			if frame>35 and frame<75:actor.direction=Vector3.FORWARD.rotated(Vector3.UP,float(frame-35)/40*1.4)
			var before:=actor.position
			actor.simulate(1.0/60)
			path_length+=actor.position.distance_to(before)
			time_sum+=actor.last_simulation_usec;max_time=maxi(max_time,actor.last_simulation_usec);lock=maxf(lock,actor.contacts.maximum_lock_error)
			if frame%45!=0:continue
			if actor.solver.roll_safe:actor.solver.circulation=TAU*float(frame)/180
			var meshes:Array=[data.body]
			for item:Dictionary in data.appendages:meshes.append(item.mesh)
			for mesh:Dictionary in meshes:
				var pose:=Oracle.mesh_pose(mesh,actor);var report:=Integrity.strain(mesh,pose.vertices,pose.reference_faces)
				var actual:=Oracle.confirmed_inversions(mesh,pose,actor,report.suspect_faces)
				maximum=maxf(maximum,report.maximum_edge_stretch);minimum_area=minf(minimum_area,report.minimum_area_ratio);inverted+=actual;collapsed+=report.collapsed
				check(actual==0,"No inverted triangles seed %d frame %d feature %s"%[data.dna.seed,frame,mesh.feature_ids[0]])
				check(report.maximum_edge_stretch<3.0,"No excessive stretch seed %d frame %d feature %s value %.3f"%[data.dna.seed,frame,mesh.feature_ids[0],report.maximum_edge_stretch])
				check(report.minimum_area_ratio>.1,"No collapsed tissue seed %d frame %d feature %s area %.4f"%[data.dna.seed,frame,mesh.feature_ids[0],report.minimum_area_ratio])
				for p:Vector3 in pose.vertices:
					if not p.is_finite():check(false,"Non-finite posed vertex");break
		var cycles:=0
		for chain:Dictionary in actor.contacts.chains:cycles+=chain.cycles
		var row:Dictionary={"seed":data.dna.seed,"mode":actor.locomotion,"maximum_edge_stretch":maximum,"minimum_triangle_area_ratio":minimum_area,"inverted_triangles":inverted,"collapsed_triangles":collapsed,"maximum_stance_error":lock,"path_length":path_length,"travel":str(actor.position-start),"contact_cycles":cycles,"guard_corrections":actor.contacts.corrected_poses,"guard_fallbacks":actor.contacts.rejected_poses,"collision_corrections":actor.contacts.collision_corrections,"mean_step_us":float(time_sum)/180,"max_step_us":max_time}
		rows.append(row);print("V4_MOTION ",index+1,"/24 ",row);actor.free()
	var file:=FileAccess.open("res://data/blobs_v4/motion_mesh_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":rows},"\t"));file.close()
	print("V4_VALIDATION_COMPLETE checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
