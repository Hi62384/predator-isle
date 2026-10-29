extends RefCounted
## Isolated stage-5, retained-triangle vascular geometry. No volume extraction.
## A versioned typed feature graph is separate from the legacy SDF-only registry.
## All collars share the exact parent port vertex IDs. No overlapping root tubes.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const Support = preload("res://alien_foundry/scripts/geometry/BlobMembraneSurface.gd")
const Routes = preload("res://alien_foundry/scripts/geometry/BlobVascularSurfaceRoutes.gd")
const KEY := "blob_surface_vascular_v2"
const MAX_BRANCHES := 15
const MAX_TRIANGLES := 10000
const SIDES := 8
const STAGE := 5

static func _error(message: String) -> Dictionary:
	return {"error": message, "error_code": "invalid_vascular_network"}

static func plan(dna: Dictionary) -> Dictionary:
	if str(dna.get("type", "")) != "Blob" or int(dna.get("seed", -1)) != 22:
		return _error("The finite vascular183b prototype supports only retained Blob seed22.")
	var core := {}; var nodes := {}; var sacs: Array = []
	for node: Dictionary in dna.get("nodes", []): nodes[str(node.id)] = node
	for feature: Dictionary in dna.get("biological_blueprint", {}).get("features", []):
		if str(feature.id) == "blob.body.core": core = feature
		if str(feature.type) == "sac": sacs.append(feature)
	if core.is_empty() or sacs.size() != 3: return _error("Expected one biological core and three primary sacs.")
	sacs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var targets: Array = []
	for sac: Dictionary in sacs:
		var host_id := str(sac.geometry_refs.node_ids[0])
		if not nodes.has(host_id) or str(nodes[host_id].kind) != "mass": return _error("Sac target has no authoritative mass carrier.")
		targets.append({"feature_id": str(sac.id), "node_id": host_id, "parent_feature_id": str(sac.parent_id)})
	return {"schema": "blob-surface-vascular-network", "version": 2, "id": "blob.vascular.surface.0", "seed": 22,
		"created_stage": STAGE, "type": "tendril", "subtype": "surface_vascular_fiber", "tissue": "vascular_fibrous",
		"core_feature_id": str(core.id), "core_node_id": str(core.geometry_refs.node_ids[0]), "targets": targets,
		"stream_seed": Blueprint.stream_seed(22, "blob.vascular.surface.0", "surface_growth.v2"),
		"levels": 3, "maximum_branches": MAX_BRANCHES, "maximum_triangles": MAX_TRIANGLES,
		"cross_section": {"sides": SIDES, "flattening": 0.75, "burial_fraction": 0.10},
		"root_radius_fraction": 0.085, "root_radius_units": "smallest_core_semiaxis",
		"level_radius_fractions": [0.085, 0.045, 0.020], "parent_radius_caps": [1.0, 0.62, 0.56],
		"tip_radius_ratios": [0.30, 0.20, 0.16], "path_samples": [64, 32, 20],
		"routing": {"method": "retained_triangle_shared_edge_astar", "expansion_limits": [12000, 4000, 4000],
			"smoothing_passes": 2, "projection_vertex_rings": 2, "projection_candidate_limit": 128,
			"minimum_core_weight": 0.30, "minimum_target_sac_weight": 0.45, "minimum_body_sac_weight": 0.70,
			"maximum_cavity_weight": 0.05, "minimum_adjacent_normal_dot": 0.42,
			"cavity_keepout": "actual_cavity_semiaxes_plus_warp_blend_and_maximum_trunk_radius", "maximum_route_length_core_semiaxes": 3.5},
		"surface_source": "retained_body_triangle_barycentric", "junctions": "shared_vertex_parent_side_ports",
		"animation_rules": {"create_bone": false, "carrier": "per_vertex_retained_host_weights"},
		"material_rules": {"material": "muscle", "tissue": "vascular_fibrous", "visual_tuning": "deferred"},
		"production_registry_integration": "pending_direct_mesh_carrier_support"}

static func validate_recipe(dna: Dictionary, supplied: Dictionary) -> Dictionary:
	var expected := plan(dna)
	if expected.has("error"): return {"valid": false, "mismatches": [expected.error]}
	var audit := {"valid": false, "mismatches": [], "representation_differences": [], "leaf_count": 0,
		"comparison": "exact_keys_ordered_arrays_typed_integral_values_exact_floating_values"}
	_compare_recipe(expected, supplied, "recipe", audit)
	audit.valid = audit.mismatches.is_empty()
	if audit.valid: audit["canonical"] = expected
	return audit

