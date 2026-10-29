extends RefCounted
## Pure, bounded index/coordinate operations for the opt-in 210 slab grid.
## No anatomical queries, mesh extraction, connectivity repair or scene calls.
const TETRAHEDRA: Array = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
const CORNERS: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)]
const MAX_REFINEMENT_PASSES: int = 1
const SPLITS_PER_INTERVAL: int = 1
const MAX_NEW_PLANES: int = 8
const MAX_NEW_PLANES_PER_AXIS: int = 4
const MAX_EXTRA_SAMPLES: int = 32000
const MAX_COARSE_SAMPLES: int = 480000
const MAX_TOTAL_SAMPLES: int = 512000
const HIGH_PREVIEW_MAX_NEW_PLANES: int = 12
const HIGH_PREVIEW_MAX_EXTRA_SAMPLES: int = 80000
const HIGH_PREVIEW_MAX_TOTAL_SAMPLES: int = 560000
const MAX_COARSE_TRIANGLES: int = 100000
const MAX_FINAL_TRIANGLES: int = 100000
const MAX_TOTAL_SOLVED_EDGES: int = 60000
const MAX_TOTAL_EDGE_QUERIES: int = 4380000
const MAX_QUERIES_PER_EDGE: int = 73
const FACE_CONFLICT_ERROR: String = "204 refined face/field-normal inconsistency; no normal or topology repair."

static func cap_for(high_preview: bool = false) -> int:
	return HIGH_PREVIEW_MAX_TOTAL_SAMPLES if high_preview else MAX_TOTAL_SAMPLES

