extends SceneTree
const Organism=preload("res://scripts/blobs/blob_organism.gd")
const Oracle=preload("res://scripts/blobs/blob_deformation_oracle.gd")
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_01.bin",FileAccess.READ);var data:Dictionary=f.get_var(false);f.close()
	var actor:=Organism.new();root.add_child(actor);actor.configure(data);actor.simulation_enabled=false
	for c:Dictionary in actor.contacts.chains:
		c.frame_seed=Frames.normals(c.rest)[0]
		for j in 8:c.points[j]=c.rest[j]+Vector3.UP*actor.solver.height
	for item:Dictionary in data.appendages:
		var id:int=item.feature.id
		if id not in [4,11,15,21]:continue
		var pose:=Oracle.mesh_pose(item.mesh,actor);var err:=.0;var worst:=0
		for i in pose.vertices.size():
			var distance:float=pose.vertices[i].distance_to(item.mesh.vertices[i])
			if distance>err:err=distance;worst=i
		print("IDENTITY ",id," error=",err," vertex=",worst," vertices=",pose.vertices.size()," integrity=",item.feature.mesh_integrity)
		print("ANCHOR ",Vector3(item.mesh.anchors[worst*4],item.mesh.anchors[worst*4+1],item.mesh.anchors[worst*4+2])," binding=",item.mesh.chain_binds.slice(worst*4,worst*4+4))
	actor.free();quit()
