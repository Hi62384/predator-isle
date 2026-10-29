extends RefCounted
## Opt-in Stage 2 V7: a physically posed tissue swath with two scoped pores.
## V1/V2 bar networks are archived and visually rejected. This candidate is not
## promoted without actual same-host clay review.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const FieldQueries = preload("res://alien_foundry/scripts/anatomy/BlobPorousGrowth.gd")
const SurfaceField = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceField.gd")
const PatchField = preload("res://alien_foundry/scripts/geometry/BlobPorousPatchField.gd")
const MAX_ADDED_NODES := 1
const MAX_CANDIDATES := 5
const OPENING_RAY_SAMPLES := 19
const PORE_COUNT := 2
const PORE_CENTERS := [Vector2(-0.06, -0.40), Vector2(0.06, 0.44)]
const EXPECTED_EULER := -4 # Two-pore sheet (genus2) + second disjoint host root adds one handle.

static func grow(g: RefCounted, regions: Dictionary, morphology: Dictionary) -> Dictionary:
	var report := {"candidate": "rounded_compound_tissue_v7", "operation": "porous_webbing", "operation_selector": "webbing", "enabled": false, "surface_stage": 2, "visual_validated": false, "status": "implemented_geometry_candidate", "added_nodes": 0, "node_ids": [], "patch_nodes": [], "opening_witnesses": [], "reused": false, "placement_attempts": 0, "rejections": [], "placement_diagnostics": []}
	if str(g.dna.get("type", "")) != "Blob":
		report["skip_reason"] = "This operator is restricted to Blob anatomy."
		return report
	if not bool(morphology.get("webbing_enabled", false)):
		report["skip_reason"] = "Porous webbing remains an explicit opt-in geometry candidate."
		return report
	var stage := int(morphology.get("pipeline_stage", 2))
	if stage not in [2, 3]:
		report["status"] = "invalid_stage"
		report["error"] = "Webbing cannot modify Stage 1 anatomy."
		return report
	var root_id := str(regions.get("root", ""))
	if g.node(root_id).is_empty():
		report["skip_reason"] = "A valid anatomical host is required."
		return report
	var intensity := clampf(float(morphology.get("intensity", morphology.get("webbing_intensity", 0.75))), 0.0, 1.0)
	if intensity < 0.08:
		report["skip_reason"] = "Webbing intensity is zero."
		return report
	var domain_id := str(morphology.get("domain_id", "host:" + root_id))
	var stream_id := str(morphology.get("stream_id", domain_id + ":webbing"))
	var application_id := str(morphology.get("application_id", stream_id))
	var signature := JSON.stringify({"regions": regions, "morphology": morphology}, "", true, true).sha256_text()
	report.merge({"pipeline_stage": stage, "domain_id": domain_id, "domain_root": root_id, "stream_id": stream_id, "application_id": application_id, "application_signature": signature})
	var applications: Dictionary = g.dna.get("metadata", {}).get("surface_applications", {})
	if applications.has(application_id):
		var old: Dictionary = applications[application_id]
		if str(old.get("application_signature", "")) != signature:
			report["status"] = "application_conflict"
			report["error"] = "This application ID already describes different geometry."
			return report
		report = old.duplicate(true)
		report["reused"] = true
		report["original_added_nodes"] = report.added_nodes
		report["added_nodes"] = 0
		return report
	var streams: Dictionary = g.dna.get("metadata", {}).get("surface_streams", {})
	if streams.has(stream_id):
		report["status"] = "stream_conflict"
		report["error"] = "This random stream already belongs to another application."
		return report
	if int(g.dna.budget.nodes) - g.dna.nodes.size() < MAX_ADDED_NODES:
		report["skip_reason"] = "Insufficient node budget for the complete continuous tissue patch."
		return report
	var quality := clampi(int(g.settings.get("quality", 1)), 0, 2)
	var field: RefCounted = SurfaceField.prepare(g.dna, quality)
	var cell: float = field.production.step / field.scale_value
	var candidates := _candidate_domains(g, regions, morphology, cell)
	var original_count: int = g.dna.nodes.size()
	var original_connections: int = g.dna.connections.size()
	var original_rng: int = g.rng.state
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.dna.seed) ^ int(stream_id.hash()) ^ 0x75B1D3
	for candidate: Dictionary in candidates:
		# Regional streams must not depend on how many previous domains failed.
		if candidate.has("stable_seed"):
			rng.seed = int(g.dna.seed) ^ int(stream_id.hash()) ^ int(candidate.stable_seed) ^ 0x75B1D3
		report.placement_attempts += 1
		var plan := _plan(g, field, candidate, morphology, rng, cell, intensity)
		if plan.has("error"):
			report.rejections.append(str(plan.error))
			report.placement_diagnostics.append({"region_id": candidate.id, "fit": candidate.get("placement_fit", {}), "origin": candidate.region_origin, "extent": candidate.region_extent, "failure": plan})
			continue
		var id: String = g.mass(str(plan.owner), "porous_patch", plan.origin, plan.size, str(candidate.get("tissue_identity", "flesh")), false)
		var node: Dictionary = g.node(id)
		node["rotation"] = Graph.arr(plan.frame.get_euler())
		node["noise"] = 0.0
		node["blend"] = cell * 2.65
		node["shape"] = {"sculpt_strength": 0.0}
		node["porous_patch"] = plan.mark
		node.merge({"blob_region": "porous_webbing", "surface_operation": "porous_webbing", "surface_operation_selector": "webbing", "surface_application": application_id, "surface_domain": domain_id, "surface_stage": 2, "pipeline_stage": stage, "webbing_region_id": candidate.id}, true)
		g.rng.state = original_rng
		var result_field: RefCounted = SurfaceField.prepare(g.dna, quality)
		var proof := _opening_proof(result_field, field, plan, candidate, cell) if result_field.production.preparation_errors.is_empty() else {"ok": false, "reason": "; ".join(result_field.production.preparation_errors)}
		if not bool(proof.ok):
			report.rejections.append(str(proof.reason))
			report.placement_diagnostics.append({"region_id": candidate.id, "failure": proof})
			_rollback(g, original_count, original_connections)
			continue
		report.merge({"enabled": true, "added_nodes": 1, "node_ids": [id], "patch_nodes": [id], "region_id": candidate.id, "placement_fit": candidate.get("placement_fit", {}), "opening_witnesses": proof.witnesses, "opening_count": PORE_COUNT, "thickness_witnesses": plan.thickness_witnesses, "network_components": 1, "minimum_radius": plan.minimum_wall * 0.5, "maximum_radius": plan.maximum_wall * 0.5, "minimum_wall": plan.minimum_wall, "maximum_wall": plan.maximum_wall, "mouth_transition_span": plan.mouth_transition_span, "edge_rounding": plan.edge_rounding, "root_height_shifts": plan.root_height_shifts, "root_height_fit": plan.root_height_fit, "height_only_invariant": plan.height_only_invariant, "root_transition_span": node.blend, "flare_depth": plan.flare_depth, "sampling_step_estimate": cell, "root_count": 6, "attachment_layout": "two_flared_zones_v2", "expected_euler": EXPECTED_EULER, "root_burial_minimum": plan.root_burial_minimum, "lift_range": [0.0, plan.maximum_lift], "coordinate_space": "unscaled_authoring", "field_validated": true, "mesh_validated": false, "reservation": {"operation": "webbing", "node_ids": [id], "position": Graph.arr(plan.origin), "radius": plan.size.length(), "blend_distance": node.blend}}, true)
		if not g.dna.metadata.has("surface_applications"): g.dna.metadata["surface_applications"] = {}
		g.dna.metadata.surface_applications[application_id] = report.duplicate(true)
		if not g.dna.metadata.has("surface_streams"): g.dna.metadata["surface_streams"] = {}
		g.dna.metadata.surface_streams[stream_id] = {"application_id": application_id, "application_signature": signature, "domain_id": domain_id, "pipeline_stage": stage}
		return report
	g.rng.state = original_rng
	report["skip_reason"] = "No region supports a rooted continuous tissue patch with two resolved, air-clear pores."
	return report