static func plan(mesh: Dictionary, dims: Vector3i, origin: Vector3, step: float, high_preview: bool = false) -> Dictionary:
	var result: Dictionary = _empty_plan(dims)
	var max_new_planes: int = HIGH_PREVIEW_MAX_NEW_PLANES if high_preview else MAX_NEW_PLANES
	var max_extra_samples: int = HIGH_PREVIEW_MAX_EXTRA_SAMPLES if high_preview else MAX_EXTRA_SAMPLES
	var shape: Dictionary = _validate_dimensions(dims, MAX_COARSE_SAMPLES)
	if not bool(shape.ok):
		return _plan_error(result, str(shape.error))
	if not origin.is_finite() or not is_finite(step) or step <= 0.0:
		return _plan_error(result, "210 requires a finite origin and positive finite original reference step.")
	var mesh_error: Variant = mesh.get("error", "")
	if not mesh_error is String:
		return _plan_error(result, "210 coarse error metadata is malformed.")
	for flag: String in ["raw_snapshot_complete", "rejected", "cancelled"]:
		var flag_value: Variant = mesh.get(flag, false)
		if not flag_value is bool:
			return _plan_error(result, "210 coarse %s metadata must be a Boolean." % flag)
	var snapshot_complete: bool = mesh.get("raw_snapshot_complete", false)
	var rejected: bool = mesh.get("rejected", false)
	var cancelled: bool = mesh.get("cancelled", false)
	if cancelled:
		return _plan_error(result, "210 cannot refine a cancelled coarse packet.")
	if not str(mesh_error).is_empty():
		if mesh_error != FACE_CONFLICT_ERROR or not snapshot_complete:
			return _plan_error(result, "210 cannot refine an incomplete or non-face coarse rejection: " + str(mesh_error))
	elif rejected:
		return _plan_error(result, "210 cannot refine a rejected or cancelled coarse packet without a complete face-conflict snapshot.")
	var vertices_value: Variant = mesh.get("vertices")
	var normals_value: Variant = mesh.get("normals")
	var indices_value: Variant = mesh.get("indices")
	if not vertices_value is PackedVector3Array or not normals_value is PackedVector3Array or not indices_value is PackedInt32Array:
		return _plan_error(result, "210 coarse positions, normals and indices require their original packed array types.")
	var vertices: PackedVector3Array = vertices_value
	var normals: PackedVector3Array = normals_value
	var indices: PackedInt32Array = indices_value
	if vertices.is_empty() or normals.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0:
		return _plan_error(result, "210 coarse mesh arrays are empty, mismatched or not complete triangles.")
	@warning_ignore("integer_division")
	var triangle_count: int = indices.size() / 3
	var counts: Dictionary = result.counts
	counts.coarse_vertices = vertices.size()
	counts.coarse_triangles = triangle_count
	counts.base_samples = int(shape.samples)
	if triangle_count > MAX_COARSE_TRIANGLES:
		return _plan_error(result, "210 coarse triangle cap exceeded; no truncation.")
	if vertices.size() > MAX_TOTAL_SOLVED_EDGES:
		return _plan_error(result, "210 coarse vertex count already exceeds the cumulative solved-edge cap.")
	for vertex_id: int in range(vertices.size()):
		var normal_length_squared: float = normals[vertex_id].length_squared()
		if not vertices[vertex_id].is_finite() or not normals[vertex_id].is_finite() or not is_finite(normal_length_squared) or normal_length_squared <= 0.0:
			return _plan_error(result, "210 nonfinite vertex or degenerate/nonfinite normal at vertex %d." % vertex_id)
	var record_map: Dictionary = _edge_records(mesh, vertices.size(), dims, int(shape.samples))
	if not bool(record_map.ok):
		return _plan_error(result, str(record_map.error))
	var records: Array = record_map.records
	var conflicts: PackedInt32Array = PackedInt32Array()
	var malformed_faces: PackedInt32Array = PackedInt32Array()
	# Do not stop after the first conflict or select a budget-sized subset.
	for face_id: int in range(triangle_count):
		var offset: int = face_id * 3
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size() or a == b or b == c or c == a:
			malformed_faces.append(face_id)
			continue
		# Deliberately the unchanged native Vector3 predicate, not a scalar
		# replacement, normalization, tolerance, sag threshold or face flip.
		var outward: Vector3 = -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		var area_squared: float = outward.length_squared()
		var summed_normal: Vector3 = normals[a] + normals[b] + normals[c]
		var alignment: float = summed_normal.dot(outward)
		if not outward.is_finite() or not is_finite(area_squared) or area_squared == 0.0 or not summed_normal.is_finite() or not is_finite(alignment):
			malformed_faces.append(face_id)
			continue
		if alignment <= 0.0:
			conflicts.append(face_id)
	result.conflict_face_ids = conflicts
	result.malformed_face_ids = malformed_faces
	counts.scanned_faces = triangle_count
	counts.conflict_faces = conflicts.size()
	if not malformed_faces.is_empty():
		return _plan_error(result, "210 malformed, nonfinite or exactly degenerate coarse faces reject; no repair.")
	if not str(mesh_error).is_empty() and conflicts.is_empty():
		return _plan_error(result, "210 rejected coarse face metadata does not agree with the complete native face scan.")
	var selected_cells: Dictionary = {}
	var interval_sets: Array[Dictionary] = [{}, {}, {}]
	var owners: Array[Dictionary] = []
	for face_id: int in conflicts:
		var offset: int = face_id * 3
		var face_records: Array = [records[indices[offset]], records[indices[offset + 1]], records[indices[offset + 2]]]
		var owner: Dictionary = _face_owner(face_records, dims)
		if not bool(owner.ok):
			result.failed_ownership_face_id = face_id
			return _plan_error(result, str(owner.error))
		var cell: Vector3i = owner.cell
		var cell_id: int = _index(cell, dims)
		selected_cells[cell_id] = cell
		owners.append({"face_id": face_id, "cell": cell, "tetrahedron": int(owner.tetrahedron)})
		for axis: int in range(3):
			var axis_set: Dictionary = interval_sets[axis]
			axis_set[cell[axis]] = true
	var sorted_cell_ids: Array = selected_cells.keys()
	sorted_cell_ids.sort()
	var owning_cells: Array[Vector3i] = []
	for cell_id: int in sorted_cell_ids:
		var cell: Vector3i = selected_cells[cell_id]
		owning_cells.append(cell)
	var split_intervals: Array[PackedInt32Array] = []
	var added: Vector3i = Vector3i.ZERO
	for axis: int in range(3):
		var axis_set: Dictionary = interval_sets[axis]
		var sorted_intervals: Array = axis_set.keys()
		sorted_intervals.sort()
		var intervals: PackedInt32Array = PackedInt32Array(sorted_intervals)
		split_intervals.append(intervals)
		added[axis] = intervals.size()
	result.owning_cells = owning_cells
	result.conflict_owners = owners
	result.split_intervals = split_intervals
	counts.owning_cells = owning_cells.size()
	counts.new_planes_per_axis = added
	counts.new_planes = added.x + added.y + added.z
	if added.x > MAX_NEW_PLANES_PER_AXIS or added.y > MAX_NEW_PLANES_PER_AXIS or added.z > MAX_NEW_PLANES_PER_AXIS or int(counts.new_planes) > max_new_planes:
		return _plan_error(result, "210 selected shared planes exceed the complete-plan cap; no truncation or respacing.")
	var refined_dims: Vector3i = dims + added
	var refined_shape: Dictionary = _validate_dimensions(refined_dims, cap_for(high_preview))
	if not bool(refined_shape.ok):
		return _plan_error(result, str(refined_shape.error))
	var extra_samples: int = int(refined_shape.samples) - int(shape.samples)
	counts.refined_samples = int(refined_shape.samples)
	counts.extra_samples = extra_samples
	result.dimensions = refined_dims
	result.refined_dimensions = refined_dims
	if extra_samples > max_extra_samples:
		return _plan_error(result, "210 extra sample cap exceeded by the complete plan; no truncation or respacing.")
	var inherited_axes: Array[PackedFloat32Array] = _uniform_axes(dims, origin, step)
	var base_validation: Dictionary = validate_axes(inherited_axes, high_preview)
	if not bool(base_validation.ok):
		return _plan_error(result, "210 original coordinates rejected: " + str(base_validation.error))
	var axes: Array[PackedFloat32Array] = []
	var widths: Array[PackedFloat32Array] = []
	for axis: int in range(3):
		var split: Dictionary = _split_axis(inherited_axes[axis], split_intervals[axis])
		if not bool(split.ok):
			return _plan_error(result, str(split.error))
		var coordinates: PackedFloat32Array = split.axis
		axes.append(coordinates)
		var interval_widths: PackedFloat32Array = PackedFloat32Array()
		for interval: int in range(coordinates.size() - 1):
			interval_widths.append(float(coordinates[interval + 1]) - float(coordinates[interval]))
		widths.append(interval_widths)
	var final_validation: Dictionary = validate_axes(axes, high_preview)
	if not bool(final_validation.ok):
		return _plan_error(result, str(final_validation.error))
	result.ok = true
	result.refine = not conflicts.is_empty()
	result.axes = axes
	result.base_axes = inherited_axes
	result.interval_widths = widths
	counts.refinement_passes = 1 if bool(result.refine) else 0
	return result

