extends RefCounted
## Opt-in blob anatomy candidate. A small region of the organism's actual
## envelope receives contained, deep cavities. This is not yet a validated
## porous-webbing operator. Holes are subtraction,
## never dark decals or a detached surface mesh. No renderer changes required.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const SDF = preload("res://alien_foundry/scripts/geometry/SDFOperations.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Field = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceField.gd")
const MAX_HOLES := 11
const MAX_PLACEMENT_ATTEMPTS := 96
const MAX_ADDED_NODES := MAX_HOLES
const RIM_SAMPLES := 24
const BURIAL_RATIO := 0.48
const SHELL_DEPTHS := [0.12, 0.0, -0.25, -0.50, -0.75, -0.90, -1.0]


## Call before Graph.finish(). Positions/radii use the graph's unscaled domain.
## regions: root, left, right, mantle, pouch, hosts, support_ids.
## morphology: width, height, depth, porosity, mirror, stage/domain/stream IDs.
## Optional region_origin, region_normal, region_extent support arbitrary
## anatomical domains without relying on coordinates of one particular seed.
static func grow(g: RefCounted, regions: Dictionary, morphology: Dictionary) -> Dictionary:
	var result := {"candidate": "contained_deep_cavities_v3", "enabled": false,
		"matrix_nodes": [], "pore_nodes": [], "fold_nodes": [], "placement_attempts": 0,
		"added_nodes": 0, "small_pores": 0, "visual_validated": false,
		"operation": "deep_cavities", "operation_selector": "cavities", "status": "implemented_geometry_candidate", "surface_stage": 2,
		"reused": false, "opening_mode": "finite_complete_rim", "containment_rejections": 0,
		"thickness_rejections": 0, "orientation_rejections": 0, "domain_rejections": 0,
		"spacing_rejections": 0, "surface_rejections": 0, "support_rejections": 0,
		"quality": clampi(int(g.settings.get("quality", 1)), 0, 2),
		"requested_cavities": 0, "accepted_cavities": 0, "unplaced_cavities": 0,
		"rejection_counts_are_placement_attempts": true}
	if str(g.dna.get("type", "")) != "Blob":
		result["skip_reason"] = "Blob-only anatomy candidate."
		return result
	var root_id := str(regions.get("root", ""))
	if g.node(root_id).is_empty():
		result["skip_reason"] = "A valid tissue carrier is required."
		return result
	var pipeline_stage := int(morphology.get("pipeline_stage", 2))
	if pipeline_stage not in [2, 3]:
		result["error"] = "Surface geometry may be invoked only during Stage 2 or on a Stage 3 secondary host."
		result["status"] = "invalid_stage"
		return result
	var domain_id := str(morphology.get("domain_id", "host:" + root_id))
	var stream_id := str(morphology.get("stream_id", "body:cavities"))
	var application_id := str(morphology.get("application_id", stream_id))
	var signature := JSON.stringify({"regions": regions, "morphology": morphology, "domain_id": domain_id, "pipeline_stage": pipeline_stage}, "", true, true).sha256_text()
	result["pipeline_stage"] = pipeline_stage
	result["domain_id"] = domain_id
	result["domain_root"] = root_id
	result["domain_hosts"] = regions.get("hosts", [root_id]).duplicate()
	result["stream_id"] = stream_id
	result["application_id"] = application_id
	result["application_signature"] = signature
	var applications: Dictionary = g.dna.get("metadata", {}).get("surface_applications", {})
	if applications.has(application_id):
		var previous: Dictionary = applications[application_id]
		if str(previous.get("application_signature", "")) != signature:
			result["error"] = "Surface application ID already belongs to a different domain or parameter set."
			result["status"] = "application_conflict"
			return result
		result = previous.duplicate(true)
		result["reused"] = true
		result["original_added_nodes"] = int(previous.get("added_nodes", 0))
		result["added_nodes"] = 0
		return result
	var streams: Dictionary = g.dna.get("metadata", {}).get("surface_streams", {})
	if streams.has(stream_id):
		var owner: Dictionary = streams[stream_id]
		if str(owner.get("application_id", "")) != application_id or str(owner.get("application_signature", "")) != signature:
			result["error"] = "Surface random stream already belongs to a different application or domain."
			result["status"] = "stream_conflict"
			return result
	if bool(morphology.get("grow_matrix", false)):
		result["skip_reason"] = "Deep cavities only carve existing tissue; covering matrix pads are not supported."
		return result
	var porosity := clampf(float(morphology.get("porosity", 0.6)), 0.0, 1.0)
	if porosity < 0.08:
		result["skip_reason"] = "This morphology has no porous growth."
		return result
	var remaining: int = int(g.dna["budget"]["nodes"]) - g.dna["nodes"].size()
	if remaining < 1:
		result["skip_reason"] = "Insufficient node budget for a real cavity."
		return result
	var start_count: int = g.dna["nodes"].size()
	var start_connections: int = g.dna.get("connections", []).size()
	var previous_rng_state: int = g.rng.state
	var allowance := mini(MAX_ADDED_NODES, remaining)
	var width := maxf(float(morphology.get("width", 1.0)), 0.12)
	var height := maxf(float(morphology.get("height", 1.0)), 0.12)
	var depth := maxf(float(morphology.get("depth", 1.0)), 0.12)
	var scale := minf(width, minf(height, depth))
	# Optional local intent changes the candidate distribution, never the global
	# lattice/feature floor, minimum wall, or host containment predicates.
	var radius_scale := scale
	if morphology.has("cavity_radius_scale"):
		radius_scale = minf(scale, float(morphology.cavity_radius_scale))
		if not is_finite(radius_scale) or radius_scale <= 0.0:
			result["skip_reason"] = "The explicit cavity radius scale must be finite and positive."
			return result
		result["cavity_radius_scale"] = radius_scale
	var mirror := -1.0 if float(morphology.get("mirror", 1.0)) < 0.0 else 1.0
	var normal := Graph.vec(morphology.get("region_normal", Vector3(-mirror * 0.14, 0.04, -1.0))).normalized()
	if normal.length_squared() < 0.5: normal = Vector3.FORWARD
	var frame := Curves.attachment_frame(Vector3.ZERO, normal).basis
	var root_center: Vector3 = g.center(root_id)
	var origin := root_center + Vector3(-mirror * width * 0.18, height * 0.31, 0.0)
	if morphology.has("region_origin"): origin = Graph.vec(morphology.region_origin)
	var domain := Vector2(width * 0.68, height * 0.67)
	if morphology.has("region_extent"):
		var extent := Graph.vec(morphology.region_extent)
		if bool(morphology.get("exact_region_extent", false)):
			if not is_finite(extent.x) or not is_finite(extent.y) or extent.x <= 0.0 or extent.y <= 0.0:
				result["skip_reason"] = "An exact local cavity domain requires finite positive tangent extents."
				return result
			domain = Vector2(extent.x, extent.y)
			result["exact_region_extent"] = true
		else:
			domain = Vector2(maxf(extent.x, scale * 0.35), maxf(extent.y, scale * 0.35))
	# Quality changes the minimum supported feature, never silently increases
	# the volume's resolution. Coarse previews receive fewer, larger apertures.
	var quality := clampi(int(g.settings.get("quality", 1)), 0, 2)
	var estimated_step := _sampling_step_estimate(g, quality)
	var feature_floor: float = maxf(scale * [0.115, 0.075, 0.058][quality], estimated_step * 1.80)
	var wall := maxf(maxf(scale * 0.075, feature_floor * 0.85), estimated_step * 1.45)
	var carrier_ids: Array = regions.get("hosts", [root_id]).duplicate()
	if root_id not in carrier_ids: carrier_ids.push_front(root_id)
	var rng := RandomNumberGenerator.new()
	# Preserve the already-tested default stream, while secondary anatomy gets
	# its own explicit stream without consuming or reseeding the body's RNG.
	rng.seed = int(g.dna.get("seed", 1)) ^ 0x5A17C3 ^ int(stream_id.hash()) ^ int("body:cavities".hash())
	# This operation is strictly subtractive. It never adds a cover pad, rim
	# torus, or buttress that could conceal a missing host wall.
	# Reuse the production displaced field, including earlier cuts. This prepares
	# influences only: no lattice samples, extraction or render job is launched.
	var containment := _prepare_containment_field(g.dna, quality)
	# Largest cavities are placed first, then bounded, non-grid rejection fills
	# a few smaller spaces. Unequal axes and oblique angles avoid a hole lattice.
	var desired := mini([7, 10, 11][quality], 5 + int(round(porosity * 6.0)))
	desired = mini(desired, allowance)
	var size_distribution_count := desired
	if morphology.has("maximum_cavities"):
		desired = mini(desired, clampi(int(morphology.maximum_cavities), 0, MAX_HOLES))
		result["maximum_cavities"] = clampi(int(morphology.maximum_cavities), 0, MAX_HOLES)
		if desired == 0:
			result["skip_reason"] = "The explicit cavity count cap is zero."
			return result
	result["requested_cavities"] = desired
	result["cavity_requests"] = []
	result["minimum_wall"] = wall
	result["feature_floor"] = feature_floor
	result["sampling_step_estimate"] = estimated_step
	result["domain_extent"] = [domain.x, domain.y]
	var rejection_keys := ["domain_rejections", "spacing_rejections", "surface_rejections", "orientation_rejections", "thickness_rejections", "containment_rejections", "support_rejections"]
	var accepted: Array = []
	for hole in range(desired):
		var initial_attempts := int(result.placement_attempts)
		var initial_rejections := {}
		for key: String in rejection_keys: initial_rejections[key] = int(result[key])
		var large := hole < 2
		var small := hole >= size_distribution_count - 2 and quality > 0
		var radius := radius_scale * (rng.randf_range(0.17, 0.22) if large else (rng.randf_range(0.078, 0.098) if small else rng.randf_range(0.105, 0.145)))
		radius = maxf(radius, feature_floor)
		var aspect := rng.randf_range(1.12, 1.80) if large else rng.randf_range(0.88, 1.42)
		var axes := Vector2(radius, maxf(feature_floor, radius * aspect))
		var angle := rng.randf_range(-0.68, 0.68)
		var depth_ratio := rng.randf_range(1.8, 2.6)
		var candidate: Dictionary = {}
		var first_containment_failure := {}
		var nearest_reported_failure := {}
		var collar_fit_attempts: Array = []
		for attempt in range(MAX_PLACEMENT_ATTEMPTS):
			result.placement_attempts += 1
			# Prefer a supported smaller cavity over a broad cut through the crown.
			if attempt > 0 and attempt % 24 == 0:
				axes = Vector2(maxf(feature_floor, axes.x * 0.86), maxf(feature_floor, axes.y * 0.86))
			var local := Vector2(rng.randf_range(-0.86, 0.86) * domain.x, rng.randf_range(-0.85, 0.85) * domain.y)
			if hole == 0 and attempt == 0: local = Vector2(-0.19 * domain.x, -0.19 * domain.y)
			if hole == 1 and attempt == 0: local = Vector2(0.38 * domain.x, 0.31 * domain.y)
			if not _fits_domain(local, axes, angle, domain, wall):
				result.domain_rejections += 1
				continue
			if not _separated(local, axes, angle, accepted, wall):
				result.spacing_rejections += 1
				continue
			var nominal := origin + frame.x * local.x + frame.y * local.y
			var projected := _front_surface(g, nominal, normal, maxf(width, maxf(height, depth)) * 2.8, carrier_ids)
			if projected.is_empty():
				result.surface_rejections += 1
				continue
			var crossing := _actual_surface_crossing(containment, projected.point, normal, maxf(scale * 0.65, estimated_step * 10.0))
			if crossing.is_empty():
				result.surface_rejections += 1
				continue
			var surface: Vector3 = crossing.point
			# Reject silhouette edges before carving. A front-domain ray must hit
			# a genuinely frontal patch, not graze the top of an inflated sac.
			if _field_normal(containment, surface, estimated_step * 0.35).dot(normal) < 0.72:
				result.orientation_rejections += 1
				continue
			var host_thickness := _contiguous_thickness(containment, surface, normal, maxf(depth * 3.0, scale * 3.0), estimated_step * 0.45)
			var throat_depth := minf(maxf(axes.x * depth_ratio, axes.y * 1.3), depth * 0.64)
			# Burial is bounded and explicit. Reserve a genuinely resolved
			# wall before the FIRST rear exit, never a later, disconnected lobe.
			throat_depth = minf(throat_depth, (host_thickness - wall * 2.0) / (1.0 + BURIAL_RATIO))
			if throat_depth < minf(axes.x, axes.y) * 1.3:
				result.thickness_rejections += 1
				continue
			var center := surface - normal * throat_depth * BURIAL_RATIO
			var cut_frame := frame * Basis(Vector3.BACK, angle)
			var radii := Vector3(axes.x, axes.y, throat_depth)
			var containment_failure := _first_containment_failure(containment, center, cut_frame, radii, wall)
			var depth_fit := {}
			if not containment_failure.is_empty() and bool(morphology.get("fit_convex_collar", false)):
				var depth_cap := minf(depth * 0.64, (host_thickness - wall * 2.0) / (1.0 + BURIAL_RATIO))
				depth_fit = _fit_convex_collar(containment, surface, cut_frame, radii, wall, depth_cap, estimated_step, containment_failure)
				depth_fit["placement_attempt"] = attempt
				collar_fit_attempts.append(depth_fit)
				containment_failure = depth_fit.failure
				throat_depth = float(depth_fit.fitted_depth)
				center = surface - normal * throat_depth * BURIAL_RATIO
				radii.z = throat_depth
			if not containment_failure.is_empty():
				containment_failure.merge({"attempt": attempt, "candidate_center": Graph.arr(center), "candidate_radii": Graph.arr(radii), "candidate_forward": Graph.arr(cut_frame.z), "surface_point": Graph.arr(surface), "surface_signed_distance": containment.sample_signed_distance(surface), "host_thickness": host_thickness}, true)
				if first_containment_failure.is_empty(): first_containment_failure = containment_failure
				if nearest_reported_failure.is_empty() or float(containment_failure.excess_distance) < float(nearest_reported_failure.excess_distance): nearest_reported_failure = containment_failure
				result.containment_rejections += 1
				continue
			if not _supports_preserved(g, regions.get("support_ids", []), center, cut_frame, radii, wall):
				result.support_rejections += 1
				continue
			candidate = {"local": local, "axes": axes, "angle": angle, "surface": surface, "parent": projected.parent, "depth": throat_depth, "center": center, "host_thickness": host_thickness}
			if not depth_fit.is_empty(): candidate["depth_fit"] = depth_fit
			break
		var request_report := {"request_index": hole, "accepted": not candidate.is_empty(), "attempts": int(result.placement_attempts) - initial_attempts, "rejection_counts": {}, "final_tangent_axes": [axes.x, axes.y], "quality": quality, "metrics_space": "unscaled_authoring"}
		for key: String in rejection_keys: request_report.rejection_counts[key] = int(result[key]) - int(initial_rejections[key])
		if bool(morphology.get("fit_convex_collar", false)):
			request_report["convex_collar_fit_attempts"] = collar_fit_attempts
		if not first_containment_failure.is_empty():
			request_report["first_containment_failure"] = first_containment_failure
			request_report["closest_reported_first_failure"] = nearest_reported_failure
			request_report["containment_diagnostic_note"] = "Each candidate stops at its first failed sample. Closest compares only those reported samples, not the complete candidate shell."
		if candidate.is_empty():
			request_report["skip_reason"] = "All bounded candidates failed the reported predicates; no aperture was forced."
			result.cavity_requests.append(request_report)
			continue
		accepted.append(candidate)
		# A depth of several aperture radii creates an actual throat and shadow
		# volume. No automatic per-hole torus/lip or front-facing decal is added.
		var throat_depth: float = candidate.depth
		var center: Vector3 = candidate.center
		var parent := _nearest_carrier(g, carrier_ids, center)
		var id: String = g.cavity(parent, center, Vector3(axes.x, axes.y, throat_depth))
		var node: Dictionary = g.node(id)
		node["rotation"] = Graph.arr((frame * Basis(Vector3.BACK, angle)).get_euler())
		node["blend"] = scale * 0.025
		node["noise"] = 0.0
		node["surface_opening"] = false
		node["normal"] = Graph.arr(normal)
		node["blob_region"] = "porous_void"
		node["porous_growth"] = {"domain_uv": [candidate.local.x / domain.x, candidate.local.y / domain.y], "minimum_wall": wall, "effective_feature_floor": feature_floor, "small": small, "complete_rim": true, "back_wall": true, "host_thickness": candidate.host_thickness, "containment_samples": RIM_SAMPLES * SHELL_DEPTHS.size() + 9, "containment_method": "contiguous_host_thickness_and_full_inward_shell", "burial_ratio": BURIAL_RATIO, "metrics_space": "unscaled_authoring"}
		if candidate.has("depth_fit"):
			var fit: Dictionary = candidate.depth_fit
			node.porous_growth["convex_collar_fit"] = {"original_depth": fit.original_depth, "fitted_depth": fit.fitted_depth, "depth_cap": fit.depth_cap, "burial_ratio": BURIAL_RATIO, "aperture_axes_preserved": true, "full_shell_rechecked": true, "fit_steps": fit.steps.size()}
		result.pore_nodes.append(id)
		request_report["cavity_id"] = id
		result.cavity_requests.append(request_report)
		if small: result.small_pores += 1
	result["accepted_cavities"] = result.pore_nodes.size()
	result["unplaced_cavities"] = desired - result.pore_nodes.size()
	if result.pore_nodes.is_empty():
		# A secondary part can be too small for the global effective resolution.
		# Do not leave an unperforated cap or claim that an effect was applied.
		for i in range(start_count, g.dna.nodes.size()): g.index.erase(str(g.dna.nodes[i].id))
		g.dna.nodes.resize(start_count)
		g.dna.connections.resize(start_connections)
		g.rng.state = previous_rng_state
		result["matrix_nodes"] = []
		result["skip_reason"] = "No supported aperture fits the requested anatomical domain and effective resolution."
		return result
	result["enabled"] = not result.pore_nodes.is_empty()
	result["added_nodes"] = g.dna.nodes.size() - start_count
	result["minimum_wall"] = wall
	result["feature_floor"] = feature_floor
	result["sampling_step_estimate"] = estimated_step
	result["matrix_growth"] = false
	result["strictly_subtractive"] = true
	result["domain_extent"] = [domain.x, domain.y]
	result["small_pores"] = mini(int(result.small_pores), 2)
	# Adding optional porosity must not reroll later faces or other body anatomy.
	g.rng.state = previous_rng_state
	for i in range(start_count, g.dna.nodes.size()):
		g.dna.nodes[i]["surface_application"] = application_id
		g.dna.nodes[i]["surface_stage"] = 2
		g.dna.nodes[i]["pipeline_stage"] = pipeline_stage
		g.dna.nodes[i]["surface_domain"] = domain_id
		g.dna.nodes[i]["surface_operation"] = "deep_cavities"
		g.dna.nodes[i]["surface_operation_selector"] = "cavities"
	if not g.dna.metadata.has("surface_applications"): g.dna.metadata["surface_applications"] = {}
	g.dna.metadata.surface_applications[application_id] = result.duplicate(true)
	if not g.dna.metadata.has("surface_streams"): g.dna.metadata["surface_streams"] = {}
	g.dna.metadata.surface_streams[stream_id] = {"application_id": application_id, "application_signature": signature, "domain_id": domain_id, "pipeline_stage": pipeline_stage}
	return result

