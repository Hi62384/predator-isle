extends RefCounted
## Pure local 2/2 tetrahedron choice. This does not query a field, create roots,
## change stored normals, repair geometry, or emit a partial triangle pair.
## a,b,c,d are the same four edge-root IDs used by MeshExtractor._emit.

static func choose(vertices: PackedVector3Array, normals: PackedVector3Array, a: int, b: int, c: int, d: int, outward: Vector3) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "error": "", "choice": "", "indices": PackedInt32Array(),
		"legacy_valid": false, "alternate_valid": false,
		"legacy_score": 0.0, "alternate_score": 0.0,
		"legacy_native_valid": false, "alternate_native_valid": false,
		"legacy_classification_winding_valid": false, "alternate_classification_winding_valid": false,
		"legacy_boundary_invariant": false, "alternate_boundary_invariant": false,
		"boundary_comparison_available": false, "candidate_boundaries_agree": false,
		"classification_winding_valid": false, "boundary_invariant": false,
		"legacy": {}, "alternate": {}
	}
	if normals.size() != vertices.size():
		return _failure(result, "229 vertex/normal array lengths differ.")
	# Check the original int64 IDs before packing, so an oversized ID cannot wrap.
	var ids: Array[int] = [a, b, c, d]
	var seen: Dictionary = {}
	for id: int in ids:
		if id < 0 or id >= vertices.size():
			return _failure(result, "229 quad root index is outside the arrays.")
		if seen.has(id):
			return _failure(result, "229 quad requires four distinct root IDs.")
		seen[id] = true
		if not vertices[id].is_finite() or not normals[id].is_finite():
			return _failure(result, "229 referenced root or stored normal is nonfinite.")
	var outward_squared: float = outward.length_squared()
	if not outward.is_finite() or not is_finite(outward_squared) or outward_squared <= 0.0:
		return _failure(result, "229 classification outward must be finite and nonzero.")

	var legacy: Dictionary = _pair(vertices, normals, a, b, d, a, d, c, a, d, ids, outward)
	var alternate: Dictionary = _pair(vertices, normals, a, b, c, b, d, c, b, c, ids, outward)
	result.legacy = legacy
	result.alternate = alternate
	for label: String in ["legacy", "alternate"]:
		var candidate: Dictionary = result[label]
		result[label + "_valid"] = candidate.valid
		result[label + "_score"] = candidate.score
		result[label + "_native_valid"] = candidate.native_valid
		result[label + "_classification_winding_valid"] = candidate.classification_winding_valid
		result[label + "_boundary_invariant"] = candidate.boundary_invariant
	result.boundary_comparison_available = legacy.boundary_invariant and alternate.boundary_invariant
	result.candidate_boundaries_agree = result.boundary_comparison_available and legacy.boundary_direction == alternate.boundary_direction
	# The source pair must already have the unchanged directed boundary. Choosing
	# an otherwise valid alternate must never repair an inconsistent source chain.
	# A native-invalid legacy face may still lose if its source chain is intact.
	if not legacy.boundary_invariant:
		return _failure(result, "229 legacy source boundary chain is inconsistent; no boundary repair.")
	if result.boundary_comparison_available and not result.candidate_boundaries_agree:
		return _failure(result, "229 candidate pairs disagree on the oriented boundary chain.")
	if not legacy.valid and not alternate.valid:
		return _failure(result, "229 neither complete candidate pair is valid; no fallback or partial faces.")

	# No quantization, tolerance or tie-breaking by normals. Invalid pairs lose;
	# a true scalar64 score tie retains precisely the legacy diagonal and order.
	var choice: String = "legacy"
	if alternate.valid and (not legacy.valid or alternate.score > legacy.score):
		choice = "alternate"
	var selected: Dictionary = result[choice]
	result.ok = true
	result.choice = choice
	result.indices = selected.indices.duplicate()
	result.classification_winding_valid = selected.classification_winding_valid
	result.boundary_invariant = selected.boundary_invariant
	return result

static func _failure(result: Dictionary, message: String) -> Dictionary:
	result.error = message
	return result

static func _pair(vertices: PackedVector3Array, normals: PackedVector3Array, a0: int, b0: int, c0: int, a1: int, b1: int, c1: int, diagonal_a: int, diagonal_b: int, ids: Array[int], outward: Vector3) -> Dictionary:
	var first: Dictionary = _face(vertices, normals, a0, b0, c0, outward)
	var second: Dictionary = _face(vertices, normals, a1, b1, c1, outward)
	var indices: PackedInt32Array = first.indices.duplicate()
	indices.append_array(second.indices)
	var boundary: Dictionary = _boundary(indices, diagonal_a, diagonal_b, ids)
	var native_valid: bool = first.native_valid and second.native_valid
	var valid: bool = first.valid and second.valid and boundary.valid
	var score: float = minf(first.score, second.score) if first.valid and second.valid else 0.0
	var error: String = ""
	if not first.valid:
		error = first.error
	elif not second.valid:
		error = second.error
	elif not boundary.valid:
		error = "229 oriented pair does not form the unchanged quad boundary chain."
	return {
		"valid": valid, "error": error, "indices": indices, "score": score,
		"native_valid": native_valid,
		"classification_winding_valid": first.classification_winding_valid and second.classification_winding_valid,
		"boundary_invariant": boundary.valid, "boundary_direction": boundary.direction,
		"interior_edge_cancels": boundary.interior_edge_cancels,
		"faces": [first, second]
	}

