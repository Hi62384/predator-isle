extends RefCounted
## Versioned anatomy authoring, not a mesh transform or a ground-placement fix.
## Only old hanging grammar 2 is in scope. Other grammar inputs are untouched.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const SETTING := "blob_body_profile"
const FOUNDATION := "foundation_171"
const COMPACT := "compact_body_v1"
const VERSION := 1

static func selection(options: Dictionary, grammar: int = -1) -> Dictionary:
	var value: Variant = options.get(SETTING, FOUNDATION)
	if not value is String or value not in [FOUNDATION, COMPACT]:
		return {"error": "Unsupported Blob body profile; use foundation_171 or compact_body_v1."}
	return {"profile": value, "active": value == COMPACT and grammar == 2}

static func lane(seed_value: int, name: String) -> int:
	return ("0x" + ("blob_compact_body_v1|%s|%s" % [seed_value, name]).sha256_text().substr(0, 13)).hex_to_int()

static func value(seed_value: int, name: String, low: float, high: float) -> float:
	return lerpf(low, high, float(lane(seed_value, name) % 1000001) / 1000000.0)

static func ellipsoid_bounds(nodes: Array) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for n: Dictionary in nodes:
		var basis: Basis = Graph.node_basis(n)
		var s: Vector3 = Graph.vec(n.size)
		var p: Vector3 = Graph.vec(n.position)
		var extent := Vector3(
			sqrt(pow(basis.x.x * s.x, 2.0) + pow(basis.y.x * s.y, 2.0) + pow(basis.z.x * s.z, 2.0)),
			sqrt(pow(basis.x.y * s.x, 2.0) + pow(basis.y.y * s.y, 2.0) + pow(basis.z.y * s.z, 2.0)),
			sqrt(pow(basis.x.z * s.x, 2.0) + pow(basis.y.z * s.y, 2.0) + pow(basis.z.z * s.z, 2.0)))
		low = low.min(p - extent); high = high.max(p + extent)
	return AABB(low, high - low)

static func _surface(n: Dictionary, direction: Vector3, fraction: float) -> Vector3:
	var outward := direction.normalized()
	var local: Vector3 = Graph.node_basis(n).inverse() * outward
	return Graph.vec(n.position) + outward * Graph.surface_radius(Graph.vec(n.size), local) * fraction

static func describe(seed_value: int, morphology: Dictionary) -> Dictionary:
	if int(morphology.get("grammar_index", -1)) != 2:
		return {"error": "compact_body_v1 only authors hanging grammar 2."}
	var w := float(morphology.width)
	var d := float(morphology.depth)
	var center := Vector3(float(morphology.mirror) * w * 0.08, 0.0, d * 0.04)
	var yaw := value(seed_value, "core.yaw", -0.22, 0.22)
	var root_size := Vector3(w * 0.68, w * 0.60, d * 0.72)
	var root_position := center + Vector3.UP * root_size.y
	var masses: Array = [{"position": Graph.arr(root_position), "size": Graph.arr(root_size), "rotation": [0.0, yaw, 0.0], "role": "core", "parent_slot": -1}]
	var count := 2 + lane(seed_value, "compartment_count") % 3
	var phase := value(seed_value, "compartment_phase", -PI, PI)
	for i in range(count):
		var prefix := "compartment.%s." % i
		var angle := phase + TAU * float(i) / float(count) + value(seed_value, prefix + "angle", -0.22, 0.22)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var size := Vector3(w * value(seed_value, prefix + "width", 0.24, 0.34), w * value(seed_value, prefix + "height", 0.22, 0.32), d * value(seed_value, prefix + "depth", 0.24, 0.35))
		var position := _surface(masses[0], direction, 0.71) + direction * w * 0.055
		position.y = size.y + w * 0.012
		masses.append({"position": Graph.arr(position), "size": Graph.arr(size), "rotation": [0.0, angle * 0.25, 0.0], "role": "lobe", "parent_slot": 0})
	# Rounded mound height derives from its actual lateral footprint. This
	# changes root volume/shape, not a uniform scaling of pre-existing anatomy.
	var body_box := ellipsoid_bounds(masses)
	var breadth := minf(body_box.size.x, body_box.size.z)
	var body_ratio := lerpf(0.83, 1.03, float(morphology.axial))
	root_size.y = breadth * body_ratio * 0.5
	root_position.y = root_size.y
	masses[0].size = Graph.arr(root_size)
	masses[0].position = Graph.arr(root_position)
	body_box = ellipsoid_bounds(masses)
	breadth = minf(body_box.size.x, body_box.size.z)
	var supports: Array = []
	var requested := 2 + lane(seed_value, "support_count") % 3
	var support_phase := value(seed_value, "support_phase", -PI, PI)
	var rejected := 0
	for i in range(requested):
		var prefix := "support.%s." % i
		var nominal := support_phase + TAU * float(i) / float(requested) + value(seed_value, prefix + "angle", -0.20, 0.20)
		var radius := breadth * value(seed_value, prefix + "radius", 0.09, 0.13)
		var tip_radius := radius * value(seed_value, prefix + "tip", 0.70, 0.82)
		var selected: Dictionary = {}
		for attempt in range(16):
			var angle: float = nominal + [0.0, -0.20, 0.20, -0.38, 0.38, -0.10, 0.10, 0.52][attempt % 8]
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var host_index := 1
			var best_score := -INF
			for h in range(1, masses.size()):
				var score := (Graph.vec(masses[h].position) - center).dot(direction)
				if score > best_score: best_score = score; host_index = h
			var host: Dictionary = masses[host_index]
			var host_center: Vector3 = Graph.vec(host.position)
			var relative_y := (breadth * 0.20 - host_center.y) / float(host.size[1])
			if absf(relative_y) >= 0.90: rejected += 1; continue
			# Ellipsoidal cross-section keeps the broad root buried at a low
			# anatomical band; it is not clipped off an already long leg.
			var anchor := host_center + (_surface(host, direction, 1.0) - host_center) * sqrt(1.0 - relative_y * relative_y) * 0.82
			anchor.y = breadth * 0.20
			var tip := anchor + direction * breadth * (0.17 if attempt < 8 else 0.11)
			tip.y = tip_radius
			var across := Vector3(-direction.z, 0.0, direction.x)
			var middle := anchor.lerp(tip, 0.48) + across * breadth * value(seed_value, prefix + "bow", -0.025, 0.025)
			var candidate := {"parent_slot": host_index, "points": [Graph.arr(anchor), Graph.arr(middle), Graph.arr(tip)], "radii": [radius, radius * 0.94, tip_radius]}
			if not _support_ok(candidate, supports, body_box): rejected += 1; continue
			selected = candidate; break
		if not selected.is_empty(): supports.append(selected)
	if supports.size() < 2:
		return {"error": "Compact anatomy could not place two bounded support lobes; no elongated fallback was authored.", "requested": requested, "accepted": supports.size()}
	return {"version": VERSION, "profile": COMPACT, "seed": seed_value, "masses": masses, "supports": supports,
		"body_bounds": {"position": Graph.arr(body_box.position), "size": Graph.arr(body_box.size)},
		"body_breadth": breadth, "requested_supports": requested, "rejected_support_candidates": rejected,
		"unplaced_supports": requested - supports.size(), "local_contact_plane_y": 0.0,
		"support_candidate_limit": 16, "identity_stream_untouched": true}