static func point(index: int, dims: Vector3i, axes: Array, high_preview: bool = false) -> Vector3:
	if not _axes_match_dimensions(axes, dims, high_preview) or index < 0 or index >= dims.x * dims.y * dims.z:
		return Vector3(NAN, NAN, NAN)
	var coordinate: Vector3i = _coordinate(index, dims)
	var x_axis: PackedFloat32Array = axes[0]
	var y_axis: PackedFloat32Array = axes[1]
	var z_axis: PackedFloat32Array = axes[2]
	return Vector3(x_axis[coordinate.x], y_axis[coordinate.y], z_axis[coordinate.z])

static func validate_axes(axes: Array, high_preview: bool = false) -> Dictionary:
	if axes.size() != 3:
		return {"ok": false, "error": "210 requires exactly three canonical axes."}
	var dims: Vector3i = Vector3i.ZERO
	for axis: int in range(3):
		var axis_value: Variant = axes[axis]
		if not axis_value is PackedFloat32Array:
			return {"ok": false, "error": "210 canonical axes must be PackedFloat32Array values."}
		var coordinates: PackedFloat32Array = axis_value
		if coordinates.size() < 2 or coordinates.size() > cap_for(high_preview):
			return {"ok": false, "error": "210 axis length is outside the bounded grid contract."}
		dims[axis] = coordinates.size()
		for index: int in range(coordinates.size()):
			var coordinate: float = coordinates[index]
			if not is_finite(coordinate) or (index > 0 and coordinate <= float(coordinates[index - 1])):
				return {"ok": false, "error": "210 canonical coordinates must be finite and strictly increasing without collapsed intervals."}
	var shape: Dictionary = _validate_dimensions(dims, cap_for(high_preview))
	if not bool(shape.ok):
		return shape
	return {"ok": true, "error": "", "dimensions": dims, "samples": int(shape.samples)}

