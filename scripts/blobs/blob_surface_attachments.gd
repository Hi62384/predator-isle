extends RefCounted
## Attach to the extracted surface after all implicit passes. A local triangle
## grid makes this independent of obsolete blockout primitives.
var mesh: Dictionary
var cell:=.5
var buckets: Dictionary={}
func configure(body: Dictionary, size: float) -> void:
	mesh=body
	cell=maxf(.2,size*.35)
	for triangle in range(0,body.indices.size(),3):
		var a: Vector3=body.vertices[body.indices[triangle]]
		var b: Vector3=body.vertices[body.indices[triangle+1]]
		var c: Vector3=body.vertices[body.indices[triangle+2]]
		var low:=Vector3i((a.min(b).min(c)/cell).floor())
		var high:=Vector3i((a.max(b).max(c)/cell).floor())
		for z in range(low.z,high.z+1):
			for y in range(low.y,high.y+1):
				for x in range(low.x,high.x+1):
					var key:=Vector3i(x,y,z)
					if not buckets.has(key): buckets[key]=PackedInt32Array()
					buckets[key].append(triangle)

func nearest(point: Vector3) -> Dictionary:
	var key:=Vector3i((point/cell).floor())
	var candidates: Dictionary={}
	for radius in [1,2,3,5]:
		for z in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				for x in range(-radius,radius+1):
					for triangle: int in buckets.get(key+Vector3i(x,y,z),PackedInt32Array()): candidates[triangle]=true
		if candidates.size()>8: break
	var best:=INF
	var result: Dictionary={}
	for triangle: int in candidates:
		var ia: int=mesh.indices[triangle]
		var ib: int=mesh.indices[triangle+1]
		var ic: int=mesh.indices[triangle+2]
		var a: Vector3=mesh.vertices[ia]
		var b: Vector3=mesh.vertices[ib]
		var c: Vector3=mesh.vertices[ic]
		var p:=_closest_triangle(point,a,b,c)
		var distance:=point.distance_squared_to(p)
		if distance>=best: continue
		best=distance
		var weights:=barycentric(p,a,b,c)
		var color: Color=mesh.colors[ia]*weights.x+mesh.colors[ib]*weights.y+mesh.colors[ic]*weights.z
		var normal: Vector3=(mesh.normals[ia]*weights.x+mesh.normals[ib]*weights.y+mesh.normals[ic]*weights.z).normalized()
		var owner: int=mesh.feature_ids[ia]
		result={"point":p,"normal":normal,"distance":sqrt(distance),"color":color,"tissue":int(mesh.uvs[ia].x),"owner":owner,"triangle":triangle,"weights":weights}
	return result

static func barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0:=b-a
	var v1:=c-a
	var v2:=p-a
	var denominator:=v0.dot(v0)*v1.dot(v1)-v0.dot(v1)*v0.dot(v1)
	if absf(denominator)<.0000000001: return Vector3(1,0,0)
	var y: float=(v1.dot(v1)*v2.dot(v0)-v0.dot(v1)*v2.dot(v1))/denominator
	var z: float=(v0.dot(v0)*v2.dot(v1)-v0.dot(v1)*v2.dot(v0))/denominator
	return Vector3(1.0-y-z,y,z)

func finalize(features: Array[Dictionary], size: float) -> Dictionary:
	var corrected:=0
	var failures: Array[String]=[]
	for f in features:
		if not f.has("points") or f.get("sheet",false) or f.get("fused_path",false): continue
		var parent: Dictionary=features[maxi(int(f.parent),0)]
		if parent.has("points") and f.feature_type in ["gripping_digit","sensory_bulb"]:
			var delta: Vector3=parent.points[-1]-f.points[0]
			for i in f.points.size(): f.points[i]+=delta
			f.center=f.points[0]
			f["terminal_parent"]=parent.id
			continue
		if parent.has("points") and f.feature_type in ["vine_branch","attachment_fiber"]:
			# Branches bind to a real point on their parent's smoothed curve.
			var curve: Dictionary=preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd").sample({"points":_arrays(parent.points),"radii":parent.radii_profile},7)
			var nearest_point: Vector3=curve.points[0]
			var best:=INF
			var along:=.0
			for i in curve.points.size():
				var distance: float=curve.points[i].distance_squared_to(f.points[0])
				if distance<best: best=distance; nearest_point=curve.points[i]; along=float(i)/float(curve.points.size()-1)
			var delta: Vector3=nearest_point-f.points[0]
			for i in f.points.size(): f.points[i]+=delta*(1.0-float(i)/float(f.points.size()))
			f.center=f.points[0]
			f["parent_along"]=along
			continue
		if f.feature_type in ["vascular_trunk","vascular_branch","capillary","anatomical_fold","eyelid","face_transition"]: continue
		var seat:=nearest(f.points[0])
		if seat.is_empty(): failures.append("No supporting surface for feature %d" % f.id); continue
		var root: Vector3=seat.point-seat.normal*float(f.radii.x)*.65
		var delta: Vector3=root-f.points[0]
		if delta.length()>size*1.3: failures.append("Feature %d is outside its parent surface" % f.id); continue
		for i in f.points.size():
			var t:=float(i)/float(maxi(f.points.size()-1,1))
			f.points[i]+=delta*(1.0-t)*(1.0-t)
		f.center=f.points[0]
		f["surface_attachment"]={"point":seat.point,"normal":seat.normal,"triangle":seat.triangle,"burial":float(f.radii.x)*.65}
		f["root_color"]=seat.color
		f["root_tissue"]=seat.tissue
		corrected+=1
	return {"corrected_roots":corrected,"failures":failures}

static func _arrays(points: Array) -> Array:
	var result: Array=[]
	for p: Vector3 in points: result.append([p.x,p.y,p.z])
	return result

static func _closest_triangle(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
	var ab:=b-a; var ac:=c-a; var ap:=p-a
	var d1:=ab.dot(ap); var d2:=ac.dot(ap)
	if d1<=0 and d2<=0: return a
	var bp:=p-b; var d3:=ab.dot(bp); var d4:=ac.dot(bp)
	if d3>=0 and d4<=d3: return b
	var vc:=d1*d4-d3*d2
	if vc<=0 and d1>=0 and d3<=0: return a+ab*(d1/(d1-d3))
	var cp:=p-c; var d5:=ab.dot(cp); var d6:=ac.dot(cp)
	if d6>=0 and d5<=d6: return c
	var vb:=d5*d2-d1*d6
	if vb<=0 and d2>=0 and d6<=0: return a+ac*(d2/(d2-d6))
	var va:=d3*d6-d5*d4
	if va<=0 and d4-d3>=0 and d5-d6>=0: return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
	var denom:=1.0/(va+vb+vc)
	return a+ab*vb*denom+ac*vc*denom