static func _compare_recipe(expected: Variant, actual: Variant, path: String, audit: Dictionary) -> void:
	if expected is Dictionary:
		if not actual is Dictionary: audit.mismatches.append({"path": path, "reason": "expected_dictionary"}); return
		var expected_keys: Array = expected.keys(); var actual_keys: Array = actual.keys()
		if expected_keys != actual_keys:
			audit.representation_differences.append({"path": path, "kind": "dictionary_key_order"})
		expected_keys.sort(); actual_keys.sort()
		if expected_keys != actual_keys: audit.mismatches.append({"path": path, "reason": "different_keys"}); return
		for key: String in expected_keys: _compare_recipe(expected[key], actual[key], path + "." + key, audit)
		return
	if expected is Array:
		if not actual is Array or expected.size() != actual.size(): audit.mismatches.append({"path": path, "reason": "array_shape"}); return
		for i in range(expected.size()): _compare_recipe(expected[i], actual[i], path + "[%s]" % i, audit)
		return
	audit.leaf_count += 1
	if expected is int:
		if not (actual is int or actual is float) or not is_finite(float(actual)) or float(actual) != float(expected) or float(actual) != floor(float(actual)):
			audit.mismatches.append({"path": path, "reason": "integral_value", "expected": expected, "actual": actual}); return
		if typeof(expected) != typeof(actual):
			audit.representation_differences.append({"path": path, "kind": "number_type", "expected_type": typeof(expected), "actual_type": typeof(actual), "exact_value": expected})
		return
	if expected is float:
		if not (actual is int or actual is float) or not is_finite(float(actual)) or float(expected) != float(actual):
			audit.mismatches.append({"path": path, "reason": "exact_floating_value", "expected": expected, "actual": actual})
		return
	if typeof(expected) != typeof(actual) or expected != actual:
		audit.mismatches.append({"path": path, "reason": "typed_scalar", "expected": expected, "actual": actual})

