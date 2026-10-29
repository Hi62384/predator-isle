extends SceneTree
## Synthetic local-array contract only: no field, authoring, meshing, resources,
## serializer, filesystem writes, scene creation, or production fixture calls.
const Choice = preload("res://alien_foundry/scripts/geometry/BlobQuadChoice229.gd")
const EXPECTED_FIXTURE_COUNT: int = 39
const EXPECTED_ASSERTION_COUNT: int = 301 # 39 * 7 fixture checks + 26 details + 2 count checks.
var fixture_count: int = 0
var assertions: int = 0
var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_run()
	_check(fixture_count == EXPECTED_FIXTURE_COUNT, "Explicit synthetic fixture count")
	_check(assertions + 1 == EXPECTED_ASSERTION_COUNT, "Explicit synthetic assertion count")
	print("BlobQuadChoice229Contract fixtures=%d expected=%d assertions=%d failures=%d" % [fixture_count, EXPECTED_FIXTURE_COUNT, assertions, failures.size()])
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	var vertices: PackedVector3Array = _square()
	var normals: PackedVector3Array = _normals(Vector3(0, 0, 1))
	var outward: Vector3 = Vector3(0, 0, 1)
	var result: Dictionary
	var changed: PackedVector3Array
	var changed_normals: PackedVector3Array

	# 01: Exact planar tie retains the original six emitted indices.
	result = _expect("planar exact tie", vertices, normals, outward, true, "legacy", true, true)
	_check(result.legacy_score == 1.0 and result.alternate_score == 1.0, "Planar scalar64 scores are exact ties")
	_check(result.indices == PackedInt32Array([0, 3, 1, 0, 2, 3]), "Legacy emitted index order stays exact")
	_check(result.candidate_boundaries_agree and result.legacy_boundary_invariant and result.alternate_boundary_invariant, "Both diagonals preserve the oriented boundary")

	# 02, 03: Simple warped quads have analytically different worst-face cosines.
	changed = vertices.duplicate()
	changed[2] = Vector3(0, 1, 1)
	result = _expect("alternate better warped quad", changed, normals, outward, true, "alternate", true, true)
	_check(result.alternate_score > result.legacy_score, "Alternate strictly improves the minimum cosine")
	_check(result.indices == PackedInt32Array([0, 2, 1, 1, 2, 3]), "Alternate canonical pair and emitted order stay exact")
	_check(absf(result.alternate_score - 1.0 / sqrt(2.0)) < 1e-14 and absf(result.legacy_score - 1.0 / sqrt(3.0)) < 1e-14, "Warped alternate scores match scalar analytic values")
	changed = vertices.duplicate()
	changed[3] = Vector3(1, 1, 1)
	result = _expect("legacy better warped quad", changed, normals, outward, true, "legacy", true, true)
	_check(result.legacy_score > result.alternate_score, "Legacy strictly improves the minimum cosine")

	# 04, 05: Margins below 1e-8 must not be rounded into an artificial tie.
	changed_normals = normals.duplicate()
	changed_normals[0] = Vector3(0.0001, 0, 1)
	changed_normals[3] = Vector3(0.0001, 0, 1)
	result = _expect("scalar64 tiny alternate improvement", vertices, changed_normals, outward, true, "alternate", true, true)
	_check(result.alternate_score - result.legacy_score > 0.0 and result.alternate_score - result.legacy_score < 1e-8, "Tiny alternate improvement is not quantized or epsilon-tied")
	changed_normals = normals.duplicate()
	changed_normals[1] = Vector3(0.0001, 0, 1)
	changed_normals[2] = Vector3(0.0001, 0, 1)
	result = _expect("scalar64 tiny legacy improvement", vertices, changed_normals, outward, true, "legacy", true, true)
	_check(result.legacy_score - result.alternate_score > 0.0 and result.legacy_score - result.alternate_score < 1e-8, "Tiny legacy improvement is not quantized or epsilon-tied")

	# 06 through 09: Native alignment is authoritative; no normal repair occurs.
	result = _expect("both pairs oppose stored normals", vertices, _normals(-outward), outward, false, "", false, false)
	_check(result.legacy_classification_winding_valid and result.alternate_classification_winding_valid, "Bad normals do not reverse classification winding")
	_expect("all normals collapsed", vertices, _normals(Vector3.ZERO), outward, false, "", false, false)
	changed_normals = PackedVector3Array([outward, -outward, Vector3.ZERO, Vector3.ZERO])
	_expect("emitted normal sum collapsed", vertices, changed_normals, outward, false, "", false, false)
	changed_normals = normals.duplicate()
	changed_normals[0] = Vector3.ZERO
	_expect("individual zero normal with valid sum", vertices, changed_normals, outward, true, "legacy", true, true)

	# 10, 11: Degeneracy cannot authorize repair of an inconsistent source chain.
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(2, 0, 0)])
	result = _expect("legacy degenerate inconsistent source boundary", changed, normals, outward, false, "", false, true)
	_check(not result.legacy.faces[0].native_valid and not result.legacy_boundary_invariant and result.alternate.interior_edge_cancels, "Valid alternate cannot repair the degenerate legacy source chain")
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0)])
	result = _expect("alternate degenerate legacy valid", changed, normals, outward, true, "legacy", true, false)
	_check(not result.alternate.faces[0].native_valid and result.legacy.interior_edge_cancels, "Alternate degeneracy does not veto a complete legacy pair")

	# 12 through 14: No partial faces, welding, or impossible boundary repair.
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0)])
	_expect("both pairs geometrically degenerate", changed, normals, outward, false, "", false, false)
	changed = vertices.duplicate()
	changed[3] = changed[1]
	_expect("distinct IDs with coincident points", changed, normals, outward, false, "", false, false)
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(1, 0, 0)])
	result = _expect("bow tie boundary chain rejected", changed, normals, outward, false, "", false, false)
	_check(result.legacy_native_valid and result.alternate_native_valid, "Bow tie face normals individually pass the native gate")
	_check(not result.legacy_boundary_invariant and not result.alternate_boundary_invariant, "Both impossible directed chains are rejected")
	_check(not result.legacy.interior_edge_cancels and not result.alternate.interior_edge_cancels, "Repeated diagonal directions cannot pass as an interior edge")

	# 15 through 17: Only classification changes winding, never normal direction.
	result = _expect("classification reversed normals unchanged", vertices, normals, -outward, false, "", false, false)
	_check(result.legacy.indices == PackedInt32Array([0, 1, 3, 0, 3, 2]), "Reversed classification reverses the exact legacy winding")
	result = _expect("classification and normals reversed", vertices, _normals(-outward), -outward, true, "legacy", true, true)
	_check(result.indices == PackedInt32Array([0, 1, 3, 0, 3, 2]) and result.legacy.boundary_direction == 1, "Reversed classification retains the reversed boundary chain")
	changed_normals = normals.duplicate()
	changed_normals[0] = Vector3(1000, -50, 1)
	changed_normals[1] = Vector3(-1000, 20, 1)
	result = _expect("normals cannot change winding", vertices, changed_normals, outward, true, "alternate", true, true)
	_check(result.legacy.indices == PackedInt32Array([0, 3, 1, 0, 2, 3]) and result.alternate.indices == PackedInt32Array([0, 2, 1, 1, 2, 3]), "Each candidate winding ignores arbitrary finite normals")

	# 18 through 23: Classification, referenced vectors, and array schema guards.
	_expect("zero classification outward", vertices, normals, Vector3.ZERO, false, "", false, false)
	_expect("orthogonal classification outward", vertices, normals, Vector3.RIGHT, false, "", false, false)
	_expect("nonfinite classification outward", vertices, normals, Vector3(INF, 0, 1), false, "", false, false)
	_expect("overflowed classification length", vertices, normals, Vector3(1e30, 0, 1), false, "", false, false)
	changed = vertices.duplicate()
	changed[0] = Vector3(NAN, 0, 0)
	_expect("nonfinite referenced vertex", changed, normals, outward, false, "", false, false)
	changed_normals = normals.duplicate()
	changed_normals[2] = Vector3(0, INF, 1)
	_expect("nonfinite stored normal", vertices, changed_normals, outward, false, "", false, false)

	# 24 through 29: IDs are checked before PackedInt32Array can wrap them.
	changed_normals = normals.duplicate()
	changed_normals.resize(3)
	_expect("mismatched vertex normal lengths", vertices, changed_normals, outward, false, "", false, false)
	_expect("negative root ID", vertices, normals, outward, false, "", false, false, [-1, 1, 2, 3])
	_expect("root ID past end", vertices, normals, outward, false, "", false, false, [0, 1, 2, 4])
	_expect("int64 root ID must not wrap", vertices, normals, outward, false, "", false, false, [4294967296, 1, 2, 3])
	_expect("duplicate root IDs", vertices, normals, outward, false, "", false, false, [0, 1, 2, 2])
	_expect("empty arrays", PackedVector3Array(), PackedVector3Array(), outward, false, "", false, false)

	# 30 through 33: Native overflow and emitted-order cancellation stay invalid.
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1e10, 0, 0), Vector3(0, 1e10, 0), Vector3(1e10, 1e10, 0)])
	_expect("native cross squared length overflow", changed, normals, outward, false, "", false, false)
	_expect("native normal sum overflow", vertices, _normals(Vector3(0, 0, 2e38)), outward, false, "", false, false)
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1e9, 0, 0), Vector3(0, 1e9, 0), Vector3(1e9, 1e9, 0)])
	_expect("native face normal dot overflow", changed, _normals(Vector3(0, 0, 1e30)), outward, false, "", false, false)
	changed_normals = PackedVector3Array([Vector3(0, 0, 16777216), Vector3(0, 0, -16777216), Vector3(0, 0, 3), Vector3(0, 0, 1)])
	result = _expect("emitted order native cancellation", vertices, changed_normals, outward, false, "", false, false)
	_check(result.legacy.faces[0].native_alignment == 0.0 and not result.legacy.faces[0].native_valid, "Exact native emitted-order zero is rejected")
	_check(Choice._scalar64_cosine(vertices, changed_normals, 0, 3, 1).score == 1.0, "A positive scalar64 score cannot rescue a native-invalid face")

	# 34 through 37: No mutation, no ID assumptions, determinism, and underflow.
	var before_vertices: PackedVector3Array = vertices.duplicate()
	var before_normals: PackedVector3Array = normals.duplicate()
	result = _expect("input arrays remain unchanged", vertices, normals, outward, true, "legacy", true, true)
	_check(vertices == before_vertices and normals == before_normals, "Input roots and stored normals remain exactly unchanged")
	changed = PackedVector3Array([vertices[3], vertices[1], Vector3(10, 10, 10), vertices[0], vertices[2]])
	changed_normals = _normals(outward)
	changed_normals.append(outward)
	result = _expect("nonconsecutive permuted root IDs", changed, changed_normals, outward, true, "legacy", true, true, [3, 1, 4, 0])
	_check(result.indices == PackedInt32Array([3, 0, 1, 3, 4, 0]), "Root IDs are preserved without positional assumptions")
	result = _expect("repeated exact deterministic choice", vertices, normals, outward, true, "legacy", true, true)
	var repeated: Dictionary = Choice.choose(vertices, normals, 0, 1, 2, 3, outward)
	_check(result.indices == repeated.indices and result.legacy_score == repeated.legacy_score and result.alternate_score == repeated.alternate_score and result.choice == repeated.choice, "Repeated choice and unquantized scores are exact")
	changed = PackedVector3Array([Vector3.ZERO, Vector3(1e-15, 0, 0), Vector3(0, 1e-15, 0), Vector3(1e-15, 1e-15, 0)])
	_expect("native cross squared length underflow", changed, normals, outward, false, "", false, false)

	# 38: Both source faces can pass the native gate while their chain is invalid.
	changed = PackedVector3Array([Vector3.ZERO, Vector3(0.2, 0.8, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)])
	result = _expect("concave inconsistent source boundary regression", changed, normals, outward, false, "", false, true)
	_check(result.legacy_native_valid and not result.legacy_boundary_invariant and result.alternate_boundary_invariant, "Concave source-chain failure is not disguised as native face invalidity")
	_check(result.error == "229 legacy source boundary chain is inconsistent; no boundary repair.", "Concave alternate is rejected by the authoritative source-chain guard")

	# 39: A native-invalid source pair may still lose if its boundary is intact.
	changed = PackedVector3Array([Vector3.ZERO, Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(-2, 0, 0)])
	result = _expect("legacy degenerate consistent source alternate valid", changed, normals, outward, true, "alternate", false, true)
	_check(not result.legacy.faces[0].native_valid and result.legacy_boundary_invariant and result.alternate_boundary_invariant and result.candidate_boundaries_agree, "Valid alternate preserves an already-consistent degenerate source boundary")

