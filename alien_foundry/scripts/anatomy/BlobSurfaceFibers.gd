extends RefCounted
## Opt-in, bounded surface-rooted branching tissue. One source, not scattered tubes.
## All three curves enter the production implicit volume and inherit host controls.
## The default adherent mode follows the true carrier; free tips are explicit.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Field = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceField.gd")
const Regions = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceRegions.gd")
const MAX_ADDED_NODES := 3
const MAX_REGIONS := 5
const MAX_ATTEMPTS := 8
const MODES := ["adherent_fibers", "free_tendrils"]

static func grow(g: RefCounted, anatomy: Dictionary, morphology: Dictionary) -> Dictionary:
	var report := {"candidate": "rooted_branching_fibers_v1", "operation": "fibers", "operation_selector": "fibers",
		"status": "implemented_geometry_candidate", "enabled": false, "added_nodes": 0, "strand_nodes": [],
		"pipeline_stage": int(morphology.get("pipeline_stage", 2)), "surface_stage": 2,
		"visual_validated": false, "mesh_validated": false, "field_validated": false,
		"coordinate_space": "unscaled_authoring", "placement_attempts": 0, "rejections": {}, "reused": false}
	if str(g.dna.get("type", "")) != "Blob":
		report["skip_reason"] = "Fibers are restricted to Blob anatomy."; return report
	if not bool(morphology.get("fibers_enabled", false)):
		report["skip_reason"] = "Fibers remain explicitly opt-in pending individual and mixed clay validation."; return report
	if int(report.pipeline_stage) not in [2, 3]:
		report.status = "invalid_stage"; report["error"] = "Surface fibers cannot modify Stage 1 anatomy."; return report
	var mode := str(morphology.get("fiber_mode", "adherent_fibers"))
	if mode not in MODES:
		report.status = "invalid_mode"; report["error"] = "Adherent fibers and free tendrils must be selected explicitly."; return report
	var root_id := str(anatomy.get("root", ""))
	if g.node(root_id).is_empty():
		report["skip_reason"] = "A valid anatomical host is required."; return report
	var domain_id := str(morphology.get("domain_id", "host:" + root_id))
	var stream_id := str(morphology.get("stream_id", domain_id + ".fibers"))
	var application_id := str(morphology.get("application_id", stream_id))
	var config := morphology.duplicate(true)
	# Realization bookkeeping is mutable; it must not change application identity.
	for record: Dictionary in config.get("surface_regions", []):
		for key in ["feature_nodes", "reservations", "realized_detail_types"]: record.erase(key)
	var signature := JSON.stringify({"anatomy": anatomy, "morphology": config}, "", true, true).sha256_text()
	report.merge({"domain_id": domain_id, "domain_root": root_id, "stream_id": stream_id,
		"application_id": application_id, "application_signature": signature, "fiber_mode": mode})
	var applications: Dictionary = g.dna.metadata.get("surface_applications", {})
	if applications.has(application_id):
		var old: Dictionary = applications[application_id]
		if str(old.get("application_signature", "")) != signature:
			report.status = "application_conflict"; report["error"] = "This application ID already owns different geometry."; return report
		var reused := old.duplicate(true); reused.reused = true; reused.added_nodes = 0; return reused
	if g.dna.metadata.get("surface_streams", {}).has(stream_id):
		report.status = "stream_conflict"; report["error"] = "This named stream belongs to another application."; return report
	if int(g.dna.budget.nodes) - g.dna.nodes.size() < MAX_ADDED_NODES:
		report["skip_reason"] = "Insufficient budget for the complete rooted branching cluster."; return report
	var records := _candidate_regions(g, anatomy, morphology)
	if records.is_empty():
		report["skip_reason"] = "No region permits fibers."; return report
	var field := Field.prepare(g.dna, int(g.settings.get("quality", 1)))
	var cell: float = field.production.step / field.scale_value
	var original_count: int = g.dna.nodes.size()
	var original_connections: int = g.dna.connections.size()
	var original_seed: int = g.rng.seed
	var original_state: int = g.rng.state
	var all_reservations: Array = []
	for record: Dictionary in morphology.get("surface_regions", []): all_reservations.append_array(record.get("reservations", []))
	var contexts: Array = []
	for record: Dictionary in records: contexts.append({"record": record, "carrier": {}})
	# Existing attempts always run first, with their original streams and data.
	# Only adherent tissue may subsequently attach to a real, already fused sac.
	var carriers := _grown_carrier_contexts(g, field, records, cell) if mode == "adherent_fibers" else {"contexts": [], "diagnostics": [], "present": false}
	contexts.append_array(carriers.contexts)
	var clearance_causes: Dictionary = {}
	for context: Dictionary in contexts:
		var record: Dictionary = context.record
		var carrier: Dictionary = context.carrier
		if float(record.get("density", 1.0)) <= 0.001 or float(record.get("intensity", 1.0)) <= 0.001: continue
		var rng := RandomNumberGenerator.new()
		var suffix := "" if carrier.is_empty() else ".carrier." + str(carrier.id)
		rng.seed = Regions.stream_seed(int(g.dna.seed), str(record.id) + "." + stream_id + suffix)
		if not carrier.is_empty():
			report["carrier_candidates"] = carriers.diagnostics.duplicate(true)
			if not report.has("carrier_attempts"): report["carrier_attempts"] = []
		for attempt in range(MAX_ATTEMPTS):
			report.placement_attempts += 1
			var attempt_report: Dictionary = {}
			if not carrier.is_empty():
				attempt_report = {"carrier_id": str(carrier.id), "region_id": str(record.id), "attempt": attempt, "accepted": false}
				report.carrier_attempts.append(attempt_report)
			var plan := _plan(g, field, record, all_reservations, morphology, mode, cell, attempt, rng, carrier)
			if plan.has("error"):
				if bool(carriers.present) and plan.has("clearance_reason"):
					var cause := str(plan.clearance_reason)
					clearance_causes[cause] = int(clearance_causes.get(cause, 0)) + 1
				if not attempt_report.is_empty():
					attempt_report["reason"] = str(plan.error)
					if plan.has("clearance_reason"): attempt_report["clearance_reason"] = str(plan.clearance_reason)
				_reject(report, str(plan.error)); continue
			var ids: Array = []
			for index in range(MAX_ADDED_NODES):
				var curve: Dictionary = plan.curves[index]
				g.rng.seed = Regions.stream_seed(int(g.dna.seed), str(record.id) + "." + stream_id + suffix + ".node." + str(index))
				var parent := str(plan.owner) if index == 0 else str(ids[0])
				var id: String = g.curve(parent, "surface_fiber" if str(curve.mode) == "adherent_fibers" else "surface_tendril", curve.points, curve.radii, str(record.get("tissue_identity", "flesh")), false)
				var node: Dictionary = g.node(id)
				node.noise = 0.0; node.blend = plan.blend
				node.shape = {"swelling": 0.0, "twist": 0.0, "taper": 0.0, "width": 1.0, "depth": 1.0}
				node.deformation = {"phase": rng.randf_range(0.0, 100.0), "warp": 0.0, "fold_frequency": 2.0}
				node.merge({"surface_operation": "fibers", "surface_operation_selector": "fibers", "surface_stage": 2,
					"pipeline_stage": report.pipeline_stage, "surface_application": application_id, "surface_domain": domain_id,
					"surface_region_id": str(record.id), "blob_region": "fibrous_growth", "fiber_mode": str(curve.mode),
					"fiber_cluster": application_id, "fiber_branch_parent": "" if index == 0 else str(ids[0]),
					"fiber_branch_knot": int(curve.get("branch_knot", -1)), "fiber_free_tip": str(curve.mode) == "free_tendrils",
					"rig_owner": str(plan.owner), "growth_origin": Graph.arr(plan.origin),
					"surface": {"growth": 0.38, "exposure": 0.16, "flow": 0.94,
						"tissue_identity": str(record.get("tissue_identity", "flesh")), "detail_type": "fibers",
						"intensity": float(record.get("intensity", 1.0)), "region_seed": int(record.get("stable_seed", rng.seed))},
					"placement_audit": {"geometry_integration": "smooth_union_same_volume", "host_thickness": plan.thickness,
						"root_burial": plan.root_burial, "root_radius": plan.root_radius, "sampling_step": cell,
						"root_transition_depth": plan.root_transition_depth, "root_transition_radius": plan.root_transition_radius,
						"maximum_length": plan.maximum_length, "minimum_radius": plan.minimum_radius,
						"surface_follow": str(curve.mode) == "adherent_fibers", "shared_tangent_departure": index > 0}})
				if not carrier.is_empty():
					node["fiber_carrier_id"] = str(carrier.id)
					node["fiber_carrier_parent"] = str(carrier.parent)
					node["fiber_attachment_contract"] = plan.carrier_proof.duplicate(true)
				ids.append(id)
			g.rng.seed = original_seed; g.rng.state = original_state
			var result_field := Field.prepare(g.dna, int(g.settings.get("quality", 1)))
			var proof := _field_proof(field, result_field, plan, ids)
			if not bool(proof.ok):
				if not attempt_report.is_empty(): attempt_report["reason"] = str(proof.reason)
				_reject(report, str(proof.reason)); _rollback(g, original_count, original_connections); continue
			for id: String in ids: Regions.reserve(record, "fibers", g.node(id))
			report.merge({"enabled": true, "added_nodes": ids.size(), "strand_nodes": ids, "region_id": str(record.id),
				"cluster_count": 1, "branch_count": 2, "root_count": 1, "field_validated": true,
				"rig_owner": str(plan.owner), "growth_origin": Graph.arr(plan.origin), "root_burial": plan.root_burial,
				"root_transition_depth": plan.root_transition_depth, "root_transition_radius": plan.root_transition_radius,
				"minimum_radius": plan.minimum_radius, "maximum_radius": plan.root_radius, "sampling_step": cell,
				"host_thickness": plan.thickness, "maximum_length": plan.maximum_length, "exposure_witnesses": proof.witnesses,
				"geometry_integration": "smooth_union_same_volume", "reservations": record.reservations.duplicate(true)}, true)
			if not carrier.is_empty():
				attempt_report["accepted"] = true
				report["placement_context"] = "adherent_grown_sac_carrier"
				report["carrier_id"] = str(carrier.id); report["carrier_parent"] = str(carrier.parent)
				report["carrier_attachment_proof"] = plan.carrier_proof.duplicate(true)
				report["clearance_rejections"] = clearance_causes.duplicate(true)
			if not g.dna.metadata.has("surface_applications"): g.dna.metadata["surface_applications"] = {}
			if not g.dna.metadata.has("surface_streams"): g.dna.metadata["surface_streams"] = {}
			g.dna.metadata.surface_applications[application_id] = report.duplicate(true)
			g.dna.metadata.surface_streams[stream_id] = {"application_id": application_id, "application_signature": signature, "domain_id": domain_id, "pipeline_stage": report.pipeline_stage}
			return report
	g.rng.seed = original_seed; g.rng.state = original_state
	if bool(carriers.present):
		report["carrier_candidates"] = carriers.diagnostics.duplicate(true)
		report["clearance_rejections"] = clearance_causes.duplicate(true)
	report["skip_reason"] = "No region safely supports one complete visible rooted cluster at this resolution."
	return report