## Only scalar field preparation from the shared production implementation.
## Production noise depends on grounded world coordinates, not only a node's
## local coordinates. Apply the exact finish transform to a private snapshot,
## then map queries back into the unscaled authoring domain.
static func _prepare_containment_field(dna: Dictionary, quality: int) -> RefCounted:
	# One shared transform/noise interpretation for all surface operators.
	# Staged hosts honor frozen Stage 1 translation; old builders keep legacy
	# grounding. Keep this wrapper for existing cavity/rim/diagnostic callers.
	return Field.prepare(dna, quality)

static func _actual_surface_crossing(field: RefCounted, nominal: Vector3, normal: Vector3, reach: float) -> Dictionary:
	# Newton-style projection along an authored normal can stall on displaced
	# tissue. Bracket the FIRST front crossing, then bisect it deterministically.
	var previous := nominal + normal * reach
	var previous_value: float = field.sample_signed_distance(previous)
	if previous_value <= 0.0: return {}
	for i in range(1, 65):
		var current := nominal + normal * lerpf(reach, -reach, float(i) / 64.0)
		var value: float = field.sample_signed_distance(current)
		if value <= 0.0 and previous_value > 0.0:
			var outside := previous
			var inside := current
			for iteration in range(14):
				var middle := outside.lerp(inside, 0.5)
				if field.sample_signed_distance(middle) <= 0.0: inside = middle
				else: outside = middle
			return {"point": outside.lerp(inside, 0.5)}
		previous = current
		previous_value = value
	return {}

