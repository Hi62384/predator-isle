extends RefCounted
## Pure second-pass planning over the complete current packed mesh.
## The retained-artifact authenticator owns source identity. This helper owns
## native conflict detection, current-grid ownership and cumulative grid caps.
## No field calls, extraction, normal changes, repair, fallback or scene calls.
const Grid = preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")
const PIN: String = "46735202dba8a4b7b528378ec4c140dd7c92cbe22750e0bbe599c4569e8c5b59"
const MODE: String = "bounded_high_preview2_v1"
const MAX_REFINEMENT_PASSES: int = 2
const MAX_NEW_PASSES: int = 1
const MAX_CUMULATIVE_NEW_PLANES: int = 16
const MAX_CUMULATIVE_NEW_PLANES_PER_AXIS: int = 6
const MAX_CUMULATIVE_EXTRA_SAMPLES: int = 100000
const MAX_TOTAL_SAMPLES: int = 560000

static func plan(mesh: Dictionary, current_axes: Array, prior_plan: Dictionary, original_dims: Vector3i, reference_cell: float) -> Dictionary:
	var result: Dictionary = _empty_plan(original_dims, reference_cell)
	if not is_finite(reference_cell) or reference_cell <= 0.0:
		return _error(result, "226 requires the positive finite original reference cell.")
	var history: Dictionary = _validate_prior(prior_plan, current_axes, original_dims, reference_cell)
	if not bool(history.ok):
		return _error(result, str(history.error))
	var dims: Vector3i = history.current_dimensions
	var current_samples: int = history.current_samples
	var base_samples: int = history.base_samples
	var prior_added: Vector3i = history.prior_added
	var counts: Dictionary = result.counts
	result.base_axes = _copy_axes(history.base_axes)
	result.current_axes = _copy_axes(current_axes)
	result.prior_split_intervals = _copy_intervals(history.prior_split_intervals)
	result.prior_plan_sha256 = _digest(var_to_bytes(prior_plan))
	result.current_dimensions = dims
	result.dimensions = dims
	result.refined_dimensions = dims
	counts.base_samples = base_samples
	counts.current_samples = current_samples
	counts.refined_samples = current_samples
	counts.prior_new_planes_per_axis = prior_added
	counts.prior_new_planes = prior_added.x + prior_added.y + prior_added.z
	counts.cumulative_new_planes_per_axis = prior_added
	counts.cumulative_new_planes = counts.prior_new_planes
	counts.cumulative_extra_samples = current_samples - base_samples
	var mesh_error: Variant = mesh.get("error", "")
	if not mesh_error is String:
		return _error(result, "226 current mesh error metadata is malformed.")
	for flag: String in ["raw_snapshot_complete", "rejected", "cancelled"]:
		var flag_value: Variant = mesh.get(flag, false)
		if not flag_value is bool:
			return _error(result, "226 current %s metadata must be a Boolean." % flag)
	var snapshot_complete: bool = mesh.get("raw_snapshot_complete", false)
	var rejected: bool = mesh.get("rejected", false)
	var cancelled: bool = mesh.get("cancelled", false)
	if cancelled:
		return _error(result, "226 cannot refine a cancelled current packet.")
	if not str(mesh_error).is_empty():
		if mesh_error != Grid.FACE_CONFLICT_ERROR or not snapshot_complete:
			return _error(result, "226 cannot refine an incomplete or non-face current rejection: " + str(mesh_error))
	elif rejected:
		return _error(result, "226 cannot refine a rejected current packet without a complete face-conflict snapshot.")
	var vertices_value: Variant = mesh.get("vertices")
	var normals_value: Variant = mesh.get("normals")
	var indices_value: Variant = mesh.get("indices")
	if not vertices_value is PackedVector3Array or not normals_value is PackedVector3Array or not indices_value is PackedInt32Array:
		return _error(result, "226 current positions, normals and indices require their original packed array types.")
	var vertices: PackedVector3Array = vertices_value
	var normals: PackedVector3Array = normals_value
	var indices: PackedInt32Array = indices_value
	if vertices.is_empty() or normals.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0:
		return _error(result, "226 current mesh arrays are empty, mismatched or not complete triangles.")
	@warning_ignore("integer_division")
	var triangle_count: int = indices.size() / 3
	counts.current_vertices = vertices.size()
	counts.current_triangles = triangle_count
	if triangle_count > Grid.MAX_FINAL_TRIANGLES:
		return _error(result, "226 current triangle cap exceeded; no truncation.")
	if vertices.size() > Grid.MAX_TOTAL_SOLVED_EDGES:
		return _error(result, "226 current vertex count already exceeds the cumulative solved-edge cap.")
	for vertex_id: int in range(vertices.size()):
		var normal_length_squared: float = normals[vertex_id].length_squared()
		if not vertices[vertex_id].is_finite() or not normals[vertex_id].is_finite() or not is_finite(normal_length_squared) or normal_length_squared <= 0.0:
			return _error(result, "226 nonfinite vertex or degenerate/nonfinite normal at vertex %d." % vertex_id)
	var record_map: Dictionary = Grid._edge_records(mesh, vertices.size(), dims, current_samples)
	if not bool(record_map.ok):
		return _error(result, str(record_map.error))
	var records: Array = record_map.records
	var conflicts: PackedInt32Array = PackedInt32Array()
	var malformed_faces: PackedInt32Array = PackedInt32Array()
	# Complete native scan. No expected face, cell or interval is a selector.
	for face_id: int in range(triangle_count):
		var offset: int = face_id * 3
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size() or a == b or b == c or c == a:
			malformed_faces.append(face_id)
			continue
		# Intentionally identical to Grid210's native Vector3 predicate.
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
		return _error(result, "226 malformed, nonfinite or exactly degenerate current faces reject; no repair.")
	if not str(mesh_error).is_empty() and conflicts.is_empty():
		return _error(result, "226 rejected current face metadata does not agree with the complete native face scan.")
	var selected_cells: Dictionary = {}
	var interval_sets: Array[Dictionary] = [{}, {}, {}]
	var owners: Array[Dictionary] = []
	for face_id: int in conflicts:
		var offset: int = face_id * 3
		var face_records: Array = [records[indices[offset]], records[indices[offset + 1]], records[indices[offset + 2]]]
		var owner: Dictionary = Grid._face_owner(face_records, dims)
		if not bool(owner.ok):
			result.failed_ownership_face_id = face_id
			return _error(result, str(owner.error))
		var cell: Vector3i = owner.cell
		var cell_id: int = Grid._index(cell, dims)
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
	var cumulative_added: Vector3i = prior_added + added
	result.owning_cells = owning_cells
	result.conflict_owners = owners
	result.split_intervals = split_intervals
	counts.owning_cells = owning_cells.size()
	counts.new_planes_per_axis = added
	counts.new_planes = added.x + added.y + added.z
	counts.cumulative_new_planes_per_axis = cumulative_added
	counts.cumulative_new_planes = cumulative_added.x + cumulative_added.y + cumulative_added.z
	if cumulative_added.x > MAX_CUMULATIVE_NEW_PLANES_PER_AXIS or cumulative_added.y > MAX_CUMULATIVE_NEW_PLANES_PER_AXIS or cumulative_added.z > MAX_CUMULATIVE_NEW_PLANES_PER_AXIS or int(counts.cumulative_new_planes) > MAX_CUMULATIVE_NEW_PLANES:
		return _error(result, "226 cumulative shared planes exceed the complete-plan cap; no truncation or respacing.")
	var refined_dims: Vector3i = dims + added
	var refined_shape: Dictionary = Grid._validate_dimensions(refined_dims, MAX_TOTAL_SAMPLES)
	if not bool(refined_shape.ok):
		return _error(result, str(refined_shape.error))
	var refined_samples: int = refined_shape.samples
	var cumulative_extra_samples: int = refined_samples - base_samples
	counts.refined_samples = refined_samples
	counts.extra_samples = refined_samples - current_samples
	counts.cumulative_extra_samples = cumulative_extra_samples
	result.dimensions = refined_dims
	result.refined_dimensions = refined_dims
	if cumulative_extra_samples > MAX_CUMULATIVE_EXTRA_SAMPLES:
		return _error(result, "226 cumulative extra sample cap exceeded by the complete plan; no truncation or respacing.")
	var axes: Array[PackedFloat32Array] = []
	var widths: Array[PackedFloat32Array] = []
	for axis: int in range(3):
		var inherited_axis: PackedFloat32Array = current_axes[axis]
		var split: Dictionary = Grid._split_axis(inherited_axis, split_intervals[axis])
		if not bool(split.ok):
			return _error(result, str(split.error))
		var coordinates: PackedFloat32Array = split.axis
		axes.append(coordinates)
		var interval_widths: PackedFloat32Array = PackedFloat32Array()
		for interval: int in range(coordinates.size() - 1):
			interval_widths.append(float(coordinates[interval + 1]) - float(coordinates[interval]))
		widths.append(interval_widths)
	var final_validation: Dictionary = Grid.validate_axes(axes, true)
	if not bool(final_validation.ok):
		return _error(result, str(final_validation.error))
	var refine: bool = not conflicts.is_empty()
	result.ok = true
	result.refine = refine
	result.reuse_current_mesh = not refine
	result.axes = axes
	result.interval_widths = widths
	counts.additional_refinement_passes = 1 if refine else 0
	counts.refinement_passes = 2 if refine else 1
	return result