static func _subset_value(field: RefCounted, indices: PackedInt32Array, point: Vector3) -> float:
	return float(field.production._field_value(point * field.scale_value + field.translation, indices)) / field.scale_value

static func _grown_carrier_contexts(g: RefCounted, field: RefCounted, records: Array, cell: float) -> Dictionary:
	var contexts: Array = []; var diagnostics: Array = []; var present := false
	for record: Dictionary in records:
		var host: Dictionary = g.node(str(record.get("host_id", "")))
		if host.is_empty(): continue
		var host_size := Graph.vec(host.size)
		var local_scale := minf(host_size.x, minf(host_size.y, host_size.z))
		var feature_scale := clampf(float(record.get("scale", 1.0)), 0.65, 1.25)
		var radius := maxf(cell * 2.25, local_scale * 0.105 * feature_scale)
		for id_value in record.get("feature_nodes", []):
			var sac: Dictionary = g.node(str(id_value))
			if sac.is_empty() or str(sac.get("kind", "")) != "mass" or str(sac.get("surface_operation", "")) != "sacs": continue
			if str(sac.get("surface_region_id", "")) != str(record.id) or str(sac.parent) not in record.get("host_ids", []): continue
			present = true
			var diagnostic := {"carrier_id": str(sac.id), "region_id": str(record.id), "eligible": false}
			diagnostics.append(diagnostic)
			# Retain the original region's template budget. A larger label or sac
			# never rescues a region that cannot resolve the unchanged cluster.
			if radius > local_scale * 0.21 or local_scale * 1.40 * feature_scale * 1.06 < radius * 6.0:
				diagnostic["reason"] = "regional_resolution"; continue
			var carrier_indices := PackedInt32Array(); var backing_indices := PackedInt32Array()
			for index in range(field.production.influences.size()):
				var item: RefCounted = field.production.influences[index]
				var id := str(field.production.node_ids[item.node_index])
				if id == str(sac.id) and not bool(item.subtract): carrier_indices.append(index)
				if bool(item.subtract) or id in record.get("host_ids", []): backing_indices.append(index)
			if carrier_indices.is_empty() or backing_indices.is_empty():
				diagnostic["reason"] = "missing_physical_carrier_or_backing"; continue
			var center := Graph.vec(sac.position); var size := Graph.vec(sac.size); var basis := Graph.node_basis(sac)
			var margin := maxf(float(record.get("minimum_wall", cell)) * 0.20, cell * 0.10)
			var witness: Dictionary = {}
			for depth: float in [0.0, 0.22]:
				for offset: Vector2 in [Vector2.ZERO, Vector2(0.45, 0), Vector2(-0.45, 0), Vector2(0, 0.45), Vector2(0, -0.45)]:
					var point := center + basis.x * size.x * offset.x + basis.y * size.y * offset.y - basis.z * size.z * depth
					var carrier_distance := _subset_value(field, carrier_indices, point)
					var backing_distance := _subset_value(field, backing_indices, point)
					var full_distance: float = field.sample_signed_distance(point)
					if maxf(carrier_distance, maxf(backing_distance, full_distance)) <= -margin:
						witness = {"point": Graph.arr(point), "carrier_distance": carrier_distance, "original_host_distance": backing_distance,
							"full_field_distance": full_distance, "required_margin": margin, "base_host_ids": record.host_ids.duplicate()}
						break
				if not witness.is_empty(): break
			if witness.is_empty():
				diagnostic["reason"] = "no_solid_carrier_base_overlap"; continue
			diagnostic["eligible"] = true; diagnostic["attachment_witness"] = witness.duplicate(true)
			contexts.append({"record": record, "carrier": {"id": str(sac.id), "parent": str(sac.parent),
				"indices": carrier_indices, "attachment_witness": witness, "volume": size.x * size.y * size.z}})
	contexts.sort_custom(_larger_carrier)
	if contexts.size() > 2: contexts.resize(2)
	return {"contexts": contexts, "diagnostics": diagnostics, "present": present}

