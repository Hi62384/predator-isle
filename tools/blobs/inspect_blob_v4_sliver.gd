extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_09.bin",FileAccess.READ);var data:Dictionary=f.get_var(false);f.close()
	var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false;actor.travel_enabled=true
	for frame in 136:
		actor.speed=.8 if frame<80 else (0.0 if frame<105 else -.6)
		if frame>35 and frame<75:actor.direction=Vector3.FORWARD.rotated(Vector3.UP,float(frame-35)/40*1.4)
		actor.simulate(1.0/60)
	var mesh:Dictionary=data.body;var pose:=Oracle.mesh_pose(mesh,actor);var report:=Integrity.strain(mesh,pose.vertices,pose.reference_faces)
	for face:int in report.suspect_faces:
		if Oracle.confirmed_inversions(mesh,pose,actor,PackedInt32Array([face]))==0:continue
		var a:Vector3=mesh.vertices[mesh.indices[face*3]];var b:Vector3=mesh.vertices[mesh.indices[face*3+1]];var c:Vector3=mesh.vertices[mesh.indices[face*3+2]]
		var lengths:=Vector3(a.distance_to(b),b.distance_to(c),c.distance_to(a));var area:float=(b-a).cross(c-a).length()
		print("BAD_FACE ",face," lengths ",lengths," area ",area," quality ",area/(lengths[lengths.max_axis_index()]*lengths[lengths.max_axis_index()])," points ",a,b,c)
	actor.free();quit()
