class_name AnatomicalSurfaceContext
extends RefCounted
## Additive, regenerated shading metadata, never a replacement for ownership.
## RGBA = attachment proximity, growth region, fibre exposure, local thickness.
const SkeletonBuilder = preload("res://alien_foundry/scripts/rigging/SkeletonGenerator.gd")

static func cache(dna: Dictionary, ids: PackedStringArray) -> Array:
	var by_id: Dictionary = {}
	for node: Dictionary in dna.get("nodes", []): by_id[str(node.get("id", ""))] = node
	var result: Array = []
	var scale_value: float = maxf(float(dna.get("settings", {}).get("size", 1.0)), 0.01)
	for id: String in ids:
		var node: Dictionary = by_id.get(id, {})
		var parent: Dictionary = by_id.get(str(node.get("parent", "")), {})
		var points := PackedVector3Array()
		for point: Variant in node.get("points", []): points.append(SkeletonBuilder.vec(point))
		var radii := PackedFloat32Array()
		for radius: Variant in node.get("radii", []): radii.append(maxf(float(radius), scale_value*0.001))
		var size_value: Vector3 = SkeletonBuilder.vec(node.get("size", []), Vector3.ONE*0.1).abs().max(Vector3.ONE*scale_value*0.001)
		var center: Vector3 = SkeletonBuilder.vec(node.get("position", []))
		var attachment: Vector3 = points[0] if not points.is_empty() else center
		var maximum_radius: float = maxf(float(node.get("radius", 0.1)), scale_value*0.001)
		if points.is_empty(): maximum_radius=maxf(size_value.x,maxf(size_value.y,size_value.z))
		var lengths := PackedFloat32Array([0.0])
		var total: float = 0.0
		for i: int in range(points.size()-1):
			total += points[i].distance_to(points[i+1]); lengths.append(total)
		for radius: float in radii: maximum_radius=maxf(maximum_radius,radius)
		var basis: Basis = Basis.from_euler(SkeletonBuilder.vec(node.get("rotation", [])))
		if points.is_empty() and not parent.is_empty():
			var target: Vector3 = _parent_point(parent, center)
			var toward: Vector3 = (target-center).normalized()
			var local: Vector3 = basis.transposed()*toward
			var support: float = 1.0/maxf(Vector3(local.x/size_value.x,local.y/size_value.y,local.z/size_value.z).length(),0.0001)
			attachment = center+toward*minf(support*0.68,center.distance_to(target)*0.5)
		if node.has("growth_origin"):
			attachment = SkeletonBuilder.vec(node.growth_origin, attachment)
		var role: String = str(node.get("role", ""))
		var growth: float = 1.0 if "growth" in role or role in ["lobe","swelling","cluster","organic_mass","visceral_lobe"] or node.has("growth_origin") else 0.0
		var material: String = str(node.get("material", "flesh"))
		var exposure: float = 0.82 if material == "root" else (0.76 if material == "muscle" else 0.0)
		if role in ["tendon","muscle_belly"] and material == "flesh": exposure=0.14
		var supplied: Dictionary = node.get("surface", {})
		exposure=clampf(float(supplied.get("exposure",exposure)),0.0,1.0)
		growth=clampf(float(supplied.get("growth",growth)),0.0,1.0)
		var shape: Dictionary = node.get("shape", {})
		var width: float = maxf(float(shape.get("width",1.0)),0.01)
		var depth: float = maxf(float(shape.get("depth",1.0)),0.01)
		result.append({"points":points,"radii":radii,"lengths":lengths,"length":total,"center":center,"size":size_value,"basis_inverse":basis.transposed(),"attachment":attachment,"has_attachment":not parent.is_empty(),"attachment_width":maxf(maximum_radius*.85,maxf(float(node.get("blend",0.1))*1.3,scale_value*.02)),"max_radius":maximum_radius,"growth":growth,"exposure":exposure,"section_ratio":minf(width,depth)/maxf(width,depth)})
	return result

static func _parent_point(parent: Dictionary, point: Vector3) -> Vector3:
	var path: Array = parent.get("points", [])
	var result: Vector3 = SkeletonBuilder.vec(parent.get("position", []))
	var closest: float = INF
	for i: int in range(path.size()-1):
		var a: Vector3 = SkeletonBuilder.vec(path[i])
		var axis: Vector3 = SkeletonBuilder.vec(path[i+1])-a
		var t: float = clampf((point-a).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)
		var candidate: Vector3 = a+axis*t
		var distance: float = point.distance_squared_to(candidate)
		if distance<closest: closest=distance; result=candidate
	return result

static func sample(point: Vector3, normal: Vector3, data: Dictionary) -> Vector4:
	var attachment: float = 0.0
	if data.has_attachment:
		attachment=exp(-point.distance_squared_to(data.attachment)/maxf(float(data.attachment_width)*float(data.attachment_width),0.000001))
	var along: float = 0.5
	var thickness: float = 1.0
	var path: PackedVector3Array = data.points
	if path.size()>1:
		var closest: float = INF
		for i: int in range(path.size()-1):
			var axis: Vector3 = path[i+1]-path[i]
			var t: float = clampf((point-path[i]).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)
			var distance: float = point.distance_squared_to(path[i]+axis*t)
			if distance<closest:
				closest=distance
				along=(float(data.lengths[i])+axis.length()*t)/maxf(float(data.length),0.000001)
				if data.radii.size()>i+1:
					thickness=lerpf(data.radii[i],data.radii[i+1],t)/maxf(float(data.max_radius),0.000001)
		thickness*=float(data.section_ratio)
	else:
		var local: Vector3 = data.basis_inverse*normal.normalized()
		var size_value: Vector3 = data.size
		var support: float = 1.0/maxf(Vector3(local.x/size_value.x,local.y/size_value.y,local.z/size_value.z).length(),0.0001)
		thickness=support/maxf(size_value.x,maxf(size_value.y,size_value.z))
	# Exposure rises on an elongated tissue's belly and recedes at its insertion.
	# This is anatomical, not a whole-node replacement of the material category.
	var belly: float = 4.0*along*(1.0-along)
	var exposure: float = float(data.exposure)*(0.30+0.70*belly)*(1.0-attachment*.85)
	var values := Vector4(attachment,float(data.growth)*(1.0-attachment*.40),exposure,thickness)
	for i: int in range(4):
		values[i]=clampf(values[i],0.0,1.0) if is_finite(values[i]) else (1.0 if i==3 else 0.0)
	return values
