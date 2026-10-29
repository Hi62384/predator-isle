extends RefCounted
## Candidate G: one localized, coherent knot of broad folded cartilage ribbons.
## This is an additive implicit structure, not the mixed-surface checkbox, thin
## fibers, independent torus copies, a cage, or a blanket of random primitives.
## Each fold shares actual tissue with the principal fold and returns to skin.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Field = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceField.gd")
const Regions = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceRegions.gd")
const MAX_ADDED_NODES := 3
const MAX_REGIONS := 5
const MAX_ATTEMPTS := 7
const AUTHORING_SUBDIVISIONS := 3

static func grow(g: RefCounted, anatomy: Dictionary, morphology: Dictionary) -> Dictionary:
	var report := {"candidate": "fused_cartilage_folds_v3", "operation": "messy_tissue", "operation_selector": "messy_tissue",
		"status": "implemented_geometry_candidate", "enabled": false, "added_nodes": 0, "fold_nodes": [],
		"pipeline_stage": int(morphology.get("pipeline_stage", 2)), "surface_stage": 2,
		"visual_validated": false, "mesh_validated": false, "field_validated": false,
		"coordinate_space": "unscaled_authoring", "placement_attempts": 0, "rejections": {}, "reused": false}
	if str(g.dna.get("type", "")) != "Blob":
		report["skip_reason"] = "Messy tissue is restricted to Blob anatomy."; return report
	if not bool(morphology.get("messy_tissue_enabled", false)):
		report["skip_reason"] = "Folded tissue remains explicitly opt-in pending component and public clay validation."; return report
	if int(report.pipeline_stage) not in [2, 3]:
		report.status = "invalid_stage"; report["error"] = "Folded tissue cannot modify pure Stage 1 anatomy."; return report
	var root_id := str(anatomy.get("root", ""))
	if g.node(root_id).is_empty():
		report["skip_reason"] = "A valid anatomical host is required."; return report
	var domain_id := str(morphology.get("domain_id", "host:" + root_id))
	var stream_id := str(morphology.get("stream_id", domain_id + ".messy_tissue"))
	var application_id := str(morphology.get("application_id", stream_id))
	var config := morphology.duplicate(true)
	for record: Dictionary in config.get("surface_regions", []):
		for key in ["feature_nodes", "reservations", "realized_detail_types"]: record.erase(key)
	var signature := JSON.stringify({"anatomy": anatomy, "morphology": config}, "", true, true).sha256_text()
	report.merge({"domain_id": domain_id, "domain_root": root_id, "stream_id": stream_id,
		"application_id": application_id, "application_signature": signature})
	var applications: Dictionary = g.dna.metadata.get("surface_applications", {})
	if applications.has(application_id):
		var old: Dictionary = applications[application_id]
		if str(old.get("application_signature", "")) != signature:
			report.status = "application_conflict"; report["error"] = "This application ID already owns different geometry."; return report
		var reused := old.duplicate(true); reused.reused = true; reused.added_nodes = 0; return reused
	if g.dna.metadata.get("surface_streams", {}).has(stream_id):
		report.status = "stream_conflict"; report["error"] = "This named stream belongs to another application."; return report
	if int(g.dna.budget.nodes) - g.dna.nodes.size() < MAX_ADDED_NODES:
		report["skip_reason"] = "Insufficient budget for the complete connected folded-tissue cluster."; return report
	var records: Array = []
	for record: Dictionary in morphology.get("surface_regions", []):
		if "messy_tissue" not in record.get("allowed_detail_types", []): continue
		records.append(record)
		if records.size() >= MAX_REGIONS: break
	if records.is_empty():
		report["skip_reason"] = "No explicit surface region permits messy tissue."; return report
	var field := Field.prepare(g.dna, int(g.settings.get("quality", 1)))
	var cell: float = field.production.step / field.scale_value
	report["sampling_step"] = cell
	var original_count: int = g.dna.nodes.size()
	var original_connections: int = g.dna.connections.size()
	var original_seed: int = g.rng.seed; var original_state: int = g.rng.state
	var reservations: Array = []
	for record: Dictionary in morphology.get("surface_regions", []): reservations.append_array(record.get("reservations", []))
	for record: Dictionary in records:
		if float(record.get("density", 1.0)) <= 0.001 or float(record.get("intensity", 1.0)) <= 0.001:
			_reject(report, "region_disabled"); continue
		var rng := RandomNumberGenerator.new()
		rng.seed = Regions.stream_seed(int(g.dna.seed), str(record.id) + "." + stream_id)
		for attempt in range(MAX_ATTEMPTS):
			report.placement_attempts += 1
			var plan := _plan(g, field, record, reservations, cell, attempt, rng)
			if plan.has("error"):
				_reject(report, str(plan.error)); continue
			var ids: Array = []
			var authored := _dense_authoring(plan.curves)
			for index in range(MAX_ADDED_NODES):
				var curve: Dictionary = authored[index]
				g.rng.seed = Regions.stream_seed(int(g.dna.seed), str(record.id) + "." + stream_id + ".node." + str(index))
				var parent := str(plan.owner) if index == 0 else str(ids[0])
				var id: String = g.curve(parent, "surface_cartilage_fold", curve.points, curve.radii, str(record.get("tissue_identity", "flesh")), false)
				var node: Dictionary = g.node(id)
				node.noise = 0.0; node.blend = plan.blend; node.shape = curve.shape.duplicate(true)
				node.deformation = {"phase": rng.randf_range(0.0, 100.0), "warp": 0.0, "fold_frequency": 2.0}
				node.merge({"surface_operation": "messy_tissue", "surface_operation_selector": "messy_tissue", "surface_stage": 2,
					"pipeline_stage": report.pipeline_stage, "surface_application": application_id, "surface_domain": domain_id,
					"surface_region_id": str(record.id), "blob_region": "folded_tissue", "tissue_cluster": application_id,
					"tissue_fold_role": ["principal_fold", "interlocking_fold", "collapsed_fold"][index],
					"shared_fold_knot": int(curve.get("shared_knot", -1)), "rig_owner": str(plan.owner), "growth_origin": Graph.arr(plan.origin),
					"surface": {"growth": 0.64, "exposure": 0.28, "flow": 0.82,
						"tissue_identity": str(record.get("tissue_identity", "flesh")), "detail_type": "messy_tissue",
						"intensity": float(record.get("intensity", 1.0)), "region_seed": int(record.get("stable_seed", rng.seed))},
					"placement_audit": {"geometry_integration": "smooth_union_same_volume", "host_thickness": plan.thickness,
						"root_burial": plan.root_burial, "sampling_step": cell, "regional_extent": plan.extent,
						"minimum_half_thickness": plan.minimum_half_thickness, "cross_section": "variable_flattened_ribbon",
						"shared_source_segment": index > 0, "destructive_operations": 0,
						"sizing_domain": plan.sizing_domain, "local_design_scale": plan.local_design_scale,
						"authoring_subdivisions": AUTHORING_SUBDIVISIONS, "authoring_knot_count": curve.points.size()}})
				ids.append(id)
			g.rng.seed = original_seed; g.rng.state = original_state
			var result_field := Field.prepare(g.dna, int(g.settings.get("quality", 1)))
			var proof := _field_proof(field, result_field, plan, ids)
			if not bool(proof.ok):
				_reject(report, str(proof.reason)); _rollback(g, original_count, original_connections); continue
			for id: String in ids: Regions.reserve(record, "messy_tissue", g.node(id))
			report.merge({"enabled": true, "added_nodes": ids.size(), "fold_nodes": ids, "region_id": str(record.id),
				"cluster_count": 1, "fold_count": 3, "root_count": 1, "field_validated": true,
				"rig_owner": str(plan.owner), "growth_origin": Graph.arr(plan.origin), "root_burial": plan.root_burial,
				"minimum_half_thickness": plan.minimum_half_thickness, "maximum_half_width": plan.maximum_half_width,
				"sampling_step": cell, "host_thickness": plan.thickness, "regional_extent": plan.extent,
				"sizing_domain": plan.sizing_domain, "local_design_scale": plan.local_design_scale,
				"exposure_witnesses": proof.witnesses, "local_void_witnesses": proof.voids,
				"geometry_integration": "smooth_union_same_volume", "reservations": record.reservations.duplicate(true)}, true)
			if not g.dna.metadata.has("surface_applications"): g.dna.metadata["surface_applications"] = {}
			if not g.dna.metadata.has("surface_streams"): g.dna.metadata["surface_streams"] = {}
			g.dna.metadata.surface_applications[application_id] = report.duplicate(true)
			g.dna.metadata.surface_streams[stream_id] = {"application_id": application_id, "application_signature": signature, "domain_id": domain_id, "pipeline_stage": report.pipeline_stage}
			return report
	g.rng.seed = original_seed; g.rng.state = original_state
	report["skip_reason"] = "No region safely supports one resolved connected fold cluster with a visible local void."
	return report