static func _candidate_domains(g: RefCounted, regions: Dictionary, morphology: Dictionary, cell: float) -> Array:
	var domains: Array = []
	var records: Array = morphology.get("surface_regions", [])
	for record: Dictionary in records:
		if "webbing" not in record.get("allowed_detail_types", [record.get("primary_detail_type", "")]): continue
		var domain := record.duplicate(true)
		domain["region_normal"] = record.get("growth_direction", record.get("region_normal", [0, 0, -1]))
		var extent := Graph.vec(domain.region_extent)
		# Reject genuinely unresolvable records before spending placement slots.
		if minf(extent.x, extent.y) < cell * 1.90 * 5.6: continue
		domains.append(domain)
		if domains.size() >= MAX_CANDIDATES: break
		# A regional bounding rectangle is not a solid body silhouette. Fit the
		# shared carrier domain inward rather than forcing unsupported roots.
		# Each option stays inside that same record and passes all field tests.
		if domain.get("host_ids", []).size() > 1:
			var origin := Graph.vec(domain.region_origin)
			var normal := Graph.vec(domain.region_normal).normalized()
			var frame := Curves.attachment_frame(origin, normal).basis
			for fit: Vector3 in [Vector3(0.0, -0.08, 0.90), Vector3(-0.12, -0.12, 0.82), Vector3(0.12, -0.12, 0.82)]:
				var fitted := domain.duplicate(true)
				fitted["region_origin"] = Graph.arr(origin + frame.x * extent.x * fit.x + frame.y * extent.y * fit.y)
				fitted["region_extent"] = Graph.arr(extent * fit.z)
				fitted["placement_fit"] = {"relative_offset": [fit.x, fit.y], "extent_scale": fit.z}
				domains.append(fitted)
				if domains.size() >= MAX_CANDIDATES: break
		if domains.size() >= MAX_CANDIDATES: break
	if not records.is_empty(): return domains
	var root_id := str(regions.root)
	var width := maxf(float(morphology.get("width", 1.0)), 0.1)
	var height := maxf(float(morphology.get("height", 1.0)), 0.1)
	var extent := Graph.vec(morphology.get("region_extent", [width * 0.80, height * 0.70, 0.0]))
	var origin: Vector3 = Graph.vec(morphology.get("region_origin", Graph.arr(g.center(root_id) + Vector3(0, height * 0.12, 0))))
	var normal := Graph.vec(morphology.get("region_normal", [0, 0.10, -1])).normalized()
	var frame := Curves.attachment_frame(origin, normal).basis
	var offsets := [Vector2.ZERO, Vector2(-0.20, 0.18), Vector2(0.22, 0.12), Vector2(-0.10, -0.18), Vector2(0.14, 0.27)]
	for i in range(MAX_CANDIDATES):
		var offset: Vector2 = offsets[i]
		domains.append({"id": str(morphology.get("region_id", "webbing_patch")) + ":" + str(i), "region_origin": Graph.arr(origin + frame.x * extent.x * offset.x + frame.y * extent.y * offset.y), "region_normal": Graph.arr(normal), "region_extent": Graph.arr(extent), "host_ids": regions.get("hosts", [root_id]).duplicate(), "tissue_identity": morphology.get("tissue_identity", "flesh")})
	return domains