static func _larger_carrier(first: Dictionary, second: Dictionary) -> bool:
	if float(first.carrier.volume) != float(second.carrier.volume): return float(first.carrier.volume) > float(second.carrier.volume)
	return str(first.carrier.id).naturalnocasecmp_to(str(second.carrier.id)) < 0

static func _candidate_regions(g: RefCounted, anatomy: Dictionary, morphology: Dictionary) -> Array:
	var result: Array = []
	for record: Dictionary in morphology.get("surface_regions", []):
		if "fibers" not in record.get("allowed_detail_types", []): continue
		result.append(record)
		if result.size() >= MAX_REGIONS: break
	if not morphology.get("surface_regions", []).is_empty(): return result
	var root := str(anatomy.root)
	var host: Dictionary = g.node(root)
	var normal := Graph.vec(morphology.get("region_normal", [0, 0.28, -1])).normalized()
	result.append({"id": str(morphology.get("domain_id", root)) + ".fiber_patch", "host_id": root,
		"host_ids": anatomy.get("hosts", [root]).duplicate(), "region_origin": host.position.duplicate(),
		"region_extent": host.size.duplicate(), "growth_direction": Graph.arr(normal), "density": 1.0,
		"scale": 1.0, "intensity": 0.75, "blend_distance": 0.025, "tissue_identity": "flesh",
		"minimum_wall": 0.035, "support_ids": anatomy.get("support_ids", []).duplicate(),
		"feature_nodes": [], "reservations": [], "realized_detail_types": []})
	return result

