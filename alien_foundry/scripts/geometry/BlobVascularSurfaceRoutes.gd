extends RefCounted
## Bounded retained-triangle adjacency routing. No extraction or host writes.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Support = preload("res://alien_foundry/scripts/geometry/BlobMembraneSurface.gd")
const Closest = preload("res://alien_foundry/scripts/geometry/BlobPorousCartilageSurface.gd")

static func prepare(dna: Dictionary, body: Dictionary, radius: float) -> Dictionary:
	var kinds := {}; var cavities: Array = []
	for feature: Dictionary in dna.biological_blueprint.features: kinds[str(feature.id)] = str(feature.type)
	for node: Dictionary in dna.nodes:
		if str(node.kind) == "cavity":
			var expansion := 1.0 + absf(float(node.get("deformation", {}).get("warp", 0.0)))
			cavities.append({"center": Graph.vec(node.position), "inverse": Basis.from_euler(Graph.vec(node.rotation)).inverse(),
				"radii": Graph.vec(node.size) * expansion + Vector3.ONE * (radius + float(node.get("blend", 0.0)))})
	var weights := {}; var allowed := PackedFloat32Array(); var cavity := PackedFloat32Array()
	allowed.resize(body.vertices.size()); cavity.resize(body.vertices.size())
	for fid: String in body.feature_ids:
		if kinds.get(fid, "") in ["body", "sac"]:
			var values := PackedFloat32Array(); values.resize(body.vertices.size()); weights[fid] = values
	for vi in range(body.vertices.size()):
		for slot in range(4):
			var fi := int(body.feature_indices[vi * 4 + slot])
			if fi < 0: continue
			var fid := str(body.feature_ids[fi]); var w := float(body.feature_weights[vi * 4 + slot])
			if weights.has(fid): weights[fid][vi] += w; allowed[vi] += w
			if kinds.get(fid, "") == "cavity": cavity[vi] += w
	var triangles: Array = []; var adjacency: Array = []; var vertex_faces: Array = []; var edges := {}; var rejected := {}
	vertex_faces.resize(body.vertices.size())
	for vi in range(vertex_faces.size()): vertex_faces[vi] = []
	for offset in range(0, body.indices.size(), 3):
		var ti := offset / 3
		var ids := Vector3i(body.indices[offset], body.indices[offset + 1], body.indices[offset + 2])
		var a: Vector3 = body.vertices[ids.x]; var b: Vector3 = body.vertices[ids.y]; var c: Vector3 = body.vertices[ids.z]
		var normal := (c - a).cross(b - a).normalized(); var center := (a + b + c) / 3.0
		var reason := ""
		for vi: int in [ids.x, ids.y, ids.z]:
			vertex_faces[vi].append(ti)
			if allowed[vi] < 0.70: reason = "non_body_sac_carrier"
			if cavity[vi] > 0.05: reason = "cavity_feature_wall_or_rim"
			if _in_cavity(body.vertices[vi], cavities): reason = "expanded_cavity_keepout"
		if _triangle_meets_cavity(a, b, c, cavities): reason = "expanded_cavity_keepout"
		triangles.append({"indices": ids, "point": center, "normal": normal, "valid": reason.is_empty()})
		adjacency.append([])
		if not reason.is_empty(): rejected[reason] = int(rejected.get(reason, 0)) + 1
		for side in range(3):
			var va := int(ids[side]); var vb := int(ids[(side + 1) % 3]); var edge := Vector2i(mini(va, vb), maxi(va, vb))
			if edges.has(edge):
				var other := int(edges[edge]); adjacency[ti].append(other); adjacency[other].append(ti)
			else: edges[edge] = ti
	return {"triangles": triangles, "adjacency": adjacency, "vertex_faces": vertex_faces, "weights": weights,
		"cavities": cavities, "neighborhood_cache": {}, "rejected_triangles": rejected, "route_source": "actual_retained_shared_edges"}

static func _in_cavity(point: Vector3, cavities: Array) -> bool:
	for cavity: Dictionary in cavities:
		var local: Vector3 = cavity.inverse * (point - Vector3(cavity.center))
		var q := local / Vector3(cavity.radii)
		if q.length_squared() <= 1.0: return true
	return false