static func _plan(g: RefCounted, field: RefCounted, domain: Dictionary, morphology: Dictionary, _rng: RandomNumberGenerator, cell: float, intensity: float) -> Dictionary:
	if float(domain.get("density", 1.0)) < 0.08 or float(domain.get("intensity", intensity)) < 0.08: return {"error": "The selected region has zero webbing density or intensity."}
	var extent := Graph.vec(domain.region_extent)
	var size := Vector3(extent.x * 0.79, extent.y * 1.08, minf(extent.x, extent.y) * 0.90)
	var minimum_size := minf(size.x, minf(size.y, size.z))
	if minimum_size < cell * 14.0: return {"error": "The selected tissue patch is too small for two resolved pores and broad walls."}
	var normal := Graph.vec(domain.get("region_normal", [0, 0, -1])).normalized()
	if normal.length_squared() < 0.5: return {"error": "The requested growth direction is invalid."}
	var nominal_origin := Graph.vec(domain.region_origin)
	var center_hit: Dictionary = FieldQueries._actual_surface_crossing(field, nominal_origin, normal, size.length() * 2.0)
	if center_hit.is_empty(): return {"error": "No underlying tissue at the proposed patch center."}
	var origin: Vector3 = center_hit.point
	var frame := Curves.attachment_frame(origin, normal).basis
	var hosts: Array = domain.get("host_ids", domain.get("hosts", [])).duplicate()
	for feature_id: Variant in domain.get("feature_nodes", []):
		if str(feature_id) not in hosts: hosts.append(str(feature_id))
	if hosts.is_empty(): hosts = [str(domain.get("host_id", morphology.get("domain_root", g.dna.nodes[0].id)))]
	var descriptor := _swath_descriptor(field, origin, frame, size, cell)
	if descriptor.has("error"): return descriptor
	var mark: Dictionary = descriptor.mark

	var patch: RefCounted = PatchField.create(mark, size, false)
	if not patch.valid: return {"error": patch.error}
	var burial := INF
	var owner := str(domain.get("host_id", morphology.get("domain_root", g.dna.nodes[0].id)))
	var root_uvs := [Vector2(-0.22, -0.78), Vector2(0.22, -0.78), Vector2(0, -0.94), Vector2(-0.22, 0.78), Vector2(0.22, 0.78), Vector2(0, 0.94)]
	for index in range(6):
		var uv: Vector2 = root_uvs[index]
		var nominal: Vector3 = origin + frame.x * uv.x * size.x + frame.y * uv.y * size.y
		var root_hit: Dictionary = FieldQueries._actual_surface_crossing(field, nominal, normal, size.length() * 2.0)
		if root_hit.is_empty(): return {"error": "A true-coordinate root witness has no host backing.", "margin": index}
		var local := Vector3.ZERO
		var point := Vector3.ZERO
		var host_distance := INF
		var patch_distance := INF
		var nearest := ""
		var best := INF
		var required := cell * 0.35
		var supported := false
		# A smooth host union's outer skin need not belong to one individual
		# influence. Search only inside the existing broad root volume for a
		# truly buried witness; never relax exact-host or patch clearance.
		for depth_cells: float in [1.6, 2.0, 2.4, 2.8, 3.2]:
			local = frame.inverse() * (Vector3(root_hit.point) - origin - normal * cell * depth_cells)
			point = origin + frame * local
			host_distance = field.sample_signed_distance(point)
			patch_distance = patch.distance(local)
			nearest = ""; best = INF
			for host_id: String in hosts:
				var host: Dictionary = g.node(host_id)
				if host.is_empty() or str(host.kind) == "cavity": continue
				var distance := _host_clearance(field, host_id, point)
				if distance < best: best = distance; nearest = host_id
			if not nearest.is_empty() and best <= -required and host_distance <= -required and patch_distance <= -required:
				supported = true; break
		if not supported: return {"error": "A root volume has no bounded fully buried exact-host witness.", "margin": index, "host_id": nearest, "host_clearance": best, "field_clearance": host_distance, "patch_clearance": patch_distance, "required": required, "searched_depth_cells": [1.6, 3.2]}
		if g.node(owner).is_empty(): owner = nearest
		if not _feature_clearance(g, point, cell * 2.0, normal): return {"error": "A patch margin collides with an existing cavity or face."}
		burial = minf(burial, -host_distance)
		mark.attachment_contract.samples.append({"zone": index / 3, "host_id": nearest, "local_point": _qarr(local / size), "required_clearance": _q(required / minimum_size), "host_clearance": _q(host_distance / minimum_size), "patch_clearance": _q(patch_distance / minimum_size)})
	for zone in range(2):
		var points: Array = []
		for index in range(3): points.append(Graph.vec(mark.attachment_contract.samples[zone * 3 + index].local_point) * size)
		var area: float = absf(Vector2(points[1].x - points[0].x, points[1].y - points[0].y).cross(Vector2(points[2].x - points[0].x, points[2].y - points[0].y))) * 0.5
		if area < cell * cell * 4.0: return {"error": "A flared attachment zone has insufficient physical root area.", "zone": zone, "area": area}
		for weights: Vector3 in [Vector3(1, 1, 1) / 3.0, Vector3(0.5, 0.5, 0), Vector3(0, 0.5, 0.5), Vector3(0.5, 0, 0.5)]:
			var local: Vector3 = points[0] * weights.x + points[1] * weights.y + points[2] * weights.z
			var point: Vector3 = origin + frame * local
			if patch.distance(local) > -cell * 0.35 or field.sample_signed_distance(point) > -cell * 0.35 or not _feature_clearance(g, point, cell * 2.0, normal): return {"error": "A flared root triangle is not continuously supported.", "zone": zone}
	patch = PatchField.create(mark, size)
	if not patch.valid: return {"error": patch.error}
	var minimum_wall := INF
	var maximum_wall := 0.0
	var thickness_witnesses: Array = []
	var septum_direction: Vector2 = (PORE_CENTERS[1] - PORE_CENTERS[0]) * Vector2(size.x, size.y)
	var wall_uvs := [(PORE_CENTERS[0] + PORE_CENTERS[1]) * 0.5, Vector2(-0.40, -0.15), Vector2(0.38, 0.10)]
	for index in range(wall_uvs.size()):
		var uv: Vector2 = wall_uvs[index]
		var local := Vector3(uv.x * size.x, uv.y * size.y, patch.mid_height(uv))
		var tangent := Vector3(septum_direction.x, septum_direction.y, 0).normalized() if index == 0 else Vector3.RIGHT
		var normal_probe := local + Vector3(0, 0, cell)
		var physical_normal: Vector3 = patch.gradient(normal_probe, cell * 0.02).normalized()
		if physical_normal.length_squared() < 0.5: return {"error": "The tissue midpoint lacks a stable local normal."}
		for axis: Vector3 in [physical_normal, tangent]:
			var front := _patch_exit(patch, local, axis, minimum_size, cell)
			var back := _patch_exit(patch, local, -axis, minimum_size, cell)
			var thickness := front + back
			if front <= 0.0 or back <= 0.0 or thickness < cell * 2.8: return {"error": "A continuous membrane or septum is below the resolved thickness floor.", "wall_index": index, "thickness": thickness, "required": cell * 2.8, "local_direction": Graph.arr(axis), "local_center": Graph.arr(local), "front": front, "back": back, "diagnostic_size": Graph.arr(size), "diagnostic_mark": mark}
			minimum_wall = minf(minimum_wall, thickness)
			maximum_wall = maxf(maximum_wall, thickness)
			thickness_witnesses.append({"center": Graph.arr(origin + frame * local), "direction": Graph.arr(frame * axis), "thickness": thickness, "reach": minimum_size, "coordinate_space": "unscaled_authoring"})
	# Sample the actual curved membrane against existing cavity openings, not
	# just region rectangles; local voids must never mask an older aperture.
	for y in range(7):
		for x in range(7):
			var uv := Vector2(float(x) / 3.0 - 1.0, float(y) / 3.0 - 1.0)
			var local := Vector3(uv.x * size.x, uv.y * size.y, patch.mid_height(uv))
			if patch.distance(local) < 0.0 and not _feature_clearance(g, origin + frame * local, cell * 2.0, normal): return {"error": "Existing cavity or face intersects the curved tissue membrane."}
	return {"mark": mark, "origin": origin, "size": size, "frame": frame, "normal": normal, "owner": owner, "minimum_wall": minimum_wall, "maximum_wall": maximum_wall, "maximum_lift": patch.arch_lift, "edge_rounding": patch.edge_rounding, "support_overlap": patch.overlap_proof, "root_height_shifts": descriptor.root_height_shifts, "root_height_fit": descriptor.root_height_fit, "height_only_invariant": descriptor.height_only_invariant, "mouth_transition_span": patch.pore_rounding, "flare_depth": cell * 3.0, "root_burial_minimum": burial, "thickness_witnesses": thickness_witnesses}

