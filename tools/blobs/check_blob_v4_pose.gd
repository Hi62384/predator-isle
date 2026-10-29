extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	for index in 3:
		var file:=FileAccess.open("res://.godot/blob_validation_v4/model_%02d.bin"%index,FileAccess.READ);var data:Dictionary=file.get_var(false);file.close()
		var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false;actor.travel_enabled=true;actor.speed=.65
		if index>0:actor.set_locomotion("vine")
		for frame in 180:
			if frame==90:actor.speed=-.5
			if frame>50 and frame<90:actor.direction=Vector3.FORWARD.rotated(Vector3.UP,float(frame-50)/40*1.2)
			actor.simulate(1.0/60)
			if frame%45!=0:continue
			if index==0:actor.solver.circulation=TAU*float(frame)/180
			var pose:=Oracle.mesh_pose(data.body,actor);var report:=Integrity.strain(data.body,pose.vertices,pose.reference_faces)
			report.inverted=Oracle.confirmed_inversions(data.body,pose,actor,report.suspect_faces);report.erase("suspect_faces")
			print("BODY ",index," frame ",frame," ",report)
			for item:Dictionary in data.appendages:
				pose=Oracle.mesh_pose(item.mesh,actor);report=Integrity.strain(item.mesh,pose.vertices,pose.reference_faces)
				report.inverted=Oracle.confirmed_inversions(item.mesh,pose,actor,report.suspect_faces);report.erase("suspect_faces")
				if report.maximum_edge_stretch>2.5 or report.minimum_area_ratio<.1 or report.inverted>0:print("APPENDAGE ",index," frame ",frame," ",item.feature.feature_type," id=",item.feature.id," ",report)
		actor.free()
	quit()
