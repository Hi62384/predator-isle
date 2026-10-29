extends RefCounted
## Hand-authored retained-array contracts only. No extraction, field sampling,
## DNA, file IO, native build, rendering, or successful-run-derived fixtures.
const Ownership = preload("res://alien_foundry/scripts/geometry/BlobQuadOwnership229.gd")
const Grid210 = preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")

const EXPECTED_CHECKS: int = 460
const TEST_TETS: Array = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
const TEST_CORNERS: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)]

static func run() -> Dictionary:
	var report: Dictionary = {"ok": false, "checks": 0, "failures": [], "field_queries": 0, "mesh_builds": 0}
	var axes: Array = [PackedFloat32Array([0.0, 1.0]), PackedFloat32Array([0.0, 1.0]), PackedFloat32Array([0.0, 1.0])]
	for mask: int in [1, 2, 4, 8, 7, 11, 13, 14]:
		var single: Dictionary = _fixture(mask, false)
		var before: PackedByteArray = var_to_bytes(single)
		var result: Dictionary = Ownership.replay(single, axes)
		_check(report, bool(result.ok), "Single cut %d authenticates." % mask)
		_check(report, result.indices == single.indices, "Single cut %d preserves exact order." % mask)
		_check(report, var_to_bytes(single) == before, "Single cut %d does not mutate its source." % mask)
		if bool(result.ok):
			_check(report, int(result.report.single_triangle_tets) == 1 and int(result.report.quads) == 0, "Single cut %d has exact group accounting." % mask)
	# Six actual cube tetrahedra times all six oriented 2/2 sign masks.
	# Complementary masks are separate fixtures; normals never set winding.
	for tetrahedron: int in range(6):
		for mask: int in [3, 5, 6, 9, 10, 12]:
			var cut: Dictionary = _fixture(mask, false, tetrahedron)
			var before: PackedByteArray = var_to_bytes(cut)
			var result: Dictionary = Ownership.replay(cut, axes)
			var other: PackedInt32Array = _alternate(cut)
			_check(report, bool(result.ok), "Every tetrahedron and 2/2 sign mask authenticates its legacy source.")
			_check(report, result.indices == cut.indices, "Every midpoint 2/2 cut retains the exact tied legacy pair.")
			_check(report, _boundary_equal(cut.indices, other), "Both legal diagonals have the same four-edge oriented boundary chain.")
			_check(report, var_to_bytes(cut) == before, "Every tetrahedron/sign fixture remains byte exact.")
			if bool(result.ok):
				_check(report, int(result.report.quads) == 1 and int(result.report.single_triangle_tets) == 0 and int(result.report.choices[0].tetrahedron) == tetrahedron, "Complete-pair accounting retains the actual tetrahedron ID.")
			var parsed: Dictionary = Grid210._edge_records(cut, 4, Vector3i(2, 2, 2), 8)
			var edge_records: Array = parsed.records
			for stream: PackedInt32Array in [cut.indices, other]:
				for face: int in range(2):
					var owner: Dictionary = Ownership.face_owner229([edge_records[stream[face * 3]], edge_records[stream[face * 3 + 1]], edge_records[stream[face * 3 + 2]]], Vector3i(2, 2, 2), 229)
					_check(report, bool(owner.ok) and owner.cell == Vector3i.ZERO and int(owner.tetrahedron) == tetrahedron, "Each legal-diagonal face has its unique actual cell/tetrahedron owner.")
			for face: int in range(2):
				_check(report, not bool(Grid210._face_owner([edge_records[other[face * 3]], edge_records[other[face * 3 + 1]], edge_records[other[face * 3 + 2]]], Vector3i(2, 2, 2)).ok), "The old Grid210 contract rejects each alternate-diagonal face.")
	var flat: Dictionary = _fixture(3, false)
	var flat_result: Dictionary = Ownership.replay(flat, axes)
	_check(report, bool(flat_result.ok), "Flat complete legacy pair authenticates.")
	_check(report, flat_result.indices == flat.indices, "Exact score tie retains the original legacy pair.")
	if bool(flat_result.ok):
		_check(report, int(flat_result.report.quads) == 1 and int(flat_result.report.single_triangle_tets) == 0 and int(flat_result.report.legacy_choices) == 1, "Flat pair is one complete quad, not two singles.")
	var warped: Dictionary = _fixture(3, true)
	var source_bytes: PackedByteArray = var_to_bytes(warped)
	var replayed: Dictionary = Ownership.replay(warped, axes)
	var alternate: PackedInt32Array = _alternate(warped)
	_check(report, bool(replayed.ok), "Warped complete legacy source authenticates.")
	_check(report, replayed.indices == alternate and replayed.indices != warped.indices, "The canonical alternate replaces the entire warped pair.")
	_check(report, var_to_bytes(warped) == source_bytes, "Quad replay does not mutate source positions, normals, indices or ledger.")
	if bool(replayed.ok):
		var choice: Dictionary = replayed.report.choices[0]
		_check(report, bool(choice.legacy_valid) and bool(choice.alternate_valid) and float(choice.alternate_score) > float(choice.legacy_score) and choice.choice == "alternate", "Both eligible scores and strict deterministic choice are reported.")
	var candidate: Dictionary = warped.duplicate(true)
	candidate.indices = alternate
	_check(report, bool(Ownership.validate_chosen(warped, axes, candidate).ok), "The complete canonical chosen candidate is authenticated.")
	_check(report, not bool(Ownership.validate_chosen(warped, axes, warped).ok), "An arbitrary unchosen legal diagonal is rejected.")
	var normalized: Dictionary = Grid210._edge_records(warped, 4, Vector3i(2, 2, 2), 8)
	var records: Array = normalized.records
	for stream: PackedInt32Array in [warped.indices, alternate]:
		for face: int in range(2):
			var triple: Array = [records[stream[face * 3]], records[stream[face * 3 + 1]], records[stream[face * 3 + 2]]]
			_check(report, bool(Ownership.face_owner229(triple, Vector3i(2, 2, 2), 229).ok), "Explicit 229 geometric ownership accepts each legal diagonal face.")
	_check(report, not bool(Ownership.face_owner229([records[0], records[1], records[2]], Vector3i(2, 2, 2), 224).ok), "The widened owner is unavailable to the old policy.")
	_check(report, not bool(Grid210._face_owner([records[alternate[0]], records[alternate[1]], records[alternate[2]]], Vector3i(2, 2, 2)).ok), "Grid210 still rejects alternate-diagonal source faces.")
	var bad: Dictionary = candidate.duplicate(true)
	bad.indices = PackedInt32Array([alternate[0], alternate[1], alternate[2], warped.indices[3], warped.indices[4], warped.indices[5]])
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "A mixed pair is not authenticated.")
	bad = candidate.duplicate(true)
	bad.indices = alternate.slice(0, 3)
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "A missing chosen face is not authenticated.")
	bad = candidate.duplicate(true)
	bad.indices = PackedInt32Array([alternate[0], alternate[1], alternate[2], alternate[0], alternate[1], alternate[2]])
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "A duplicated chosen face is not authenticated.")
	bad = candidate.duplicate(true)
	bad.indices = PackedInt32Array([alternate[0], alternate[2], alternate[1], alternate[3], alternate[4], alternate[5]])
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "A reversed chosen face is not authenticated.")
	bad = candidate.duplicate(true)
	var moved: PackedVector3Array = bad.vertices.duplicate()
	moved[0] += Vector3(0.0001, 0.0, 0.0)
	bad.vertices = moved
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "Changing a retained position byte is forbidden.")
	bad = candidate.duplicate(true)
	var changed_normals: PackedVector3Array = bad.normals.duplicate()
	changed_normals[0] = -changed_normals[0]
	bad.normals = changed_normals
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "Changing a retained normal is forbidden.")
	bad = candidate.duplicate(true)
	bad.edge_refinement204.adaptive_normal207.edge_records[0].audit_note = "changed"
	_check(report, not bool(Ownership.validate_chosen(warped, axes, bad).ok), "Even unused edge-ledger metadata must remain byte exact.")
	bad = warped.duplicate(true)
	bad.indices = bad.indices.slice(0, 3)
	_check(report, not bool(Ownership.replay(bad, axes).ok), "Missing legacy partner cannot masquerade as a single cut.")
	bad = warped.duplicate(true)
	bad.indices = PackedInt32Array([warped.indices[0], warped.indices[1], warped.indices[2], warped.indices[0], warped.indices[1], warped.indices[2]])
	_check(report, not bool(Ownership.replay(bad, axes).ok), "Duplicate legacy partner is rejected.")
	bad = warped.duplicate(true)
	bad.indices = PackedInt32Array([warped.indices[0], warped.indices[2], warped.indices[1], warped.indices[3], warped.indices[4], warped.indices[5]])
	_check(report, not bool(Ownership.replay(bad, axes).ok), "One reversed legacy face is rejected.")
	bad = warped.duplicate(true)
	bad.edge_refinement204.adaptive_normal207.edge_records[0].second = 3
	_check(report, not bool(Ownership.replay(bad, axes).ok), "A crossing edge with the wrong actual owner is rejected.")
	bad = _fixture(1, false)
	var reversed_normals: PackedVector3Array = bad.normals.duplicate()
	for vertex_id: int in range(reversed_normals.size()):
		reversed_normals[vertex_id] = -reversed_normals[vertex_id]
	bad.normals = reversed_normals
	_check(report, not bool(Ownership.replay(bad, axes).ok), "Unchanged single cuts still obey the native final normal predicate.")
	_check(report, not bool(Ownership.replay(warped, [PackedFloat32Array([0.0, 0.0]), axes[1], axes[2]]).ok), "Collapsed canonical coordinates are rejected.")
	_check(report, var_to_bytes(warped) == source_bytes, "All negative tests leave the original retained source unchanged.")
	var interleaved: Dictionary = _interleaved_fixture(warped)
	var interleaved_axes: Array = [PackedFloat32Array([0.0, 1.0, 2.0]), axes[1], axes[2]]
	var interleaved_result: Dictionary = Ownership.replay(interleaved, interleaved_axes)
	_check(report, bool(interleaved_result.ok), "Nonadjacent source face partners are grouped by actual cell and tetrahedron.")
	var expected_interleaved: PackedInt32Array = PackedInt32Array()
	for face: int in range(2):
		for copy: int in range(2):
			for corner: int in range(3):
				expected_interleaved.append(alternate[face * 3 + corner] + copy * 4)
	_check(report, interleaved_result.indices == expected_interleaved, "Both complete replacements preserve their original interleaved face positions.")
	if bool(interleaved_result.ok):
		_check(report, int(interleaved_result.report.quads) == 2 and int(interleaved_result.report.single_triangle_tets) == 0, "Interleaved ownership contains exactly two complete quads.")
	report.expected_checks = EXPECTED_CHECKS
	report.exact_assertion_count = int(report.checks) == EXPECTED_CHECKS
	if not bool(report.exact_assertion_count):
		report.failures.append("Ownership assertion count differs from the fixed source contract.")
	report.ok = report.failures.is_empty()
	return report