static func _field_normal(field: RefCounted, point: Vector3, epsilon: float) -> Vector3:
	var e := maxf(epsilon, 0.001)
	return Vector3(
		field.sample_signed_distance(point + Vector3.RIGHT * e) - field.sample_signed_distance(point - Vector3.RIGHT * e),
		field.sample_signed_distance(point + Vector3.UP * e) - field.sample_signed_distance(point - Vector3.UP * e),
		field.sample_signed_distance(point + Vector3.BACK * e) - field.sample_signed_distance(point - Vector3.BACK * e)).normalized()

static func _contiguous_thickness(field: RefCounted, surface: Vector3, normal: Vector3, reach: float, sample_step: float) -> float:
	# Bounded marching, stopping at the first exit. A back-wall sample alone
	# can wrongly find a different sac beyond an intervening air gap.
	var steps := clampi(ceili(reach / maxf(sample_step, 0.002)), 8, 256)
	var stride := reach / float(steps)
	var inside := false
	for i in range(1, steps + 1):
		var distance := float(i) * stride
		var value: float = field.sample_signed_distance(surface - normal * distance)
		if value < 0.0:
			inside = true
		elif inside:
			return maxf(distance - stride, 0.0)
		else:
			return 0.0
	return reach if inside else 0.0

static func _fit_convex_collar(field: RefCounted, surface: Vector3, frame: Basis, radii: Vector3, wall: float, depth_cap: float, sample_step: float, original_failure: Dictionary) -> Dictionary:
	# Optional regional fit only. Deeper burial at the SAME ratio preserves the
	# intended aperture axes while moving the supported collar into convex
	# tissue. Every trial still has to pass the exact complete-shell/back test.
	var result := {"accepted": false, "original_depth": radii.z, "fitted_depth": radii.z, "depth_cap": depth_cap, "aperture_axes": [radii.x, radii.y], "burial_ratio": BURIAL_RATIO, "maximum_fit_steps": 5, "steps": [], "failure": original_failure.duplicate(true), "metrics_space": "unscaled_authoring"}
	var depth := radii.z
	var failure := original_failure.duplicate(true)
	for fit_index in range(5):
		if str(failure.get("check", "")) != "full_inward_shell" or float(failure.get("depth_fraction", -1.0)) < 0.0:
			result["stop_reason"] = "The failed constraint is not the front collar; no deeper fit is attempted."
			break
		# This is a bounded proposal, not a safety estimate. The measured excess
		# only chooses the next depth; the full production field decides validity.
		var advance := maxf(sample_step * 0.50, float(failure.excess_distance) / 0.25)
		var next_depth := minf(depth_cap, depth + advance)
		if next_depth <= depth + 0.000001:
			result["stop_reason"] = "The unchanged anatomical/first-exit depth cap has been reached."
			break
		var trial_radii := Vector3(radii.x, radii.y, next_depth)
		var center := surface - frame.z * next_depth * BURIAL_RATIO
		var trial_failure := _first_containment_failure(field, center, frame, trial_radii, wall)
		result.steps.append({"fit_index": fit_index, "previous_depth": depth, "trial_depth": next_depth, "previous_failure": failure.duplicate(true), "failure": trial_failure.duplicate(true), "complete_shell_passed": trial_failure.is_empty()})
		depth = next_depth
		result.fitted_depth = depth
		result.failure = trial_failure
		if trial_failure.is_empty():
			result.accepted = true
			return result
		failure = trial_failure
	if not result.has("stop_reason"): result["stop_reason"] = "The bounded five-step fit did not produce a completely contained shell."
	return result

