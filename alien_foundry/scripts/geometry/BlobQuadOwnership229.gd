extends RefCounted
## Source-only retained replay. No fields, DNA, file IO, extraction or repairs.
## The caller binds the saved source packet and axes. This helper authenticates
## every complete legacy cut before changing a whole 2/2 pair atomically.
const Grid210 = preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")
const Choice229 = preload("res://alien_foundry/scripts/geometry/BlobQuadChoice229.gd")
const POLICY_VERSION: int = 229
const MAX_VERTICES: int = 60000
const MAX_FACES: int = 100000
const MAX_GRID_SAMPLES: int = 560000

static func replay(mesh: Dictionary, axes: Array) -> Dictionary:
	var shape: Dictionary = Grid210.validate_axes(axes, true)
	if not bool(shape.ok):
		return _failure("229 axes rejected: " + str(shape.error))
	var dims: Vector3i = shape.dimensions
	var source_error: Variant = mesh.get("error", "")
	if not source_error is String:
		return _failure("229 source error metadata must be a String.")
	for flag: String in ["rejected", "cancelled", "raw_snapshot_complete"]:
		if not mesh.get(flag, false) is bool:
			return _failure("229 source status flags must be Boolean values.")
	if bool(mesh.get("cancelled", false)):
		return _failure("229 cannot replay a cancelled source.")
	if not str(source_error).is_empty():
		if source_error != Grid210.FACE_CONFLICT_ERROR or not bool(mesh.get("raw_snapshot_complete", false)):
			return _failure("229 requires a complete source, not a partial or non-face rejection.")
	elif bool(mesh.get("rejected", false)):
		return _failure("229 rejected source is missing its complete face-conflict status.")
	var vertices_value: Variant = mesh.get("vertices")
	var normals_value: Variant = mesh.get("normals")
	var indices_value: Variant = mesh.get("indices")
	if not vertices_value is PackedVector3Array or not normals_value is PackedVector3Array or not indices_value is PackedInt32Array:
		return _failure("229 retained arrays must preserve their original packed types.")
	var vertices: PackedVector3Array = vertices_value
	var normals: PackedVector3Array = normals_value
	var indices: PackedInt32Array = indices_value
	if vertices.is_empty() or vertices.size() > MAX_VERTICES or normals.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0 or indices.size() > MAX_FACES * 3:
		return _failure("229 retained array sizes violate the bounded complete-triangle contract.")
	for vertex_id: int in range(vertices.size()):
		var length_squared: float = normals[vertex_id].length_squared()
		if not vertices[vertex_id].is_finite() or not normals[vertex_id].is_finite() or not is_finite(length_squared) or length_squared <= 0.0:
			return _failure("229 nonfinite position or invalid normal at vertex %d." % vertex_id)
	var validated_records: Dictionary = Grid210._edge_records(mesh, vertices.size(), dims, int(shape.samples))
	if not bool(validated_records.ok):
		return _failure("229 edge provenance rejected: " + str(validated_records.error))
	var records: Array = validated_records.records
	var edge_vertices: Dictionary = {}
	for vertex_id: int in range(records.size()):
		var record: Dictionary = records[vertex_id]
		edge_vertices[Grid210._edge_key(int(record.first), int(record.second))] = vertex_id
	var groups: Dictionary = {}
	@warning_ignore("integer_division")
	var face_count: int = indices.size() / 3
	for face_id: int in range(face_count):
		var offset: int = face_id * 3
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size() or a == b or b == c or c == a:
			return _failure("229 invalid vertex indices at source face %d." % face_id)
		var cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if not cross.is_finite() or not is_finite(cross.length_squared()) or cross.length_squared() == 0.0:
			return _failure("229 source face %d is nonfinite or degenerate." % face_id)
		# Source is always legacy. Do not widen Grid210's existing acceptance.
		var owner: Dictionary = Grid210._face_owner([records[a], records[b], records[c]], dims)
		if not bool(owner.ok):
			return _failure("229 source face %d ownership rejected: %s" % [face_id, str(owner.error)])
		var cell: Vector3i = owner.cell
		var owner_key: int = Grid210._index(cell, dims) * Grid210.TETRAHEDRA.size() + int(owner.tetrahedron)
		if not groups.has(owner_key):
			groups[owner_key] = {"cell": cell, "tetrahedron": int(owner.tetrahedron), "faces": PackedInt32Array()}
		var group: Dictionary = groups[owner_key]
		var faces: PackedInt32Array = group.faces
		faces.append(face_id)
		group.faces = faces
		if faces.size() > 2:
			return _failure("229 duplicate or excess source faces claim one tetrahedron.")
	var output: PackedInt32Array = indices.duplicate()
	var keys: Array = groups.keys()
	keys.sort()
	var choices: Array[Dictionary] = []
	var singles: int = 0
	var legacy_choices: int = 0
	var alternate_choices: int = 0
	for owner_key: int in keys:
		var group: Dictionary = groups[owner_key]
		var authenticated: Dictionary = _authenticate_legacy_group(group, indices, vertices, records, edge_vertices, dims, axes)
		if not bool(authenticated.ok):
			return _failure("229 source group %d rejected: %s" % [owner_key, str(authenticated.error)])
		var faces: PackedInt32Array = group.faces
		if faces.size() == 1:
			var offset: int = faces[0] * 3
			var a: int = indices[offset]
			var b: int = indices[offset + 1]
			var c: int = indices[offset + 2]
			# Retain 1/3 bytes, but never allow an unchanged failing face through.
			var geometric_outward: Vector3 = -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			var summed_normal: Vector3 = normals[a] + normals[b] + normals[c]
			var native_dot: float = summed_normal.dot(geometric_outward)
			if not geometric_outward.is_finite() or geometric_outward.length_squared() == 0.0 or not summed_normal.is_finite() or not is_finite(native_dot) or native_dot <= 0.0:
				return _failure("229 unchanged single-triangle cut fails the native stored-normal predicate.")
			singles += 1
			continue
		var ids: PackedInt32Array = authenticated.quad_vertices
		var chosen: Dictionary = Choice229.choose(vertices, normals, ids[0], ids[1], ids[2], ids[3], authenticated.outward)
		if not bool(chosen.get("ok", false)):
			return _failure("229 complete quad %d rejected atomically: %s" % [owner_key, str(chosen.get("error", "invalid choice result"))])
		var replacement_value: Variant = chosen.get("indices")
		if not replacement_value is PackedInt32Array or replacement_value.size() != 6:
			return _failure("229 choice helper returned an incomplete pair.")
		var replacement: PackedInt32Array = replacement_value
		for pair_face: int in range(2):
			for corner: int in range(3):
				output[faces[pair_face] * 3 + corner] = replacement[pair_face * 3 + corner]
		var choice_name: String = str(chosen.get("choice", ""))
		if choice_name == "legacy":
			legacy_choices += 1
		elif choice_name == "alternate":
			alternate_choices += 1
		else:
			return _failure("229 choice helper returned an unknown canonical choice.")
		choices.append({"owner_key": owner_key, "cell": [group.cell.x, group.cell.y, group.cell.z], "tetrahedron": int(group.tetrahedron), "face_ids": Array(faces), "quad_vertices": Array(ids), "choice": choice_name, "legacy_score": chosen.get("legacy_score"), "alternate_score": chosen.get("alternate_score"), "legacy_valid": chosen.get("legacy_valid"), "alternate_valid": chosen.get("alternate_valid")})
	return {"ok": true, "error": "", "indices": output, "report": {"policy_version": POLICY_VERSION, "quads": choices.size(), "complete_quads": choices.size(), "single_triangle_tets": singles, "tetrahedra": groups.size(), "faces": face_count, "vertices": vertices.size(), "legacy_choices": legacy_choices, "alternate_choices": alternate_choices, "choices": choices, "field_queries": 0, "mesh_builds": 0, "source_mutated": false}}