static func _support_ok(candidate: Dictionary, prior: Array, body_box: AABB) -> bool:
	var breadth := minf(body_box.size.x, body_box.size.z)
	var a: Vector3 = Graph.vec(candidate.points[0])
	var b: Vector3 = Graph.vec(candidate.points[1])
	var t: Vector3 = Graph.vec(candidate.points[2])
	var radius := float(candidate.radii[0])
	var tip_radius := float(candidate.radii[-1])
	var middle_y := body_box.position.y
	if a.y - middle_y > 0.30 * breadth or a.y - t.y > 0.28 * breadth or a.y < t.y: return false
	if Vector2(a.x - t.x, a.z - t.z).length() > 0.30 * breadth: return false
	if a.distance_to(b) + b.distance_to(t) > 0.50 * breadth: return false
	if radius * 2.0 < 0.18 * breadth - 0.000002 or radius * 2.0 > 0.26 * breadth + 0.000002 or tip_radius < radius * 0.65: return false
	var c := body_box.get_center()
	if absf(t.x - c.x) > body_box.size.x * 0.625 or absf(t.z - c.z) > body_box.size.z * 0.625: return false
	for other: Dictionary in prior:
		if t.distance_to(Graph.vec(other.points[-1])) < (tip_radius + float(other.radii[-1])) * 1.20: return false
	return true

static func build(owner: RefCounted, g: RefCounted, morphology: Dictionary) -> Dictionary:
	var plan := describe(int(g.dna.seed), morphology)
	if plan.has("error"): return plan
	if plan.masses.size() + plan.supports.size() > int(g.dna.budget.nodes):
		return {"error": "Compact anatomy exceeds the node budget."}
	var ids: Array = []
	for spec: Dictionary in plan.masses:
		var parent := "" if int(spec.parent_slot) < 0 else str(ids[int(spec.parent_slot)])
		var id: String = owner._mass(g, parent, str(spec.role), Graph.vec(spec.position), Graph.vec(spec.size), Graph.vec(spec.rotation), "flesh", "core" if parent.is_empty() else "compact_basal_compartment", 0.085)
		g.node(id).shape = {"sculpt_strength": 0.12}
		ids.append(id)
	var regions: Dictionary = owner._semantic_regions(g, str(ids[0]), ids)
	var support_ids: Array = []
	for spec: Dictionary in plan.supports:
		var id: String = g.curve(str(ids[int(spec.parent_slot)]), "limb", spec.points, spec.radii, "flesh", true)
		var node: Dictionary = g.node(id)
		node.blend = float(spec.radii[0]) * 0.65
		node.noise = 0.0
		node.shape = {"swelling": 0.0, "twist": 0.0, "width": 1.0, "depth": 1.0, "width_profile": [1.0, 1.0], "depth_profile": [1.0, 1.0]}
		node["blob_region"] = "compact_basal_support"
		node["surface"] = {"growth": 0.0, "exposure": 0.10}
		support_ids.append(id)
	regions["support_ids"] = support_ids
	var report: Dictionary = plan.duplicate(true)
	report.erase("masses"); report.erase("supports")
	report["body_node_ids"] = ids.duplicate()
	report["support_node_ids"] = support_ids.duplicate()
	report["contact_intent"] = {"body_feature_ids": [g.feature_for_node(str(ids[0]))], "support_feature_ids": [],
		"role": "rounded_belly_and_short_basal_supports", "space": "unscaled_authoring_local", "plane_y": 0.0,
		"actual_surface_contact_unverified": true, "placement_is_separate": true}
	for id: String in support_ids: report.contact_intent.support_feature_ids.append(g.feature_for_node(id))
	g.dna.metadata["compact_body_anatomy"] = report
	return regions