static func _fixture(mask: int, warped: bool, tetrahedron: int = 0) -> Dictionary:
	var points: Array[Vector3] = []
	var endpoints: PackedInt32Array = PackedInt32Array()
	for corner: int in TEST_TETS[tetrahedron]:
		points.append(Vector3(TEST_CORNERS[corner]))
		endpoints.append(Grid210._index(TEST_CORNERS[corner], Vector3i(2, 2, 2)))
	var inside: PackedInt32Array = PackedInt32Array()
	var outside: PackedInt32Array = PackedInt32Array()
	for position: int in range(4):
		if (mask & (1 << position)) != 0:
			inside.append(position)
		else:
			outside.append(position)
	var outward: Vector3 = Vector3.ZERO
	for position: int in outside:
		outward += points[position] / float(outside.size())
	for position: int in inside:
		outward -= points[position] / float(inside.size())
	var pairs: Array = []
	if inside.size() == 2:
		pairs = [[inside[0], outside[0]], [inside[0], outside[1]], [inside[1], outside[0]], [inside[1], outside[1]]]
	else:
		var single: int = inside[0] if inside.size() == 1 else outside[0]
		var other: PackedInt32Array = outside if inside.size() == 1 else inside
		pairs = [[single, other[0]], [single, other[1]], [single, other[2]]]
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var records: Array[Dictionary] = []
	var fractions: Array[float] = [0.2, 0.7, 0.4, 0.6]
	for index: int in range(pairs.size()):
		var a: int = pairs[index][0]
		var b: int = pairs[index][1]
		var fraction: float = fractions[index] if warped else 0.5
		vertices.append(points[a] + (points[b] - points[a]) * fraction)
		normals.append(outward.normalized())
		records.append({"edge_ordinal": index, "first": mini(endpoints[a], endpoints[b]), "second": maxi(endpoints[a], endpoints[b]), "ok": true, "error": ""})
	var indices: PackedInt32Array = _emit(vertices, 0, 1, 3, outward) if inside.size() == 2 else _emit(vertices, 0, 1, 2, outward)
	if inside.size() == 2:
		indices.append_array(_emit(vertices, 0, 3, 2, outward))
	return {"vertices": vertices, "normals": normals, "indices": indices, "fixture_outward": outward, "edge_refinement204": {"error": "", "adaptive_normal207": {"edge_records": records}}}

