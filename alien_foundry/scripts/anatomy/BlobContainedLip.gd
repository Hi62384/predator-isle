extends RefCounted
## Opt-in field composition only. No positive fold nodes and no cutter edits.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Porous = preload("res://alien_foundry/scripts/anatomy/BlobPorousGrowth.gd")
const Intersection = preload("res://alien_foundry/scripts/anatomy/BlobCavityRim.gd")

static func grow(g: RefCounted, growth: Dictionary, morphology: Dictionary) -> Dictionary:
	var result := {"candidate": "contained_post_subtraction_lip_v1", "operation": "contained_lip_candidate", "enabled": false, "added_nodes": 0, "visual_validated": false, "surface_stage": 2, "composition": "post_subtraction_union_with_protected_throat"}
	if str(g.dna.get("type", "")) != "Blob" or not bool(g.settings.get("blob_contained_lip_candidate", false)):
		result["skip_reason"] = "The separate Blob-only contained lip flag is required."; return result
	var profile := str(g.settings.get("blob_contained_lip_profile", ""))
	var broad_v2 := profile == "broad_host_collar_v2"
	if profile not in ["", "narrow_host_collar_v1", "broad_host_collar_v2"]:
		result["skip_reason"] = "Unsupported contained lip profile."; return result
	if broad_v2:
		result["candidate"] = "contained_post_subtraction_lip_v2"
		result["profile"] = profile
	if bool(g.settings.get("blob_cavity_rim_candidate", false)):
		result["skip_reason"] = "The rejected curve-rim experiment cannot be combined with the contained lip."; return result
	if not bool(growth.get("enabled", false)) or growth.get("pore_nodes", []).is_empty():
		result["skip_reason"] = "An already-contained cavity is required."; return result
	var stage := int(morphology.get("pipeline_stage", 2))
	if stage not in [2, 3]:
		result["skip_reason"] = "The lip cannot modify base anatomy or materials."; return result
	var cavity: Dictionary = g.node(str(growth.pore_nodes[0]))
	if bool(cavity.get("surface_opening", false)) or not bool(cavity.get("porous_growth", {}).get("complete_rim", false)) or not bool(cavity.get("porous_growth", {}).get("back_wall", false)):
		result["skip_reason"] = "Only an unrelocated, finite complete-rim cavity is supported."; return result
	if broad_v2 and cavity.has("contained_lip") and int(cavity.contained_lip.get("version", 0)) != 2:
		result["skip_reason"] = "An existing different lip profile cannot be overwritten."; return result
	var application := str(growth.application_id) + (".contained_lip.broad_v2" if broad_v2 else ".contained_lip")
	var stream := str(growth.stream_id) + (".contained_lip.broad_v2" if broad_v2 else ".contained_lip")
	var signature := JSON.stringify({"cavity_id": cavity.id, "morphology": morphology, "candidate": result.candidate}, "", true, true).sha256_text()
	var applications: Dictionary = g.dna.metadata.get("surface_applications", {})
	if applications.has(application):
		var previous: Dictionary = applications[application]
		if str(previous.get("application_signature", "")) != signature:
			result["error"] = "Contained lip application ID has conflicting parameters."; return result
		result = previous.duplicate(true); result["reused"] = true; return result
	var streams: Dictionary = g.dna.metadata.get("surface_streams", {})
	if streams.has(stream):
		result["error"] = "Contained lip stream is already reserved."; return result
	var axes := Graph.vec(cavity.size)
	var wall := float(cavity.porous_growth.minimum_wall)
	var radius := minf(minf(wall * 0.65, minf(axes.x, axes.y) * 0.60), minf(axes.z * 0.20, float(cavity.porous_growth.host_thickness) * 0.08))
	if broad_v2:
		# Coherent physical width, independent of quality. This profile can only
		# survive if the unchanged measured forward collar and host backing fit.
		radius = minf(minf(wall * 0.95, minf(axes.x, axes.y) * 0.72), minf(axes.z * 0.22, float(cavity.porous_growth.host_thickness) * 0.08))
	var minimum_radius := radius * 0.84
	var step := float(growth.sampling_step_estimate)
	result.merge({"radius": radius, "minimum_radius": minimum_radius, "estimated_cell_size": step, "quality": int(g.settings.get("quality", 1)), "metrics_space": "unscaled_authoring", "pipeline_stage": stage, "domain_id": growth.domain_id, "application_id": application, "stream_id": stream, "application_signature": signature, "reused": false}, true)
	if minimum_radius * 2.0 < step * 2.2:
		result["skip_reason"] = "Local thickness cannot resolve the entire unequal lip at 2.2 estimated cells."; return result
	var host: Dictionary = g.dna.duplicate(true)
	var host_nodes: Array = []
	for node: Dictionary in host.nodes:
		if str(node.id) not in growth.pore_nodes: host_nodes.append(node)
	host.nodes = host_nodes
	var field := Porous._prepare_containment_field(host, int(result.quality))
	var basis := Graph.node_basis(cavity)
	var center := Graph.vec(cavity.position)
	var intersection_samples: Array = []
	var intersection_points: Array[Vector3] = []
	var available_collar_radius := INF
	var limiting_sample := -1
	var minimum_intersection_z := INF
	for sample in range(32):
		var phase := TAU * float(sample) / 32.0
		var crossing: Dictionary = Intersection._intersection(field, center, basis, axes, phase)
		if crossing.is_empty():
			result["skip_reason"] = "No continuous host/cutter intersection supports the lip."; return result
		var local: Vector3 = basis.inverse() * (crossing.point - center)
		intersection_samples.append(Graph.arr(local))
		intersection_points.append(crossing.point)
		var supported_radius := (local.z - axes.z * 0.12) / 1.5
		if supported_radius < available_collar_radius:
			available_collar_radius = supported_radius
			limiting_sample = sample
			minimum_intersection_z = local.z
	# Fit the existing conservative axial rule to the complete measured rim.
	# Do not move the cutter or relax the protected collar. The one-percent
	# reserve keeps floating-point equality away from the clipping plane.
	var requested_radius := radius
	radius = minf(radius, maxf(0.0, available_collar_radius * 0.99))
	minimum_radius = radius * 0.84
	result.merge({"requested_radius": requested_radius, "radius": radius, "minimum_radius": minimum_radius, "collar_fit": {"limiting_sample": limiting_sample, "minimum_intersection_local_z": minimum_intersection_z, "collar_floor_z": axes.z * 0.12, "conservative_axial_radius_multiplier": 1.5, "available_radius": available_collar_radius, "shrink_factor": radius / requested_radius}}, true)
	if minimum_radius * 2.0 < step * 2.2:
		result["skip_reason"] = "The supported forward collar cannot resolve the entire unequal lip at 2.2 estimated cells."; return result
	for point: Vector3 in intersection_points:
		var normal := Porous._field_normal(field, point, step * 0.25)
		if field.sample_signed_distance(point - normal * radius) >= -radius * 0.55:
			result["skip_reason"] = "The actual lip intersection lacks embedded backing."; return result
	var descriptor := {"version": 1, "radius": radius, "minimum_radius": minimum_radius, "host_id": str(cavity.parent), "cavity_id": str(cavity.id), "application_id": application, "domain_id": growth.domain_id, "metrics_space": "unscaled_authoring", "throat_ratio": 0.50, "collar_min_fraction": 0.12, "host_intersection_checks": 32, "local_intersection_samples": intersection_samples, "cutter_transform_preserved": true, "composition": result.composition}
	if broad_v2:
		descriptor["version"] = 2
		descriptor["profile"] = profile
	cavity["contained_lip"] = descriptor
	result["cavity_id"] = cavity.id
	result["host_id"] = cavity.parent
	result["enabled"] = true
	applications[application] = result.duplicate(true)
	streams[stream] = {"application_id": application, "application_signature": signature}
	g.dna.metadata["surface_applications"] = applications
	g.dna.metadata["surface_streams"] = streams
	return result