static func build(dna: Dictionary, body: Dictionary, spec: Dictionary, controls: RefCounted = null) -> Dictionary:
	var validated := validate_recipe(dna, spec)
	if not bool(validated.get("valid", false)): return _error("Unsupported or modified vascular183b descriptor: " + str(validated.get("mismatches", [])))
	# Restore only the types whose exact scalar values were already verified.
	spec = validated.canonical
	if body.get("vertices", PackedVector3Array()).is_empty() or body.get("indices", PackedInt32Array()).is_empty():
		return _error("Vascular growth requires exact retained body triangles.")
	var report := {"version": 2, "status": "planned", "seed": 22, "created_stage": STAGE,
		"primary_mesh_mutated": false, "body_extractions": 0, "new_bones": 0, "visual_validated": false,
		"limits": {"branches": MAX_BRANCHES, "triangles": MAX_TRIANGLES, "levels": 3},
		"stopped_paths": [], "rejected_paths": [], "body_weld": false, "junctions": "shared_vertex_ports"}
	var nodes := {}
	for node: Dictionary in dna.nodes: nodes[str(node.id)] = node
	var core: Dictionary = nodes[str(spec.core_node_id)]
	var core_size := Graph.vec(core.size)
	var scale := minf(core_size.x, minf(core_size.y, core_size.z))
	var root_radius := scale * float(spec.root_radius_fraction)
	var paths: Array = []
	var surface := Routes.prepare(dna, body, root_radius)
	report["routing"] = {"method": surface.route_source, "retained_triangles": surface.triangles.size(), "excluded_triangles": surface.rejected_triangles,
		"projection": "two_vertex_neighborhood_rings_max128", "cavity_exclusions_relaxed": false}
	for ti in range(spec.targets.size()):
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		var target: Dictionary = spec.targets[ti]
		var sac: Dictionary = nodes[str(target.node_id)]
		var sac_feature := Blueprint.feature(dna.biological_blueprint, str(target.feature_id))
		var direction := Graph.vec(sac_feature.growth_direction).normalized()
		var across := Vector3.UP.cross(direction).normalized()
		var insertion := _core_insertion(body, surface, core, sac, direction, scale)
		var goal := Routes.endpoint(body, surface, _sac_probe(sac, direction, across, 0, 0), str(target.feature_id), 0.45)
		if insertion.is_empty() or goal.is_empty():
			report.rejected_paths.append({"id": "blob.vascular.surface.0.feeder.%s" % ti, "reason": "no_valid_core_or_sac_endpoint", "unattempted_descendants": 4}); continue
		var branch := _candidate(spec, ti, "", 0, insertion.point, goal.point, root_radius, -1, 1)
		branch["surface_start"] = insertion; branch["surface_goal"] = goal
		var sampled := _sample_path(body, surface, branch, paths, scale, spec)
		if not bool(sampled.get("ok", false)):
			report.rejected_paths.append({"id": branch.id, "reason": sampled.get("reason", "unsupported_root"), "route_audit": sampled.get("route_audit", {}), "unattempted_descendants": 4}); continue
		branch.merge(sampled, true)
		branch["target_attachment_weight"] = Routes.feature_weight(surface, branch.samples[-1], str(target.feature_id))
		branch["root_core_weight"] = Routes.feature_weight(surface, insertion, str(spec.core_feature_id))
		paths.append(branch)
		for ci in range(2):
			var segment := clampi(roundi(float(branch.samples.size() - 2) * (0.35 if ci == 0 else 0.64)), 4, branch.samples.size() - 5)
			var side := 1 if ci == 0 else -1
			var child := _grow_child(spec, branch, segment, side, ci, scale, body, surface, paths, sac, direction, across)
			if child.has("error"):
				report.rejected_paths.append({"parent_id": branch.id, "child_slot": ci, "level": 1, "reason": child.error, "route_audit": child.get("route_audit", {}), "unattempted_descendants": 1}); continue
			paths.append(child)
			var twig_segment := clampi(roundi(float(child.samples.size() - 2) * 0.48), 4, child.samples.size() - 5)
			var twig := _grow_child(spec, child, twig_segment, side, 0, scale, body, surface, paths, sac, direction, across)
			if twig.has("error"):
				report.rejected_paths.append({"parent_id": child.id, "level": 2, "reason": twig.error, "route_audit": twig.get("route_audit", {}), "unattempted_descendants": 0}); continue
			paths.append(twig)
	if paths.is_empty(): report.status = "no_supported_growth"; return {"report": report}
	if paths.size() > MAX_BRANCHES: return _error("Vascular branch ceiling exceeded.")
	var mesh := _empty_mesh(body, paths)
	var host_features := {}
	for node_id: String in nodes: host_features[node_id] = str(nodes[node_id].get("feature_id", ""))
	mesh["host_feature_by_node"] = host_features
	var realized: Array = []; var lookup := {}
	for path: Dictionary in paths: lookup[str(path.id)] = path
	for pi in range(paths.size()):
		var path: Dictionary = paths[pi]
		var parent: Dictionary = lookup.get(str(path.parent_id), {})
		var made := _sweep(body, surface, mesh, path, parent, paths, pi)
		if made.has("error"): return made
		var record := _record_path(path, spec)
		realized.append(record)
	if mesh.indices.size() / 3 > MAX_TRIANGLES: return _error("Vascular triangle ceiling exceeded.")
	_recompute_normals(mesh)
	var safe := safety_audit(mesh)
	if not bool(safe.valid): return {"error": "Unsafe vascular geometry.", "safety": safe, "report": report}
	mesh.stats = {"vertices": mesh.vertices.size(), "triangles": mesh.indices.size() / 3, "cell_size": body.get("stats", {}).get("cell_size", 0.0), "welded_to_primary": false}
	var bounds := AABB(mesh.vertices[0], Vector3.ZERO)
	for point: Vector3 in mesh.vertices: bounds = bounds.expand(point)
	mesh["bounds"] = bounds
	var descriptor := spec.duplicate(true)
	descriptor["branches"] = realized
	descriptor["support_mesh_sha256"] = physical_hash(body)
	descriptor["realization"] = "stage5_local_mesh_before_final_binding"
	report.merge({"status": "realized_pending_native_clay", "branches": paths.size(), "triangles": mesh.indices.size() / 3,
		"vertices": mesh.vertices.size(), "shared_junctions": mesh.junctions.size(), "binding_witnesses": mesh.surface_root_samples.size(),
		"mesh_safety": safe, "source_body_sha256": descriptor.support_mesh_sha256, "registry_scope": "isolated_typed_descriptor_not_production_active_features"}, true)
	return {"mesh": mesh, "descriptor": descriptor, "report": report}

