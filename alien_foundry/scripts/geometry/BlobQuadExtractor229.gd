extends "res://alien_foundry/scripts/geometry/BlobRectilinearExtractor210.gd"
## Deliberately versioned229 architecture, not a repair to any legacy artifact.
## The original base/210 extractor remains byte-exact. Only the 2/2 case chooses
## a diagonal; inherited root solving, point lookup and final validation are used.
const Choice229 = preload("res://alien_foundry/scripts/geometry/BlobQuadChoice229.gd")
const Policy229 = preload("res://alien_foundry/scripts/geometry/BlobQuadPolicy229.gd")
const SlabEdge210 = preload("res://alien_foundry/scripts/geometry/BlobSlabEdge210.gd")
var _authorized229: bool = false
var _choices229: PackedByteArray = PackedByteArray()
var _quad_rows229: Array = []
var _single_count229: int = 0

func extract_rectilinear229(values: PackedFloat32Array, axes: Array, minimum: Vector3, reference_step: float, recipe_value: Variant, job: RefCounted = null, refinement: RefCounted = null) -> Dictionary:
	var checked: Dictionary = Policy229.validate_recipe(recipe_value)
	if not checked.ok:
		return {"error": checked.error}
	if axes.size() != 3:
		return {"error": "229 requires the three exact224 canonical axes."}
	for axis in range(3):
		if not axes[axis] is PackedFloat32Array or axes[axis].to_byte_array().hex_encode() != Policy229.SOURCE_AXES_HEX[axis]:
			return {"error": "229 cannot add, move or remove224 planes."}
	var cell_bits: PackedByteArray = PackedByteArray(); cell_bits.resize(8); cell_bits.encode_double(0, reference_step)
	if cell_bits.hex_encode() != Policy229.CELL_BITS or PackedVector3Array([minimum]).to_byte_array().hex_encode() != Policy229.ORIGIN_BITS:
		return {"error": "229 cannot change the original field/normal reference cell or origin."}
	if refinement == null or refinement.get_script() != SlabEdge210:
		return {"error": "229 requires the unchanged bounded cumulative210/208v2 solver."}
	_authorized229 = true
	var result: Dictionary = extract_rectilinear(values, axes, minimum, reference_step, job, refinement, true)
	_authorized229 = false
	return result

func extract_rectilinear(values: PackedFloat32Array, axes: Array, minimum: Vector3, reference_step: float, job: RefCounted = null, refinement: RefCounted = null, high_preview: bool = false) -> Dictionary:
	if not _authorized229:
		return {"error": "229 legacy rectilinear entry point cannot enable the new policy."}
	var validated: Dictionary = Grid210.validate_axes(axes, high_preview)
	if not bool(validated.ok):
		return {"error": str(validated.error)}
	var dims: Vector3i = validated.dimensions
	if values.size() != int(validated.samples):
		return {"error": "210 rectilinear sample count does not match its canonical axes."}
	if not minimum.is_finite() or not is_finite(reference_step) or reference_step <= 0.0:
		return {"error": "210 requires the original finite minimum and positive normal-reference step."}
	var x_axis: PackedFloat32Array = axes[0]
	var y_axis: PackedFloat32Array = axes[1]
	var z_axis: PackedFloat32Array = axes[2]
	if minimum != Vector3(x_axis[0], y_axis[0], z_axis[0]):
		return {"error": "210 canonical axis origins do not match the original grid minimum."}
	for value: float in values:
		if not is_finite(value):
			return {"error": "210 rectilinear extraction rejects nonfinite field samples."}
	# Never allow the inherited uniform-gradient / normal-reconciliation path.
	if refinement == null or not refinement.has_method("solve") or not refinement.has_method("reject") or not refinement.has_method("snapshot"):
		return {"error": "210 rectilinear extraction requires an explicit complete-field edge/normal solver."}
	var snapshot_value: Variant = refinement.call("snapshot")
	if not snapshot_value is Dictionary:
		return {"error": "210 refinement solver snapshot is malformed."}
	var snapshot: Dictionary = snapshot_value
	if snapshot.get("error", "") != "" or int(snapshot.get("unique_edges", -1)) != 0 or int(snapshot.get("continuous_queries", -1)) != 0 or int(snapshot.get("endpoint_cache_entries", -1)) != 0:
		return {"error": "210 requires a fresh error-free per-pass solver and endpoint cache."}
	canonical_axes = [x_axis.duplicate(), y_axis.duplicate(), z_axis.duplicate()]
	# _point is dynamically dispatched by the inherited traversal and _edge.
	# reference_step remains the ORIGINAL step, not an inserted interval width.
	return extract(values, dims, minimum, reference_step, job, refinement)