static func _swath_descriptor(field: RefCounted, origin: Vector3, frame: Basis, size: Vector3, cell: float) -> Dictionary:
	var uv_centers := [Vector2(-0.04, -0.82), Vector2(-0.07, -0.47), Vector2.ZERO, Vector2(0.07, 0.47), Vector2(0.04, 0.82)]
	var centers: Array[Vector3] = []
	var surface_guides: Array[Vector3] = []
	var host_normals: Array[Vector3] = []
	for i in range(uv_centers.size()):
		var uv: Vector2 = uv_centers[i]
		var nominal := origin + frame.x * uv.x * size.x + frame.y * uv.y * size.y
		var hit: Dictionary = FieldQueries._actual_surface_crossing(field, nominal, frame.z, size.length() * 2.0)
		if hit.is_empty(): return {"error": "A true-coordinate swath carrier sample crosses empty silhouette.", "volume": i}
		var surface: Vector3 = hit.point
		var lift: float = cell * float([-3.9, 4.54, 4.90, 4.80, -3.9][i])
		centers.append(frame.inverse() * (surface + frame.z * lift - origin))
		# Visible tissue follows a raised host-surface guide, never a buried
		# support center. Otherwise its thin rootward edge grazes the host
		# outside the broad support zone and creates an opposed-normal cusp.
		var guide_lift := cell * (4.54 if i == 0 else 4.80) if i == 0 or i == 4 else lift
		surface_guides.append(frame.inverse() * (surface + frame.z * guide_lift - origin))
		host_normals.append(frame.inverse() * FieldQueries._field_normal(field, surface, cell * 0.2))
	var widths := [0.52, 0.53, 0.43, 0.43, 0.48]
	# Rounded shoulders extend beneath the entire unchanged support triangles.
	var lengths := [0.38, 0.60, 0.51, 0.60, 0.38]
	var depths := [4.9, 2.75, 2.75, 2.75, 4.9]
	var envelopes: Array = []
	for i in range(centers.size()):
		var guide: Array[Vector3] = centers if i == 0 or i == 4 else surface_guides
		var tangent: Vector3 = (guide[mini(i + 1, 4)] - guide[maxi(i - 1, 0)]).normalized()
		var across: Vector3 = (Vector3.RIGHT - host_normals[i] * host_normals[i].x).normalized()
		var outward: Vector3 = across.cross(tangent).normalized()
		if outward.z < 0.0: outward = -outward
		across = tangent.cross(outward).normalized()
		var pose := Basis(across, tangent, outward)
		var radii := Vector3(size.x * float(widths[i]), size.y * float(lengths[i]), cell * float(depths[i]))
		envelopes.append({"center": _qarr(centers[i] / size), "radii": _qarr(radii / size), "rotation": _qarr(pose.get_euler())})
	var minimum_size := minf(size.x, minf(size.y, size.z))
	var mark := {"enabled": true, "version": 1, "composition": "rounded_tissue_swath_v5", "coordinate_space": "normalized_node_size", "envelopes": envelopes,
		"union_blend": _q(cell * 1.8 / minimum_size), "pore_rounding": _q(cell * 2.8 / minimum_size), "minimum_wall": _q(cell * 2.8 / minimum_size), "maximum_lift": _q(cell * 4.90 / minimum_size),
		"edge_rounding": _q(cell * 2.25 / minimum_size), "overlap_clearance": _q(cell * 0.65 / minimum_size),
		"pores": [{"lobes": [{"center": [-0.06, -0.40], "radii": [0.28, 0.34], "angle": -0.22}], "blend": 0.0}, {"lobes": [{"center": [0.06, 0.44], "radii": [0.16, 0.22], "angle": 0.34}], "blend": 0.0}],
		"attachment_contract": {"field_contract": "production_authoring_v1", "layout": "two_flared_zones_v2", "samples": []}}
	return _fit_root_heights(mark, size, cell)