static func _validate_prior(prior_plan: Dictionary, current_axes: Array, original_dims: Vector3i, reference_cell: float) -> Dictionary:
	var original_shape: Dictionary = Grid._validate_dimensions(original_dims, Grid.MAX_COARSE_SAMPLES)
	if not bool(original_shape.ok):
		return {"ok": false, "error": str(original_shape.error)}
	var current_validation: Dictionary = Grid.validate_axes(current_axes, true)
	if not bool(current_validation.ok):
		return {"ok": false, "error": "226 current axes rejected: " + str(current_validation.error)}
	if not _bool_is(prior_plan.get("ok"), true) or not _bool_is(prior_plan.get("refine"), true) or not _text_is(prior_plan.get("error"), ""):
		return {"ok": false, "error": "226 requires one successful validated prior refinement plan."}
	var base_dims_value: Variant = prior_plan.get("base_dimensions")
	var prior_dims_value: Variant = prior_plan.get("dimensions")
	var prior_refined_dims_value: Variant = prior_plan.get("refined_dimensions")
	var base_axes_value: Variant = prior_plan.get("base_axes")
	var prior_axes_value: Variant = prior_plan.get("axes")
	var intervals_value: Variant = prior_plan.get("split_intervals")
	var counts_value: Variant = prior_plan.get("counts")
	if not base_dims_value is Vector3i or not prior_dims_value is Vector3i or not prior_refined_dims_value is Vector3i or not base_axes_value is Array or not prior_axes_value is Array or not intervals_value is Array or not counts_value is Dictionary:
		return {"ok": false, "error": "226 prior plan grid, axes, split intervals or counters are malformed."}
	var base_dims: Vector3i = base_dims_value
	var prior_dims: Vector3i = prior_dims_value
	var prior_refined_dims: Vector3i = prior_refined_dims_value
	var base_axes: Array = base_axes_value
	var prior_axes: Array = prior_axes_value
	var prior_intervals: Array = intervals_value
	var prior_counts: Dictionary = counts_value
	var dims: Vector3i = current_validation.dimensions
	var base_samples: int = original_shape.samples
	var current_samples: int = current_validation.samples
	if base_dims != original_dims or prior_dims != dims or prior_refined_dims != dims:
		return {"ok": false, "error": "226 prior plan dimensions do not match the original and current grids."}
	var base_validation: Dictionary = Grid.validate_axes(base_axes, true)
	var prior_validation: Dictionary = Grid.validate_axes(prior_axes, true)
	if not bool(base_validation.ok) or not bool(prior_validation.ok):
		return {"ok": false, "error": "226 prior plan requires complete finite strictly increasing packed axes."}
	var checked_base_dims: Vector3i = base_validation.dimensions
	var checked_prior_dims: Vector3i = prior_validation.dimensions
	if checked_base_dims != original_dims or checked_prior_dims != dims or not _axes_equal(prior_axes, current_axes):
		return {"ok": false, "error": "226 current axes must match the validated prior output byte for byte."}
	var base_x: PackedFloat32Array = base_axes[0]
	var base_y: PackedFloat32Array = base_axes[1]
	var base_z: PackedFloat32Array = base_axes[2]
	var origin: Vector3 = Vector3(base_x[0], base_y[0], base_z[0])
	var uniform_axes: Array[PackedFloat32Array] = Grid._uniform_axes(original_dims, origin, reference_cell)
	if not _axes_equal(uniform_axes, base_axes):
		return {"ok": false, "error": "226 base axes do not preserve the original native uniform grid and reference cell."}
	if prior_intervals.size() != 3:
		return {"ok": false, "error": "226 prior plan requires exactly three packed split-interval sets."}
	var prior_added: Vector3i = dims - original_dims
	var prior_planes: int = prior_added.x + prior_added.y + prior_added.z
	if prior_added.x < 0 or prior_added.y < 0 or prior_added.z < 0 or prior_added.x > Grid.MAX_NEW_PLANES_PER_AXIS or prior_added.y > Grid.MAX_NEW_PLANES_PER_AXIS or prior_added.z > Grid.MAX_NEW_PLANES_PER_AXIS or prior_planes <= 0 or prior_planes > Grid.HIGH_PREVIEW_MAX_NEW_PLANES or current_samples - base_samples > Grid.HIGH_PREVIEW_MAX_EXTRA_SAMPLES:
		return {"ok": false, "error": "226 prior grid exceeds the unchanged224 plane or sample caps."}
	for axis: int in range(3):
		var interval_value: Variant = prior_intervals[axis]
		if not interval_value is PackedInt32Array:
			return {"ok": false, "error": "226 prior split intervals require PackedInt32Array values."}
		var intervals: PackedInt32Array = interval_value
		if intervals.size() != prior_added[axis]:
			return {"ok": false, "error": "226 prior split counts disagree with current dimensions."}
		var inherited_axis: PackedFloat32Array = base_axes[axis]
		var replay: Dictionary = Grid._split_axis(inherited_axis, intervals)
		if not bool(replay.ok):
			return {"ok": false, "error": "226 prior split replay rejected: " + str(replay.error)}
		var replay_axis: PackedFloat32Array = replay.axis
		var current_axis: PackedFloat32Array = current_axes[axis]
		if replay_axis.to_byte_array() != current_axis.to_byte_array():
			return {"ok": false, "error": "226 prior split replay does not match current axis bytes."}
	for pair: Array in [["base_samples", base_samples], ["refined_samples", current_samples], ["extra_samples", current_samples - base_samples], ["new_planes", prior_planes], ["refinement_passes", 1], ["splits_per_interval", 1], ["detector_field_queries", 0]]:
		var key: String = pair[0]
		var expected: int = pair[1]
		if not _int_is(prior_counts.get(key), expected):
			return {"ok": false, "error": "226 prior pass counter mismatch: " + key}
	var prior_axis_counts_value: Variant = prior_counts.get("new_planes_per_axis")
	if not prior_axis_counts_value is Vector3i or prior_axis_counts_value != prior_added:
		return {"ok": false, "error": "226 prior per-axis counts disagree with the canonical grids."}
	return {"ok": true, "error": "", "base_axes": base_axes, "prior_split_intervals": prior_intervals, "current_dimensions": dims, "base_samples": base_samples, "current_samples": current_samples, "prior_added": prior_added}