static func _face(vertices: PackedVector3Array, normals: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> Dictionary:
	var canonical_cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	# This is exactly MeshExtractor._emit's classification-only orientation rule.
	# It deliberately does not use any stored normal or scalar64 score.
	var swap: bool = canonical_cross.dot(outward) > 0.0
	var emitted: PackedInt32Array = PackedInt32Array([a, c, b] if swap else [a, b, c])
	var i: int = emitted[0]
	var j: int = emitted[1]
	var k: int = emitted[2]
	# Recompute in exact emitted order, just as _validate_refined_normals does.
	var cross: Vector3 = (vertices[j] - vertices[i]).cross(vertices[k] - vertices[i])
	var geometric_outward: Vector3 = -cross
	var cross_squared: float = cross.length_squared()
	var classification_alignment: float = geometric_outward.dot(outward)
	var summed_normal: Vector3 = normals[i] + normals[j] + normals[k]
	var native_alignment: float = summed_normal.dot(geometric_outward)
	var geometry_valid: bool = cross.is_finite() and is_finite(cross_squared) and cross_squared > 0.0
	var classification_valid: bool = geometry_valid and is_finite(classification_alignment) and classification_alignment > 0.0
	var native_valid: bool = classification_valid and summed_normal.is_finite() and is_finite(native_alignment) and native_alignment > 0.0
	var result: Dictionary = {
		"valid": false, "error": "", "indices": emitted, "swapped": swap,
		"score": 0.0, "native_valid": native_valid,
		"classification_winding_valid": classification_valid,
		"native_alignment": native_alignment, "classification_alignment": classification_alignment,
		"cross_squared": cross_squared
	}
	if not geometry_valid:
		result.error = "229 native face cross or squared length is nonfinite or degenerate."
		return result
	if not classification_valid:
		result.error = "229 emitted face does not face strictly along classification outward."
		return result
	if not native_valid:
		result.error = "229 emitted-order native stored-normal alignment is not finite and strictly positive."
		return result
	var scalar: Dictionary = _scalar64_cosine(vertices, normals, i, j, k)
	if not scalar.ok:
		result.error = "229 scalar64 face/normal score is nonfinite or undefined."
		return result
	result.valid = true
	result.score = scalar.score
	return result

static func _scalar64_cosine(vertices: PackedVector3Array, normals: PackedVector3Array, a: int, b: int, c: int) -> Dictionary:
	# GDScript float is scalar64. Cast components BEFORE subtracting or adding;
	# Vector3 subtraction, cross, sum, normalization or dot must not score a pair.
	var ux: float = float(vertices[b].x) - float(vertices[a].x)
	var uy: float = float(vertices[b].y) - float(vertices[a].y)
	var uz: float = float(vertices[b].z) - float(vertices[a].z)
	var vx: float = float(vertices[c].x) - float(vertices[a].x)
	var vy: float = float(vertices[c].y) - float(vertices[a].y)
	var vz: float = float(vertices[c].z) - float(vertices[a].z)
	var gx: float = -(uy * vz - uz * vy)
	var gy: float = -(uz * vx - ux * vz)
	var gz: float = -(ux * vy - uy * vx)
	var nx: float = (float(normals[a].x) + float(normals[b].x)) + float(normals[c].x)
	var ny: float = (float(normals[a].y) + float(normals[b].y)) + float(normals[c].y)
	var nz: float = (float(normals[a].z) + float(normals[b].z)) + float(normals[c].z)
	var geometric_squared: float = (gx * gx + gy * gy) + gz * gz
	var normal_squared: float = (nx * nx + ny * ny) + nz * nz
	var numerator: float = (gx * nx + gy * ny) + gz * nz
	if not is_finite(geometric_squared) or not is_finite(normal_squared) or not is_finite(numerator) or geometric_squared <= 0.0 or normal_squared <= 0.0:
		return {"ok": false, "score": 0.0}
	var denominator: float = sqrt(geometric_squared) * sqrt(normal_squared)
	if not is_finite(denominator) or denominator <= 0.0:
		return {"ok": false, "score": 0.0}
	var score: float = numerator / denominator
	return {"ok": is_finite(score), "score": score}

static func _edge_key(a: int, b: int) -> String:
	return str(a) + ":" + str(b)

static func _boundary(indices: PackedInt32Array, diagonal_a: int, diagonal_b: int, ids: Array[int]) -> Dictionary:
	var edges: Dictionary = {}
	for offset: int in [0, 3]:
		for step: int in range(3):
			var key: String = _edge_key(indices[offset + step], indices[offset + (step + 1) % 3])
			edges[key] = int(edges.get(key, 0)) + 1
	var forward: String = _edge_key(diagonal_a, diagonal_b)
	var reverse: String = _edge_key(diagonal_b, diagonal_a)
	var cancels: bool = int(edges.get(forward, 0)) == 1 and int(edges.get(reverse, 0)) == 1
	if not cancels:
		return {"valid": false, "direction": 0, "interior_edge_cancels": false}
	edges.erase(forward)
	edges.erase(reverse)
	# The unchanged four boundary edges are a-b-d-c-a for either diagonal.
	var cycle: Array[int] = [ids[0], ids[1], ids[3], ids[2]]
	var matches_forward: bool = edges.size() == 4
	var matches_reverse: bool = edges.size() == 4
	for step: int in range(4):
		var a: int = cycle[step]
		var b: int = cycle[(step + 1) % 4]
		matches_forward = matches_forward and int(edges.get(_edge_key(a, b), 0)) == 1
		matches_reverse = matches_reverse and int(edges.get(_edge_key(b, a), 0)) == 1
	var direction: int = 1 if matches_forward else (-1 if matches_reverse else 0)
	return {"valid": direction != 0, "direction": direction, "interior_edge_cancels": true}