static func _fit_root_heights(mark: Dictionary, size: Vector3, cell: float) -> Dictionary:
	# Only root center.z changes. Intersect the full-zone raw interval
	# constraints once; this is not a pose/radius search or smoothing repair.
	var shifts: Array = []
	var fit_records: Array = []
	var before := mark.duplicate(true)
	for zone in range(2):
		var index := 0 if zone == 0 else 4
		var original: float = mark.envelopes[index].center[2]
		var helper: RefCounted = PatchField.create(mark, size, false)
		if not helper.valid: return {"error": helper.error}
		var feasible: Dictionary = helper.support_height_interval(zone)
		if not feasible.ok: return {"error": "The full support-zone interval constraints are infeasible.", "overlap": feasible, "diagnostic_size": Graph.arr(size), "diagnostic_mark": mark}
		var required: float = feasible.required_shift
		# Four millionths cover only descriptor/vector rounding, never a cell-
		# scale geometric deficit. Actual stored shift is checked against cap.
		mark.envelopes[index].center[2] = _q(original + required / size.z + (0.000004 if required > 0.0 else 0.0))
		var actual_shift: float = (float(mark.envelopes[index].center[2]) - original) * size.z
		if actual_shift > cell * 4.5 or actual_shift > float(feasible.maximum_feasible_shift): return {"error": "The required full-zone root height exceeds its bounded 4.5-cell fit.", "required_shift": actual_shift, "maximum_shift": cell * 4.5, "overlap": feasible, "diagnostic_size": Graph.arr(size), "diagnostic_mark": mark}
		shifts.append(actual_shift)
		feasible["actual_shift"] = actual_shift
		feasible["center_protrusion_above_sampled_host"] = actual_shift - cell * 3.9
		fit_records.append(feasible)
	var final_helper: RefCounted = PatchField.create(mark, size, false)
	for zone in range(2):
		var proof: Dictionary = final_helper.support_overlap(zone)
		if not proof.ok: return {"error": "Dense support-zone overlap failed after the bounded height-only fit.", "zone": zone, "overlap": proof, "diagnostic_size": Graph.arr(size), "diagnostic_mark": mark}
	var invariant := mark.duplicate(true)
	for index: int in [0, 4]: invariant.envelopes[index].center[2] = before.envelopes[index].center[2]
	if JSON.stringify(invariant, "", true, true) != JSON.stringify(before, "", true, true): return {"error": "A forbidden non-height descriptor channel changed during the root fit."}
	return {"mark": mark, "root_height_shifts": shifts, "root_height_fit": fit_records, "height_only_invariant": true}