static func locate(query_point: Vector3, axes: Array, high_preview: bool = false) -> Dictionary:
	var outside: Dictionary = {"inside": false, "cell": Vector3i.ZERO, "fraction": Vector3.ZERO}
	var validated: Dictionary = validate_axes(axes, high_preview)
	if not bool(validated.ok):
		outside.error = str(validated.error)
		return outside
	return locate_validated(query_point, axes)

## Fast path for an unchanged canonical-axis set that already passed
## validate_axes. Never substitute this for validation at the grid boundary.
static func locate_validated(query_point: Vector3, axes: Array) -> Dictionary:
	var outside: Dictionary = {"inside": false, "cell": Vector3i.ZERO, "fraction": Vector3.ZERO}
	if not query_point.is_finite() or axes.size() != 3:
		return outside
	var cell: Vector3i = Vector3i.ZERO
	var fraction: Vector3 = Vector3.ZERO
	for axis: int in range(3):
		var axis_value: Variant = axes[axis]
		if not axis_value is PackedFloat32Array:
			return outside
		var coordinates: PackedFloat32Array = axis_value
		if coordinates.size() < 2:
			return outside
		var query_value: float = query_point[axis]
		if query_value < float(coordinates[0]) or query_value > float(coordinates[coordinates.size() - 1]):
			return outside
		var interval: int = _interval(query_value, coordinates)
		var lower: float = coordinates[interval]
		var upper: float = coordinates[interval + 1]
		if not is_finite(lower) or not is_finite(upper) or lower >= upper:
			return outside
		cell[axis] = interval
		fraction[axis] = (query_value - lower) / (upper - lower)
	return {"inside": true, "cell": cell, "fraction": fraction}

static func trilinear(query_point: Vector3, field: PackedFloat32Array, dims: Vector3i, axes: Array, outside_value: float, high_preview: bool = false) -> float:
	var validated: Dictionary = validate_axes(axes, high_preview)
	if not bool(validated.ok):
		return outside_value
	return trilinear_validated(query_point, field, dims, axes, outside_value, high_preview)

## Production interpolation after a one-time validate_axes, with unchanged axes.
static func trilinear_validated(query_point: Vector3, field: PackedFloat32Array, dims: Vector3i, axes: Array, outside_value: float, high_preview: bool = false) -> float:
	if not _axes_match_dimensions(axes, dims, high_preview) or field.size() != dims.x * dims.y * dims.z:
		return outside_value
	var located: Dictionary = locate_validated(query_point, axes)
	if not bool(located.inside):
		return outside_value
	var cell: Vector3i = located.cell
	var q: Vector3 = located.fraction
	var row: int = dims.x
	var plane: int = row * dims.y
	var base: int = _index(cell, dims)
	return lerpf(lerpf(lerpf(field[base], field[base + 1], q.x), lerpf(field[base + row], field[base + row + 1], q.x), q.y), lerpf(lerpf(field[base + plane], field[base + plane + 1], q.x), lerpf(field[base + plane + row], field[base + plane + row + 1], q.x), q.y), q.z)

static func tetrahedral(query_point: Vector3, field: PackedFloat32Array, dims: Vector3i, axes: Array, outside_value: float, high_preview: bool = false) -> float:
	var validated: Dictionary = validate_axes(axes, high_preview)
	if not bool(validated.ok):
		return outside_value
	return tetrahedral_validated(query_point, field, dims, axes, outside_value, high_preview)

