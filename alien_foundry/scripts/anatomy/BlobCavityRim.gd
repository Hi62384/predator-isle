extends RefCounted
## Optional, unaccepted rim experiment. Two unequal open folds grow from the
## actual host/void intersection. Never a translated torus or covering pad.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Porous = preload("res://alien_foundry/scripts/anatomy/BlobPorousGrowth.gd")
const MAX_RIM_NODES := 2
const POINTS_PER_FOLD := 13

static func grow(g: RefCounted, cavity_growth: Dictionary, morphology: Dictionary) -> Dictionary:
	var result := {"candidate": "host_intersection_rim_folds_v1", "operation": "cavity_rim_candidate", "enabled": false,
		"visual_validated": false, "rim_nodes": [], "added_nodes": 0, "surface_stage": 2, "reused": false,
		"maximum_nodes": MAX_RIM_NODES, "placement_rejections": 0}
	if str(g.dna.get("type", "")) != "Blob" or not bool(cavity_growth.get("enabled", false)):
		result["skip_reason"] = "A successfully contained Blob cavity is required."
		return result
	var stage := int(morphology.get("pipeline_stage", 2))
	if stage not in [2, 3]:
		result["skip_reason"] = "Rim tissue is surface geometry, not base anatomy or a material."
		return result
	var application := str(cavity_growth.application_id) + ".rim_candidate"
	var stream := str(cavity_growth.stream_id) + ".rim_candidate"
	var signature := JSON.stringify({"cavities": cavity_growth.pore_nodes, "morphology": morphology, "candidate": result.candidate}, "", true, true).sha256_text()
	var applications: Dictionary = g.dna.metadata.get("surface_applications", {})
	if applications.has(application):
		var previous: Dictionary = applications[application]
		if str(previous.get("application_signature", "")) != signature:
			result["error"] = "Rim application ID already belongs to another parameter set."
			return result
		result = previous.duplicate(true)
		result["reused"] = true
		result["added_nodes"] = 0
		return result
	var streams: Dictionary = g.dna.metadata.get("surface_streams", {})
	if streams.has(stream):
		result["error"] = "Rim random stream is already reserved by another application."
		return result
	result.merge({"pipeline_stage": stage, "domain_id": cavity_growth.domain_id, "application_id": application,
		"stream_id": stream, "application_signature": signature, "quality": int(g.settings.get("quality", 1))}, true)
	if int(g.dna.budget.nodes) - g.dna.nodes.size() < MAX_RIM_NODES:
		result["skip_reason"] = "Insufficient node budget for the bounded rim experiment."
		return result
	# Remove only this application's cutters from a private field copy. The
	# host surface includes all prior anatomy and other-domain surface details.
	var host_dna: Dictionary = g.dna.duplicate(true)
	var host_nodes: Array = []
	for node: Dictionary in host_dna.nodes:
		if str(node.id) not in cavity_growth.pore_nodes: host_nodes.append(node)
	host_dna.nodes = host_nodes
	var field := Porous._prepare_containment_field(host_dna, int(result.quality))
	var step := float(cavity_growth.sampling_step_estimate)
	# One cavity per invocation is deliberate. This is a bounded comparison,
	# not a new blanket decoration over every pore.
	var cavity: Dictionary = g.node(str(cavity_growth.pore_nodes[0]))
	var axes := Graph.vec(cavity.size)
	var center := Graph.vec(cavity.position)
	var basis := Graph.node_basis(cavity)
	var wall := float(cavity.porous_growth.minimum_wall)
	var thickness := float(cavity.porous_growth.host_thickness)
	var radius := minf(minf(wall * 0.95, minf(axes.x, axes.y) * 0.46), minf(axes.z * 0.16, thickness * 0.09))
	result["rim_radius"] = radius
	result["estimated_cell_size"] = step
	result["metrics_space"] = "unscaled_authoring"
	if radius < step * 1.10:
		result["skip_reason"] = "Local tissue cannot support a rim at least 2.2 estimated cells wide."
		return result
	var paths: Array = []
	# Different spans, positions and thicknesses. Tapered gaps expose the host
	# transition instead of producing a uniform closed ring around the opening.
	for arc in range(2):
		var points: Array = []
		var widths: Array = []
		var start := -0.32 if arc == 0 else 3.01
		var span := 2.67 if arc == 0 else 2.08
		for i in range(POINTS_PER_FOLD):
			var u := float(i) / float(POINTS_PER_FOLD - 1)
			var phase := start + span * u
			var crossing := _intersection(field, center, basis, axes, phase)
			if crossing.is_empty():
				result.placement_rejections += 1
				break
			var point: Vector3 = crossing.point
			var normal := Porous._field_normal(field, point, step * 0.30)
			var radial := basis * Vector3(cos(phase) * axes.x, sin(phase) * axes.y, 0.0)
			radial = (radial - normal * radial.dot(normal)).normalized()
			var taper := pow(sin(PI * u), 0.70)
			var width := maxf(0.025, radius * lerpf(0.45, 1.0 if arc == 0 else 0.82, taper))
			var embed := lerpf(1.12, 0.40, taper)
			var anchored := point + radial * width * 0.35 - normal * width * embed
			# Every center remains inside real host tissue; every root has deeper
			# backing. No geometry is added to rescue an unsupported aperture.
			if field.sample_signed_distance(anchored) > -width * 0.12 or field.sample_signed_distance(point - normal * width * 1.8) > -width * 0.75:
				result.placement_rejections += 1
				break
			points.append(anchored)
			widths.append(width)
		if points.size() != POINTS_PER_FOLD:
			result["skip_reason"] = "The actual cavity intersection cannot support the complete tapered rim folds."
			return result
		var attachment := _root_in_carrier(g, points[0], maxf(float(widths[0]), 0.035), radius * 0.85, wall)
		if attachment.is_empty() or field.sample_signed_distance(attachment.point) > -float(widths[0]) * 0.40:
			result["skip_reason"] = "No existing carrier can own the embedded rim root without an automatic bridge."
			return result
		points[0] = attachment.point
		paths.append({"points": points, "radii": widths, "parent": attachment.parent})
	var previous_rng_state: int = g.rng.state
	for path: Dictionary in paths:
		var id: String = g.curve(str(path.parent), "cavity_rim_fold", path.points, path.radii, "flesh", false)
		var node: Dictionary = g.node(id)
		node["noise"] = 0.0
		node["blend"] = radius * 0.85
		node["shape"] = {"swelling": 0.0, "twist": 0.0, "taper": 0.0}
		node["blob_region"] = "cavity_rim_fold"
		node["surface_stage"] = 2
		node["pipeline_stage"] = stage
		node["surface_domain"] = cavity_growth.domain_id
		node["surface_application"] = application
		node["surface_operation"] = "cavity_rim_candidate"
		node["surface_operation_selector"] = "cavities"
		node["cavity_rim"] = {"cavity_id": cavity.id, "root_embedded": true, "intersection_traced": true, "complete_ring": false, "metrics_space": "unscaled_authoring", "minimum_host_wall": wall}
		result.rim_nodes.append(id)
	# Only the bounded transition blend changes; tested cutter position, axes,
	# burial and throat depth stay identical to the safe cavity baseline.
	result["original_cavity_blend"] = float(cavity.blend)
	cavity["blend"] = maxf(float(cavity.blend), radius * 0.75)
	cavity["rim_candidate"] = application
	g.rng.state = previous_rng_state
	result["cavity_id"] = cavity.id
	result["enabled"] = true
	result["added_nodes"] = result.rim_nodes.size()
	applications[application] = result.duplicate(true)
	streams[stream] = {"application_id": application, "application_signature": signature}
	g.dna.metadata["surface_applications"] = applications
	g.dna.metadata["surface_streams"] = streams
	return result