static func _triangle_meets_cavity(a: Vector3, b: Vector3, c: Vector3, cavities: Array) -> bool:
	# A whole retained face must miss the fixed expanded ellipsoid, not just its corners.
	for cavity: Dictionary in cavities:
		var qa: Vector3 = (cavity.inverse * (a - Vector3(cavity.center))) / Vector3(cavity.radii)
		var qb: Vector3 = (cavity.inverse * (b - Vector3(cavity.center))) / Vector3(cavity.radii)
		var qc: Vector3 = (cavity.inverse * (c - Vector3(cavity.center))) / Vector3(cavity.radii)
		var closest := Closest._triangle_point(Vector3.ZERO, qa, qb, qc)
		if Vector3(closest.point).length_squared() <= 1.0: return true
	return false

static func feature_weight(surface: Dictionary, hit: Dictionary, feature_id: String) -> float:
	var weights: PackedFloat32Array = surface.weights.get(feature_id, PackedFloat32Array())
	if weights.is_empty(): return 0.0
	var result := 0.0
	for corner in range(3): result += weights[int(hit.indices[corner])] * float(hit.barycentric[corner])
	return result

static func endpoint(body: Dictionary, surface: Dictionary, probe: Vector3, feature_id: String, minimum_weight: float, direction: Vector3 = Vector3.ZERO) -> Dictionary:
	var weights: PackedFloat32Array = surface.weights.get(feature_id, PackedFloat32Array())
	if weights.is_empty(): return {}
	var best := INF; var chosen := {}
	for ti in range(surface.triangles.size()):
		var triangle: Dictionary = surface.triangles[ti]
		if not bool(triangle.valid): continue
		var ids: Vector3i = triangle.indices
		if minf(weights[ids.x], minf(weights[ids.y], weights[ids.z])) < minimum_weight: continue
		if not direction.is_zero_approx() and Vector3(triangle.normal).dot(direction) < 0.25: continue
		var cost := probe.distance_squared_to(Vector3(triangle.point))
		if cost < best:
			var hit := hit_on(body, surface, ti, probe)
			if not _in_cavity(Vector3(hit.point), surface.cavities): best = cost; chosen = hit
	return chosen

static func hit_on(body: Dictionary, surface: Dictionary, ti: int, point: Vector3) -> Dictionary:
	var triangle: Dictionary = surface.triangles[ti]; var ids: Vector3i = triangle.indices
	var closest := Closest._triangle_point(point, body.vertices[ids.x], body.vertices[ids.y], body.vertices[ids.z])
	return {"point": closest.point, "barycentric": closest.barycentric, "indices": ids, "triangle": ti, "normal": triangle.normal}

static func neighborhood(surface: Dictionary, seed_triangle: int) -> Array:
	if surface.neighborhood_cache.has(seed_triangle): return surface.neighborhood_cache[seed_triangle]
	# Two vertex-neighborhood rings, ordered by triangle ID, maximum128 supports.
	var seen := {seed_triangle: true}; var frontier: Array = [seed_triangle]
	for depth in range(2):
		var next: Array = []
		for ti: int in frontier:
			var ids: Vector3i = surface.triangles[ti].indices
			for vi: int in [ids.x, ids.y, ids.z]:
				for other: int in surface.vertex_faces[vi]:
					if not seen.has(other) and bool(surface.triangles[other].valid): seen[other] = true; next.append(other)
		frontier = next
	var result: Array = seen.keys(); result.sort()
	if result.size() > 128:
		var origin: Vector3 = surface.triangles[seed_triangle].point
		result.sort_custom(func(a: int, b: int) -> bool:
			var da := origin.distance_squared_to(Vector3(surface.triangles[a].point)); var db := origin.distance_squared_to(Vector3(surface.triangles[b].point))
			return da < db if da != db else a < b)
		result.resize(128)
	surface.neighborhood_cache[seed_triangle] = result
	return result