static func _core_insertion(body: Dictionary, surface: Dictionary, core: Dictionary, sac: Dictionary, direction: Vector3, scale: float) -> Dictionary:
	var center := Graph.vec(core.position)
	var away := center - Graph.vec(sac.position)
	away -= direction * away.dot(direction)
	if away.length_squared() < 0.0001: away = Vector3.UP
	away = away.normalized()
	var probe := center + direction * Graph.vec(core.size) * 0.85 + away * scale * 0.60
	return Routes.endpoint(body, surface, probe, "blob.body.core", 0.30, direction)

static func _sac_probe(sac: Dictionary, direction: Vector3, across: Vector3, level: int, side: int) -> Vector3:
	var radial := direction * 0.72 + Vector3.UP * 0.52
	if level == 1: radial = direction * 0.55 + across * side * 0.72 + Vector3.UP * (0.45 if side > 0 else 0.12)
	if level == 2: radial = direction * 0.20 + across * side * 0.92 + Vector3.UP * (0.15 if side > 0 else 0.60)
	return Graph.vec(sac.position) + Graph.vec(sac.size) * radial.normalized()

static func _candidate(spec: Dictionary, target_index: int, parent_id: String, level: int, start: Vector3, goal: Vector3, radius: float, parent_segment: int, side: int, suffix: int = 0) -> Dictionary:
	var id := "blob.vascular.surface.0.feeder.%s" % target_index
	if not parent_id.is_empty(): id = parent_id + ".branch.%s" % suffix
	return {"id": id, "parent_id": parent_id, "level": level, "target_index": target_index,
		"target_feature_id": str(spec.targets[target_index].feature_id), "target_node_id": str(spec.targets[target_index].node_id),
		"start": start, "goal": goal, "radius": radius, "parent_segment": parent_segment, "side": side,
		"sample_count": int(spec.path_samples[level]), "children": [], "port_start": 7 if side > 0 else 3,
		"junction_envelope": radius * 3.0}

static func _grow_child(spec: Dictionary, parent: Dictionary, segment: int, side: int, suffix: int, scale: float, body: Dictionary, surface: Dictionary, paths: Array, sac: Dictionary, direction: Vector3, sac_across: Vector3) -> Dictionary:
	var first: Dictionary = parent.samples[segment]; var second: Dictionary = parent.samples[segment + 1]
	var tangent: Vector3 = (Vector3(second.point) - Vector3(first.point)).normalized()
	var across := tangent.cross(Vector3(first.normal)).normalized()
	var start: Vector3 = Vector3(first.point).lerp(Vector3(second.point), 0.5) + across * side * float(first.radius) * 0.82
	var level := int(parent.level) + 1
	var root_hit := Routes.project(body, surface, start, int(first.triangle), float(first.radius) * 0.6 + scale * 0.01)
	var goal := Routes.endpoint(body, surface, _sac_probe(sac, direction, sac_across, level, side), str(parent.target_feature_id), 0.45)
	if root_hit.is_empty() or goal.is_empty(): return {"error": "no_supported_junction_or_sac_side_endpoint"}
	var radius := minf(scale * float(spec.level_radius_fractions[level]), float(first.radius) * float(spec.parent_radius_caps[level]))
	var child := _candidate(spec, int(parent.target_index), str(parent.id), level, root_hit.point, goal.point, radius, segment, side, suffix)
	child["surface_start"] = root_hit; child["surface_goal"] = goal; child["junction_envelope"] = float(first.radius) * 3.0
	var sampled := _sample_path(body, surface, child, paths, scale, spec)
	if not bool(sampled.get("ok", false)): return {"error": sampled.get("reason", "unsupported_branch"), "route_audit": sampled.get("route_audit", {})}
	child.merge(sampled, true)
	child["target_attachment_weight"] = Routes.feature_weight(surface, child.samples[-1], str(parent.target_feature_id))
	parent.children.append(child.id)
	return child