static func _plan(g: RefCounted, field: RefCounted, record: Dictionary, reservations: Array, morphology: Dictionary, mode: String, cell: float, attempt: int, rng: RandomNumberGenerator, carrier: Dictionary = {}) -> Dictionary:
	var host: Dictionary = g.node(str(record.get("host_id", "")))
	if host.is_empty(): return {"error": "host"}
	var size := Graph.vec(host.size)
	var local_scale := minf(size.x, minf(size.y, size.z))
	var feature_scale := clampf(float(record.get("scale", 1.0)), 0.65, 1.25)
	var radius := maxf(cell * 2.25, local_scale * 0.105 * feature_scale)
	var minimum := maxf(cell * 1.12, 0.026)
	var length := local_scale * 1.40 * feature_scale * rng.randf_range(0.90, 1.06)
	# Refuse to inflate a small region into coarse tubes merely to pass a voxel floor.
	if radius > local_scale * 0.21 or length < radius * 6.0: return {"error": "regional_resolution"}
	var direction := Graph.vec(record.get("growth_direction", [0, 0.25, -1])).normalized()
	var anchor_host: Dictionary = host
	if not carrier.is_empty():
		anchor_host = g.node(str(carrier.id))
		if anchor_host.is_empty(): return {"error": "missing_carrier"}
		direction = Graph.node_basis(anchor_host).z
		var filtered: Array = []
		for reservation: Dictionary in reservations:
			# Only the one selected, physically proven carrier is tissue to
			# adhere to. Other growths and every hollow structure remain obstacles.
			var ids: Array = reservation.get("node_ids", [])
			if str(reservation.get("operation", "")) == "sacs" and ids.size() == 1 and str(ids[0]) == str(carrier.id): continue
			filtered.append(reservation)
		reservations = filtered
	var frame := Curves.attachment_frame(Vector3.ZERO, direction).basis
	var phase := float(attempt) * 2.39996323
	var spread := 0.14 + float(attempt) * 0.065
	var outward := (direction + frame.x * cos(phase) * spread + frame.y * (0.38 + sin(phase) * spread)).normalized()
	var nominal := Graph.vec(anchor_host.position) + outward * Graph.surface_radius(Graph.vec(anchor_host.size), Graph.node_basis(anchor_host).inverse() * outward)
	var origin: Vector3 = field.project(nominal, outward)
	var normal: Vector3 = field.normal_at(origin, cell * 0.25)
	if absf(field.sample_signed_distance(origin)) > cell * 0.15 or normal.dot(outward) < 0.55: return {"error": "surface"}
	var owner := ""
	var owner_distance := INF
	if not carrier.is_empty():
		owner = str(carrier.id)
		owner_distance = _subset_value(field, carrier.indices, origin - normal * radius * 1.65)
	else:
		for id_value in record.get("host_ids", [str(record.host_id)]):
			var id := str(id_value); var candidate: Dictionary = g.node(id)
			if candidate.is_empty() or str(candidate.get("kind", "")) != "mass": continue
			var distance: float = Graph.distance_to_tissue(candidate, origin - normal * radius * 1.65)
			if distance < owner_distance: owner = id; owner_distance = distance
	if owner.is_empty() or owner_distance > -radius * 0.20: return {"error": "owner_burial"}
	var wall := float(record.get("minimum_wall", cell))
	var thickness: float = field.thickness(origin, normal, local_scale * 3.0, cell * 0.5)
	if thickness < radius * 3.0 + wall * 2.0: return {"error": "thickness"}
	var flow := Vector3.DOWN + frame.x * rng.randf_range(-0.22, 0.22)
	flow = (flow - normal * flow.dot(normal)).normalized()
	if flow.length_squared() < 0.5: return {"error": "flow"}
	var trunk := _trace(g, field, record, reservations, origin, normal, flow, length, radius, minimum, cell, rng.randf_range(-0.19, 0.19), false, true)
	if trunk.has("error"): return trunk
	trunk["mode"] = "adherent_fibers"
	var curves: Array = [trunk]
	for branch in range(2):
		var knot := 3 if branch == 0 else 5
		var start: Vector3 = trunk.surfaces[knot]
		var n: Vector3 = trunk.normals[knot]
		var tangent: Vector3 = (trunk.surfaces[knot] - trunk.surfaces[knot - 1]).normalized()
		var branch_length := length * (0.70 if branch == 0 else 0.49) * rng.randf_range(0.93, 1.06)
		var bend := (0.94 if branch == 0 else -1.12) * rng.randf_range(0.92, 1.08)
		var split := _trace(g, field, record, reservations, start, n, tangent, branch_length, radius * (0.77 if branch == 0 else 0.63), minimum, cell, bend, mode == "free_tendrils", false)
		if split.has("error"): return split
		# A shared section and matching departure tangent make an actual fork.
		# The split is not an independent cap seated somewhere near the stem.
		split.points[0] = trunk.points[knot - 1]
		split.points.insert(1, trunk.points[knot])
		split.radii[0] = maxf(minimum, float(trunk.radii[knot - 1]) * 0.77)
		split.radii.insert(1, maxf(minimum, float(trunk.radii[knot]) * 0.80))
		split["mode"] = mode; split["branch_knot"] = knot
		curves.append(split)
	var root_point: Vector3 = trunk.points[0]
	var root_burial := -float(field.sample_signed_distance(root_point))
	if root_burial < float(trunk.radii[0]) * 1.05: return {"error": "root_burial"}
	var carrier_proof: Dictionary = {}
	if not carrier.is_empty():
		var carrier_root_distance := _subset_value(field, carrier.indices, root_point)
		var required_carrier_burial := float(trunk.radii[0]) * 0.20
		if carrier_root_distance > -required_carrier_burial: return {"error": "carrier_root_burial"}
		carrier_proof = {"carrier_id": str(carrier.id), "anatomical_parent": str(carrier.parent),
			"root_point": Graph.arr(root_point), "carrier_root_distance": carrier_root_distance,
			"required_carrier_burial": required_carrier_burial, "full_field_root_burial": root_burial,
			"base_overlap": carrier.attachment_witness.duplicate(true), "resolution_host_id": str(record.host_id),
			"excluded_reservation_node_ids": [str(carrier.id)], "coordinate_space": "unscaled_authoring"}
	# A buried endpoint alone does not guarantee a smooth emergence: a steep
	# early ramp made a small nub on a real crest. Keep the first quarter mostly
	# buried, checked against the actual field rather than just its normal offset.
	var transition_depth := -float(field.sample_signed_distance(trunk.points[2]))
	if transition_depth < float(trunk.radii[2]) * 0.75: return {"error": "abrupt_root_emergence"}
	for curve: Dictionary in curves:
		var sample := Curves.sample(curve, 5, true)
		for i in range(sample.points.size()):
			var point: Vector3 = sample.points[i]
			var r: float = sample.radii[i]
			var clearance := _clearance_reason(g, record, reservations, point, r, wall)
			if not clearance.is_empty(): return {"error": "sampled_clearance", "clearance_reason": clearance}
			if point.y - r < -field.translation.y / field.scale_value + cell: return {"error": "ground"}
			if point.distance_to(origin) > length * 1.65: return {"error": "regional_extent"}
	var result := {"curves": curves, "owner": owner, "origin": origin, "normal": normal,
		"root_burial": root_burial, "root_radius": trunk.radii[0], "minimum_radius": minimum,
		"root_transition_depth": transition_depth, "root_transition_radius": trunk.radii[2],
		"maximum_length": length * 1.65, "thickness": thickness, "blend": radius * 0.48}
	if not carrier_proof.is_empty(): result["carrier_proof"] = carrier_proof
	return result

