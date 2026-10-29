extends RefCounted
## New bounded authoring policy. Existing183b geometry helpers and route limits
## are reused, never rewritten or relaxed. No seed/physical-hash allowlist.
const Legacy = preload("res://alien_foundry/scripts/geometry/BlobSurfaceVascularNetwork.gd")
const Routes = preload("res://alien_foundry/scripts/geometry/BlobVascularSurfaceRoutes.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const ID := "blob.vascular.surface.0"
const KEY := "blob_blueprint_vascular_v1"
const MAX_BRANCHES := 15
const MAX_TRIANGLES := 10000
const STAGE := 5

static func _error(message: String) -> Dictionary:
	return {"error": message, "error_code": "invalid_blueprint_vascular"}

static func _unit(seed_value: int, feature_id: String, lane: String) -> float:
	return float(Blueprint.stream_seed(seed_value, feature_id, "vascular_blueprint_v1." + lane) % 1000001) / 1000000.0

static func _mass(feature: Dictionary, nodes: Dictionary, core: bool) -> Dictionary:
	var candidates: Array = []
	var refs: Variant = feature.get("geometry_refs", {}).get("node_ids")
	if not refs is Array: return {}
	for node_id: Variant in refs:
		if not node_id is String or not nodes.has(node_id): continue
		var node: Dictionary = nodes[node_id]
		if node.get("kind") != "mass" or node.get("feature_id") != feature.id: continue
		if not core and node.get("role") != "lobe": continue # excludes owned transition masses
		candidates.append(node)
	if candidates.size() != 1: return {}
	var found: Dictionary = candidates[0]
	for field: String in ["position", "size", "rotation"]:
		var value: Variant = found.get(field)
		if not value is Array or value.size() != 3: return {}
		for scalar: Variant in value:
			if not (scalar is int or scalar is float) or not is_finite(float(scalar)): return {}
	var size := Graph.vec(found.size)
	if minf(size.x, minf(size.y, size.z)) <= 0.0001: return {}
	return found

static func plan(dna: Dictionary) -> Dictionary:
	if dna.get("type") != "Blob" or not dna.get("biological_blueprint") is Dictionary or not dna.biological_blueprint.get("features") is Array or not dna.get("nodes") is Array:
		return _error("Blueprint vascular planning requires supported Blob anatomy.")
	var nodes := {}; var core := {}; var sacs: Array = []
	for node: Variant in dna.nodes:
		if not node is Dictionary or not node.get("id") is String or nodes.has(node.id): return _error("Invalid or duplicate vascular host node.")
		nodes[node.id] = node
	for item: Variant in dna.biological_blueprint.features:
		if not item is Dictionary: return _error("Malformed biological feature registry.")
		if item.get("id") == "blob.body.core": core = item
		if item.get("type") == "sac": sacs.append(item)
	if core.is_empty() or core.get("type") != "body" or sacs.size() > 3: return _error("Expected one authoritative body core and at most three supported sacs.")
	var core_node := _mass(core, nodes, true)
	if core_node.is_empty(): return _error("Core has no unique supported mass carrier.")
	var seed_value := int(dna.seed)
	var targets: Array = []
	sacs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for sac: Dictionary in sacs:
		var node := _mass(sac, nodes, false)
		if node.is_empty(): return _error("Sac has no unique authoritative primary lobe: " + str(sac.id))
		var direction: Variant = sac.get("growth_direction")
		if not direction is Array or direction.size() != 3: return _error("Missing sac growth direction.")
		for scalar: Variant in direction:
			if not (scalar is int or scalar is float) or not is_finite(float(scalar)): return _error("Invalid sac growth direction.")
		if Graph.vec(direction).length_squared() < 0.000001: return _error("Zero sac growth direction.")
		var fid := str(sac.id)
		var feeder := ID + ".target." + fid + ".feeder"
		var levels := 1 + Blueprint.stream_seed(seed_value, fid, "vascular_blueprint_v1.levels") % 3
		var children: Array = []
		if levels >= 2:
			var child_count := 1 + Blueprint.stream_seed(seed_value, fid, "vascular_blueprint_v1.children") % 2
			for ci in range(child_count):
				var child_id := feeder + ".branch.%s" % ci
				children.append({"id": child_id, "slot": ci, "side": 1 if ci == 0 else -1,
					"parent_fraction": 0.35 if ci == 0 else 0.64,
					"twig": levels == 3 and _unit(seed_value, child_id, "twig") >= 0.30})
		targets.append({"feature_id": fid, "node_id": str(node.id), "parent_feature_id": str(sac.parent_id),
			"feeder_id": feeder, "levels": levels, "children": children,
			"radius_fraction": lerpf(0.070, 0.085, _unit(seed_value, fid, "radius")),
			"probe_lateral": lerpf(-0.12, 0.12, _unit(seed_value, fid, "probe_lateral")),
			"probe_lift": lerpf(-0.10, 0.10, _unit(seed_value, fid, "probe_lift"))})
	return {"schema": "blob-blueprint-vascular-network", "version": 1, "id": ID, "seed": seed_value,
		"created_stage": STAGE, "type": "tendril", "subtype": "surface_vascular_fiber", "tissue": "vascular_fibrous",
		"core_feature_id": str(core.id), "core_node_id": str(core_node.id), "targets": targets,
		"planning_status": "skipped_no_sac_targets" if targets.is_empty() else "planned",
		"maximum_branches": MAX_BRANCHES, "maximum_triangles": MAX_TRIANGLES,
		"cross_section": {"sides": 8, "flattening": 0.75, "burial_fraction": 0.10},
		"target_radius_cap": 0.12, "root_radius_units": "minimum_core_semiaxis_capped_by_target",
		"level_radius_fractions": [0.085, 0.045, 0.020], "parent_radius_caps": [1.0, 0.62, 0.56],
		"tip_radius_ratios": [0.30, 0.20, 0.16], "path_samples": [64, 32, 20],
		"routing": {"method": "retained_triangle_shared_edge_astar", "expansion_limits": [12000, 4000, 4000],
			"smoothing_passes": 2, "projection_vertex_rings": 2, "projection_candidate_limit": 128,
			"minimum_core_weight": 0.30, "minimum_target_sac_weight": 0.45, "minimum_body_sac_weight": 0.70,
			"maximum_cavity_weight": 0.05, "minimum_adjacent_normal_dot": 0.42,
			"cavity_keepout": "actual_cavity_semiaxes_plus_warp_blend_and_maximum_trunk_radius", "maximum_route_length_core_semiaxes": 3.5},
		"surface_source": "retained_body_triangle_barycentric", "junctions": "shared_vertex_parent_side_ports",
		"animation_rules": {"create_bone": false, "carrier": "per_vertex_retained_host_weights"},
		"material_rules": {"material": "muscle", "tissue": "vascular_fibrous", "visual_tuning": "deferred"}}

static func validate_recipe(dna: Dictionary, supplied: Dictionary) -> Dictionary:
	var expected := plan(dna)
	if expected.has("error"): return {"valid": false, "mismatches": [expected.error]}
	var audit := {"valid": false, "mismatches": [], "representation_differences": [], "leaf_count": 0}
	Legacy._compare_recipe(expected, supplied, "recipe", audit)
	audit.valid = audit.mismatches.is_empty()
	if audit.valid: audit["canonical"] = expected
	return audit

static func _across(direction: Vector3) -> Vector3:
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	return up.cross(direction).normalized()

static func _probe(sac: Dictionary, direction: Vector3, across: Vector3, target: Dictionary, level: int, side: int) -> Vector3:
	var radial := direction * 0.72 + Vector3.UP * (0.52 + float(target.probe_lift)) + across * float(target.probe_lateral)
	if level == 1: radial = direction * 0.55 + across * (side * 0.72 + float(target.probe_lateral)) + Vector3.UP * ((0.45 if side > 0 else 0.12) + float(target.probe_lift))
	if level == 2: radial = direction * 0.20 + across * (side * 0.92 + float(target.probe_lateral)) + Vector3.UP * ((0.15 if side > 0 else 0.60) + float(target.probe_lift))
	var basis := Basis.from_euler(Graph.vec(sac.rotation))
	return Graph.vec(sac.position) + basis * (Graph.vec(sac.size) * (basis.inverse() * radial).normalized())

static func _candidate(spec: Dictionary, target_index: int, parent_id: String, level: int, start: Vector3, goal: Vector3, radius: float, segment: int, side: int, suffix: int = 0) -> Dictionary:
	var result := Legacy._candidate(spec, target_index, parent_id, level, start, goal, radius, segment, side, suffix)
	result.id = str(spec.targets[target_index].feeder_id) if parent_id.is_empty() else parent_id + ".branch.%s" % suffix
	return result

static func _child(spec: Dictionary, parent: Dictionary, segment: int, side: int, suffix: int, scale: float, body: Dictionary, surface: Dictionary, paths: Array, sac: Dictionary, direction: Vector3, across: Vector3) -> Dictionary:
	var first: Dictionary = parent.samples[segment]; var second: Dictionary = parent.samples[segment + 1]
	var tangent: Vector3 = (Vector3(second.point) - Vector3(first.point)).normalized()
	var local_across := tangent.cross(Vector3(first.normal)).normalized()
	var start := Vector3(first.point).lerp(Vector3(second.point), 0.5) + local_across * side * float(first.radius) * 0.82
	var level := int(parent.level) + 1
	var root_hit := Routes.project(body, surface, start, int(first.triangle), float(first.radius) * 0.6 + scale * 0.01)
	var target: Dictionary = spec.targets[int(parent.target_index)]
	var goal := Routes.endpoint(body, surface, _probe(sac, direction, across, target, level, side), str(target.feature_id), 0.45)
	if root_hit.is_empty() or goal.is_empty(): return {"error": "no_supported_junction_or_sac_side_endpoint"}
	var radius := minf(scale * float(spec.level_radius_fractions[level]), float(first.radius) * float(spec.parent_radius_caps[level]))
	var result := _candidate(spec, int(parent.target_index), str(parent.id), level, root_hit.point, goal.point, radius, segment, side, suffix)
	result["surface_start"] = root_hit; result["surface_goal"] = goal; result["junction_envelope"] = float(first.radius) * 3.0
	var sampled: Dictionary = Legacy._sample_path(body, surface, result, paths, scale, spec)
	if not sampled.get("ok", false): return {"error": sampled.get("reason", "unsupported_branch"), "route_audit": sampled.get("route_audit", {})}
	result.merge(sampled, true)
	result["target_attachment_weight"] = Routes.feature_weight(surface, result.samples[-1], str(target.feature_id))
	parent.children.append(result.id)
	return result

static func build(dna: Dictionary, body: Dictionary, supplied: Dictionary, controls: RefCounted = null) -> Dictionary:
	var checked := validate_recipe(dna, supplied)
	if not checked.valid: return _error("Modified or unsupported blueprint vascular recipe: " + str(checked.mismatches))
	var spec: Dictionary = checked.canonical
	var report := {"version": 1, "seed": int(dna.seed), "status": "planned", "primary_mesh_mutated": false,
		"body_extractions": 0, "new_bones": 0, "rejected_paths": [], "body_weld": false, "visual_validated": false}
	if spec.targets.is_empty(): return {"skipped": true, "reason": "skipped_no_sac_targets", "report": report}
	var nodes := {}
	for node: Dictionary in dna.nodes: nodes[str(node.id)] = node
	var core: Dictionary = nodes[str(spec.core_node_id)]
	var core_size := Graph.vec(core.size); var scale := minf(core_size.x, minf(core_size.y, core_size.z))
	var maximum_radius := 0.0
	for target: Dictionary in spec.targets:
		var size := Graph.vec(nodes[str(target.node_id)].size)
		maximum_radius = maxf(maximum_radius, minf(scale * float(target.radius_fraction), float(spec.target_radius_cap) * minf(size.x, minf(size.y, size.z))))
	var surface := Routes.prepare(dna, body, maximum_radius)
	report["routing"] = {"method": surface.route_source, "retained_triangles": surface.triangles.size(), "excluded_triangles": surface.rejected_triangles, "cavity_exclusions_relaxed": false}
	var paths: Array = []
	for ti in range(spec.targets.size()):
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		var target: Dictionary = spec.targets[ti]; var sac: Dictionary = nodes[str(target.node_id)]
		var direction := Graph.vec(Blueprint.feature(dna.biological_blueprint, str(target.feature_id)).growth_direction).normalized()
		var across := _across(direction)
		var insertion: Dictionary = Legacy._core_insertion(body, surface, core, sac, direction, scale)
		var goal := Routes.endpoint(body, surface, _probe(sac, direction, across, target, 0, 0), str(target.feature_id), 0.45)
		if insertion.is_empty() or goal.is_empty(): report.rejected_paths.append({"id": target.feeder_id, "reason": "no_valid_core_or_sac_endpoint"}); continue
		var size := Graph.vec(sac.size)
		var radius := minf(scale * float(target.radius_fraction), float(spec.target_radius_cap) * minf(size.x, minf(size.y, size.z)))
		var feeder := _candidate(spec, ti, "", 0, insertion.point, goal.point, radius, -1, 1)
		feeder["surface_start"] = insertion; feeder["surface_goal"] = goal
		var sampled: Dictionary = Legacy._sample_path(body, surface, feeder, paths, scale, spec)
		if not sampled.get("ok", false): report.rejected_paths.append({"id": feeder.id, "reason": sampled.get("reason", "unsupported_root"), "route_audit": sampled.get("route_audit", {})}); continue
		feeder.merge(sampled, true)
		feeder["target_attachment_weight"] = Routes.feature_weight(surface, feeder.samples[-1], str(target.feature_id))
		feeder["root_core_weight"] = Routes.feature_weight(surface, insertion, str(spec.core_feature_id))
		paths.append(feeder)
		for child_plan: Dictionary in target.children:
			var segment := clampi(roundi(float(feeder.samples.size() - 2) * float(child_plan.parent_fraction)), 4, feeder.samples.size() - 5)
			var child := _child(spec, feeder, segment, int(child_plan.side), int(child_plan.slot), scale, body, surface, paths, sac, direction, across)
			if child.has("error"): report.rejected_paths.append({"id": child_plan.id, "reason": child.error, "route_audit": child.get("route_audit", {})}); continue
			paths.append(child)
			if not bool(child_plan.twig): continue
			var twig_segment := clampi(roundi(float(child.samples.size() - 2) * 0.48), 4, child.samples.size() - 5)
			var twig := _child(spec, child, twig_segment, int(child_plan.side), 0, scale, body, surface, paths, sac, direction, across)
			if twig.has("error"): report.rejected_paths.append({"id": str(child.id) + ".branch.0", "reason": twig.error, "route_audit": twig.get("route_audit", {})}); continue
			paths.append(twig)
	if paths.is_empty():
		report.status = "skipped_no_safe_routes"
		return {"skipped": true, "reason": "skipped_no_safe_routes", "report": report}
	if paths.size() > MAX_BRANCHES: return _error("Blueprint vascular branch ceiling exceeded.")
	var mesh: Dictionary = Legacy._empty_mesh(body, paths)
	mesh.name = "BlueprintVascularNetwork188"; mesh.geometry_path = KEY
	var host_features := {}; var lookup := {}; var realized: Array = []
	for node_id: String in nodes: host_features[node_id] = str(nodes[node_id].get("feature_id", ""))
	mesh["host_feature_by_node"] = host_features
	for path: Dictionary in paths: lookup[str(path.id)] = path
	for pi in range(paths.size()):
		var path: Dictionary = paths[pi]
		var made: Dictionary = Legacy._sweep(body, surface, mesh, path, lookup.get(str(path.parent_id), {}), paths, pi)
		if made.has("error"): return made
		realized.append(Legacy._record_path(path, spec))
	if mesh.vertices.size() > 6000 or mesh.indices.size() / 3 > MAX_TRIANGLES: return _error("Blueprint vascular aggregate mesh ceiling exceeded.")
	Legacy._recompute_normals(mesh)
	var safe: Dictionary = Legacy.safety_audit(mesh)
	if not safe.valid: return {"error": "Unsafe blueprint vascular geometry.", "safety": safe, "report": report}
	mesh.stats = {"vertices": mesh.vertices.size(), "triangles": mesh.indices.size() / 3, "cell_size": body.get("stats", {}).get("cell_size", 0.0), "welded_to_primary": false}
	var bounds := AABB(mesh.vertices[0], Vector3.ZERO)
	for point: Vector3 in mesh.vertices: bounds = bounds.expand(point)
	mesh["bounds"] = bounds
	var descriptor := spec.duplicate(true); descriptor["branches"] = realized
	descriptor["support_mesh_sha256"] = Legacy.physical_hash(body)
	report.merge({"status": "realized_pending_native_clay", "branches": paths.size(), "vertices": mesh.vertices.size(), "triangles": mesh.indices.size() / 3, "shared_junctions": mesh.junctions.size(), "mesh_safety": safe}, true)
	return {"mesh": mesh, "descriptor": descriptor, "report": report}