static func _contained_cut(field: RefCounted, center: Vector3, frame: Basis, radii: Vector3, wall: float) -> bool:
	return _first_containment_failure(field, center, frame, radii, wall).is_empty()

static func _first_containment_failure(field: RefCounted, center: Vector3, frame: Basis, radii: Vector3, wall: float) -> Dictionary:
	# The complete inward ellipsoid shell, inflated by a resolved wall, must
	# remain in actual displaced host tissue. Two equatorial rings cannot
	# protect tapered flanks or prevent an open-edge bite through the crown.
	for depth_fraction: float in SHELL_DEPTHS:
		var radial := sqrt(maxf(0.0, 1.0 - depth_fraction * depth_fraction))
		for i in range(RIM_SAMPLES):
			var angle := TAU * float(i) / float(RIM_SAMPLES)
			var shell := Vector3(cos(angle) * (radii.x + wall) * radial, sin(angle) * (radii.y + wall) * radial, (radii.z + wall) * depth_fraction)
			var value: float = field.sample_signed_distance(center + frame * shell)
			if value > -wall * 0.35:
				return {"check": "full_inward_shell", "depth_fraction": depth_fraction, "angular_sample": i, "sample_local": Graph.arr(shell), "sample_authoring": Graph.arr(center + frame * shell), "signed_distance": value, "required_maximum_distance": -wall * 0.35, "excess_distance": value + wall * 0.35, "metrics_space": "unscaled_authoring"}
	# A finite disk immediately behind the throat verifies a real back wall,
	# including oblique taper away from the center ray.
	for i in range(9):
		var angle := TAU * float(i) / 8.0
		var radial := 0.0 if i == 8 else 0.40
		var back := Vector3(cos(angle) * radii.x * radial, sin(angle) * radii.y * radial, -radii.z - wall)
		var value: float = field.sample_signed_distance(center + frame * back)
		if value > -wall * 0.35:
			return {"check": "finite_back_disk", "angular_sample": i, "sample_local": Graph.arr(back), "sample_authoring": Graph.arr(center + frame * back), "signed_distance": value, "required_maximum_distance": -wall * 0.35, "excess_distance": value + wall * 0.35, "metrics_space": "unscaled_authoring"}
	return {}

