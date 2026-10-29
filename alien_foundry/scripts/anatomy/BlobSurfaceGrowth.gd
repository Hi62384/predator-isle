extends RefCounted
## Three distinct tissue operations sharing one regional placement contract.
## Smooth additive ellipsoids enter the SAME implicit field as their host.
## No display mesh, global rock noise, detached beads or hidden operation aliases.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Field = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceField.gd")
const Regions = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceRegions.gd")
const OPERATIONS := ["normal_lumpy", "bumps", "sacs"]
const MAX_ATTEMPTS := 20

static func apply(g: RefCounted, records: Array, morphology: Dictionary, operation: String, stage: int = 2) -> Dictionary:
	var report := {"operation": operation, "status": "implemented_geometry", "pipeline_stage": stage,
		"requested": 0, "accepted": 0, "enabled": false, "node_ids": [], "rejections": {"buried": 0, "support": 0, "thickness": 0, "overlap": 0, "ground": 0, "cavity": 0, "perimeter": 0},
		"coordinate_space": "unscaled_authoring", "region_results": [], "visual_validated": false}
	if str(g.dna.get("type", "")) != "Blob" or operation not in OPERATIONS or stage not in [2, 3]:
		report.status = "unsupported_domain_or_operation"; report["skip_reason"] = "Only implemented Blob surface operations in Stage 2 or 3 are supported."; return report
	var domain := str(records[0].domain_id) if not records.is_empty() else str(morphology.get("domain_id", "primary_body"))
	var application_id := domain + "." + operation
	var configuration: Array = []
	for record: Dictionary in records:
		var clean: Dictionary = record.duplicate(true)
		for key in ["feature_nodes", "reservations", "realized_detail_types"]: clean.erase(key)
		configuration.append(clean)
	var signature := JSON.stringify({"records": configuration, "operation": operation, "stage": stage, "morphology": morphology}, "", true, true).sha256_text()
	var applications: Dictionary = g.dna.metadata.get("surface_growth_applications", {})
	if applications.has(application_id):
		var previous: Dictionary = applications[application_id]
		if str(previous.get("application_signature", "")) != signature:
			report.status = "application_conflict"; report["error"] = "Surface application ID already belongs to another region configuration."; return report
		var reused: Dictionary = previous.duplicate(true)
		reused["reused"] = true; reused["added_nodes"] = 0
		return reused
	report["application_id"] = application_id; report["application_signature"] = signature; report["reused"] = false
	var cell := Regions.estimated_cell(g, morphology)
	var width := maxf(float(morphology.get("width", 1.0)), 0.05)
	var previous_rng_seed: int = g.rng.seed
	var previous_rng_state: int = g.rng.state
	var bottom := _bottom(g.dna.nodes)
	var first_new_node: int = g.dna.nodes.size()
	var field := Field.prepare(g.dna, int(g.settings.get("quality", 1)))
	var all_reservations: Array = []
	for record: Dictionary in records: all_reservations.append_array(record.reservations)
	for record: Dictionary in records:
		if operation not in record.allowed_detail_types: continue
		var host: Dictionary = g.node(str(record.host_id))
		if host.is_empty(): continue
		var intensity := float(record.intensity) * (1.0 if str(record.primary_detail_type) == operation else 0.83)
		var density := float(record.density)
		var region_result := {"region_id": str(record.id), "operation": operation, "accepted": 0, "requested": 0}
		var desired := 0
		if density > 0.001 and intensity > 0.001:
			desired = (1 + int(floor(density * 3.0))) if operation == "bumps" else 1
			if operation == "sacs" and density < 0.22: desired = 0
		report.requested += desired; region_result.requested = desired
		var rng := RandomNumberGenerator.new()
		rng.seed = Regions.stream_seed(int(g.dna.seed), str(record.id) + "." + operation)
		for feature_index in range(desired):
			if g.dna.nodes.size() >= int(g.dna.budget.nodes): break
			var best: Dictionary = {}; var score := -INF
			var size := _feature_size(operation, width, Graph.vec(host.size), float(record.scale), intensity, cell, rng)
			var radial_depth := size.z
			var burial := 0.82 if operation == "normal_lumpy" else (0.34 if operation == "bumps" else 0.27)
			# Relief blends over its tangent footprint, not its tiny radial depth.
			# The previous shallow / narrow union exposed an oblate sheet edge.
			var blend := maxf(float(record.blend_distance), minf(size.x, size.y) * 0.90) if operation == "normal_lumpy" else maxf(float(record.blend_distance), minf(size.x, minf(size.y, size.z)) * 0.55)
			var patch_direction := Graph.vec(record.growth_direction).normalized()
			var patch_frame := Curves.attachment_frame(Vector3.ZERO, patch_direction).basis
			for attempt in range(MAX_ATTEMPTS):
				var phase := float(attempt) * 2.39996323 + rng.randf_range(-0.2, 0.2)
				var spread := rng.randf_range(0.22, 0.95)
				var outward := (patch_direction + patch_frame.x * cos(phase) * spread + patch_frame.y * sin(phase) * spread).normalized()
				var local := Graph.node_basis(host).inverse() * outward
				var anchor := Graph.vec(host.position) + outward * Graph.surface_radius(Graph.vec(host.size), local)
				anchor = field.project(anchor, outward)
				if absf(field.sample_signed_distance(anchor)) > cell * 0.15:
					report.rejections.buried += 1; continue
				var normal: Vector3 = field.normal_at(anchor, cell * 0.25)
				if normal.length_squared() < 0.5 or normal.dot(outward) < 0.55:
					report.rejections.buried += 1; continue
				var basis := Curves.attachment_frame(anchor, normal).basis * Basis(Vector3.BACK, rng.randf_range(-0.25, 0.25))
				var position := anchor - normal * radial_depth * burial
				var proposed := {"kind": "mass", "position": Graph.arr(position), "size": Graph.arr(size), "rotation": Graph.arr(basis.get_euler())}
				var perimeter_gap := _perimeter_gap(position, basis, size, field) if operation == "normal_lumpy" else 0.0
				if operation == "normal_lumpy" and perimeter_gap > blend * 0.15:
					report.rejections.perimeter += 1; continue
				var extent_y := sqrt(pow(basis.x.y * size.x, 2.0) + pow(basis.y.y * size.y, 2.0) + pow(basis.z.y * size.z, 2.0))
				if position.y - extent_y < bottom + cell:
					report.rejections.ground += 1; continue
				if not Regions.support_clear(g, record, position, minf(size.x, size.y)):
					report.rejections.support += 1; continue
				var thickness: float = field.thickness(anchor, normal, width * 3.0, cell * 0.6)
				if Graph.distance_to_tissue(host, position) > minf(size.x, minf(size.y, size.z)) * 0.80:
					report.rejections.thickness += 1; continue
				if thickness < radial_depth * 0.70 + float(record.minimum_wall) * 2.0:
					report.rejections.thickness += 1; continue
				if Regions.conflicts(position, minf(size.x, size.y), all_reservations, cell * 0.15, operation):
					report.rejections.overlap += 1; continue
				if _occludes_cavity(proposed, g.dna.nodes, float(record.minimum_wall)):
					report.rejections.cavity += 1; continue
				var exposure := Regions.exposure(proposed, g.dna.nodes, field, first_new_node)
				var minimum_protrusion := cell * (0.40 if operation == "normal_lumpy" else 1.15)
				if float(exposure.fraction) < float(record.minimum_exposure) or float(exposure.protrusion) < minimum_protrusion:
					report.rejections.buried += 1; continue
				if _swallows_feature(proposed, g.dna.nodes):
					report.rejections.overlap += 1; continue
				var candidate_score := float(exposure.fraction) + float(exposure.protrusion) / maxf(radial_depth, 0.001) * 0.15
				if operation == "normal_lumpy":
					candidate_score = -maxf(perimeter_gap, 0.0) / cell + minf(float(exposure.protrusion) / maxf(radial_depth, 0.001), 0.5)
				if candidate_score > score:
					score = candidate_score
					best = {"position": position, "basis": basis, "anchor": anchor, "normal": normal, "exposure": exposure, "thickness": thickness, "minimum_protrusion": minimum_protrusion, "perimeter_gap": perimeter_gap}
			if best.is_empty(): continue
			g.rng.seed = Regions.stream_seed(int(g.dna.seed), str(record.id) + "." + operation + ".node.%s" % feature_index)
			var id: String = g.mass(str(record.host_id), "swelling" if operation == "sacs" else "surface_relief", best.position, size, str(record.tissue_identity), operation == "sacs")
			var node: Dictionary = g.node(id)
			node.rotation = Graph.arr(best.basis.get_euler())
			node.noise = 0.0
			node["shape"] = {"sculpt_strength": 0.0}
			node.blend = blend
			node.deformation = {"phase": rng.randf_range(0.0, 100.0), "warp": 0.0, "fold_frequency": 2.0}
			node["pipeline_stage"] = stage; node["surface_stage"] = stage
			node["surface_operation"] = operation; node["surface_region_id"] = str(record.id)
			node["surface_domain"] = str(record.domain_id); node["blob_region"] = operation
			node["growth_origin"] = Graph.arr(best.anchor)
			node["surface"] = {"growth": (0.18 if operation == "normal_lumpy" else (0.62 if operation == "bumps" else 0.94)) * intensity,
				"exposure": 0.06 if operation == "sacs" else 0.02, "tissue_identity": str(record.tissue_identity),
				"region_seed": int(record.stable_seed), "detail_type": operation, "intensity": intensity}
			node["placement_audit"] = {"exposed_fraction": best.exposure.fraction, "max_protrusion": best.exposure.protrusion,
				"minimum_protrusion": best.minimum_protrusion, "host_thickness": best.thickness, "minimum_wall": record.minimum_wall,
				"burial_ratio": burial, "perimeter_field_gap": best.perimeter_gap, "perimeter_gap_limit": blend * 0.15 if operation == "normal_lumpy" else 0.0, "tested_directions": MAX_ATTEMPTS, "noise_amplitude": 0.0, "geometry_integration": "smooth_union_same_volume"}
			Regions.reserve(record, operation, node)
			all_reservations.append(record.reservations[-1])
			report.node_ids.append(id); report.accepted += 1; region_result.accepted += 1
		report.region_results.append(region_result)
	g.rng.seed = previous_rng_seed
	g.rng.state = previous_rng_state
	report["enabled"] = int(report.accepted) > 0
	if not report.enabled:
		report["skip_reason"] = "Region density/intensity requested no tissue." if int(report.requested) == 0 else "No candidate passed the field, exposure, support and reservation checks."
	report["unplaced"] = int(report.requested) - int(report.accepted)
	report["added_nodes"] = int(report.accepted)
	if not g.dna.metadata.has("surface_growth_applications"): g.dna.metadata["surface_growth_applications"] = {}
	g.dna.metadata.surface_growth_applications[application_id] = report.duplicate(true)
	return report

