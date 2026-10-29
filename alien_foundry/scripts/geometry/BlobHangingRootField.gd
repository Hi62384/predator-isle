extends RefCounted
## Five-control hanging roots retain their routes and distal authored controls.
## A scoped marker shares the existing exact transported-ellipse evaluator.
const Primitive = preload("res://alien_foundry/scripts/geometry/BlobMantleButtressField.gd")
const Placement = preload("res://alien_foundry/scripts/anatomy/BlobMantlePlacement.gd")
const Radial = preload("res://alien_foundry/scripts/geometry/BlobGrownEnvelopeField.gd")
const KEY := "hanging_root_version"
const SUBDIVISIONS := 5

static func marked(node: Dictionary) -> bool:
	return node.get("shape", {}).has(KEY)

static func create(node: Dictionary) -> RefCounted:
	return Primitive.create(node)

static func minimum(node: Dictionary) -> Dictionary:
	return Placement.support_minimum(node)

static func valid_host(dna: Dictionary, node: Dictionary) -> bool:
	if node.has("porous_patch"): return false
	if str(dna.get("type", "")) != "Blob" or str(node.get("kind", "")) != "curve": return false
	if str(node.get("role", "")) != "limb" or str(node.get("operation", "union")) != "union": return false
	if not Radial._number(node.get("pipeline_stage")) or float(node.pipeline_stage) != 1.0: return false
	if not Radial._number(node.get("noise")) or float(node.noise) != 0.0: return false
	var points: Variant = node.get("points"); var radii: Variant = node.get("radii")
	if not points is Array or points.size() != 5 or not radii is Array or radii.size() != 5: return false
	for point in points:
		if not point is Array or point.size() != 3: return false
		for value in point:
			if not Radial._number(value): return false
	for radius in radii:
		if not Radial._number(radius) or float(radius) < 0.006: return false
	var shape: Dictionary = node.get("shape", {})
	if shape.size() != 8: return false
	for key in shape:
		if key not in [KEY, "width", "depth", "swelling", "twist", "taper", "width_profile", "depth_profile"]: return false
		if key.ends_with("_profile"):
			if not shape[key] is Array or shape[key].size() != 5: return false
			for value in shape[key]:
				if not Radial._number(value) or float(value) < 0.7 or float(value) > 1.6: return false
		else:
			if not Radial._number(shape[key]): return false
	if float(shape.get(KEY, 0)) != 1.0 or float(shape.width) != 1.0 or float(shape.depth) != 0.95: return false
	return float(shape.swelling) == 0.0 and float(shape.twist) == 0.0 and float(shape.taper) == 0.0