func _expect(label: String, vertices: PackedVector3Array, normals: PackedVector3Array, outward: Vector3, expected_ok: bool, expected_choice: String, legacy_valid: bool, alternate_valid: bool, ids: Array[int] = [0, 1, 2, 3]) -> Dictionary:
	fixture_count += 1
	var result: Dictionary = Choice.choose(vertices, normals, ids[0], ids[1], ids[2], ids[3], outward)
	_check(result.ok == expected_ok, label + ": acceptance")
	_check(result.choice == expected_choice, label + ": choice")
	_check(result.legacy_valid == legacy_valid and result.alternate_valid == alternate_valid, label + ": per-pair validity")
	_check(result.indices.size() == (6 if expected_ok else 0), label + ": complete pair or empty atomic failure")
	_check(result.error.is_empty() == expected_ok, label + ": authoritative error state")
	_check(_matches_old_emission(result, vertices, ids, outward), label + ": exact old classification-only emission")
	_check(not expected_ok or _native_accepts(result, vertices, normals, outward), label + ": selected pair passes exact native gate and boundary checks")
	return result

func _matches_old_emission(result: Dictionary, vertices: PackedVector3Array, ids: Array[int], outward: Vector3) -> bool:
	if result.legacy.is_empty() or result.alternate.is_empty():
		return result.legacy.is_empty() and result.alternate.is_empty()
	var expected_legacy: PackedInt32Array = _old_face(vertices, ids[0], ids[1], ids[3], outward)
	expected_legacy.append_array(_old_face(vertices, ids[0], ids[3], ids[2], outward))
	var expected_alternate: PackedInt32Array = _old_face(vertices, ids[0], ids[1], ids[2], outward)
	expected_alternate.append_array(_old_face(vertices, ids[1], ids[3], ids[2], outward))
	return result.legacy.indices == expected_legacy and result.alternate.indices == expected_alternate

func _old_face(vertices: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> PackedInt32Array:
	var cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	return PackedInt32Array([a, c, b] if cross.dot(outward) > 0.0 else [a, b, c])

func _native_accepts(result: Dictionary, vertices: PackedVector3Array, normals: PackedVector3Array, outward: Vector3) -> bool:
	if not result.boundary_invariant or not result.classification_winding_valid:
		return false
	for offset: int in [0, 3]:
		var a: int = result.indices[offset]
		var b: int = result.indices[offset + 1]
		var c: int = result.indices[offset + 2]
		var geometric: Vector3 = -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		var alignment: float = (normals[a] + normals[b] + normals[c]).dot(geometric)
		if not geometric.is_finite() or not is_finite(geometric.length_squared()) or geometric.length_squared() <= 0.0 or not is_finite(alignment) or alignment <= 0.0 or geometric.dot(outward) <= 0.0:
			return false
	return true

func _square() -> PackedVector3Array:
	return PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)])

func _normals(value: Vector3) -> PackedVector3Array:
	return PackedVector3Array([value, value, value, value])

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