static func _dense_authoring(curves: Array) -> Array:
	# Local sampling correction only. Keep the same Catmull-Rom design, original
	# knots, profiles and shared tissue, but reduce angular changes between the
	# production field's hard-min transported elliptical segments. No global
	# volume, quality, lighting or shader change is involved.
	var result: Array = []
	for index in range(curves.size()):
		var source: Dictionary = curves[index]
		var dense := Curves.sample(source, AUTHORING_SUBDIVISIONS, true)
		var curve := {"points": Array(dense.points), "radii": Array(dense.radii), "shape": source.shape.duplicate(true)}
		if index > 0:
			var shared_knot := int(source.shared_knot) * AUTHORING_SUBDIVISIONS
			for offset in range(AUTHORING_SUBDIVISIONS + 1):
				curve.points[offset] = result[0].points[shared_knot + offset]
				curve.radii[offset] = result[0].radii[shared_knot + offset]
			curve["shared_knot"] = shared_knot
		result.append(curve)
	return result

static func _plan(g: RefCounted, field: RefCounted, record: Dictionary, reservations: Array, cell: float, attempt: int, rng: RandomNumberGenerator) -> Dictionary:
	var host: Dictionary = g.node(str(record.get("host_id", "")))
	if host.is_empty(): return {"error": "host"}
	var size := Graph.vec(host.size)
	var local_scale := minf(size.x, minf(size.y, size.z))
	var feature_scale := clampf(float(record.get("scale", 1.0)), 0.70, 1.20)
	var extent := local_scale * 0.92 * feature_scale
	var radius := maxf(cell * 1.92, local_scale * 0.098 * feature_scale)
	var direction := Graph.vec(record.get("growth_direction", [0, 0.25, -1])).normalized()
	var frame := Curves.attachment_frame(Vector3.ZERO, direction).basis
	var sizing_domain := "single_anatomical_mass"
	if radius > local_scale * 0.16 or extent < cell * 14.0:
		# A small internal core is an ownership anchor, not the size of the
		# anterior carrier union. Only an explicit multi-host region may supply
		# a larger footprint, and only the minimum resolvable size is requested.
		# Keep the original design exactly when primitive sizing already works.
		var region_size := Graph.vec(record.get("region_extent", [0, 0, 0]))
		if record.get("host_ids", []).size() < 2:
			return {"error": "regional_resolution"}
		if minf(region_size.x, minf(region_size.y, region_size.z)) <= 0.0: return {"error": "regional_resolution"}
		var required_scale := maxf(cell * 1.92 / 0.16, cell * 14.0 / (0.92 * feature_scale)) * 1.025
		var tangent_capacity := minf(Graph.surface_radius(region_size, frame.x), Graph.surface_radius(region_size, frame.y))
		var required_extent := required_scale * 0.92 * feature_scale
		var required_radius := maxf(cell * 1.92, required_scale * 0.098 * feature_scale)
		# Half the centerline span plus its largest ribbon cross-section must
		# fit the actual region. Do not turn a coarse host into oversized logs.
		if required_scale > local_scale * 1.65 or required_extent * 0.54 + required_radius * 2.90 > tangent_capacity:
			return {"error": "regional_resolution"}
		local_scale = required_scale; extent = required_extent; radius = required_radius
		sizing_domain = "explicit_connected_region_union"
	# Reject tiny/coarse hosts rather than expanding a delicate ribbon into logs.
	if radius > local_scale * 0.16 or extent < cell * 14.0: return {"error": "regional_resolution"}
	var phase := float(attempt) * 2.39996323
	var spread := 0.10 + float(attempt) * 0.085
	# Search the supplied anterior domain itself for a union-sized patch, not
	# always its upper rim. The original suitable-host placement is unchanged.
	var vertical_bias := 0.0 if sizing_domain == "explicit_connected_region_union" else 0.36
	var outward := (direction + frame.x * cos(phase) * spread + frame.y * (vertical_bias + sin(phase) * spread)).normalized()
	var nominal := Graph.vec(host.position) + outward * Graph.surface_radius(size, Graph.node_basis(host).inverse() * outward)
	var origin: Vector3 = field.project(nominal, outward)
	var normal: Vector3 = field.normal_at(origin, cell * 0.25)
	if absf(field.sample_signed_distance(origin)) > cell * 0.15 or normal.dot(outward) < 0.58: return {"error": "surface"}
	frame = Curves.attachment_frame(origin, normal).basis
	# Rotation and side preference are regional, not independent per-fragment RNG.
	var roll := rng.randf_range(-0.28, 0.28)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var x_axis := frame.x.rotated(normal, roll) * side
	var y_axis := frame.y.rotated(normal, roll)
	var wall := float(record.get("minimum_wall", cell))
	var thickness: float = field.thickness(origin, normal, local_scale * 3.0, cell * 0.5)
	if thickness < radius * 4.8 + wall * 2.0: return {"error": "essential_body_thickness"}
	# One low asymmetric S-fold with an oblique interlocking return and collapsed
	# side flap. The initial tall two-handle candidate was visually rejected:
	# these turns deliberately collapse the repeated open-loop silhouettes.
	# A variable broad section makes fleshy laminae, not parallel round ribs.
	var templates: Array = [
		[Vector3(-0.42,-0.44,-0.34), Vector3(-0.30,-0.22,0.06), Vector3(-0.24,0.08,0.28), Vector3(-0.06,0.35,0.36), Vector3(0.16,0.26,0.34), Vector3(0.18,0.04,0.20), Vector3(-0.04,-0.11,0.29), Vector3(0.10,-0.32,0.06), Vector3(0.20,-0.47,-0.32)],
		[Vector3(-0.42,-0.44,-0.34), Vector3(-0.30,-0.22,0.06), Vector3(-0.10,-0.18,0.13), Vector3(0.22,-0.10,0.25), Vector3(0.41,0.07,0.31), Vector3(0.39,0.26,0.18), Vector3(0.24,0.38,-0.30)],
		[Vector3(-0.24,0.08,0.28), Vector3(-0.06,0.35,0.36), Vector3(-0.23,0.48,0.22), Vector3(-0.47,0.34,0.08), Vector3(-0.50,0.09,-0.32)]]
	var curves: Array = []
	var maximum_half_width := 0.0
	var minimum_half_thickness := INF
	var height_gain := rng.randf_range(0.94, 1.10)
	for index in range(templates.size()):
		var points: Array = []; var radii: Array = []; var surfaces: Array = []; var normals: Array = []
		var template: Array = templates[index]
		var width: float = [1.95, 1.82, 2.14][index]
		var depth: float = [0.90, 0.88, 0.82][index]
		var shape := {"swelling": 0.0, "twist": 0.0, "taper": 0.0, "width": width, "depth": depth,
			"width_profile": [1.12, 0.66, 1.18, 0.74, 1.03], "depth_profile": [1.10, 1.0, 1.05, 1.0, 1.12]}
		for knot in range(template.size()):
			var local: Vector3 = template[knot]
			var predicted := origin + x_axis * local.x * extent + y_axis * local.y * extent
			var surface: Vector3 = field.project(predicted, normal)
			var n: Vector3 = field.normal_at(surface, cell * 0.25)
			if surface.distance_to(predicted) > extent * 0.48 or absf(field.sample_signed_distance(surface)) > cell * 0.15: return {"error": "regional_surface_continuity"}
			if n.dot(normal) < 0.67: return {"error": "regional_curvature"}
			var t := float(knot) / float(template.size() - 1)
			var r := radius * (1.17 - 0.17 * sin(t * PI))
			var point := surface + n * local.z * extent * height_gain
			var half_width := r * float(width) * Curves.profile_value(shape.width_profile, t)
			var half_depth := r * float(depth) * Curves.profile_value(shape.depth_profile, t)
			maximum_half_width = maxf(maximum_half_width, half_width)
			minimum_half_thickness = minf(minimum_half_thickness, half_depth)
			if not _clear(g, record, reservations, point, half_width, wall): return {"error": "reserved_feature_clearance"}
			if point.y - half_width < -field.translation.y / field.scale_value + cell: return {"error": "ground"}
			if point.distance_to(origin) > extent * 1.15: return {"error": "regional_extent"}
			if sizing_domain == "explicit_connected_region_union":
				var region_size := Graph.vec(record.region_extent)
				var offset := surface - Graph.vec(record.region_origin)
				if absf(offset.dot(x_axis)) + half_width > Graph.surface_radius(region_size, x_axis) or absf(offset.dot(y_axis)) + half_width > Graph.surface_radius(region_size, y_axis):
					return {"error": "union_region_extent"}
			points.append(point); radii.append(r); surfaces.append(surface); normals.append(n)
		var curve := {"points": points, "radii": radii, "shape": shape, "surfaces": surfaces, "normals": normals}
		if index > 0:
			var shared_knot := 0 if index == 1 else 2
			for offset in range(2):
				curve.points[offset] = curves[0].points[shared_knot + offset]
				curve.radii[offset] = curves[0].radii[shared_knot + offset]
				curve.surfaces[offset] = curves[0].surfaces[shared_knot + offset]
				curve.normals[offset] = curves[0].normals[shared_knot + offset]
			curve["shared_knot"] = shared_knot
		curves.append(curve)
	var root_point: Vector3 = curves[0].points[0]
	var root_burial := -float(field.sample_signed_distance(root_point))
	if root_burial < radius * 2.25: return {"error": "broad_root_burial"}
	var owner := ""; var owner_distance := INF
	for id_value in record.get("host_ids", [str(record.host_id)]):
		var id := str(id_value); var candidate: Dictionary = g.node(id)
		if candidate.is_empty() or str(candidate.get("kind", "")) != "mass": continue
		var distance: float = Graph.distance_to_tissue(candidate, root_point)
		if distance < owner_distance: owner = id; owner_distance = distance
	if owner.is_empty() or owner_distance > -radius * 0.50: return {"error": "anatomical_root_owner"}
	# Validate the final densified authoring representation, not only its sparse
	# design controls, so the sampling correction cannot cross a reserved cavity.
	for curve: Dictionary in _dense_authoring(curves):
		var samples := Curves.sample(curve, 5, true)
		for index in range(samples.points.size()):
			var t := float(index) / float(samples.points.size() - 1)
			var envelope: float = samples.radii[index] * float(curve.shape.width) * Curves.profile_value(curve.shape.width_profile, t)
			var p: Vector3 = samples.points[index]
			if not _clear(g, record, reservations, p, envelope, wall): return {"error": "sampled_clearance"}
			if p.y - envelope < -field.translation.y / field.scale_value + cell: return {"error": "sampled_ground"}
		var distal: Vector3 = curve.points[-1]
		if field.sample_signed_distance(distal) > -radius * 1.80: return {"error": "distal_attachment_burial"}
	return {"curves": curves, "owner": owner, "origin": origin, "normal": normal, "extent": extent,
		"sizing_domain": sizing_domain, "local_design_scale": local_scale,
		"root_burial": root_burial, "thickness": thickness, "maximum_half_width": maximum_half_width,
		"minimum_half_thickness": minimum_half_thickness, "blend": radius * 0.46, "cell": cell}