## Same six-tetrahedron affine rule, with no repeated linear axis validation.
static func tetrahedral_validated(query_point: Vector3, field: PackedFloat32Array, dims: Vector3i, axes: Array, outside_value: float, high_preview: bool = false) -> float:
	if not _axes_match_dimensions(axes, dims, high_preview) or field.size() != dims.x * dims.y * dims.z:
		return outside_value
	var located: Dictionary = locate_validated(query_point, axes)
	if not bool(located.inside):
		return outside_value
	# Preserve the original attachment consumer's half-open upper boundary.
	# Trilinear lookup, in contrast, intentionally includes the maximum point.
	for axis: int in range(3):
		var coordinates: PackedFloat32Array = axes[axis]
		if query_point[axis] >= coordinates[coordinates.size() - 1]:
			return outside_value
	var cell: Vector3i = located.cell
	var q: Vector3 = located.fraction
	var row: int = dims.x
	var plane: int = row * dims.y
	var base: int = _index(cell, dims)
	var first: int = 1
	var second: int = row
	var high: float = q.x
	var middle: float = q.y
	var low: float = q.z
	if q.x >= q.y:
		if q.y >= q.z:
			pass
		elif q.x >= q.z:
			second = plane; middle = q.z; low = q.y
		else:
			first = plane; second = 1; high = q.z; middle = q.x; low = q.y
	else:
		if q.x >= q.z:
			first = row; second = 1; high = q.y; middle = q.x; low = q.z
		elif q.y >= q.z:
			first = row; second = plane; high = q.y; middle = q.z; low = q.x
		else:
			first = plane; second = row; high = q.z; middle = q.y; low = q.x
	return field[base] * (1.0 - high) + field[base + first] * (high - middle) + field[base + first + second] * (middle - low) + field[base + 1 + row + plane] * low

static func audit_connectivity(field: PackedFloat32Array, dims: Vector3i, job: RefCounted = null, high_preview: bool = false) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "", "field": field, "collars": [], "original_components": 0, "audit_complete": false, "repairs": 0}
	var shape: Dictionary = _validate_dimensions(dims, cap_for(high_preview))
	if not bool(shape.ok) or field.size() != int(shape.get("samples", -1)):
		result.error = "210 connectivity audit requires a complete bounded field with matching dimensions."
		return result
	for index: int in range(field.size()):
		if not is_finite(field[index]):
			result.error = "210 connectivity audit rejects nonfinite field values."
			return result
	var labels: PackedInt32Array = PackedInt32Array()
	labels.resize(field.size())
	labels.fill(-1)
	var plane: int = dims.x * dims.y
	var offsets: PackedInt32Array = PackedInt32Array([1, -1, dims.x, -dims.x, plane, -plane])
	var components: int = 0
	var negative_samples: int = 0
	for start: int in range(field.size()):
		if start % 4096 == 0 and job != null and job.is_cancelled():
			result.cancelled = true
			return result
		if field[start] >= 0.0 or labels[start] >= 0:
			continue
		var queue: PackedInt32Array = PackedInt32Array([start])
		labels[start] = components
		var cursor: int = 0
		while cursor < queue.size():
			if cursor % 4096 == 0 and job != null and job.is_cancelled():
				result.cancelled = true
				return result
			var index: int = queue[cursor]
			cursor += 1
			var coordinate: Vector3i = _coordinate(index, dims)
			for direction: int in range(6):
				if not _neighbour_in_bounds(coordinate, direction, dims):
					continue
				var adjacent: int = index + offsets[direction]
				if field[adjacent] < 0.0 and labels[adjacent] < 0:
					labels[adjacent] = components
					queue.append(adjacent)
		negative_samples += queue.size()
		components += 1
		result.original_components = components
	result.audit_complete = true
	result.negative_samples = negative_samples
	if components > 1:
		result.error = "210 rectilinear field has %d disconnected negative components; repair is forbidden." % components
		return result
	result.ok = true
	return result

static func _empty_plan(dims: Vector3i) -> Dictionary:
	return {"ok": false, "error": "", "refine": false, "conflict_face_ids": PackedInt32Array(), "malformed_face_ids": PackedInt32Array(), "owning_cells": [], "conflict_owners": [], "split_intervals": [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()], "axes": [], "base_axes": [], "base_dimensions": dims, "dimensions": dims, "refined_dimensions": dims, "counts": {"coarse_vertices": 0, "coarse_triangles": 0, "scanned_faces": 0, "conflict_faces": 0, "owning_cells": 0, "base_samples": 0, "refined_samples": 0, "extra_samples": 0, "new_planes": 0, "new_planes_per_axis": Vector3i.ZERO, "refinement_passes": 0, "splits_per_interval": SPLITS_PER_INTERVAL, "detector_field_queries": 0}}

