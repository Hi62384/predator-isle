extends SceneTree
const Solver=preload("res://scripts/blobs/blob_surface_circulation.gd")
func _initialize()->void:call_deferred("run")
static func volume(vertices:PackedVector3Array,indices:PackedInt32Array)->float:
	var result:=.0
	for i in range(0,indices.size(),3):result+=vertices[indices[i]].dot(vertices[indices[i+1]].cross(vertices[indices[i+2]]))/6
	return absf(result)
func run()->void:
	var rows:Array=[];var maximum:=.0
	for index in 24:
		var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%index,FileAccess.READ);var data:Dictionary=f.get_var(false);f.close()
		var solver:=Solver.new();solver.configure(data.dna,data.rig,data.body);solver.idle_enabled=false
		var original:=volume(data.body.vertices,data.body.indices);var ratios:Array=[]
		for sample in 8:
			solver.circulation=TAU*float(sample)/8
			solver.strain=Vector3(.15,.08,.2) if sample%2 else Vector3.ZERO
			var points:=PackedVector3Array()
			for p:Vector3 in data.body.vertices:points.append(solver.map_point(p))
			var ratio:=volume(points,data.body.indices)/original;ratios.append(ratio);maximum=maxf(maximum,absf(ratio-1))
		rows.append({"seed":data.dna.seed,"full_circulation_allowed":solver.roll_safe,"volume_ratios":ratios})
	var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_00.bin",FileAccess.READ);var data:Dictionary=f.get_var(false);f.close()
	var solver:=Solver.new();solver.configure(data.dna,data.rig,data.body)
	var sac:Dictionary={};var count:=0
	for feature:Dictionary in data.features:
		if feature.feature_type!="inflated_sac":continue
		var owner_count:=0
		for id:int in data.body.feature_ids:
			if id==feature.id:owner_count+=1
		if owner_count>count:sac=feature;count=owner_count
	var point:Vector3=sac.center+sac.direction*sac.radii.z
	var minimum:=INF;var largest:=.0
	for frame in 480:
		solver.step(1.0/60,0,"roll")
		var radius:float=solver.map_point(point).distance_to(solver.map_point(sac.center));minimum=minf(minimum,radius);largest=maxf(largest,radius)
	var pulse_change:=largest/minimum-1
	var report:Dictionary={"maximum_volume_error":maximum,"models":rows,"idle_seconds":8,"sac_feature":sac.id,"sac_radial_change":pulse_change,"sac_exposed_vertices":count}
	f=FileAccess.open("res://data/blobs_v4/volume_idle_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("V4_VOLUME_IDLE max_error=",maximum," sac_change=",pulse_change);quit(0 if maximum<.04 and pulse_change>.015 else 1)