static func _sample_path(body: Dictionary, surface: Dictionary, path: Dictionary, accepted: Array, scale: float, spec: Dictionary) -> Dictionary:
	var routed := Routes.route(body, surface, path.surface_start, path.surface_goal, int(spec.routing.expansion_limits[int(path.level)]), path, accepted)
	var route_audit := {"expanded": routed.get("expanded", 0), "clearance_blocks": routed.get("clearance_blocks", 0)}
	if not bool(routed.get("ok", false)): return {"ok": false, "reason": routed.reason, "route_audit": route_audit}
	var hits: Array = routed.hits
	for smoothing_pass in range(2):
		var next_hits: Array = [hits[0]]
		for i in range(1, hits.size() - 1):
			var probe: Vector3 = Vector3(hits[i - 1].point) * 0.25 + Vector3(hits[i].point) * 0.50 + Vector3(hits[i + 1].point) * 0.25
			var hit := Routes.project(body, surface, probe, int(hits[i].triangle), scale * 0.12)
			if hit.is_empty(): return {"ok": false, "reason": "smoothing_left_supported_corridor", "route_audit": route_audit}
			next_hits.append(hit)
		next_hits.append(hits[-1]); hits = next_hits
	var cumulative: Array = [0.0]
	for i in range(1, hits.size()): cumulative.append(float(cumulative[-1]) + Vector3(hits[i].point).distance_to(Vector3(hits[i - 1].point)))
	var length := float(cumulative[-1]); route_audit["length"] = length; route_audit["triangle_count"] = routed.route_triangles.size()
	if length < scale * 0.08 or length > scale * 3.5: return {"ok": false, "reason": "route_length_outside_fixed_limits", "route_audit": route_audit}
	var samples: Array = []; var cursor := 0
	for i in range(int(path.sample_count)):
		var t := float(i) / float(int(path.sample_count) - 1); var distance := t * length
		while cursor + 1 < hits.size() - 1 and float(cumulative[cursor + 1]) < distance: cursor += 1
		var factor := clampf((distance - float(cumulative[cursor])) / maxf(float(cumulative[cursor + 1]) - float(cumulative[cursor]), 0.000001), 0.0, 1.0)
		var probe: Vector3 = Vector3(hits[cursor].point).lerp(Vector3(hits[cursor + 1].point), factor)
		var hit := Routes.project(body, surface, probe, int(hits[cursor].triangle), scale * 0.08)
		if i == 0: hit = path.surface_start
		if i == int(path.sample_count) - 1: hit = path.surface_goal
		if hit.is_empty(): return {"ok": false, "reason": "resample_left_supported_corridor", "route_audit": route_audit}
		var normal := _normal(body, hit)
		var radius := float(path.radius) * lerpf(1.0, float(spec.tip_radius_ratios[int(path.level)]), pow(t, 0.78))
		if not samples.is_empty():
			if normal.dot(Vector3(samples[-1].normal)) < 0.42: return {"ok": false, "reason": "resampled_sharp_normal_change", "route_audit": route_audit}
			if Vector3(hit.point).distance_to(Vector3(samples[-1].point)) > maxf(scale * 0.13, length / float(path.sample_count - 1) * 3.5):
				return {"ok": false, "reason": "resampled_surface_discontinuity", "route_audit": route_audit}
		if not Routes.clear(Vector3(hit.point), radius, path, accepted): return {"ok": false, "reason": "resampled_nonadjacent_clearance", "route_audit": route_audit}
		var influences := Support._hit_influences(body, hit)
		samples.append({"point": hit.point, "normal": normal, "triangle": hit.triangle, "barycentric": hit.barycentric,
			"indices": hit.indices, "radius": radius, "t": t, "local_t": t, "host_node_id": str(body.node_ids[int(influences.owners[0])])})
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		var tangent: Vector3 = (Vector3(samples[mini(i + 1, samples.size() - 1)].point) - Vector3(samples[maxi(0, i - 1)].point)).normalized()
		var across := tangent.cross(Vector3(sample.normal)).normalized()
		for k in range(SIDES):
			var angle := (float(k) - 0.5) * TAU / SIDES
			var probe: Vector3 = Vector3(sample.point) + across * cos(angle) * float(sample.radius)
			if Routes.project(body, surface, probe, int(sample.triangle), float(sample.radius) * 0.45 + scale * 0.01).is_empty():
				return {"ok": false, "reason": "unsupported_ring_footprint", "sample_index": i, "route_audit": route_audit}
	return {"ok": true, "samples": samples, "stop_reason": "reached_target", "reached_target": true, "route_audit": route_audit,
		"route_triangles": routed.route_triangles, "surface_scale": scale}