## A candidate is not authenticated merely because each triangle is legal.
## Its complete index stream must equal the deterministic source replay.
static func validate_chosen(source_mesh: Dictionary, axes: Array, candidate_mesh: Dictionary) -> Dictionary:
	var canonical: Dictionary = replay(source_mesh, axes)
	if not bool(canonical.ok):
		return canonical
	for key: String in ["vertices", "normals"]:
		var candidate_value: Variant = candidate_mesh.get(key)
		var source_value: Variant = source_mesh.get(key)
		if not candidate_value is PackedVector3Array or candidate_value.size() != source_value.size() or candidate_value.to_byte_array() != source_value.to_byte_array():
			return _failure("229 candidate changed exact retained %s bytes." % key)
	var source_ledger: Variant = source_mesh.get("edge_refinement204")
	var candidate_ledger: Variant = candidate_mesh.get("edge_refinement204")
	if not candidate_ledger is Dictionary or var_to_bytes(source_ledger) != var_to_bytes(candidate_ledger):
		return _failure("229 candidate changed exact retained edge provenance bytes.")
	var candidate_indices: Variant = candidate_mesh.get("indices")
	if not candidate_indices is PackedInt32Array or candidate_indices.size() != canonical.indices.size() or candidate_indices.to_byte_array() != canonical.indices.to_byte_array():
		return _failure("229 candidate is not the complete canonical chosen pair stream.")
	return {"ok": true, "error": "", "indices": canonical.indices, "report": canonical.report}