static func _trace(g: RefCounted, field: RefCounted, record: Dictionary, reservations: Array, origin: Vector3, initial_normal: Vector3, flow: Vector3, length: float, radius: float, minimum: float, cell: float, bend: float, free: bool, stem: bool) -> Dictionary:
	var points: Array = []; var radii: Array = []; var surfaces: Array = []; var normals: Array = []
	var surface := origin; var normal := initial_normal; var tangent := flow
	var wall := float(record.get("minimum_wall", cell))
	for i in range(9):
		var t := float(i) / 8.0
		if i > 0:
			# Parallel transport carries the anatomical flow around convex sacs.
			# Local obstacle gradients steer around joints rather than crossing them.
			var steering := _avoidance(g, record, reservations, surface, radius, wall)
			var desired := tangent.rotated(normal, bend / 8.0) + steering * 0.26
			desired -= normal * desired.dot(normal)
			if desired.length_squared() < 0.1: return {"error": "flow"}
			tangent = desired.normalized()
			var predicted := surface + tangent * length / 8.0
			var projected: Vector3 = field.project(predicted, normal)
			if projected.distance_to(predicted) > length * 0.20 or absf(field.sample_signed_distance(projected)) > cell * 0.16: return {"error": "surface_continuity"}
			var next_normal: Vector3 = field.normal_at(projected, cell * 0.25)
			if next_normal.dot(normal) < 0.65: return {"error": "surface_curvature"}
			surface = projected; normal = next_normal
		var r := maxf(minimum, radius * lerpf(1.12, 0.42, pow(t, 0.85)))
		var burial := lerpf(1.65, 0.17, smoothstep(0.0, 0.52, t)) if stem else 0.17
		if not free: burial = lerpf(burial, 1.18, smoothstep(0.77, 1.0, t))
		var point := surface - normal * r * burial
		if free:
			# A bounded outward bow, not a long replicated hanging tube. The
			# asymmetrical tapered end is explicitly free instead of reattached.
			point += normal * length * 0.30 * smoothstep(0.0, 0.88, t)
			point += Vector3.DOWN * length * 0.10 * t * t
		var clearance := _clearance_reason(g, record, reservations, point, r, wall)
		if not clearance.is_empty(): return {"error": "clearance", "clearance_reason": clearance}
		points.append(point); radii.append(r); surfaces.append(surface); normals.append(normal)
	return {"points": points, "radii": radii, "surfaces": surfaces, "normals": normals,
		"shape": {"swelling": 0.0, "twist": 0.0, "taper": 0.0}}

