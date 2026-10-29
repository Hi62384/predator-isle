extends RefCounted
## Generic explicit vertex IDs, unlike the legacy membrane's paired vertices.
## Interpolated final weights are an approximation under differential skinning;
## tests must measure displacement separation against the actual support triangle.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")

static func bind(detail: Dictionary, skin: Dictionary, body: Dictionary, body_skin: Dictionary) -> Dictionary:
	if not detail.has("surface_root_samples"): return {}
	var triangles: PackedInt32Array = body.get("indices", PackedInt32Array())
	var count := 0
	for sample: Dictionary in detail.surface_root_samples:
		var offset := int(sample.get("triangle", -1)) * 3
		var vertex := int(sample.get("vertex_id", -1))
		if offset < 0 or offset + 2 >= triangles.size() or vertex < 0 or (vertex + 1) * 4 > skin.weights.size():
			return {"error": "Explicit tissue root lost its final retained support.", "error_code": "invalid_surface_root_binding"}
		var bary := Graph.vec(sample.get("barycentric", []))
		if not bary.is_finite() or absf(bary.x + bary.y + bary.z - 1.0) > 0.0001 or minf(bary.x, minf(bary.y, bary.z)) < -0.0001:
			return {"error": "Invalid surface-root barycentric coordinates.", "error_code": "invalid_surface_root_binding"}
		var combined := {}
		for corner in range(3):
			var body_vertex := triangles[offset + corner]
			for slot in range(4):
				var index := body_vertex * 4 + slot
				if index >= body_skin.weights.size(): return {"error": "Root support lacks finalized body weights.", "error_code": "invalid_surface_root_binding"}
				var amount: float = body_skin.weights[index] * bary[corner]
				if amount <= 0.000001: continue
				var bone: int = body_skin.bones[index]
				combined[bone] = float(combined.get(bone, 0.0)) + amount
		var ordered: Array = combined.keys()
		ordered.sort_custom(func(a: int, b: int) -> bool: return float(combined[a]) > float(combined[b]) if combined[a] != combined[b] else a < b)
		if ordered.is_empty(): return {"error": "Surface root has no final influence.", "error_code": "invalid_surface_root_binding"}
		var total := 0.0
		for bone: int in ordered.slice(0, 4): total += float(combined[bone])
		for slot in range(4):
			skin.bones[vertex * 4 + slot] = int(ordered[slot]) if slot < ordered.size() else 0
			skin.weights[vertex * 4 + slot] = float(combined[ordered[slot]]) / total if slot < ordered.size() else 0.0
		count += 1
	skin["explicit_surface_root_binding"] = {"root_vertices": count, "source": "final_body_triangle_barycentric_weights", "pose_exactness": "measured_not_assumed"}
	return {}
