extends RefCounted
## Fixed candidate-only sampling. This is the same elliptical segment field
## used by OrganicVolume, including the taper projection and rounded caps.
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const KEY := "mantle_buttress_version"
const SUBDIVISIONS := 5
var segments: Array = []
var bounds := AABB()

static func marked(node: Dictionary) -> bool:
	return node.get("shape", {}).has(KEY)

static func create(node: Dictionary) -> RefCounted:
	var result = load("res://alien_foundry/scripts/geometry/BlobMantleButtressField.gd").new()
	var sampled: Dictionary = Curves.sample(node, SUBDIVISIONS, true)
	var points: PackedVector3Array = sampled.points; var radii: PackedFloat32Array = sampled.radii
	var shape: Dictionary = node.get("shape", {})
	var previous_across := Vector3.ZERO
	for i in range(points.size() - 1):
		var axis := points[i + 1] - points[i]
		if axis.length_squared() < 0.0000001: continue
		var axial := axis.normalized()
		var across := previous_across - axial*previous_across.dot(axial)
		if across.length_squared() < 0.01: across = axial.cross(Vector3.UP if absf(axial.y) < 0.9 else Vector3.FORWARD)
		across = across.normalized(); previous_across = across
		var depth_axis := axial.cross(across).normalized()
		var t0 := float(i)/float(points.size()-1); var t1 := float(i+1)/float(points.size()-1)
		var wa := float(shape.get("width", 1.0))*Curves.profile_value(shape.get("width_profile", []), t0)
		var wb := float(shape.get("width", 1.0))*Curves.profile_value(shape.get("width_profile", []), t1)
		var da := float(shape.get("depth", 1.0))*Curves.profile_value(shape.get("depth_profile", []), t0)
		var db := float(shape.get("depth", 1.0))*Curves.profile_value(shape.get("depth_profile", []), t1)
		var extent := (across.abs()*maxf(wa,wb)+depth_axis.abs()*maxf(da,db)+axial.abs())*maxf(radii[i],radii[i+1])
		var box := AABB(points[i].min(points[i+1])-extent, points[i].max(points[i+1])-points[i].min(points[i+1])+extent*2.0)
		result.bounds = box if result.segments.is_empty() else result.bounds.merge(box)
		result.segments.append({"position":points[i],"axis":axis,"inverse_length":1.0/axis.length_squared(),"axial":axial,"across":across,"depth_axis":depth_axis,"ra":float(radii[i]),"rb":float(radii[i+1]),"wa":wa,"wb":wb,"da":da,"db":db})
	return result

func distance(point: Vector3) -> float:
	var answer := INF
	for s: Dictionary in segments:
		var t := clampf((point-s.position).dot(s.axis)*float(s.inverse_length),0.0,1.0)
		var radial := point.distance_to(s.position+s.axis*t)
		t = clampf(t+(float(s.rb)-float(s.ra))*radial*float(s.inverse_length),0.0,1.0)
		var offset: Vector3 = point-s.position-s.axis*t
		var scale := Vector3(lerpf(s.wa,s.wb,t),lerpf(s.da,s.db,t),1.0)
		var q := Vector3(offset.dot(s.across),offset.dot(s.depth_axis),offset.dot(s.axial))/scale
		var k0 := q.length(); var k1 := (q/scale).length(); var radius := lerpf(s.ra,s.rb,t)
		var d := -radius*minf(1.0,minf(scale.x,scale.y)) if k1<0.000001 else k0*(k0-radius)/k1
		answer = minf(answer,d)
	return answer