static func _normal(body: Dictionary, hit: Dictionary) -> Vector3:
	var normals: PackedVector3Array = body.get("normals", PackedVector3Array())
	var normal := Vector3.ZERO
	if normals.size() == body.vertices.size():
		for corner in range(3): normal += Vector3(normals[int(hit.indices[corner])]) * float(hit.barycentric[corner])
	if normal.length_squared() < 0.1: return Vector3(hit.normal)
	normal = normal.normalized()
	return normal if normal.dot(Vector3(hit.normal)) >= 0.0 else -normal

static func _empty_mesh(body: Dictionary, paths: Array) -> Dictionary:
	var ids := PackedStringArray()
	for path: Dictionary in paths: ids.append(str(path.id))
	return {"name": "SurfaceVascularNetwork183b", "role": "tendril", "created_stage": STAGE, "pipeline_stage": STAGE,
		"geometry_path": KEY, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "indices": PackedInt32Array(),
		"colors": PackedColorArray(), "uvs": PackedVector2Array(), "uvs2": PackedVector2Array(),
		"component_ids": PackedInt32Array(), "component_indices": PackedInt32Array(), "component_weights": PackedFloat32Array(),
		"node_ids": body.node_ids, "feature_ids": ids, "feature_indices": PackedInt32Array(), "feature_weights": PackedFloat32Array(),
		"feature_influence_method": "authoritative_vascular_branch_descriptor", "feature_influence_slots": 4,
		"branch_indices": PackedInt32Array(), "surface_root_samples": [], "junctions": [], "authored_surface_context": PackedFloat32Array(),
		"fibre_uv_mode": "authored", "stats": {}}

static func _sweep(body: Dictionary, atlas: Dictionary, mesh: Dictionary, path: Dictionary, parent: Dictionary, paths: Array, feature_index: int) -> Dictionary:
	var rings: Array = []; var sample_count: int = path.samples.size()
	var phase := 0
	if not parent.is_empty():
		var port := _port_loop(parent.rings, int(path.parent_segment), int(path.port_start))
		rings.append(port)
		# A cyclic relabeling, never reversal, preserves the port's winding.
		var next: Dictionary = path.samples[1]
		var tangent: Vector3 = (Vector3(path.samples[2].point) - Vector3(path.samples[0].point)).normalized()
		var across := tangent.cross(Vector3(next.normal)).normalized()
		var best := INF
		for shift in range(SIDES):
			var score := 0.0
			for k in range(SIDES):
				var angle := (float(k + shift) - 0.5) * TAU / SIDES
				var expected := Vector3(next.point) + across * cos(angle) * float(next.radius) + Vector3(next.normal) * sin(angle) * float(next.radius) * 0.75
				score += expected.distance_squared_to(Vector3(mesh.vertices[int(port[k])]))
			if score < best: best = score; phase = shift
		mesh.junctions.append({"parent_id": parent.id, "child_id": path.id, "shared_vertex_ids": Array(port),
			"parent_segment": path.parent_segment, "port_start": path.port_start, "boundary_vertices": SIDES})
	for si in range(0 if parent.is_empty() else 1, sample_count):
		var sample: Dictionary = path.samples[si]
		var previous: Vector3 = path.samples[maxi(0, si - 1)].point
		var next: Vector3 = path.samples[mini(sample_count - 1, si + 1)].point
		var tangent := (next - previous).normalized()
		var across := tangent.cross(Vector3(sample.normal)).normalized()
		var ring := PackedInt32Array()
		for k in range(SIDES):
			var angle := (float(k + phase) - 0.5) * TAU / SIDES
			var probe := Vector3(sample.point) + across * cos(angle) * float(sample.radius)
			var hit := Routes.project(body, atlas, probe, int(sample.triangle), float(sample.radius) * 0.45 + float(path.surface_scale) * 0.01)
			if hit.is_empty(): return _error("Ring footprint lost its retained support: " + str(path.id))
			var normal := _normal(body, hit)
			var t := float(sample.local_t)
			var insertion := 1.0 - smoothstep(0.0, 0.14, t) if parent.is_empty() else 0.0
			var tip := smoothstep(0.84, 1.0, t)
			var height := float(sample.radius) * 0.75 * (sin(angle) - 0.10 - 1.08 * maxf(insertion, tip))
			var point := Vector3(hit.point) + normal * height
			var vi := _vertex(body, mesh, point, normal, hit, feature_index, path, t, float(k) / SIDES, height)
			ring.append(vi)
		rings.append(ring)
	path["rings"] = rings
	path["phase"] = phase
	# Parent strip holes are generated only for fully supported accepted children.
	var holes := {}
	for child: Dictionary in paths:
		if str(child.parent_id) != str(path.id): continue
		child["port_start"] = posmod((7 if int(child.side) > 0 else 3) - phase, SIDES)
		var sectors: Array = []
		for j in range(3): sectors.append((int(child.port_start) + j) % SIDES)
		holes[int(child.parent_segment)] = sectors
	for si in range(rings.size() - 1):
		for k in range(SIDES):
			if k in holes.get(si, []): continue
			var a: int = rings[si][k]; var b: int = rings[si + 1][k]
			var c: int = rings[si + 1][(k + 1) % SIDES]; var d: int = rings[si][(k + 1) % SIDES]
			mesh.indices.append_array(PackedInt32Array([a, d, b, d, c, b]))
	if parent.is_empty(): _cap(body, atlas, mesh, path, rings[0], 0, feature_index, true)
	_cap(body, atlas, mesh, path, rings[-1], sample_count - 1, feature_index, false)
	return {}

