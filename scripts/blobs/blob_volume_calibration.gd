extends RefCounted
## Measure the generated closed shell across a complete circulation cycle.
## This includes material islands, unlike an ellipsoid-volume estimate.
const Solver=preload("res://scripts/blobs/blob_surface_circulation.gd")
const SAMPLES=32
static func calibrate(data:Dictionary,job:RefCounted=null) -> PackedFloat32Array:
	var solver:=Solver.new()
	var calibration_dna:Dictionary=data.dna.duplicate(true)
	calibration_dna.erase("volume_curve"); calibration_dna.erase("strain_volume_curve")
	solver.configure(calibration_dna,data.rig,data.body)
	var mesh:Dictionary=data.body
	var rest:=_volume(mesh.vertices,mesh.indices)
	var curve:=PackedFloat32Array()
	for sample in SAMPLES:
		if job!=null and job.is_cancelled(): return PackedFloat32Array()
		solver.circulation=TAU*float(sample)/float(SAMPLES)
		solver._update_groups(.0)
		var vertices:=PackedVector3Array(); vertices.resize(mesh.vertices.size())
		for i in vertices.size(): vertices[i]=solver.map_bound(mesh.vertices[i],int(mesh.binds[i*4])-1,float(mesh.binds[i*4+1]))
		var deformed:=_volume(vertices,mesh.indices)
		curve.append(pow(rest/maxf(deformed,rest*.12),1.0/3.0))
	data.dna["strain_volume_curve"]=calibrate_strain(data,job)
	return curve

static func calibrate_strain(data:Dictionary,job:RefCounted=null) -> PackedFloat32Array:
	var solver:=Solver.new()
	var dna:Dictionary=data.dna.duplicate(true)
	dna.erase("volume_curve"); dna.erase("strain_volume_curve")
	solver.configure(dna,data.rig,data.body)
	var mesh:Dictionary=data.body
	var base:=.0
	var curve:=PackedFloat32Array()
	for corner in 8:
		if job!=null and job.is_cancelled(): return PackedFloat32Array()
		solver.strain=Vector3(.22 if corner&1 else 0,.22 if corner&2 else 0,.22 if corner&4 else 0)
		solver._update_groups(.0)
		var vertices:=PackedVector3Array(); vertices.resize(mesh.vertices.size())
		for i in vertices.size(): vertices[i]=solver.map_bound(mesh.vertices[i],int(mesh.binds[i*4])-1,float(mesh.binds[i*4+1]))
		var measured:=_volume(vertices,mesh.indices)
		if corner==0: base=measured
		curve.append(pow(base/maxf(measured,base*.12),1.0/3.0))
	return curve

static func _volume(vertices:PackedVector3Array,indices:PackedInt32Array) -> float:
	var value:=.0
	for i in range(0,indices.size(),3): value+=vertices[indices[i]].dot(vertices[indices[i+1]].cross(vertices[indices[i+2]]))/6.0
	return absf(value)