static func project(body: Dictionary, surface: Dictionary, probe: Vector3, seed_triangle: int, maximum_distance: float) -> Dictionary:
	var best := maximum_distance * maximum_distance; var found := {}
	var reference: Vector3 = surface.triangles[seed_triangle].normal
	for ti: int in neighborhood(surface, seed_triangle):
		var triangle: Dictionary = surface.triangles[ti]
		if not bool(triangle.valid) or reference.dot(Vector3(triangle.normal)) < 0.42: continue
		var hit := hit_on(body, surface, ti, probe)
		var distance := probe.distance_squared_to(Vector3(hit.point))
		if distance < best and not _in_cavity(Vector3(hit.point), surface.cavities): best = distance; found = hit
	return found

static func route(body: Dictionary, surface: Dictionary, start: Dictionary, goal: Dictionary, limit: int, path: Dictionary, accepted: Array) -> Dictionary:
	var first := int(start.triangle); var last := int(goal.triangle)
	var distance := {first: 0.0}; var parents := {}; var closed := {}; var heap: Array = []
	_push(heap, [Vector3(start.point).distance_to(Vector3(goal.point)), first])
	var expanded := 0; var blocked_clearance := 0
	while not heap.is_empty() and expanded < limit:
		var at := int(_pop(heap)[1])
		if closed.has(at): continue
		closed[at] = true; expanded += 1
		if at == last:
			var route_ids: Array = [last]; var cursor := last
			while cursor != first: cursor = int(parents[cursor]); route_ids.push_front(cursor)
			var hits: Array = [start]
			for ti: int in route_ids:
				if ti != first and ti != last: hits.append(hit_on(body, surface, ti, surface.triangles[ti].point))
			hits.append(goal)
			return {"ok": true, "hits": hits, "route_triangles": route_ids, "expanded": expanded, "clearance_blocks": blocked_clearance}
		var here: Dictionary = surface.triangles[at]
		for next: int in surface.adjacency[at]:
			if closed.has(next): continue
			var there: Dictionary = surface.triangles[next]
			if not bool(there.valid): continue
			var alignment := Vector3(here.normal).dot(Vector3(there.normal))
			if alignment < 0.42: continue
			if not clear(Vector3(there.point), float(path.radius), path, accepted): blocked_clearance += 1; continue
			var cost := float(distance[at]) + Vector3(here.point).distance_to(Vector3(there.point)) * (1.0 + 2.0 * (1.0 - alignment))
			if cost >= float(distance.get(next, INF)): continue
			distance[next] = cost; parents[next] = at
			_push(heap, [cost + Vector3(there.point).distance_to(Vector3(goal.point)), next])
	return {"ok": false, "reason": "route_expansion_limit" if expanded >= limit else "no_connected_cavity_safe_route", "expanded": expanded, "clearance_blocks": blocked_clearance}

static func clear(point: Vector3, radius: float, path: Dictionary, accepted: Array) -> bool:
	var root_distance := point.distance_to(Vector3(path.start))
	for other: Dictionary in accepted:
		for sample: Dictionary in other.samples:
			if str(other.id) == str(path.parent_id) and root_distance < float(path.junction_envelope):
				if Vector3(sample.point).distance_to(Vector3(path.start)) < float(path.junction_envelope): continue
			if int(path.level) == 0 and int(other.level) == 0 and root_distance < float(path.radius) * 2.5 and float(sample.local_t) < 0.14: continue
			if point.distance_squared_to(Vector3(sample.point)) < pow((radius + float(sample.radius)) * 0.80, 2.0): return false
	return true

static func _less(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0]) if a[0] != b[0] else int(a[1]) < int(b[1])

static func _push(heap: Array, item: Array) -> void:
	heap.append(item); var at := heap.size() - 1
	while at > 0:
		var parent := (at - 1) / 2
		if not _less(heap[at], heap[parent]): break
		var swap: Array = heap[parent]; heap[parent] = heap[at]; heap[at] = swap; at = parent

static func _pop(heap: Array) -> Array:
	var item: Array = heap[0]; var tail: Array = heap.pop_back()
	if heap.is_empty(): return item
	heap[0] = tail; var at := 0
	while true:
		var left := at * 2 + 1
		if left >= heap.size(): break
		var chosen := left; var right := left + 1
		if right < heap.size() and _less(heap[right], heap[left]): chosen = right
		if not _less(heap[chosen], heap[at]): break
		var swap: Array = heap[at]; heap[at] = heap[chosen]; heap[chosen] = swap; at = chosen
	return item