static func _clear(g: RefCounted, record: Dictionary, reservations: Array, point: Vector3, radius: float, wall: float) -> bool:
	if not Regions.support_clear(g, record, point, radius): return false
	if Regions.conflicts(point, radius, reservations, wall * 0.2, "messy_tissue"): return false
	for node: Dictionary in g.dna.nodes:
		if str(node.get("kind", "")) == "cavity" and Graph.distance_to_tissue(node, point) < radius + wall: return false
	for module: Dictionary in g.dna.get("modules", []):
		var size := Graph.vec(module.get("scale", [0.2, 0.2, 0.2]))
		if point.distance_to(Graph.vec(module.position)) < maxf(size.x, maxf(size.y, size.z)) * 0.65 + radius + wall: return false
	return true

static func _field_proof(host: RefCounted, result: RefCounted, plan: Dictionary, ids: Array) -> Dictionary:
	for id: String in ids:
		for node: Dictionary in result.production.source_dna.nodes:
			if str(node.id) == "bridge_" + id: return {"ok": false, "reason": "unexpected_graph_bridge"}
	for key in ["attachment_collars", "thin_features"]:
		for item: Dictionary in result.production.geometry_adjustments.get(key, []):
			if str(item.get("node_id", "")) in ids: return {"ok": false, "reason": "unexpected_" + key}
	var cell := float(plan.cell)
	if float(plan.minimum_half_thickness) < result.production.step / result.scale_value * 1.12:
		return {"ok": false, "reason": "ribbon_thickness_unresolved"}
	var witnesses: Array = []; var voids: Array = []
	for index in range(plan.curves.size()):
		var curve: Dictionary = plan.curves[index]
		var found := false
		# Skip shared source segments: every fold needs its OWN exterior evidence.
		for knot in range(2, curve.points.size() - 1):
			var point: Vector3 = curve.points[knot]
			var before: float = host.sample_signed_distance(point)
			var after: float = result.sample_signed_distance(point)
			if before > cell * 2.0 and after < -cell * 0.60:
				witnesses.append({"node_id": ids[index], "point": Graph.arr(point), "host_distance": before, "grown_distance": after})
				found = true; break
		if not found: return {"ok": false, "reason": "buried_or_unresolved_fold"}
		for knot in range(2, curve.points.size() - 1):
			var roof: Vector3 = curve.points[knot]
			var surface: Vector3 = curve.surfaces[knot]
			var delta := roof - surface
			if delta.length() < cell * 5.0: continue
			for fraction in [0.35, 0.48, 0.61]:
				var point := surface.lerp(roof, fraction)
				var margin: float = result.sample_signed_distance(point)
				# A genuine local empty volume beneath a tissue roof, not a dark
				# texture or a cavity subtracting essential carrier thickness.
				for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
					margin = minf(margin, result.sample_signed_distance(point + direction * cell * 0.65))
				if margin > cell * 0.45 and host.sample_signed_distance(point) > cell:
					voids.append({"under_fold": ids[index], "point": Graph.arr(point), "roof": Graph.arr(roof),
						"empty_ball_radius": cell * 0.65, "minimum_clearance": margin})
					break
			if not voids.is_empty(): break
	if voids.is_empty(): return {"ok": false, "reason": "local_void_closed"}
	return {"ok": true, "witnesses": witnesses, "voids": voids}

static func _reject(report: Dictionary, reason: String) -> void:
	report.rejections[reason] = int(report.rejections.get(reason, 0)) + 1

static func _rollback(g: RefCounted, count: int, connections: int) -> void:
	for i in range(count, g.dna.nodes.size()): g.index.erase(str(g.dna.nodes[i].id))
	g.dna.nodes.resize(count); g.dna.connections.resize(connections)