static func _port_loop(rings: Array, segment: int, start: int) -> PackedInt32Array:
	var loop := PackedInt32Array()
	for k in range(4): loop.append(int(rings[segment][(start + k) % SIDES]))
	for k in range(3, -1, -1): loop.append(int(rings[segment + 1][(start + k) % SIDES]))
	return loop

static func _vertex(body: Dictionary, mesh: Dictionary, point: Vector3, normal: Vector3, hit: Dictionary, feature_index: int, path: Dictionary, t: float, u: float, height: float) -> int:
	var vi: int = mesh.vertices.size()
	var influences := Support._hit_influences(body, hit)
	mesh.vertices.append(point); mesh.normals.append(normal)
	mesh.component_ids.append(int(influences.owners[0])); mesh.component_indices.append_array(influences.owners); mesh.component_weights.append_array(influences.weights)
	mesh.colors.append(Color(2.0 / 7.0, 0.5, 0.0, 1.0)); mesh.uvs.append(Vector2(u, t)); mesh.uvs2.append(Vector2.ZERO)
	mesh.feature_indices.append_array(PackedInt32Array([feature_index, -1, -1, -1])); mesh.feature_weights.append_array(PackedFloat32Array([1, 0, 0, 0])); mesh.branch_indices.append(feature_index)
	mesh.authored_surface_context.append_array(PackedFloat32Array([1.0 - smoothstep(0.0, 0.18, t), 0.6, 0.45, 0.35]))
	mesh.surface_root_samples.append({"vertex_id": vi, "triangle": int(hit.triangle), "barycentric": Graph.arr(hit.barycentric),
		"point": Graph.arr(hit.point), "normal": Graph.arr(normal), "height": height, "branch_id": str(path.id),
		"host_node_id": str(body.node_ids[int(influences.owners[0])]), "host_feature_id": mesh.host_feature_by_node.get(str(body.node_ids[int(influences.owners[0])]), ""), "binding": "final_retained_triangle_weights"})
	return vi

static func _cap(body: Dictionary, atlas: Dictionary, mesh: Dictionary, path: Dictionary, ring: PackedInt32Array, sample_index: int, feature_index: int, root: bool) -> void:
	var sample: Dictionary = path.samples[sample_index]
	var hit: Dictionary = sample
	var normal := _normal(body, hit)
	var height := -float(sample.radius) * 0.75 * 1.30
	var center := _vertex(body, mesh, Vector3(hit.point) + normal * height, normal, hit, feature_index, path, float(sample.local_t), 0.5, height)
	for k in range(SIDES):
		var next := (k + 1) % SIDES
		mesh.indices.append_array(PackedInt32Array([center, ring[next], ring[k]] if root else [center, ring[k], ring[next]]))

