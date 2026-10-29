class_name OrganicMeshExtractor
extends RefCounted
## Indexed marching tetrahedra. Every lattice edge (including face diagonals)
## owns exactly one vertex. A consistent cube decomposition avoids ambiguous
## marching-cubes cases and cracks at tile boundaries. No scene-tree calls.
const TETRAHEDRA: Array = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var indices := PackedInt32Array()
var edge_vertices: Dictionary = {}
var field := PackedFloat32Array()
var dimensions := Vector3i.ZERO
var origin := Vector3.ZERO
var spacing: float = 0.1
var sample_count: int = 0
var plane: int = 0
var controls: RefCounted
var edge_refinement: RefCounted=null

func extract(values: PackedFloat32Array, dims: Vector3i, minimum: Vector3, cell_size: float, job: RefCounted = null, refinement: RefCounted = null) -> Dictionary:
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
					match inside.size():
						1:
							_emit(_edge(inside[0], outside[0]), _edge(inside[0], outside[1]), _edge(inside[0], outside[2]), outward)
						3:
							_emit(_edge(outside[0], inside[0]), _edge(outside[0], inside[1]), _edge(outside[0], inside[2]), outward)
						2:
							var a := _edge(inside[0], outside[0])
							var b := _edge(inside[0], outside[1])
							var c := _edge(inside[1], outside[0])
							var d := _edge(inside[1], outside[1])
							_emit(a, b, d, outward)
							_emit(a, d, c, outward)
	if edge_refinement==null:
		_reconcile_normals()
	else:
		# An edge failure during the final z slice is still a partial extraction.
		if not edge_refinement.error.is_empty(): return {"error":edge_refinement.error,"edge_refinement204":edge_refinement.snapshot()}
		_validate_refined_normals()
		if not edge_refinement.error.is_empty(): return _completed_refined_rejection(active_cells)
	var result := {"vertices": vertices, "normals": normals, "indices": indices, "active_cells": active_cells}
	if edge_refinement!=null: result["edge_refinement204"]=edge_refinement.snapshot()
	# The final packed arrays are the only persistent result; free lattice caches.
	edge_vertices.clear()
	field = PackedFloat32Array()
	return result

func _point(index: int) -> Vector3:
	@warning_ignore("integer_division")
	var z: int = index / plane
	var remain: int = index - z * plane
	@warning_ignore("integer_division")
	var y: int = remain / dimensions.x
	var x: int = remain - y * dimensions.x
	return origin + Vector3(x, y, z) * spacing

func _gradient(index: int) -> Vector3:
	@warning_ignore("integer_division")
	var z: int = index / plane
	var remain: int = index - z * plane
	@warning_ignore("integer_division")
	var y: int = remain / dimensions.x
	var x: int = remain - y * dimensions.x
	var dx := field[index + (1 if x + 1 < dimensions.x else 0)] - field[index - (1 if x > 0 else 0)]
	var dy := field[index + (dimensions.x if y + 1 < dimensions.y else 0)] - field[index - (dimensions.x if y > 0 else 0)]
	var dz := field[index + (plane if z + 1 < dimensions.z else 0)] - field[index - (plane if z > 0 else 0)]
	return Vector3(dx, dy, dz)

func _edge(first: int, second: int) -> int:
	var low := mini(first, second)
	var high := maxi(first, second)
	var key: int = low * sample_count + high
	if edge_vertices.has(key):
		return int(edge_vertices[key])
	var value_a := float(field[low])
	var value_b := float(field[high])
	if edge_refinement!=null:
		var refined: Dictionary=edge_refinement.solve(low,high,_point(low),_point(high),value_a,value_b)
		if refined.has("error"): return -1
		var refined_id:=vertices.size()
		vertices.append(refined.point);normals.append(refined.normal);edge_vertices[key]=refined_id
		return refined_id
	var t := clampf(value_a / (value_a - value_b), 0.0001, 0.9999)
	var vertex := _point(low).lerp(_point(high), t)
	var normal := _gradient(low).lerp(_gradient(high), t).normalized()
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	var id := vertices.size()
	vertices.append(vertex)
	normals.append(normal)
	edge_vertices[key] = id
	return id

func _emit(a: int, b: int, c: int, outward: Vector3) -> void:
	if edge_refinement!=null and (a<0 or b<0 or c<0): return
	if a == b or b == c or c == a:
		return
	var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	if cross.length_squared() == 0.0:
		if edge_refinement!=null: edge_refinement.reject("204 refined face degenerated; no topology repair.")
		return
	# Winding follows the tetrahedron's INSIDE/OUTSIDE classification, never
	# the smoothed gradient (which may reverse on a sub-voxel cavity). Godot
	# front faces are clockwise and geometric normals still point outward.
	if cross.dot(outward) > 0.0:
		indices.append(a)
		indices.append(c)
		indices.append(b)
	else:
		indices.append(a)
		indices.append(b)
		indices.append(c)

func _reconcile_normals() -> void:
	var geometric := PackedVector3Array()
	geometric.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var outward := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		geometric[a] += outward
		geometric[b] += outward
		geometric[c] += outward
	for i in range(normals.size()):
		var surface_normal := geometric[i].normalized()
		if surface_normal.length_squared() < 0.01:
			continue
		if surface_normal.dot(normals[i]) < 0.55:
			normals[i] = surface_normal
		else:
			# Retain smooth analytic field shading, lightly regularized by the
			# actual extracted curvature; this does not move or erase anatomy.
			normals[i] = surface_normal.lerp(normals[i], 0.72).normalized()

	# A tiny re-entrant cavity can have a sliver whose area is overwhelmed by
	# neighboring faces in the averaged normal. Project only those inconsistent
	# vertex normals into the actual face hemisphere; never reverse topology.
	for _pass in range(10):
		var corrected := 0
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var outward := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
			var alignment := (normals[a] + normals[b] + normals[c]).dot(outward) / 3.0
			if alignment < 0.025:
				var correction := outward * (0.035 - alignment) * 1.25
				normals[a] = (normals[a] + correction).normalized()
				normals[b] = (normals[b] + correction).normalized()
				normals[c] = (normals[c] + correction).normalized()
				corrected += 1
		if corrected == 0:
			break

func _validate_refined_normals() -> void:
	for i in range(0,indices.size(),3):
		var a:=indices[i];var b:=indices[i+1];var c:=indices[i+2]
		var outward:=-(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		if not outward.is_finite() or outward.length_squared()==0.0 or (normals[a]+normals[b]+normals[c]).dot(outward)<=0.0:
			edge_refinement.reject("204 refined face/field-normal inconsistency; no normal or topology repair.")
			return

func _completed_refined_rejection(active_cells: int) -> Dictionary:
	# Diagnostic packet only. The error remains authoritative for every caller;
	# these arrays are never repaired, attributed or accepted as a built mesh.
	var result: Dictionary={"error":edge_refinement.error,"edge_refinement204":edge_refinement.snapshot(),"rejected":true,"raw_snapshot_complete":false}
	if vertices.is_empty() or normals.size()!=vertices.size() or indices.is_empty() or indices.size()%3!=0: return result
	for point: Vector3 in vertices:
		if not point.is_finite(): return result
	for normal: Vector3 in normals:
		if not normal.is_finite(): return result
	for index: int in indices:
		if index<0 or index>=vertices.size(): return result
	result.merge({"vertices":vertices,"normals":normals,"indices":indices,"active_cells":active_cells,"raw_snapshot_complete":true,"raw_snapshot_status":"completed_finite_index_safe_rejected_before_attribution","finite_index_safe":true},true)
	return result