static func plan_digest(plan_result: Dictionary, reference_cell: float) -> String:
	# Pin the COMPLETE deterministic result, including original/current/final
	# axes, current owner intervals, prior-plan digest, pass index and counters.
	# No caller's plan digest is accepted as evidence for choosing a split.
	var canonical: Dictionary = {"pin": PIN, "reference_cell": reference_cell, "plan": plan_result}
	return _digest(var_to_bytes(canonical))

static func _empty_plan(original_dims: Vector3i, reference_cell: float) -> Dictionary:
	return {
		"ok": false, "error": "", "mode": MODE, "pin": PIN, "pass_index": 2,
		"reference_cell": reference_cell, "refine": false, "reuse_current_mesh": false,
		"conflict_face_ids": PackedInt32Array(), "malformed_face_ids": PackedInt32Array(),
		"owning_cells": [], "conflict_owners": [],
		"split_intervals": [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()],
		"prior_split_intervals": [], "prior_plan_sha256": "",
		"axes": [], "base_axes": [], "current_axes": [], "interval_widths": [],
		"base_dimensions": original_dims, "current_dimensions": original_dims,
		"dimensions": original_dims, "refined_dimensions": original_dims,
		"counts": {
			"current_vertices": 0, "current_triangles": 0, "scanned_faces": 0,
			"conflict_faces": 0, "owning_cells": 0, "base_samples": 0,
			"current_samples": 0, "refined_samples": 0, "extra_samples": 0,
			"new_planes": 0, "new_planes_per_axis": Vector3i.ZERO,
			"prior_new_planes": 0, "prior_new_planes_per_axis": Vector3i.ZERO,
			"cumulative_new_planes": 0, "cumulative_new_planes_per_axis": Vector3i.ZERO,
			"cumulative_extra_samples": 0, "prior_refinement_passes": 1,
			"additional_refinement_passes": 0, "refinement_passes": 1,
			"refinement_pass_cap": MAX_REFINEMENT_PASSES, "new_pass_cap": MAX_NEW_PASSES,
			"splits_per_interval": Grid.SPLITS_PER_INTERVAL, "detector_field_queries": 0
		}
	}