static func _host_clearance(field: RefCounted, host_id: String, point: Vector3) -> float:
	var host_index: int = field.production.node_ids.find(host_id)
	var world_point: Vector3 = point * field.scale_value + field.translation
	var distance := INF
	for item in field.production.influences:
		if item.node_index == host_index and not item.subtract:
			distance = minf(distance, (float(item.distance(world_point)) + float(item.amplitude) * 1.8) / field.scale_value)
	return distance

static func _q(value: float) -> float:
	return roundf(value * PatchField.QUANTIZATION) / PatchField.QUANTIZATION

static func _qarr(value: Vector3) -> Array:
	return [_q(value.x), _q(value.y), _q(value.z)]

static func _patch_exit(patch: RefCounted, point: Vector3, direction: Vector3, reach: float, cell: float) -> float:
	if patch.distance(point) >= 0.0: return 0.0
	var previous := 0.0
	var count := ceili(reach / (cell * 0.25))
	for i in range(1, count + 1):
		var current := reach * float(i) / float(count)
		if patch.distance(point + direction * current) >= 0.0:
			for iteration in range(12):
				var middle := (previous + current) * 0.5
				if patch.distance(point + direction * middle) < 0.0: previous = middle
				else: current = middle
			return previous
		previous = current
	return 0.0