static func _interleaved_fixture(quad: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var records: Array[Dictionary] = []
	var source_records: Array = quad.edge_refinement204.adaptive_normal207.edge_records
	for copy: int in range(2):
		for vertex_id: int in range(4):
			vertices.append(quad.vertices[vertex_id] + Vector3(copy, 0, 0))
			normals.append(quad.normals[vertex_id])
			var source: Dictionary = source_records[vertex_id]
			var first: Vector3i = Grid210._coordinate(int(source.first), Vector3i(2, 2, 2)) + Vector3i(copy, 0, 0)
			var second: Vector3i = Grid210._coordinate(int(source.second), Vector3i(2, 2, 2)) + Vector3i(copy, 0, 0)
			records.append({"edge_ordinal": vertex_id + copy * 4, "first": Grid210._index(first, Vector3i(3, 2, 2)), "second": Grid210._index(second, Vector3i(3, 2, 2)), "ok": true, "error": ""})
	var indices: PackedInt32Array = PackedInt32Array()
	for face: int in range(2):
		for copy: int in range(2):
			for corner: int in range(3):
				indices.append(quad.indices[face * 3 + corner] + copy * 4)
	return {"vertices": vertices, "normals": normals, "indices": indices, "edge_refinement204": {"error": "", "adaptive_normal207": {"edge_records": records}}}

static func _alternate(mesh: Dictionary) -> PackedInt32Array:
	var indices: PackedInt32Array = _emit(mesh.vertices, 0, 1, 2, mesh.fixture_outward)
	indices.append_array(_emit(mesh.vertices, 1, 3, 2, mesh.fixture_outward))
	return indices

static func _emit(vertices: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> PackedInt32Array:
	return PackedInt32Array([a, c, b]) if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(outward) > 0.0 else PackedInt32Array([a, b, c])

static func _boundary_equal(first: PackedInt32Array, second: PackedInt32Array) -> bool:
	var first_boundary: Dictionary = _boundary(first)
	var second_boundary: Dictionary = _boundary(second)
	if first_boundary.size() != 4 or second_boundary.size() != 4:
		return false
	for edge: String in first_boundary:
		if int(first_boundary[edge]) != 1 or int(second_boundary.get(edge, 0)) != 1:
			return false
	return true

static func _boundary(indices: PackedInt32Array) -> Dictionary:
	var edges: Dictionary = {}
	for face: int in range(2):
		for corner: int in range(3):
			var first: int = indices[face * 3 + corner]
			var second: int = indices[face * 3 + (corner + 1) % 3]
			var forward: String = "%d:%d" % [first, second]
			var reverse: String = "%d:%d" % [second, first]
			if edges.has(reverse):
				edges.erase(reverse)
			else:
				edges[forward] = int(edges.get(forward, 0)) + 1
	return edges

static func _check(report: Dictionary, condition: bool, label: String) -> void:
	report.checks = int(report.checks) + 1
	if not condition:
		report.failures.append(label)
