class_name OrganicFieldConnectivity
extends RefCounted
## Repair undersampled biological necks in the volume, never by deleting shells.
## A six-neighbour path of negative lattice samples guarantees an interior path
## in the consistent tetrahedral extraction. Each repair is a short swept SDF
## collar to the nearest main-body sample and retains its source anatomy id.
const SDF = preload("res://alien_foundry/scripts/geometry/SDFOperations.gd")

static func repair(values: PackedFloat32Array, dims: Vector3i, origin: Vector3, step: float, job: RefCounted = null) -> Dictionary:
	var labels := PackedInt32Array()
	labels.resize(values.size())
	labels.fill(-1)
	var components: Array = []
	var plane := dims.x * dims.y
	var offsets := PackedInt32Array([1, -1, dims.x, -dims.x, plane, -plane])
	var largest := -1
	var largest_size := 0
	for start in range(values.size()):
		if values[start] >= 0.0 or labels[start] >= 0:
			continue
		if job != null and job.is_cancelled():
			return {"cancelled": true}
		var cid := components.size()
		var queue := PackedInt32Array([start])
		labels[start] = cid
		var cursor := 0
		while cursor < queue.size():
			var index := queue[cursor]
			cursor += 1
			var coordinate := _coordinate(index, dims.x, plane)
			for direction in range(6):
				if not _in_bounds(coordinate, direction, dims):
					continue
				var adjacent := index + offsets[direction]
				if values[adjacent] < 0.0 and labels[adjacent] < 0:
					labels[adjacent] = cid
					queue.append(adjacent)
		components.append(queue)
		if queue.size() > largest_size:
			largest = cid
			largest_size = queue.size()
	var collars: Array = []
	if components.size() <= 1:
		return {"field": values, "collars": collars, "original_components": components.size()}
	if components.size() > 33:
		return {"error": "More than 32 disconnected tissue islands exceed the bounded field-repair budget."}
	if job != null:
		job.set_progress(0.475, "Reinforcing sub-voxel tissue connections")
	for cid in range(components.size()):
		if cid == largest:
			continue
		if job != null and job.is_cancelled():
			return {"cancelled": true}
		var queue: PackedInt32Array = components[cid].duplicate()
		var origins: Dictionary = {}
		for id in queue:
			origins[id] = id
		var cursor := 0
		var start_index := -1
		var end_index := -1
		# Multi-source breadth-first search finds a nearby main-body boundary,
		# not an arbitrary line to the creature's centre through empty space.
		while cursor < queue.size() and cursor < 24000 and end_index < 0:
			var index := queue[cursor]
			cursor += 1
			var coordinate := _coordinate(index, dims.x, plane)
			for direction in range(6):
				if not _in_bounds(coordinate, direction, dims):
					continue
				var adjacent := index + offsets[direction]
				if labels[adjacent] == largest:
					start_index = int(origins[index])
					end_index = adjacent
					break
				if not origins.has(adjacent):
					origins[adjacent] = origins[index]
					queue.append(adjacent)
		if end_index < 0:
			return {"error": "A disconnected anatomical region is too far from its carrier for a safe local tissue repair."}
		var a := origin + Vector3(_coordinate(start_index, dims.x, plane)) * step
		var b := origin + Vector3(_coordinate(end_index, dims.x, plane)) * step
		var radius := step * 1.08
		var blend := step * 0.35
		var low := Vector3i(((a.min(b) - Vector3.ONE * (radius + blend) - origin) / step).floor()).max(Vector3i.ONE)
		var high := Vector3i(((a.max(b) + Vector3.ONE * (radius + blend) - origin) / step).ceil()).min(dims - Vector3i.ONE * 2)
		for z in range(low.z, high.z + 1):
			for y in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var index := x + y * dims.x + z * plane
					var point := origin + Vector3(x, y, z) * step
					var collar_distance := SDF.tapered_capsule(point, a, b, radius, radius)
					values[index] = SDF.smooth_union(values[index], collar_distance, blend)
		collars.append({"start": a, "end": b, "radius": radius, "blend": blend, "island_samples": components[cid].size()})
	return {"field": values, "collars": collars, "original_components": components.size()}

static func _coordinate(index: int, width: int, plane: int) -> Vector3i:
	@warning_ignore("integer_division")
	var z: int = index / plane
	var remainder := index - z * plane
	@warning_ignore("integer_division")
	var y: int = remainder / width
	return Vector3i(remainder - y * width, y, z)

static func _in_bounds(p: Vector3i, direction: int, dims: Vector3i) -> bool:
	match direction:
		0: return p.x + 1 < dims.x
		1: return p.x > 0
		2: return p.y + 1 < dims.y
		3: return p.y > 0
		4: return p.z + 1 < dims.z
		_: return p.z > 0