static func _perimeter_gap(position: Vector3, basis: Basis, size: Vector3, field: RefCounted) -> float:
	# A broad flat seed is not allowed to overhang a convex host as a plate.
	# Require its entire tangent rim to lie inside the union transition band.
	var gap := -INF
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var point := position + basis.x * cos(angle) * size.x + basis.y * sin(angle) * size.y
		gap = maxf(gap, field.sample_signed_distance(point))
	return gap

static func _feature_size(operation: String, width: float, host_size: Vector3, scale_value: float, intensity: float, cell: float, rng: RandomNumberGenerator) -> Vector3:
	var host_min := minf(host_size.x, minf(host_size.y, host_size.z))
	var factor := scale_value * rng.randf_range(0.88, 1.12)
	match operation:
		"normal_lumpy":
			# Wide, shallow, continuously blended tissue, never granular noise.
			var depth := maxf(width * 0.072 * factor * intensity, cell * 1.35)
			var footprint := minf(maxf(width * 0.23 * factor, depth * 2.5), host_min * 0.82)
			depth = minf(depth, footprint * 0.38)
			return Vector3(footprint, footprint * 1.14, depth)
		"bumps":
			var radius := minf(maxf(width * 0.10 * factor, cell * 1.8), host_min * 0.36)
			return Vector3(radius, radius * rng.randf_range(0.85, 1.12), radius * lerpf(0.80, 1.20, intensity))
		"sacs":
			# Substantial elongated inflation, with a broad buried attachment.
			var radius := minf(maxf(width * 0.255 * factor, cell * 3.0), host_min * 0.73)
			return Vector3(radius * rng.randf_range(0.78, 1.0), radius * rng.randf_range(1.28, 1.68), radius * lerpf(0.92, 1.30, intensity))
	return Vector3.ZERO