static func _supports_preserved(g: RefCounted, supports: Array, center: Vector3, frame: Basis, radii: Vector3, wall: float) -> bool:
	for id: String in supports:
		var support: Dictionary = g.node(id)
		if support.is_empty(): continue
		var points: Array = support.get("points", [support.get("position", [0, 0, 0])])
		var support_radii: Array = support.get("radii", [])
		for i in range(points.size()):
			var radius := float(support_radii[i]) if i < support_radii.size() else Graph.vec(support.get("size", [0.1, 0.1, 0.1])).length() * 0.58
			if SDF.ellipsoid(frame.inverse() * (Graph.vec(points[i]) - center), radii) < radius + wall: return false
	return true

static func _fits_domain(point: Vector2, axes: Vector2, angle: float, extent: Vector2, wall: float) -> bool:
	for i in range(12):
		var phase := TAU * float(i) / 12.0
		var rim := point + Vector2(cos(phase) * (axes.x + wall), sin(phase) * (axes.y + wall)).rotated(angle)
		if (rim / extent).length_squared() > 1.0: return false
	return true

static func _ellipse_support(axes: Vector2, angle: float, direction: Vector2) -> float:
	var local := direction.rotated(-angle)
	return sqrt(pow(local.x * axes.x, 2.0) + pow(local.y * axes.y, 2.0))