## Opt-in geometric ownership only. This does not authenticate a pair or grant
## acceptance to an arbitrary alternate diagonal; use validate_chosen for that.
## Records have the normalized shape returned by Grid210._edge_records.
static func face_owner229(records: Array, dims: Vector3i, policy_version: int) -> Dictionary:
	if policy_version != POLICY_VERSION:
		return {"ok": false, "error": "229 two-diagonal ownership requires explicit policy version 229."}
	var shape: Dictionary = Grid210._validate_dimensions(dims, MAX_GRID_SAMPLES)
	if not bool(shape.ok) or records.size() != 3:
		return {"ok": false, "error": "229 ownership requires a bounded grid and three crossing edges."}
	var low: Vector3i = dims
	var high: Vector3i = Vector3i.ZERO
	var endpoints: Dictionary = {}
	var edges: Dictionary = {}
	for record_value: Variant in records:
		if not record_value is Dictionary:
			return {"ok": false, "error": "229 malformed normalized edge record."}
		var record: Dictionary = record_value
		if not record.get("first") is int or not record.get("second") is int or not record.get("a") is Vector3i or not record.get("b") is Vector3i:
			return {"ok": false, "error": "229 normalized edge record types are invalid."}
		var first: int = record.first
		var second: int = record.second
		var a: Vector3i = record.a
		var b: Vector3i = record.b
		if first < 0 or first >= second or second >= int(shape.samples) or a != Grid210._coordinate(first, dims) or b != Grid210._coordinate(second, dims):
			return {"ok": false, "error": "229 normalized edge endpoints are invalid."}
		var difference: Vector3i = b - a
		var edge_key: String = Grid210._edge_key(first, second)
		if edges.has(edge_key) or difference.x < 0 or difference.y < 0 or difference.z < 0 or difference.x > 1 or difference.y > 1 or difference.z > 1:
			return {"ok": false, "error": "229 duplicate or non-tetrahedral crossing edge."}
		edges[edge_key] = true
		low = low.min(a).min(b)
		high = high.max(a).max(b)
		endpoints[first] = a
		endpoints[second] = b
	if endpoints.size() != 4:
		return {"ok": false, "error": "229 face crossing edges must span four tetrahedron endpoints."}
	var minimum_cell: Vector3i = (high - Vector3i.ONE).max(Vector3i.ZERO)
	var maximum_cell: Vector3i = low.min(dims - Vector3i.ONE * 2)
	var candidates: Array[Dictionary] = []
	for z: int in range(minimum_cell.z, maximum_cell.z + 1):
		for y: int in range(minimum_cell.y, maximum_cell.y + 1):
			for x: int in range(minimum_cell.x, maximum_cell.x + 1):
				var cell: Vector3i = Vector3i(x, y, z)
				for tetrahedron: int in range(Grid210.TETRAHEDRA.size()):
					var tet: Array = Grid210.TETRAHEDRA[tetrahedron]
					var contains_all: bool = true
					for endpoint_value: Variant in endpoints.values():
						var endpoint: Vector3i = endpoint_value
						var corner: int = Grid210.CORNERS.find(endpoint - cell)
						if corner < 0 or not tet.has(corner):
							contains_all = false
							break
					if contains_all:
						candidates.append({"cell": cell, "tetrahedron": tetrahedron})
	if candidates.size() != 1:
		return {"ok": false, "error": "229 face does not have exactly one actual cell/tetrahedron owner."}
	var owner: Dictionary = candidates[0]
	if not _is_emitted_face229(edges, owner.cell, Grid210.TETRAHEDRA[int(owner.tetrahedron)], dims):
		return {"ok": false, "error": "229 crossing edges are not either legal sign-cut diagonal."}
	return {"ok": true, "error": "", "cell": owner.cell, "tetrahedron": int(owner.tetrahedron), "policy_version": POLICY_VERSION}