static func _clear(g: RefCounted, record: Dictionary, reservations: Array, point: Vector3, radius: float, wall: float) -> bool:
	return _clearance_reason(g, record, reservations, point, radius, wall).is_empty()

static func _clearance_reason(g: RefCounted, record: Dictionary, reservations: Array, point: Vector3, radius: float, wall: float) -> String:
	if not Regions.support_clear(g, record, point, radius): return "support"
	for reservation: Dictionary in reservations:
		if Regions.conflicts(point, radius, [reservation], wall * 0.15, "fibers"):
			return "reservation:" + str(reservation.get("operation", "unknown"))
	for node: Dictionary in g.dna.nodes:
		if str(node.get("kind", "")) == "cavity" and Graph.distance_to_tissue(node, point) < radius + wall: return "cavity"
	for module: Dictionary in g.dna.get("modules", []):
		var size := Graph.vec(module.get("scale", [0.2, 0.2, 0.2]))
		if point.distance_to(Graph.vec(module.position)) < maxf(size.x, maxf(size.y, size.z)) * 0.65 + radius + wall: return "module"
	return ""

static func _avoidance(g: RefCounted, record: Dictionary, reservations: Array, point: Vector3, radius: float, wall: float) -> Vector3:
	var result := Vector3.ZERO
	for id in record.get("support_ids", []):
		var support: Dictionary = g.node(str(id))
		if support.is_empty(): continue
		var gap := Graph.distance_to_tissue(support, point) - radius - wall
		if gap < radius * 4.0: result += (point - Graph.vec(support.position)).normalized() * clampf(1.0 - gap / (radius * 4.0), 0.0, 1.0)
	for reservation: Dictionary in reservations:
		var delta := point - Graph.vec(reservation.get("position", reservation.get("center", [])))
		var gap := delta.length() - float(reservation.get("radius", 0.0)) - radius
		if gap < radius * 4.0: result += delta.normalized() * clampf(1.0 - gap / (radius * 4.0), 0.0, 1.0)
	return result.limit_length(1.0)