func extract(values: PackedFloat32Array, dims: Vector3i, minimum: Vector3, cell_size: float, job: RefCounted = null, refinement: RefCounted = null) -> Dictionary:
	if not _authorized229 or refinement == null:
		return {"error": "229 requires the explicit versioned rectilinear entry point and solver."}
	_choices229.clear(); _quad_rows229.clear()
	_single_count229 = 0
	edge_refinement = refinement
	field = values
	dimensions = dims
	origin = minimum
	spacing = cell_size
	controls = job
	sample_count = values.size()
	plane = dims.x * dims.y
	vertices.clear()
	normals.clear()
	indices.clear()
	edge_vertices.clear()
	var offsets := PackedInt32Array([0, 1, dims.x + 1, dims.x, plane, plane + 1, plane + dims.x + 1, plane + dims.x])
	var active_cells := 0
	for z in range(dims.z - 1):
		if edge_refinement!=null and not edge_refinement.error.is_empty(): return {"error":edge_refinement.error,"edge_refinement204":edge_refinement.snapshot()}
		if job != null:
			if job.is_cancelled():
				return {"cancelled": true}
			job.set_progress(0.48 + 0.35 * float(z) / float(maxi(dims.z - 1, 1)), "Extracting continuous tissue")
		for y in range(dims.y - 1):
			var row: int = z * plane + y * dims.x
			for x in range(dims.x - 1):
				var base: int = row + x
				var mask: int = 0
				for c in range(8):
					if field[base + offsets[c]] < 0.0:
						mask |= 1 << c
				if mask == 0 or mask == 255:
					continue
				active_cells += 1
				for tet in TETRAHEDRA:
					var inside := PackedInt32Array()
					var outside := PackedInt32Array()
					for corner in tet:
						var grid_index: int = base + offsets[corner]
						if field[grid_index] < 0.0:
							inside.append(grid_index)
						else:
							outside.append(grid_index)
					if inside.is_empty() or outside.is_empty():
						continue
					var outward := Vector3.ZERO
					for id in outside:
						outward += _point(id) / float(outside.size())
					for id in inside:
						outward -= _point(id) / float(inside.size())
					var next_indices229: int = 6 if inside.size() == 2 else 3
					if indices.size() + next_indices229 > Policy229.TRIANGLE_CAP * 3:
						edge_refinement.reject("229 triangle cap exceeded before atomic emission.")
						return {"error": edge_refinement.error, "edge_refinement204": edge_refinement.snapshot(), "quad_policy229": _report229(), "raw_snapshot_complete": false}
					match inside.size():
						1:
							_single_count229 += 1
							_emit(_edge(inside[0], outside[0]), _edge(inside[0], outside[1]), _edge(inside[0], outside[2]), outward)
						3:
							_single_count229 += 1
							_emit(_edge(outside[0], inside[0]), _edge(outside[0], inside[1]), _edge(outside[0], inside[2]), outward)
						2:
							var a := _edge(inside[0], outside[0])
							var b := _edge(inside[0], outside[1])
							var c := _edge(inside[1], outside[0])
							var d := _edge(inside[1], outside[1])
							if not _emit_quad229(a, b, c, d, outward, Vector3i(x, y, z), TETRAHEDRA.find(tet)):
								return {"error": edge_refinement.error, "edge_refinement204": edge_refinement.snapshot(), "quad_policy229": _report229(), "raw_snapshot_complete": false}
	if edge_refinement==null:
		_reconcile_normals()
	else:
		# An edge failure during the final z slice is still a partial extraction.
		if not edge_refinement.error.is_empty(): return {"error":edge_refinement.error,"edge_refinement204":edge_refinement.snapshot()}
		_validate_refined_normals()
		if not edge_refinement.error.is_empty(): return _with_report229(_completed_refined_rejection(active_cells))
	var result := {"vertices": vertices, "normals": normals, "indices": indices, "active_cells": active_cells}
	if edge_refinement!=null: result["edge_refinement204"]=edge_refinement.snapshot()
	# The final packed arrays are the only persistent result; free lattice caches.
	edge_vertices.clear()
	field = PackedFloat32Array()
	return _with_report229(result)

func _emit_quad229(a: int, b: int, c: int, d: int, outward: Vector3, cell: Vector3i, tetrahedron: int) -> bool:
	var selected: Dictionary = Choice229.choose(vertices, normals, a, b, c, d, outward)
	if not selected.ok:
		edge_refinement.reject("229 no eligible complete quad; " + str(selected.error))
		return false
	# Selection is atomic. Never emit half a pair or change its roots/normals.
	var emitted: PackedInt32Array = selected.indices
	indices.append_array(emitted)
	_choices229.append(1 if selected.choice == "alternate" else 0)
	_quad_rows229.append({"cell": [cell.x, cell.y, cell.z], "tetrahedron": tetrahedron, "roots_abcd": [a, b, c, d], "choice": selected.choice, "legacy_valid": selected.legacy_valid, "alternate_valid": selected.alternate_valid, "legacy_score64": selected.legacy_score, "alternate_score64": selected.alternate_score})
	return true

func _report229() -> Dictionary:
	var alternate: int = 0
	for value: int in _choices229:
		alternate += value
	return {"mode": Policy229.MODE, "pin": Policy229.PIN, "quads": _choices229.size(), "single_triangle_tets": _single_count229, "alternate_quads": alternate, "legacy_quads": _choices229.size() - alternate, "choice_bytes_hex": _choices229.hex_encode(), "quad_records": _quad_rows229.duplicate(true), "field_changed": false, "root_positions_changed": false, "normals_changed": false, "triangulation_architecture_changed": true, "legacy_rejections_preserved": true, "artistic_acceptance": false}

func _with_report229(result: Dictionary) -> Dictionary:
	result["quad_policy229"] = _report229()
	return result
