extends RefCounted
## New scoped marker; reuse the fixed curve evaluator, never mantle anatomy.
const Primitive = preload("res://alien_foundry/scripts/geometry/BlobMantleButtressField.gd")
const Placement = preload("res://alien_foundry/scripts/anatomy/BlobMantlePlacement.gd")
const KEY := "grown_contact_version"
const SUBDIVISIONS := 5

static func marked(node: Dictionary) -> bool:
	return node.get("shape",{}).has(KEY)

static func create(node: Dictionary) -> RefCounted:
	return Primitive.create(node)

static func minimum(node: Dictionary) -> Dictionary:
	return Placement.support_minimum(node)

static func valid_host(dna: Dictionary,node: Dictionary) -> bool:
	if node.has("porous_patch"):return false
	if str(dna.get("type",""))!="Blob" or str(node.get("kind",""))!="curve":return false
	if str(node.get("role",""))!="limb" or str(node.get("operation","union"))!="union":return false
	if not _number(node.get("pipeline_stage")) or float(node.pipeline_stage)!=1.0:return false
	if not _number(node.get("noise")) or float(node.noise)!=0.0:return false
	var points: Variant=node.get("points");var radii: Variant=node.get("radii")
	if not points is Array or points.size()!=4 or not radii is Array or radii.size()!=4:return false
	for point in points:
		if not point is Array or point.size()!=3:return false
		for value in point:
			if not _number(value):return false
	for radius in radii:
		if not _number(radius) or float(radius)<0.006:return false
	var shape: Dictionary=node.get("shape",{})
	if shape.size()!=6:return false
	for key in shape:
		if key not in [KEY,"width","depth","swelling","twist","taper"] or not _number(shape[key]):return false
	if float(shape.get(KEY,0))!=1.0:return false
	if float(shape.width)<0.8 or float(shape.width)>1.8 or float(shape.depth)<0.6 or float(shape.depth)>1.2:return false
	return float(shape.swelling)==0.0 and float(shape.twist)==0.0 and float(shape.taper)==0.0

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