static func _field_proof(host: RefCounted, result: RefCounted, plan: Dictionary, ids: Array) -> Dictionary:
	for id: String in ids:
		for node: Dictionary in result.production.source_dna.nodes:
			if str(node.id) == "bridge_" + id: return {"ok": false, "reason": "unexpected_graph_bridge"}
	for key in ["attachment_collars", "thin_features"]:
		for item: Dictionary in result.production.geometry_adjustments.get(key, []):
			if str(item.get("node_id", "")) in ids: return {"ok": false, "reason": "unexpected_" + key}
	var witnesses: Array = []
	for i in range(plan.curves.size()):
		var curve: Dictionary = plan.curves[i]
		var found := false
		for knot in [4, 5, 6]:
			var point: Vector3 = curve.points[knot]
			var normal: Vector3 = host.normal_at(point, float(plan.minimum_radius) * 0.15)
			var witness := point + normal * float(curve.radii[knot]) * 0.78
			var before: float = host.sample_signed_distance(witness)
			var after: float = result.sample_signed_distance(witness)
			if before > float(plan.minimum_radius) * 0.22 and after < -float(plan.minimum_radius) * 0.08:
				witnesses.append({"node_id": ids[i], "point": Graph.arr(witness), "normal": Graph.arr(normal), "host_distance": before, "grown_distance": after})
				found = true; break
		if not found: return {"ok": false, "reason": "buried_or_unresolved_strand"}
	return {"ok": true, "witnesses": witnesses}

static func _reject(report: Dictionary, reason: String) -> void:
	report.rejections[reason] = int(report.rejections.get(reason, 0)) + 1

static func _rollback(g: RefCounted, count: int, connections: int) -> void:
	for i in range(count, g.dna.nodes.size()): g.index.erase(str(g.dna.nodes[i].id))
	g.dna.nodes.resize(count); g.dna.connections.resize(connections)
