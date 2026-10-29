extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
class Ground extends Node3D:
	func get_height_at(p:Vector3)->float:return .08*sin(p.x*.7)+.06*sin(p.z*.9)+.09*p.z
func _initialize()->void:call_deferred("run")
func run()->void:
	var ground:=Ground.new();root.add_child(ground)
	var failures:Array=[];var rows:Array=[]
	for index in [0,1,2,3,20]:
		var file:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%index,FileAccess.READ);var data:Dictionary=file.get_var(false);file.close()
		var actor:=Organism.new();root.add_child(actor)
		actor.global_position=Vector3(120,0,240);actor.global_position.y=ground.get_height_at(actor.global_position);actor.ground_height=actor.global_position.y;actor.terrain=ground
		actor.configure(data);actor.simulation_enabled=false;actor.travel_enabled=true
		var frames:=1440 if actor.solver.roll_safe else 480
		var clearance:=INF;var lock:=.0;var inverted:=0;var maximum:=.0;var path:=.0;var original:=actor.position
		for frame in frames:
			var time:=float(frame)/60
			actor.speed=1.0 if fmod(time,12)<5 else (0 if fmod(time,12)<6 else (-.8 if fmod(time,12)<11 else 0))
			if time>2 and time<5:actor.direction=Vector3.FORWARD.rotated(Vector3.UP,(time-2)*.35)
			var before:=actor.position;actor.simulate(1.0/60);path+=actor.position.distance_to(before);lock=maxf(lock,actor.contacts.maximum_lock_error)
			if frame%120!=0:continue
			var meshes:Array=[data.body]
			for item:Dictionary in data.appendages:meshes.append(item.mesh)
			for mesh:Dictionary in meshes:
				var pose:=Oracle.mesh_pose(mesh,actor);var report:=Integrity.strain(mesh,pose.vertices,pose.reference_faces)
				inverted+=Oracle.confirmed_inversions(mesh,pose,actor,report.suspect_faces);maximum=maxf(maximum,report.maximum_edge_stretch)
				if mesh==data.body:
					for p:Vector3 in pose.vertices:
						var world:Vector3=p+actor.global_position+Vector3.UP*actor.solver.height
						clearance=minf(clearance,world.y-ground.get_height_at(world))
		var row:Dictionary={"seed":data.dna.seed,"mode":actor.locomotion,"seconds":float(frames)/60,"path_length":path,"inverted_triangles":inverted,"maximum_edge_stretch":maximum,"minimum_dense_body_clearance":clearance,"maximum_stance_error":lock,"signed_circulation":actor.solver.circulation,"net_travel":str(actor.position-original)}
		rows.append(row);print("LONG_TERRAIN ",row)
		if inverted>0 or maximum>3 or clearance<-.06 or lock>.02:failures.append(row)
		actor.free()
	var file:=FileAccess.open("res://data/blobs_v4/long_terrain_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"failures":failures,"runs":rows},"\t"));file.close()
	print("LONG_TERRAIN_COMPLETE failures=",failures.size());quit(0 if failures.is_empty() else 1)
