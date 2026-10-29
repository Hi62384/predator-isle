extends RefCounted
## Deterministic marching tetrahedra on a sparse, uniform Cartesian lattice.
## Negative values are inside; zero is outside. The caller supplies finite
## samples, a positive finite step, and unique cells in a stable order.
## Missing corners skip their entire cell; missing_samples counts distinct
## absent lattice coordinates. The caller must reject incomplete/open output.
## No positional welding, interpolation clamps, repair, or vertex movement.

const CORNERS: Array = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0),
	Vector3i(1, 1, 0), Vector3i(0, 1, 0),
	Vector3i(0, 0, 1), Vector3i(1, 0, 1),
	Vector3i(1, 1, 1), Vector3i(0, 1, 1),
]
# Identical face diagonals in neighboring cells, including sparse boundaries.
const TETRAHEDRA: Array = [
	[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6],
	[0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6],
]

static func extract(values: Dictionary, cells: Array, origin: Vector3, step: float, controls: RefCounted = null) -> Dictionary:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var edge_vertices: Dictionary = {}
	var missing: Dictionary = {}
	var active_cells: int = 0
	var zero_area_skipped: int = 0
	var corners: Array[Vector3i] = []
	corners.resize(8)
	for cell_index in range(cells.size()):
		if cell_index % 128 == 0 and controls != null and controls.is_cancelled():
			return {"cancelled": true}
		var cell: Vector3i = cells[cell_index]
		var mask: int = 0
		var complete: bool = true
		for corner_index in range(8):
			var corner: Vector3i = cell + Vector3i(CORNERS[corner_index])
			corners[corner_index] = corner
			if not values.has(corner):
				missing[corner] = true
				complete = false
			elif float(values[corner]) < 0.0:
				mask |= 1 << corner_index
		if not complete or mask == 0 or mask == 255:
			continue
		active_cells += 1
		for tetrahedron: Array in TETRAHEDRA:
			var inside := PackedInt32Array()
			var outside := PackedInt32Array()
			for corner_index: int in tetrahedron:
				if (mask & (1 << corner_index)) != 0:
					inside.append(corner_index)
				else:
					outside.append(corner_index)
			if inside.is_empty() or outside.is_empty():
				continue
			# Local coordinates avoid subtracting large world-space origins.
			var outward := Vector3.ZERO
			for corner_index: int in outside:
				outward += Vector3(CORNERS[corner_index]) / float(outside.size())
			for corner_index: int in inside:
				outward -= Vector3(CORNERS[corner_index]) / float(inside.size())
			if inside.size() == 1 or outside.size() == 1:
				var single: int = inside[0] if inside.size() == 1 else outside[0]
				var other: PackedInt32Array = outside if inside.size() == 1 else inside
				var a: int = _edge(corners[single], corners[other[0]], values, origin, step, vertices, edge_vertices)
				var b: int = _edge(corners[single], corners[other[1]], values, origin, step, vertices, edge_vertices)
				var c: int = _edge(corners[single], corners[other[2]], values, origin, step, vertices, edge_vertices)
				if not _emit(a, b, c, outward, vertices, indices):
					zero_area_skipped += 1
			else:
				var a: int = _edge(corners[inside[0]], corners[outside[0]], values, origin, step, vertices, edge_vertices)
				var b: int = _edge(corners[inside[0]], corners[outside[1]], values, origin, step, vertices, edge_vertices)
				var c: int = _edge(corners[inside[1]], corners[outside[0]], values, origin, step, vertices, edge_vertices)
				var d: int = _edge(corners[inside[1]], corners[outside[1]], values, origin, step, vertices, edge_vertices)
				if not _emit(a, b, d, outward, vertices, indices):
					zero_area_skipped += 1
				if not _emit(a, d, c, outward, vertices, indices):
					zero_area_skipped += 1
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.ZERO)
	for triangle_index in range(0, indices.size(), 3):
		if triangle_index % 12288 == 0 and controls != null and controls.is_cancelled():
			return {"cancelled": true}
		var a: int = indices[triangle_index]
		var b: int = indices[triangle_index + 1]
		var c: int = indices[triangle_index + 2]
		# Godot front faces are clockwise: reverse the usual cross product.
		var face_normal: Vector3 = (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += face_normal
		normals[b] += face_normal
		normals[c] += face_normal
	for vertex_index in range(normals.size()):
		if vertex_index % 4096 == 0 and controls != null and controls.is_cancelled():
			return {"cancelled": true}
		normals[vertex_index] = normals[vertex_index].normalized()
	return {
		"vertices": vertices, "normals": normals, "indices": indices,
		"active_cells": active_cells, "zero_area_skipped": zero_area_skipped,
		"missing_samples": missing.size(),
	}

static func _edge(first: Vector3i, second: Vector3i, values: Dictionary, origin: Vector3, step: float, vertices: PackedVector3Array, edge_vertices: Dictionary) -> int:
	var low: Vector3i = first
	var high: Vector3i = second
	if _before(high, low):
		low = second
		high = first
	# Exact signed integer endpoints, not quantized/rounded world positions.
	var key: String = "%d,%d,%d|%d,%d,%d" % [low.x, low.y, low.z, high.x, high.y, high.z]
	if edge_vertices.has(key):
		return int(edge_vertices[key])
	var value_a: float = float(values[low])
	var value_b: float = float(values[high])
	# Opposite classifications guarantee a nonzero denominator. Exact-zero
	# endpoints remain exact: distinct edges are never welded or perturbed.
	var fraction: float = value_a / (value_a - value_b)
	var point: Vector3 = Vector3(low).lerp(Vector3(high), fraction)
	var vertex_index: int = vertices.size()
	vertices.append(origin + point * step)
	edge_vertices[key] = vertex_index
	return vertex_index

static func _before(first: Vector3i, second: Vector3i) -> bool:
	if first.x != second.x:
		return first.x < second.x
	if first.y != second.y:
		return first.y < second.y
	return first.z < second.z

static func _emit(a: int, b: int, c: int, outward: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array) -> bool:
	if a == b or b == c or c == a:
		return false
	var cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	if cross == Vector3.ZERO:
		return false
	indices.append(a)
	if cross.dot(outward) > 0.0:
		indices.append(c)
		indices.append(b)
	else:
		indices.append(b)
		indices.append(c)
	return true
