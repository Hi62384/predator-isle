extends RefCounted
## Experimental, default-off Stage 4 overlay. Existing positive adherent-fiber
## provenance supplies a mask; no new geometry, noise, flow or node material.
const PROFILE := "authored_adherent_fiber_v1"
const VERSION := 1
const SETTING := "blob_fiber_material_assignment"
const FLESH := 0
const MUSCLE := 2
const EPSILON := 0.00001

static func is_enabled(dna: Dictionary) -> bool:
	return str(dna.get("type", "")) == "Blob" and str(dna.get("settings", {}).get(SETTING, "")) == PROFILE

static func cache_key(final_geometry_key: String) -> String:
	return final_geometry_key + ":" + PROFILE + ":mask_v" + str(VERSION)

static func _closed(reason: String) -> Dictionary:
	return {"version": VERSION, "profile": PROFILE, "trusted": false, "reason": reason, "changes_geometry": false, "changes_binding": false}

static func build(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	if not is_enabled(dna): return _closed("The versioned Blob adherent-fiber overlay is not enabled.")
	var vertices: PackedVector3Array = geometry.get("vertices", PackedVector3Array())
	var ids: PackedStringArray = geometry.get("node_ids", PackedStringArray())
	var components: PackedInt32Array = geometry.get("component_indices", PackedInt32Array())
	var source_weights: PackedFloat32Array = geometry.get("component_weights", PackedFloat32Array())
	if vertices.is_empty() or ids.is_empty() or components.size() != vertices.size() * 4 or source_weights.size() != components.size():
		return _closed("The final body lacks complete four-component positive provenance.")
	var positive := PackedByteArray(); positive.resize(ids.size())
	var fibers := PackedByteArray(); fibers.resize(ids.size())
	var fiber_ids := PackedStringArray()
	for node: Dictionary in dna.get("nodes", []):
		var at := ids.find(str(node.get("id", "")))
		if at < 0 or str(node.get("kind", "")) == "cavity" or str(node.get("operation", "union")) == "subtract": continue
		positive[at] = 1
		if str(node.get("surface_operation", "")) == "fibers" and str(node.get("fiber_mode", "")) == "adherent_fibers":
			fibers[at] = 1; fiber_ids.append(ids[at])
	var weights := PackedFloat32Array(); weights.resize(vertices.size())
	var counts := {"provenance_vertices": 0, "invalid_provenance_vertices": 0, "maximum_weight": 0.0, "weight_sum": 0.0}
	for vi in range(vertices.size()):
		if vi % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		var total := 0.0; var fiber := 0.0; var valid := true
		for slot in range(vi * 4, vi * 4 + 4):
			var weight := float(source_weights[slot])
			if not is_finite(weight) or weight < 0.0: valid = false; break
			if weight == 0.0: continue
			var owner := components[slot]
			if owner < 0 or owner >= positive.size() or positive[owner] == 0: valid = false; break
			total += weight
			if fibers[owner] != 0: fiber += weight
		if not valid or total <= 0.0:
			counts.invalid_provenance_vertices += 1; continue
		weights[vi] = clampf(fiber / total, 0.0, 1.0)
		if weights[vi] > EPSILON: counts.provenance_vertices += 1
		counts.maximum_weight = maxf(float(counts.maximum_weight), weights[vi])
		counts.weight_sum += weights[vi]
	return {"version": VERSION, "profile": PROFILE, "trusted": true, "vertex_count": vertices.size(), "fiber_node_ids": fiber_ids,
		"weights": weights, "counts": counts, "changes_geometry": false, "changes_binding": false,
		"scope": "fused_body_positive_adherent_fiber_provenance_only"}

static func apply(dna: Dictionary, geometry: Dictionary, context: Dictionary) -> Dictionary:
	if not is_enabled(dna): return {"enabled": false, "changed_vertices": 0}
	if not bool(context.get("trusted", false)) or int(context.get("version", 0)) != VERSION or str(context.get("profile", "")) != PROFILE:
		return {"enabled": true, "applied": false, "reason": str(context.get("reason", "Unsupported fiber material context.")), "changed_vertices": 0}
	var vertices: PackedVector3Array = geometry.get("vertices", PackedVector3Array())
	var colors: PackedColorArray = geometry.get("colors", PackedColorArray())
	var source_uv: PackedVector2Array = geometry.get("uvs2", PackedVector2Array())
	var indices: PackedInt32Array = geometry.get("indices", PackedInt32Array())
	var weights: PackedFloat32Array = context.get("weights", PackedFloat32Array()).duplicate()
	if colors.size() != vertices.size() or source_uv.size() != vertices.size() or weights.size() != vertices.size() or indices.size() % 3 != 0:
		return {"enabled": true, "applied": false, "reason": "Fiber context does not match the final body attributes.", "changed_vertices": 0}
	for index in indices:
		if index < 0 or index >= vertices.size():
			return {"enabled": true, "applied": false, "reason": "Fiber overlay requires valid body triangles.", "changed_vertices": 0}
	# Precedence is deliberately conservative: every pre-existing UV2 value is
	# immutable, even same-category muscle or a zero-weight cavity guard. Do not
	# infer vacant slots from y alone, or increase cavity amounts with fibers.
	var locked := PackedByteArray(); locked.resize(vertices.size())
	var rejected := PackedByteArray(); rejected.resize(vertices.size())
	var existing := PackedByteArray(); existing.resize(vertices.size())
	for vi in range(vertices.size()):
		if source_uv[vi] != Vector2.ZERO: existing[vi] = 1; locked[vi] = 1
	# Freeze complete pre-existing blend triangles, including zero UV entries.
	# A new guard at an adjacent shared vertex must not corrupt their varying ID.
	for base in range(0, indices.size(), 3):
		if existing[indices[base]] == 0 and existing[indices[base + 1]] == 0 and existing[indices[base + 2]] == 0: continue
		for j in range(3): locked[indices[base + j]] = 1
	var eligible := 0
	for vi in range(vertices.size()):
		if not is_finite(weights[vi]) or weights[vi] < 0.0 or weights[vi] > 1.0:
			return {"enabled": true, "applied": false, "reason": "Fiber context contains invalid normalized weights.", "changed_vertices": 0}
		if roundi(colors[vi].r * 7.0) != FLESH or source_uv[vi] != Vector2.ZERO: locked[vi] = 1
		if weights[vi] > EPSILON:
			eligible += 1
			if locked[vi] != 0: rejected[vi] = 1
		else: weights[vi] = 0.0
	# A candidate must be safe in ALL incident triangles. Reject neighboring
	# candidates too, rather than allowing interpolation through a third ID.
	for base in range(0, indices.size(), 3):
		if locked[indices[base]] == 0 and locked[indices[base + 1]] == 0 and locked[indices[base + 2]] == 0: continue
		for j in range(3):
			var vi := indices[base + j]
			if weights[vi] > 0.0: rejected[vi] = 1
	var rejected_count := 0
	for vi in range(vertices.size()):
		if rejected[vi] != 0: weights[vi] = 0.0; rejected_count += 1
	var guards := PackedByteArray(); guards.resize(vertices.size())
	var active_triangles := 0
	for base in range(0, indices.size(), 3):
		if weights[indices[base]] <= 0.0 and weights[indices[base + 1]] <= 0.0 and weights[indices[base + 2]] <= 0.0: continue
		active_triangles += 1
		for j in range(3): guards[indices[base + j]] = 1
	var output := source_uv.duplicate()
	var active := 0; var guarded := 0; var amount := 0.0
	for vi in range(vertices.size()):
		if guards[vi] == 0: continue
		output[vi] = Vector2(float(MUSCLE) / 7.0, weights[vi])
		if weights[vi] > 0.0: active += 1; amount += weights[vi]
		else: guarded += 1
	# Do not replace even an identical packed stream when no triangle is active.
	if active > 0: geometry["uvs2"] = output
	return {"enabled": true, "applied": active > 0, "version": VERSION, "profile": PROFILE,
		"changed_vertices": active + guarded, "fiber_vertices": active, "zero_weight_guard_vertices": guarded,
		"active_triangles": active_triangles, "provenance_vertices": eligible, "conflicting_vertices_rejected": rejected_count,
		"muscle_weight_sum": amount, "changes_geometry": false, "changes_binding": false, "changed_channels": ["uvs2"] if active > 0 else [],
		"precedence": "existing_secondary_assignments_and_zero_weight_guards_first"}