static func _separated(point: Vector2, axes: Vector2, angle: float, accepted: Array, wall: float) -> bool:
	for previous: Dictionary in accepted:
		var delta: Vector2 = point - previous.local
		var direction := delta.normalized()
		if delta.length() < _ellipse_support(axes, angle, direction) + _ellipse_support(previous.axes, previous.angle, direction) + wall: return false
	return true

static func _nearest_carrier(g: RefCounted, hosts: Array, point: Vector3) -> String:
	var nearest := INF
	var selected := str(hosts[0])
	for host: String in hosts:
		var distance := absf(Graph.distance_to_tissue(g.node(host), point))
		if distance < nearest: nearest = distance; selected = host
	return selected

static func _front_surface(g: RefCounted, point: Vector3, normal: Vector3, reach: float, carrier_ids: Array) -> Dictionary:
	# Cast toward the body from outside. Exact ellipsoid/capsule primitives are
	# sufficient for the authored anchor; the aperture extends well beyond its
	# small displacement band. Ignore cavities to avoid seating on a prior hole.
	var previous := point + normal * reach
	var previous_distance := _envelope(g, previous, carrier_ids)
	for i in range(1, 65):
		var current := point + normal * lerpf(reach, -reach, float(i) / 64.0)
		var distance := _envelope(g, current, carrier_ids)
		if distance < 0.0 and previous_distance >= 0.0:
			var outside := previous
			var inside := current
			for iteration in range(12):
				var middle := outside.lerp(inside, 0.5)
				if _envelope(g, middle, carrier_ids) < 0.0: inside = middle
				else: outside = middle
			var surface := outside.lerp(inside, 0.5)
			var closest := INF
			var parent := ""
			for node: Dictionary in g.dna.nodes:
				if str(node.id) not in carrier_ids: continue
				if node.kind == "cavity" or node.get("operation", "union") == "subtract": continue
				var d := absf(Graph.distance_to_tissue(node, surface))
				if d < closest: closest = d; parent = str(node.id)
			return {"point": surface, "parent": parent}
		previous = current
		previous_distance = distance
	return {}