static func _feature_clearance(g: RefCounted, point: Vector3, radius: float, normal: Vector3) -> bool:
	for node: Dictionary in g.dna.nodes:
		if str(node.kind) != "cavity": continue
		# Also protect the outward continuation of the existing aperture. An
		# arch floating over a cavity mouth is not a safe independent placement.
		for offset in [0.0, radius * 2.0, radius * 4.0]:
			if Graph.distance_to_tissue(node, point - normal * offset) < radius + float(node.get("porous_growth", {}).get("minimum_wall", 0.0)): return false
	for module: Dictionary in g.dna.get("modules", []):
		var size := Graph.vec(module.get("scale", [0.2, 0.2, 0.2]))
		if point.distance_to(Graph.vec(module.position)) < maxf(size.x, size.y) * 0.60 + radius: return false
	return true

static func _opening_proof(field: RefCounted, host: RefCounted, plan: Dictionary, domain: Dictionary, cell: float) -> Dictionary:
	var witnesses: Array = []
	var extent: Vector3 = plan.size
	var origin: Vector3 = plan.origin
	var normal: Vector3 = plan.normal
	var frame: Basis = plan.frame
	for uv: Vector2 in PORE_CENTERS:
		var nominal := origin + frame.x * extent.x * uv.x + frame.y * extent.y * uv.y
		var hit: Dictionary = FieldQueries._actual_surface_crossing(host, nominal, normal, maxf(extent.x, extent.y) * 3.0)
		if hit.is_empty(): return {"ok": false, "reason": "An aperture has no underlying visible host tissue."}
		var surface: Vector3 = hit.point
		var aperture_radius := cell * 1.18
		var min_clearance := INF
		var worst_point := Vector3.ZERO
		var start: Vector3 = surface + normal * (float(plan.maximum_lift) + float(plan.maximum_wall))
		var end := surface + normal * maxf(cell * 1.55, cell * 1.55)
		for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for j in range(OPENING_RAY_SAMPLES):
				var point: Vector3 = start.lerp(end, float(j) / float(OPENING_RAY_SAMPLES - 1)) + (frame.x * offset.x + frame.y * offset.y) * aperture_radius
				var clearance: float = field.sample_signed_distance(point)
				if clearance < min_clearance:
					min_clearance = clearance
					worst_point = point
		if min_clearance < cell * 0.32: return {"ok": false, "reason": "An authored opening is occluded or below the actual production-field resolution floor.", "opening_index": witnesses.size(), "minimum_clearance": min_clearance, "required_clearance": cell * 0.32, "worst_point": Graph.arr(worst_point), "underlying_host": Graph.arr(surface)}
		witnesses.append({"uv": [uv.x, uv.y], "ray_start": Graph.arr(start), "ray_end": Graph.arr(end), "normal": Graph.arr(normal), "minimum_clearance": min_clearance, "resolved_probe_radius": aperture_radius, "open_depth": start.distance_to(end), "underlying_host": Graph.arr(surface), "coordinate_space": "unscaled_authoring"})
	return {"ok": true, "witnesses": witnesses}

static func _rollback(g: RefCounted, count: int, connections: int) -> void:
	for i in range(count, g.dna.nodes.size()): g.index.erase(str(g.dna.nodes[i].id))
	g.dna.nodes.resize(count)
	g.dna.connections.resize(connections)