static func _error(result: Dictionary, message: String) -> Dictionary:
	result.ok = false
	result.refine = false
	result.reuse_current_mesh = false
	result.error = message
	return result

static func _axes_equal(left: Array, right: Array) -> bool:
	if left.size() != 3 or right.size() != 3:
		return false
	for axis: int in range(3):
		var left_value: Variant = left[axis]
		var right_value: Variant = right[axis]
		if not left_value is PackedFloat32Array or not right_value is PackedFloat32Array:
			return false
		var left_axis: PackedFloat32Array = left_value
		var right_axis: PackedFloat32Array = right_value
		if left_axis.to_byte_array() != right_axis.to_byte_array():
			return false
	return true

static func _copy_axes(axes: Array) -> Array[PackedFloat32Array]:
	var copied: Array[PackedFloat32Array] = []
	for axis: int in range(axes.size()):
		var coordinates: PackedFloat32Array = axes[axis]
		copied.append(coordinates.duplicate())
	return copied

static func _copy_intervals(intervals: Array) -> Array[PackedInt32Array]:
	var copied: Array[PackedInt32Array] = []
	for axis: int in range(intervals.size()):
		var axis_intervals: PackedInt32Array = intervals[axis]
		copied.append(axis_intervals.duplicate())
	return copied

static func _int_is(value: Variant, expected: int) -> bool:
	return value is int and value == expected

static func _bool_is(value: Variant, expected: bool) -> bool:
	return value is bool and value == expected

static func _text_is(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _digest(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
