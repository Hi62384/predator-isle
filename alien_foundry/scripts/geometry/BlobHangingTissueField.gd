extends RefCounted
## A distinct multi-compartment host marker. The radial mathematics and its
## versioned descriptor are reused unchanged; grown-envelope hosts stay strict.
const Radial = preload("res://alien_foundry/scripts/geometry/BlobGrownEnvelopeField.gd")
const KEY := "hanging_tissue"

static func marked(node: Dictionary) -> bool:
	return node.get("shape", {}).has(KEY)

static func create(descriptor: Dictionary, size: Vector3) -> RefCounted:
	return Radial.create(descriptor, size)

static func valid_host(dna: Dictionary, node: Dictionary) -> bool:
	if str(dna.get("type", "")) != "Blob" or str(node.get("kind", "")) != "mass": return false
	if str(node.get("role", "")) not in ["core", "lobe"] or str(node.get("operation", "union")) != "union": return false
	if not Radial._number(node.get("pipeline_stage")) or float(node.pipeline_stage) != 1.0: return false
	if not Radial._number(node.get("noise")) or float(node.noise) != 0.0: return false
	if node.has("porous_patch") or not node.get("points", []) is Array or not node.get("points", []).is_empty(): return false
	var size: Variant = node.get("size")
	if not size is Array or size.size() != 3: return false
	for value in size:
		if not Radial._number(value) or float(value) < 0.006: return false
	var shape: Dictionary = node.get("shape", {})
	return shape.size() == 1 and Radial.valid_descriptor(shape.get(KEY))
