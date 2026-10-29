extends SceneTree
const Solver=preload("res://scripts/blobs/blob_surface_circulation.gd")
func _initialize() -> void: call_deferred("run")
func volume(mesh:Dictionary,solver:RefCounted=null) -> float:
	var vertices:PackedVector3Array=mesh.vertices.duplicate()
	if solver!=null:
		for i in vertices.size(): vertices[i]=solver.map_bound(vertices[i],int(mesh.binds[i*4])-1,float(mesh.binds[i*4+1]))
	var result:=.0
	for i in range(0,mesh.indices.size(),3): result+=vertices[mesh.indices[i]].dot(vertices[mesh.indices[i+1]].cross(vertices[mesh.indices[i+2]]))/6.0
	return absf(result)
func run() -> void:
	var rows:Array=[]
	var maximum_error:=.0
	for index in 24:
		var file:=FileAccess.open("res://.godot/blob_validation_v3/model_%02d.bin"%index,FileAccess.READ); var data:Dictionary=file.get_var(false); file.close()
		var solver:=Solver.new(); solver.configure(data.dna,data.rig,data.body)
		if data.dna.get("volume_curve",PackedFloat32Array()).is_empty(): push_error("Missing volume calibration"); quit(1); return
		var rest:=volume(data.body)
		var ratios:Array=[]
		for frame in 6:
			solver.circulation=TAU*float(frame)/6.0; solver._update_groups(.0); solver._update_volume()
			var ratio:=volume(data.body,solver)/rest
			ratios.append(ratio); maximum_error=maxf(maximum_error,absf(ratio-1.0))
		rows.append({"seed":data.dna.seed,"volume_ratios":ratios}); print(rows[-1])
	var file:=FileAccess.open("res://data/blobs_v3/volume_validation.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows,"\t")); file.close()
	print("MAX_VOLUME_ERROR ",maximum_error)
	quit(0 if maximum_error<.04 else 1)