static func _plan_error(result: Dictionary, message: String) -> Dictionary:
	result.ok = false
	result.refine = false
	result.error = message
	return result

static func _validate_dimensions(dims: Vector3i, cap: int) -> Dictionary:
	# Component bounds precede multiplication, so hostile dimensions cannot
	# overflow an int64 product before the sample cap is checked.
	if dims.x < 2 or dims.y < 2 or dims.z < 2 or dims.x > MAX_TOTAL_SAMPLES or dims.y > MAX_TOTAL_SAMPLES or dims.z > MAX_TOTAL_SAMPLES:
		return {"ok": false, "error": "210 dimensions must describe a bounded three-dimensional grid."}
	var samples: int = dims.x * dims.y * dims.z
	if samples > cap:
		return {"ok": false, "error": "210 grid sample cap exceeded; no fallback or respacing.", "samples": samples}
	return {"ok": true, "error": "", "samples": samples}

static func _edge_records(mesh: Dictionary, vertex_count: int, dims: Vector3i, sample_count: int) -> Dictionary:
	var refinement_value: Variant = mesh.get("edge_refinement204")
	if not refinement_value is Dictionary:
		return {"ok": false, "error": "210 requires original edge_refinement204 provenance for every vertex."}
	var refinement: Dictionary = refinement_value
	var refinement_error: Variant = refinement.get("error", "")
	if not refinement_error is String or (not str(refinement_error).is_empty() and refinement_error != FACE_CONFLICT_ERROR):
		return {"ok": false, "error": "210 cannot use a failed edge/root/normal solve as a refinement trigger."}
	var adaptive_value: Variant = refinement.get("adaptive_normal207")
	if not adaptive_value is Dictionary:
		return {"ok": false, "error": "210 requires original adaptive_normal207 edge records."}
	var adaptive: Dictionary = adaptive_value
	var records_value: Variant = adaptive.get("edge_records")
	if not records_value is Array:
		return {"ok": false, "error": "210 edge_records must be an Array."}
	var source_records: Array = records_value
	if source_records.size() != vertex_count:
		return {"ok": false, "error": "210 requires exactly one edge record for every coarse vertex."}
	var records: Array = []
	records.resize(vertex_count)
	var seen_ordinals: Dictionary = {}
	var seen_edges: Dictionary = {}
	for record_value: Variant in source_records:
		if not record_value is Dictionary:
			return {"ok": false, "error": "210 malformed coarse edge record."}
		var record: Dictionary = record_value
		var ordinal_value: Variant = record.get("edge_ordinal")
		var first_value: Variant = record.get("first")
		var second_value: Variant = record.get("second")
		if not ordinal_value is int or not first_value is int or not second_value is int:
			return {"ok": false, "error": "210 edge ordinals and endpoint IDs must be exact integers."}
		var ordinal: int = ordinal_value
		var first: int = first_value
		var second: int = second_value
		if ordinal < 0 or ordinal >= vertex_count or seen_ordinals.has(ordinal) or first < 0 or second >= sample_count or first >= second:
			return {"ok": false, "error": "210 edge records have duplicate/missing ordinals or invalid canonical endpoints."}
		var record_ok_value: Variant = record.get("ok", false)
		var record_error_value: Variant = record.get("error", "")
		if not record_ok_value is bool or not record_error_value is String:
			return {"ok": false, "error": "210 normal record status metadata is malformed."}
		if not bool(record_ok_value) or not str(record_error_value).is_empty():
			return {"ok": false, "error": "210 rejected coarse normal records cannot be refined."}
		var edge_key: int = first * sample_count + second
		if seen_edges.has(edge_key):
			return {"ok": false, "error": "210 more than one coarse vertex claims the same shared edge."}
		var a: Vector3i = _coordinate(first, dims)
		var b: Vector3i = _coordinate(second, dims)
		var difference: Vector3i = b - a
		# Every edge in the fixed six tetrahedra follows a monotone corner chain.
		if difference.x < 0 or difference.y < 0 or difference.z < 0 or difference.x > 1 or difference.y > 1 or difference.z > 1 or difference == Vector3i.ZERO:
			return {"ok": false, "error": "210 edge endpoints do not belong to the unchanged six-tetrahedron grid."}
		records[ordinal] = {"first": first, "second": second, "a": a, "b": b}
		seen_ordinals[ordinal] = true
		seen_edges[edge_key] = true
	return {"ok": true, "error": "", "records": records}