static func _bottom(nodes: Array) -> float:
	var result := INF
	for node: Dictionary in nodes:
		if str(node.get("kind", "")) == "mass":
			var basis := Graph.node_basis(node); var size := Graph.vec(node.size)
			var extent := sqrt(pow(basis.x.y * size.x, 2.0) + pow(basis.y.y * size.y, 2.0) + pow(basis.z.y * size.z, 2.0))
			result = minf(result, Graph.vec(node.position).y - extent)
		elif str(node.get("kind", "")) == "curve":
			for i in range(node.points.size()): result = minf(result, Graph.vec(node.points[i]).y - float(node.radii[i]))
	return result

static func _swallows_feature(proposed: Dictionary, nodes: Array) -> bool:
	for node: Dictionary in nodes:
		if str(node.get("surface_operation", "")) not in OPERATIONS: continue
		var covered := 0
		for i in range(20):
			if Graph.distance_to_tissue(proposed, Regions.surface_sample(node, i, 20)) < 0.0: covered += 1
		if covered > 7: return true
	return false

static func _occludes_cavity(proposed: Dictionary, nodes: Array, wall: float) -> bool:
	for node: Dictionary in nodes:
		if str(node.get("kind", "")) != "cavity": continue
		# Safe for reuse on secondary carriers or after an existing cavity pass.
		for index in range(16):
			if Graph.distance_to_tissue(proposed, Regions.surface_sample(node, index, 16)) < wall: return true
	return false