static func _authenticate_legacy_group(group: Dictionary, indices: PackedInt32Array, vertices: PackedVector3Array, records: Array, edge_vertices: Dictionary, dims: Vector3i, axes: Array) -> Dictionary:
	var faces: PackedInt32Array = group.faces
	var wanted_edges: Dictionary = {}
	var actual: PackedInt32Array = PackedInt32Array()
	for face_id: int in faces:
		for corner: int in range(3):
			var vertex_id: int = indices[face_id * 3 + corner]
			actual.append(vertex_id)
			var record: Dictionary = records[vertex_id]
			wanted_edges[Grid210._edge_key(int(record.first), int(record.second))] = true
	var tet: Array = Grid210.TETRAHEDRA[int(group.tetrahedron)]
	var matched: Array[Dictionary] = []
	# The crossing-edge graph determines a bipartition up to complement.
	# Exhausting fourteen constant-size masks also checks every required edge.
	for mask: int in range(1, 15):
		var partition: Dictionary = _partition(group.cell, tet, dims, mask)
		var inside: PackedInt32Array = partition.inside
		var outside: PackedInt32Array = partition.outside
		if (inside.size() == 2) != (faces.size() == 2):
			continue
		var crossing: Dictionary = {}
		for first: int in inside:
			for second: int in outside:
				crossing[Grid210._edge_key(first, second)] = true
		if not _same_keys(crossing, wanted_edges):
			continue
		var outward: Vector3 = _classification_outward(inside, outside, dims, axes)
		if not outward.is_finite() or outward.length_squared() == 0.0:
			continue
		var expected: PackedInt32Array = PackedInt32Array()
		var quad_vertices: PackedInt32Array = PackedInt32Array()
		if inside.size() == 2:
			quad_vertices = PackedInt32Array([_edge_vertex(edge_vertices, inside[0], outside[0]), _edge_vertex(edge_vertices, inside[0], outside[1]), _edge_vertex(edge_vertices, inside[1], outside[0]), _edge_vertex(edge_vertices, inside[1], outside[1])])
			expected.append_array(_emitted(vertices, quad_vertices[0], quad_vertices[1], quad_vertices[3], outward))
			expected.append_array(_emitted(vertices, quad_vertices[0], quad_vertices[3], quad_vertices[2], outward))
		else:
			var single: int = inside[0] if inside.size() == 1 else outside[0]
			var other: PackedInt32Array = outside if inside.size() == 1 else inside
			expected = _emitted(vertices, _edge_vertex(edge_vertices, single, other[0]), _edge_vertex(edge_vertices, single, other[1]), _edge_vertex(edge_vertices, single, other[2]), outward)
		if expected == actual:
			matched.append({"outward": outward, "quad_vertices": quad_vertices, "inside": inside, "outside": outside})
	if matched.size() != 1:
		return {"ok": false, "error": "Incomplete, mixed, reversed, duplicate or noncanonical legacy cut; sign orientation is not unique."}
	var result: Dictionary = matched[0]
	result.ok = true
	result.error = ""
	return result