static func _face_owner(records: Array, dims: Vector3i) -> Dictionary:
	var low: Vector3i = dims
	var high: Vector3i = Vector3i.ZERO
	var endpoints: Dictionary = {}
	for record: Dictionary in records:
		var a: Vector3i = record.a
		var b: Vector3i = record.b
		low = low.min(a).min(b)
		high = high.max(a).max(b)
		endpoints[int(record.first)] = a
		endpoints[int(record.second)] = b
	var minimum_cell: Vector3i = (high - Vector3i.ONE).max(Vector3i.ZERO)
	var maximum_cell: Vector3i = low.min(dims - Vector3i.ONE * 2)
	var candidates: Array[Dictionary] = []
	# Equal endpoint coordinates allow BOTH neighbouring cells, not just min.
	# Enumerate their actual tetrahedra and reject boundary ambiguity explicitly.
	for z: int in range(minimum_cell.z, maximum_cell.z + 1):
		for y: int in range(minimum_cell.y, maximum_cell.y + 1):
			for x: int in range(minimum_cell.x, maximum_cell.x + 1):
				var cell: Vector3i = Vector3i(x, y, z)
				for tetrahedron: int in range(TETRAHEDRA.size()):
					var tet: Array = TETRAHEDRA[tetrahedron]
					var contains_all: bool = true
					for endpoint_value: Variant in endpoints.values():
						var endpoint: Vector3i = endpoint_value
						var corner: int = CORNERS.find(endpoint - cell)
						if corner < 0 or not tet.has(corner):
							contains_all = false
							break
					if contains_all:
						candidates.append({"cell": cell, "tetrahedron": tetrahedron})
	if candidates.size() != 1:
		return {"ok": false, "error": "210 conflict face has %d actual cell/tetrahedron owners; ownership must be unique." % candidates.size()}
	# A real marching-tetrahedra face uses three crossing edges spanning all
	# four tetrahedron vertices. A triangle of three lattice endpoints is not
	# a valid sign cut even when the box boundary leaves only one candidate.
	if endpoints.size() != 4:
		return {"ok": false, "error": "210 conflict face edge records do not span one complete tetrahedron."}
	var owner: Dictionary = candidates[0]
	var owner_cell: Vector3i = owner.cell
	var owner_tet: Array = TETRAHEDRA[int(owner.tetrahedron)]
	if not _is_emitted_face(records, owner_cell, owner_tet, dims):
		return {"ok": false, "error": "210 conflict edges cannot form a face emitted by the unchanged tetrahedron triangulation."}
	return {"ok": true, "error": "", "cell": owner_cell, "tetrahedron": int(owner.tetrahedron)}

static func _is_emitted_face(records: Array, cell: Vector3i, tet: Array, dims: Vector3i) -> bool:
	var wanted: Array[String] = []
	for record: Dictionary in records:
		wanted.append(_edge_key(int(record.first), int(record.second)))
	wanted.sort()
	for mask: int in range(1, 15):
		var inside: PackedInt32Array = PackedInt32Array()
		var outside: PackedInt32Array = PackedInt32Array()
		for position: int in range(4):
			var corner: int = int(tet[position])
			var endpoint: int = _index(cell + CORNERS[corner], dims)
			if (mask & (1 << position)) != 0:
				inside.append(endpoint)
			else:
				outside.append(endpoint)
		var possible: Array = []
		if inside.size() == 1:
			possible.append([_edge_key(inside[0], outside[0]), _edge_key(inside[0], outside[1]), _edge_key(inside[0], outside[2])])
		elif inside.size() == 3:
			possible.append([_edge_key(outside[0], inside[0]), _edge_key(outside[0], inside[1]), _edge_key(outside[0], inside[2])])
		else:
			var a: String = _edge_key(inside[0], outside[0])
			var b: String = _edge_key(inside[0], outside[1])
			var c: String = _edge_key(inside[1], outside[0])
			var d: String = _edge_key(inside[1], outside[1])
			possible.append([a, b, d])
			possible.append([a, d, c])
		for candidate: Array in possible:
			candidate.sort()
			if candidate == wanted:
				return true
	return false

