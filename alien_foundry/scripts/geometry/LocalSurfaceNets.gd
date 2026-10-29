extends RefCounted
## Bounded local surface nets. One vertex per active cube avoids the redundant
## face-diagonal triangles of the primary marching-tetrahedra extractor. This
## is a separate opt-in polygonizer; the primary body extractor is untouched.
## Ambiguous-cell topology is not repaired: the caller must validate/reject it.
const CORNERS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const EDGES := [Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(3,0),Vector2i(4,5),Vector2i(5,6),Vector2i(6,7),Vector2i(7,4),Vector2i(0,4),Vector2i(1,5),Vector2i(2,6),Vector2i(3,7)]

static func extract(field: PackedFloat32Array, dims: Vector3i, origin: Vector3, step: float, job: RefCounted = null) -> Dictionary:
	var cells := dims - Vector3i.ONE
	var plane := dims.x * dims.y
	var cell_plane := cells.x * cells.y
	var ids := PackedInt32Array(); ids.resize(cells.x * cells.y * cells.z); ids.fill(-1)
	var vertices := PackedVector3Array(); var indices := PackedInt32Array()
	var ambiguous_cells := 0; var ambiguous_examples: Array = []
	var offsets := PackedInt32Array()
	for corner: Vector3i in CORNERS: offsets.append(corner.x + corner.y * dims.x + corner.z * plane)
	for z in range(cells.z):
		if job != null and job.is_cancelled(): return {"cancelled": true}
		for y in range(cells.y):
			for x in range(cells.x):
				var first := x + y * dims.x + z * plane
				var mask := 0
				for i in range(8):
					if field[first + offsets[i]] < 0.0: mask |= 1 << i
				if mask == 0 or mask == 255: continue
				if _ambiguous(mask):
					ambiguous_cells += 1
					if ambiguous_examples.size() < 8: ambiguous_examples.append({"cell": [x,y,z], "mask": mask})
					continue
				var center := Vector3.ZERO; var crossings := 0
				for edge: Vector2i in EDGES:
					var a := float(field[first + offsets[edge.x]]); var b := float(field[first + offsets[edge.y]])
					if (a < 0.0) == (b < 0.0): continue
					var t := clampf(a / (a - b), 0.00001, 0.99999)
					center += Vector3(CORNERS[edge.x]).lerp(Vector3(CORNERS[edge.y]), t)
					crossings += 1
				ids[x + y * cells.x + z * cell_plane] = vertices.size()
				vertices.append(origin + (Vector3(x,y,z) + center / float(crossings)) * step)
	if ambiguous_cells > 0:
		return {"rejected": true, "reason": "ambiguous_local_cells", "ambiguous_cells": ambiguous_cells, "ambiguous_examples": ambiguous_examples}
	var unresolved := 0
	# Each sign-changing primal edge owns one dual quad, emitted once.
	# The descriptor's positive boundary collar is required for closed output.
	for z in range(1, dims.z - 1):
		if job != null and job.is_cancelled(): return {"cancelled": true}
		for y in range(1, dims.y - 1):
			for x in range(1, dims.x - 1):
				var first := x + y * dims.x + z * plane
				var a := float(field[first])
				var ci := x + y * cells.x + z * cell_plane
				for axis in range(3):
					var delta: int = [1, dims.x, plane][axis]
					var b := float(field[first + delta])
					if (a < 0.0) == (b < 0.0): continue
					var quad := PackedInt32Array()
					if axis == 0: quad = PackedInt32Array([ids[ci - cells.x - cell_plane], ids[ci - cell_plane], ids[ci], ids[ci - cells.x]])
					elif axis == 1: quad = PackedInt32Array([ids[ci - 1 - cell_plane], ids[ci - 1], ids[ci], ids[ci - cell_plane]])
					else: quad = PackedInt32Array([ids[ci - 1 - cells.x], ids[ci - cells.x], ids[ci], ids[ci - 1]])
					if quad.has(-1): unresolved += 1; continue
					var outward := Vector3.ZERO; outward[axis] = 1.0 if b > a else -1.0
					_quad(vertices, indices, quad, outward)
	var normals := PackedVector3Array(); normals.resize(vertices.size()); normals.fill(Vector3.ZERO)
	for i in range(0, indices.size(), 3):
		var a := indices[i]; var b := indices[i + 1]; var c := indices[i + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += normal; normals[b] += normal; normals[c] += normal
	for i in range(normals.size()): normals[i] = normals[i].normalized()
	return {"vertices": vertices, "normals": normals, "indices": indices, "active_cells": vertices.size(), "unresolved_dual_edges": unresolved, "ambiguous_cells": 0}

static func _quad(vertices: PackedVector3Array, indices: PackedInt32Array, q: PackedInt32Array, outward: Vector3) -> void:
	var a := q[0]; var b := q[1]; var c := q[2]; var d := q[3]
	if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(outward) > 0.0:
		var swap := b; b = d; d = swap
	# Choose the shorter diagonal once; no decimation or missing faces.
	if vertices[a].distance_squared_to(vertices[c]) <= vertices[b].distance_squared_to(vertices[d]):
		indices.append_array(PackedInt32Array([a,b,c,a,c,d]))
	else:
		indices.append_array(PackedInt32Array([a,b,d,b,c,d]))

static func _ambiguous(mask: int) -> bool:
	# A dual vertex may only join one connected inside and one connected
	# outside corner set. This catches checkerboard faces and interior split
	# masks instead of silently joining distinct surface sheets in one cell.
	for side in [0, 1]:
		var remaining := 0
		for corner in range(8):
			if ((mask >> corner) & 1) == side: remaining |= 1 << corner
		var groups := 0
		while remaining != 0:
			groups += 1
			if groups > 1: return true
			var seed_corner := 0
			while (remaining & (1 << seed_corner)) == 0: seed_corner += 1
			var queue := PackedInt32Array([seed_corner]); remaining &= ~(1 << seed_corner)
			var cursor := 0
			while cursor < queue.size():
				var current := queue[cursor]; cursor += 1
				for edge: Vector2i in EDGES:
					var adjacent := edge.y if edge.x == current else (edge.x if edge.y == current else -1)
					if adjacent >= 0 and (remaining & (1 << adjacent)) != 0:
						remaining &= ~(1 << adjacent); queue.append(adjacent)
	return false