static func _partition(cell: Vector3i, tet: Array, dims: Vector3i, mask: int) -> Dictionary:
	var inside: PackedInt32Array = PackedInt32Array()
	var outside: PackedInt32Array = PackedInt32Array()
	for position: int in range(4):
		var endpoint: int = Grid210._index(cell + Grid210.CORNERS[int(tet[position])], dims)
		if (mask & (1 << position)) != 0:
			inside.append(endpoint)
		else:
			outside.append(endpoint)
	return {"inside": inside, "outside": outside}

static func _classification_outward(inside: PackedInt32Array, outside: PackedInt32Array, dims: Vector3i, axes: Array) -> Vector3:
	# Native Vector3 operation order exactly matches OrganicMeshExtractor.
	# Do not replace with scalar centroids, a negated complement or normals.
	var outward: Vector3 = Vector3.ZERO
	for endpoint: int in outside:
		outward += _point(endpoint, dims, axes) / float(outside.size())
	for endpoint: int in inside:
		outward -= _point(endpoint, dims, axes) / float(inside.size())
	return outward

static func _point(endpoint: int, dims: Vector3i, axes: Array) -> Vector3:
	var coordinate: Vector3i = Grid210._coordinate(endpoint, dims)
	var x_axis: PackedFloat32Array = axes[0]
	var y_axis: PackedFloat32Array = axes[1]
	var z_axis: PackedFloat32Array = axes[2]
	return Vector3(x_axis[coordinate.x], y_axis[coordinate.y], z_axis[coordinate.z])

static func _edge_vertex(edge_vertices: Dictionary, first: int, second: int) -> int:
	return int(edge_vertices.get(Grid210._edge_key(first, second), -1))

static func _emitted(vertices: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> PackedInt32Array:
	if a < 0 or b < 0 or c < 0:
		return PackedInt32Array()
	var cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	var classification_dot: float = cross.dot(outward)
	# A zero classification dot cannot distinguish the two sign complements.
	if not cross.is_finite() or not is_finite(cross.length_squared()) or cross.length_squared() == 0.0 or not is_finite(classification_dot) or classification_dot == 0.0:
		return PackedInt32Array()
	return PackedInt32Array([a, c, b]) if classification_dot > 0.0 else PackedInt32Array([a, b, c])

static func _is_emitted_face229(wanted: Dictionary, cell: Vector3i, tet: Array, dims: Vector3i) -> bool:
	for mask: int in range(1, 15):
		var partition: Dictionary = _partition(cell, tet, dims, mask)
		var inside: PackedInt32Array = partition.inside
		var outside: PackedInt32Array = partition.outside
		var possible: Array = []
		if inside.size() == 2:
			var a: String = Grid210._edge_key(inside[0], outside[0])
			var b: String = Grid210._edge_key(inside[0], outside[1])
			var c: String = Grid210._edge_key(inside[1], outside[0])
			var d: String = Grid210._edge_key(inside[1], outside[1])
			possible = [[a, b, d], [a, d, c], [a, b, c], [b, d, c]]
		else:
			var single: int = inside[0] if inside.size() == 1 else outside[0]
			var other: PackedInt32Array = outside if inside.size() == 1 else inside
			possible = [[Grid210._edge_key(single, other[0]), Grid210._edge_key(single, other[1]), Grid210._edge_key(single, other[2])]]
		for candidate: Array in possible:
			var keys: Dictionary = {}
			for key: String in candidate:
				keys[key] = true
			if _same_keys(keys, wanted):
				return true
	return false

static func _same_keys(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for key: Variant in first:
		if not second.has(key):
			return false
	return true

static func _failure(message: String) -> Dictionary:
	# Never return a partially changed stream on failure.
	return {"ok": false, "error": message, "indices": PackedInt32Array(), "report": {}}