static func _envelope(g: RefCounted, point: Vector3, carrier_ids: Array) -> float:
	var distance := INF
	for node: Dictionary in g.dna.nodes:
		if str(node.id) not in carrier_ids: continue
		if node.kind == "cavity" or node.get("operation", "union") == "subtract": continue
		if node.get("role", "") == "tendon" or node.get("shape", {}).get("geometry", "") == "detail": continue
		var field := INF
		if node.kind == "curve":
			var points: Array = node.get("points", [])
			var radii: Array = node.get("radii", [])
			for i in range(points.size() - 1):
				field = minf(field, SDF.tapered_capsule(point, Graph.vec(points[i]), Graph.vec(points[i + 1]), float(radii[i]), float(radii[i + 1])))
		else:
			field = SDF.ellipsoid(Graph.node_basis(node).inverse() * (point - Graph.vec(node.position)), Graph.vec(node.size))
		distance = field if distance == INF else SDF.smooth_union(distance, field, maxf(float(node.get("blend", 0.1)), 0.001))
	return distance

static func _sampling_step_estimate(g: RefCounted, quality: int) -> float:
	# Conservative unscaled-domain estimate of the production lattice. Account
	# for the WHOLE creature, not just this patch: tall sacs or long supports
	# must reduce pore count instead of shrinking pores below useful resolution.
	var bounds := AABB()
	var initialized := false
	var irregularity := clampf(float(g.settings.get("irregularity", 0.45)), 0.0, 1.0)
	for node: Dictionary in g.dna.nodes:
		if node.kind == "cavity" or node.get("operation", "union") == "subtract": continue
		if node.get("role", "") == "tendon" or node.get("shape", {}).get("geometry", "") == "detail": continue
		var size := Graph.vec(node.size)
		var shape: Dictionary = node.get("shape", {})
		var box := AABB()
		var padding := float(node.get("blend", 0.1)) * 1.1 + minf(size.x, minf(size.y, size.z)) * 0.18
		if node.kind == "curve":
			var maximum_radius := 0.0
			for radius: float in node.get("radii", []): maximum_radius = maxf(maximum_radius, radius)
			maximum_radius *= maxf(1.0, maxf(float(shape.get("width", 1.0)), float(shape.get("depth", 1.0)))) * 1.12
			var points: Array = node.get("points", [])
			if points.is_empty(): continue
			box = AABB(Graph.vec(points[0]), Vector3.ZERO)
			for point: Variant in points: box = box.expand(Graph.vec(point))
			box = box.grow(maximum_radius + padding)
		else:
			var basis := Graph.node_basis(node)
			var extent := basis.x.abs() * size.x + basis.y.abs() * size.y + basis.z.abs() * size.z
			var sculpt := (0.12 + irregularity * 0.17) * clampf(float(shape.get("sculpt_strength", 1.0)), 0.0, 1.0)
			extent = extent * (1.0 + sculpt * 1.2) + Vector3.ONE * padding
			box = AABB(Graph.vec(node.position) - extent, extent * 2.0)
		bounds = bounds.merge(box) if initialized else box
		initialized = true
	if not initialized: return 0.01
	var axis_limit: int = [48, 94, 132][quality]
	var sample_limit: int = [125000, 480000, 1000000][quality]
	var step := maxf(maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) / float(axis_limit), 0.004)
	for iteration in range(8):
		var dims := Vector3i(ceili(bounds.size.x / step) + 5, ceili(bounds.size.y / step) + 5, ceili(bounds.size.z / step) + 5)
		var count := dims.x * dims.y * dims.z
		if count <= sample_limit: break
		step *= pow(float(count) / float(sample_limit), 1.0 / 3.0) * 1.015
	return step