static func _edge_key(first: int, second: int) -> String:
	return "%d:%d" % [mini(first, second), maxi(first, second)]

static func _uniform_axes(dims: Vector3i, origin: Vector3, step: float) -> Array[PackedFloat32Array]:
	var axes: Array[PackedFloat32Array] = []
	for axis: int in range(3):
		var coordinates: PackedFloat32Array = PackedFloat32Array()
		for index: int in range(dims[axis]):
			# Preserve the extractor's native Vector3 expression and binary32
			# storage, rather than scalar origin[axis] + index * step arithmetic.
			var inherited: Vector3 = Vector3.ZERO
			match axis:
				0: inherited = origin + Vector3(index, 0, 0) * step
				1: inherited = origin + Vector3(0, index, 0) * step
				2: inherited = origin + Vector3(0, 0, index) * step
			coordinates.append(inherited[axis])
		axes.append(coordinates)
	return axes

static func _split_axis(base: PackedFloat32Array, intervals: PackedInt32Array) -> Dictionary:
	var coordinates: PackedFloat32Array = PackedFloat32Array()
	var cursor: int = 0
	for index: int in range(base.size()):
		coordinates.append(base[index])
		if cursor >= intervals.size() or intervals[cursor] != index:
			continue
		if index + 1 >= base.size():
			return {"ok": false, "error": "210 split interval is outside the original grid."}
		var a: float = base[index]
		var b: float = base[index + 1]
		# Pinned scalar operation order, followed by binary32 packed storage.
		var midpoint: float = a + (b - a) * 0.5
		coordinates.append(midpoint)
		var stored_midpoint: float = coordinates[coordinates.size() - 1]
		if not is_finite(midpoint) or not is_finite(stored_midpoint) or stored_midpoint <= a or stored_midpoint >= b:
			return {"ok": false, "error": "210 binary32 midpoint collapsed, reordered or became nonfinite; no alternate split."}
		cursor += 1
	if cursor != intervals.size():
		return {"ok": false, "error": "210 split intervals are not unique sorted original intervals."}
	return {"ok": true, "error": "", "axis": coordinates}

static func _axes_match_dimensions(axes: Array, dims: Vector3i, high_preview: bool = false) -> bool:
	if axes.size() != 3 or dims.x < 2 or dims.y < 2 or dims.z < 2 or dims.x > MAX_TOTAL_SAMPLES or dims.y > MAX_TOTAL_SAMPLES or dims.z > MAX_TOTAL_SAMPLES:
		return false
	if dims.x * dims.y * dims.z > cap_for(high_preview):
		return false
	for axis: int in range(3):
		var axis_value: Variant = axes[axis]
		if not axis_value is PackedFloat32Array:
			return false
		var coordinates: PackedFloat32Array = axis_value
		if coordinates.size() != dims[axis]:
			return false
	return true

static func _interval(value: float, coordinates: PackedFloat32Array) -> int:
	var low: int = 0
	var high: int = coordinates.size() - 1
	while high - low > 1:
		@warning_ignore("integer_division")
		var middle: int = (low + high) / 2
		if value < float(coordinates[middle]):
			high = middle
		else:
			low = middle
	return mini(low, coordinates.size() - 2)

static func _coordinate(index: int, dims: Vector3i) -> Vector3i:
	var plane: int = dims.x * dims.y
	@warning_ignore("integer_division")
	var z: int = index / plane
	var remainder: int = index - z * plane
	@warning_ignore("integer_division")
	var y: int = remainder / dims.x
	return Vector3i(remainder - y * dims.x, y, z)

static func _index(coordinate: Vector3i, dims: Vector3i) -> int:
	return coordinate.x + coordinate.y * dims.x + coordinate.z * dims.x * dims.y

static func _neighbour_in_bounds(coordinate: Vector3i, direction: int, dims: Vector3i) -> bool:
	match direction:
		0: return coordinate.x + 1 < dims.x
		1: return coordinate.x > 0
		2: return coordinate.y + 1 < dims.y
		3: return coordinate.y > 0
		4: return coordinate.z + 1 < dims.z
		_: return coordinate.z > 0
