extends RefCounted
## Real carriers for seeded_v1 only. Missing slots create neither nodes nor
## blueprint entries. Foundation171 deliberately stays on its untouched path.
const TendonDetail = preload("res://alien_foundry/scripts/anatomy/BlobSecondaryTendonDetail.gd")
const Profiles = preload("res://alien_foundry/scripts/anatomy/BlobIdentityProfiles.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")

static func realize(owner: RefCounted, g: RefCounted, regions: Dictionary, morphology: Dictionary, profile: Dictionary, stage: int) -> Dictionary:
	var validated: Dictionary = Profiles.validate_descriptor(profile)
	if validated.has("error"): return validated
	if profile.profile not in [Profiles.SEEDED,Profiles.POSITIVE] or int(profile.seed) != int(g.dna.seed) or str(g.dna.type) != "Blob" or stage not in [3, 6] or g.current_iteration != stage:
		return {"error": "Blob identity realization requires its matching seeded_v1 organism and authoring stage."}
	var planned: Array = []
	for spec: Dictionary in profile.features:
		if int(spec.stage) == stage: planned.append(spec)
	# Reject rather than silently reusing a parent when AnatomyGraph hits its
	# cap. This protects carrier ownership and truthful absence/presence counts.
	if g.dna.nodes.size() + planned.size() > int(g.dna.budget.nodes):
		return {"error": "Insufficient anatomy node budget for the selected identity profile."}
	for spec: Dictionary in planned:
		if not Blueprint.feature(g.biological_blueprint, str(spec.id)).is_empty():
			return {"error": "Blob identity feature was already realized: " + str(spec.id)}
		if spec.type != "cavity" and (not regions.has(spec.host_region) or g.node(str(regions[spec.host_region])).is_empty()):
			return {"error": "Missing anatomical host for Blob identity feature: " + str(spec.id)}
	var carriers := {}
	var scales := {}
	var ids: Array = []
	for spec: Dictionary in planned:
		var node_id := ""
		match str(spec.type):
			"sac":
				var host_id := str(regions[spec.host_region])
				var host: Dictionary = g.node(host_id)
				var scale := clampf(Graph.vec(host.size).length() * 0.37, 0.24, 0.48) * float(spec.scale_multiplier)
				node_id = _sac(owner, g, host_id, spec, scale)
				scales[spec.id] = scale
			"cavity":
				var parent_id := str(spec.host_feature_id)
				# Descriptor validation guarantees a prior parent sac in stage3.
				node_id = _ostium(g, str(carriers[parent_id]), spec, float(scales[parent_id]))
			"tendril":
				node_id = _tendril(owner, g, str(regions[spec.host_region]), spec, float(morphology.width) * float(spec.length_multiplier))
		carriers[spec.id] = node_id
		ids.append(spec.id)
	return {"ok": true, "status": "realized_geometry" if not ids.is_empty() else "skipped_profile_absent",
		"feature_ids": ids, "carrier_count": ids.size(), "stage": stage,
		"scope": "Authored carriers only; exposed surface and cavity openings require native geometry and visual validation."}

static func _sac(owner: RefCounted, g: RefCounted, host_id: String, spec: Dictionary, scale: float) -> String:
	var host: Dictionary = g.node(host_id)
	var direction: Vector3 = Graph.vec(spec.direction).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = Blueprint.stream_seed(int(g.dna.seed), str(spec.id), "primary_shape")
	var radii := Vector3(scale * rng.randf_range(0.82, 1.04), scale * rng.randf_range(1.10, 1.38), scale * 0.87)
	var position: Vector3 = owner._surface_point(host, direction, 0.98) + direction * scale * 0.28
	Blueprint.declare(g.biological_blueprint, str(spec.id), "sac", g.feature_for_node(host_id), 3, direction,
		{"kind": "mass", "role": "primary_sac", "position": Graph.arr(position), "size": Graph.arr(radii), "host_node_id": host_id,
		"attachment": "overlapping_host_neck", "introduction": "base_iteration_3"})
	g.declared_feature_id = str(spec.id)
	g.rng.seed = Blueprint.stream_seed(int(g.dna.seed), str(spec.id), "node_realization")
	var node_id: String = g.mass(host_id, "lobe", position, radii, "flesh", true)
	var node: Dictionary = g.node(node_id)
	node["noise"] = 0.0
	node["blend"] = scale * 0.12
	node["shape"] = {"sculpt_strength": 0.04}
	node["surface"] = {"growth": 0.42, "exposure": 0.12}
	return node_id

static func _ostium(g: RefCounted, parent_node_id: String, spec: Dictionary, parent_scale: float) -> String:
	var parent: Dictionary = g.node(parent_node_id)
	var direction: Vector3 = Graph.vec(spec.direction).normalized()
	var radii: Vector3 = Graph.vec(parent.size)
	# Same outward cap construction as the foundation, at or below its cutter
	# scale. Never subtract directly from a body/support/neck host. Integration
	# stage4 moves and scales this cutter with the owning sac as before.
	var position: Vector3 = Graph.vec(parent.position) + direction * Graph.surface_radius(radii, direction) * 0.94
	var size := Vector3(parent_scale * 0.26, parent_scale * 0.30, parent_scale * 0.32) * float(spec.scale_multiplier)
	Blueprint.declare(g.biological_blueprint, str(spec.id), "cavity", str(spec.host_feature_id), 3, direction,
		{"kind": "cavity", "position": Graph.arr(position), "size": Graph.arr(size), "host_node_id": parent_node_id})
	g.declared_feature_id = str(spec.id)
	g.rng.seed = Blueprint.stream_seed(int(g.dna.seed), str(spec.id), "node_realization")
	var node_id: String = g.cavity(parent_node_id, position, size)
	g.node(node_id)["surface_opening"] = false
	return node_id

static func _tendril(owner: RefCounted, g: RefCounted, host_id: String, spec: Dictionary, length: float) -> String:
	var direction: Vector3 = Graph.vec(spec.direction).normalized()
	var host: Dictionary = g.node(host_id)
	var start: Vector3 = owner._surface_point(host, direction, 0.77)
	var side := direction.cross(Vector3.FORWARD).normalized()
	var middle := start + direction * length * 0.67 + side * length * 0.20
	var end := start + direction * length + side * length * 0.48 - Vector3.UP * length * 0.19
	var radius := clampf(length * 0.075, 0.055, 0.11)
	var points := [start, middle, end]
	var radii := [radius, radius * 0.62, radius * 0.27]
	Blueprint.declare(g.biological_blueprint, str(spec.id), "tendril", g.feature_for_node(host_id), int(spec.stage), direction,
		{"kind": "curve", "role": "tendril", "points": [Graph.arr(start), Graph.arr(middle), Graph.arr(end)], "radii": radii.duplicate(), "host_node_id": host_id})
	# Author the rule before creating this stage6 geometry carrier.
	if int(spec.stage) == 6:
		var detail_rules: Dictionary = TendonDetail.rules(g.settings)
		if not detail_rules.is_empty(): Blueprint.feature(g.biological_blueprint, str(spec.id))["detail_rules"] = detail_rules
	g.declared_feature_id = str(spec.id)
	g.rng.seed = Blueprint.stream_seed(int(g.dna.seed), str(spec.id), "node_realization")
	var node_id: String = g.curve(host_id, "tendril", points, radii, "muscle", true)
	g.node(node_id)["noise"] = 0.0
	g.node(node_id)["shape"] = {"swelling": 0.0, "twist": 0.0, "taper": 0.0}
	return node_id