static func _intersection(field: RefCounted, center: Vector3, basis: Basis, axes: Vector3, phase: float) -> Dictionary:
	var lower := 0.12
	var previous := _surface_point(center, basis, axes, phase, lower)
	if field.sample_signed_distance(previous) >= 0.0: return {}
	for step_index in range(1, 17):
		var upper := lerpf(0.12, 1.0, float(step_index) / 16.0)
		var point := _surface_point(center, basis, axes, phase, upper)
		if field.sample_signed_distance(point) >= 0.0:
			for _iteration in range(14):
				var middle := (lower + upper) * 0.5
				if field.sample_signed_distance(_surface_point(center, basis, axes, phase, middle)) < 0.0: lower = middle
				else: upper = middle
			return {"point": _surface_point(center, basis, axes, phase, (lower + upper) * 0.5)}
		lower = upper
	return {}

static func _surface_point(center: Vector3, basis: Basis, axes: Vector3, phase: float, fraction: float) -> Vector3:
	var ring := sqrt(maxf(0.0, 1.0 - fraction * fraction))
	return center + basis * Vector3(cos(phase) * axes.x * ring, sin(phase) * axes.y * ring, axes.z * fraction)

static func _root_in_carrier(g: RefCounted, point: Vector3, own_radius: float, blend: float, wall: float) -> Dictionary:
	# Match Graph.repair's real attachment rule. A field-union point can belong
	# to a different carrier than the cavity center; choosing the latter blindly
	# creates hidden bridge geometry and violates this candidate's two-node cap.
	var parent := ""
	var closest := INF
	for node: Dictionary in g.dna.nodes:
		if str(node.kind) == "cavity" or str(node.get("blob_region", "")) == "cavity_rim_fold": continue
		var distance := Graph.distance_to_tissue(node, point)
		if distance < closest:
			closest = distance
			parent = str(node.id)
	if parent.is_empty(): return {}
	var anchored := point
	var direction: Vector3 = (g.center(parent) - point).normalized()
	for _iteration in range(12):
		if Graph.distance_to_tissue(g.node(parent), anchored) <= own_radius + blend * 0.8 - 0.005:
			return {"parent": parent, "point": anchored}
		anchored += direction * wall * 0.12
	return {}