static func _record_path(path: Dictionary, spec: Dictionary) -> Dictionary:
	var samples: Array = []
	for sample: Dictionary in path.samples:
		samples.append({"point": Graph.arr(sample.point), "normal": Graph.arr(sample.normal), "triangle": sample.triangle,
			"barycentric": Graph.arr(sample.barycentric), "radius": sample.radius, "t": sample.local_t, "host_node_id": sample.host_node_id})
	return {"id": path.id, "type": "tendril", "subtype": "vascular_feeder" if int(path.level) == 0 else "vascular_branch",
		"parent_id": str(path.parent_id) if not str(path.parent_id).is_empty() else str(spec.core_feature_id), "children": path.children,
		"level": path.level, "created_stage": STAGE, "target_feature_id": path.target_feature_id, "target_node_id": path.target_node_id,
		"growth_origin": samples[0], "growth_direction": Graph.arr((Vector3(path.samples[1].point) - Vector3(path.samples[0].point)).normalized()),
		"radius": path.radius, "reached_target": path.reached_target, "stop_reason": path.stop_reason,
		"route_triangles": path.route_triangles, "route_audit": path.route_audit, "root_core_weight": path.get("root_core_weight", 0.0), "target_attachment_weight": path.get("target_attachment_weight", 0.0),
		"parent_segment": path.parent_segment, "material_rules": spec.material_rules, "animation_rules": spec.animation_rules, "samples": samples}

static func physical_hash(body: Dictionary) -> String:
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes([body.get("vertices"), body.get("normals"), body.get("indices")]))
	return digest.finish().hex_encode()

static func _recompute_normals(mesh: Dictionary) -> void:
	var normals := PackedVector3Array(); normals.resize(mesh.vertices.size())
	for i in range(0, mesh.indices.size(), 3):
		var a: int = mesh.indices[i]; var b: int = mesh.indices[i + 1]; var c: int = mesh.indices[i + 2]
		var n: Vector3 = (mesh.vertices[c] - mesh.vertices[a]).cross(mesh.vertices[b] - mesh.vertices[a])
		normals[a] += n; normals[b] += n; normals[c] += n
	for i in range(normals.size()): normals[i] = normals[i].normalized()
	mesh.normals = normals

static func safety_audit(mesh: Dictionary) -> Dictionary:
	var nonfinite := 0; var bad_indices := 0; var zero_area := 0; var zero_normals := 0
	for p: Vector3 in mesh.vertices:
		if not p.is_finite(): nonfinite += 1
	for n: Vector3 in mesh.normals:
		if not n.is_finite(): nonfinite += 1
		elif n.length_squared() < 0.1: zero_normals += 1
	for index: int in mesh.indices:
		if index < 0 or index >= mesh.vertices.size(): bad_indices += 1
	if bad_indices == 0:
		for i in range(0, mesh.indices.size(), 3):
			var a: Vector3 = mesh.vertices[mesh.indices[i]]; var b: Vector3 = mesh.vertices[mesh.indices[i + 1]]; var c: Vector3 = mesh.vertices[mesh.indices[i + 2]]
			if (b - a).cross(c - a).length_squared() <= 1e-20: zero_area += 1
	return {"valid": nonfinite == 0 and bad_indices == 0 and zero_area == 0 and zero_normals == 0,
		"nonfinite": nonfinite, "bad_indices": bad_indices, "zero_area": zero_area, "zero_normals": zero_normals}

static func topology_audit(mesh: Dictionary) -> Dictionary:
	var edges := {}; var adjacency := {}; var used := {}; var orientation_errors := 0
	for i in range(0, mesh.indices.size(), 3):
		for e in range(3):
			var a: int = mesh.indices[i + e]; var b: int = mesh.indices[i + (e + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not edges.has(key): edges[key] = [0, 0]
			edges[key][0] += 1; edges[key][1] += 1 if a < b else -1
			if not adjacency.has(a): adjacency[a] = []
			adjacency[a].append(b); used[a] = true
	var bad_edges := 0
	for edge: Array in edges.values():
		if int(edge[0]) != 2: bad_edges += 1
		if int(edge[1]) != 0: orientation_errors += 1
	var seen := {}; var components := 0
	for vertex: int in used:
		if seen.has(vertex): continue
		components += 1; var queue: Array = [vertex]; seen[vertex] = true
		while not queue.is_empty():
			var at: int = queue.pop_back()
			for other: int in adjacency.get(at, []):
				if not seen.has(other): seen[other] = true; queue.append(other)
	return {"components": components, "bad_edges": bad_edges, "orientation_errors": orientation_errors,
		"euler": used.size() - edges.size() + mesh.indices.size() / 3, "shared_junctions": mesh.junctions.size(),
		"self_intersections": "not_exhaustively_tested; growth_paths_have_nonadjacent_clearance"}
