extends RefCounted
## Default-off Stage 1 experiment. Four or five existing primary compartments
## form a descending load, not a radial crown of equally exposed decorations.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const VERSIONS := [1, 2, 3, 4]
const STREAM := "base.loaded_lobes.v1"
const CANDIDATE_LIMIT := 12

static func build(generator: RefCounted, g: RefCounted, m: Dictionary) -> Dictionary:
	var version := int(g.settings.get("blob_loaded_lobe_version", 1))
	g.rng.seed = generator._stream_seed(int(g.dna.seed), STREAM)
	var w := float(m.width); var h := float(m.height); var d := float(m.depth)
	var mirror := float(m.mirror)
	var fullness := lerpf(0.96, 1.05, float(m.belly))
	var upper_scale := lerpf(0.98, 1.05, float(m.mass_hierarchy))
	var root: String = generator._mass(g, "", "core",
		Vector3(mirror * w * 0.12, h * 0.91, d * 0.13),
		Vector3(w * 0.58, h * 0.57, d * 0.61) * upper_scale,
		Vector3(0.12, -mirror * 0.08, -mirror * 0.17), "flesh", "loaded_upper_mass", 0.075)
	var hosts: Array = [root]
	var placement: Array = []
	# V2 changes only the belly's authored depth and settling. Keep the v1
	# stream and every other parameter so the comparison isolates this change.
	var belly := _place(generator, g, hosts, root,
		Vector3(-mirror * w * 0.16, h * (0.29 if version == 2 else 0.34), -d * (0.47 if version == 2 else 0.23)),
		Vector3(w * 0.59, h * 0.38, d * 0.57) * fullness,
		Vector3(0.12, mirror * 0.13, mirror * 0.10),
		Vector3(-mirror * w * 0.06, -h * 0.025, -d * 0.06), "loaded_belly", placement)
	var flank := _place(generator, g, hosts, root,
		Vector3(mirror * w * 0.54, h * 0.64, -d * 0.24),
		Vector3(w * 0.42, h * 0.40, d * 0.46),
		Vector3(-0.14, -mirror * 0.12, mirror * 0.23),
		Vector3(mirror * w * 0.06, 0.0, -d * 0.07), "loaded_flank", placement)
	# This subordinate compartment grows down the flank compartment itself.
	# Its broad overlap with the belly also settles the load into the base.
	_place(generator, g, hosts, flank if not flank.is_empty() else root,
		Vector3(mirror * w * 0.57, h * 0.25, -d * 0.12),
		Vector3(w * 0.32, h * 0.27, d * 0.37),
		Vector3(0.15, mirror * 0.15, -mirror * 0.14),
		Vector3(mirror * w * 0.05, -h * 0.015, -d * 0.045), "loaded_lower_flank", placement)
	var optional_count: int = generator._compartment_count(g, 0, 1)
	if optional_count == 1:
		_place(generator, g, hosts, belly if not belly.is_empty() else root,
			Vector3(-mirror * w * 0.55, h * 0.43, d * 0.20),
			Vector3(w * 0.32, h * 0.30, d * 0.37),
			Vector3(-0.18, mirror * 0.18, mirror * 0.16),
			Vector3(-mirror * w * 0.05, 0.0, d * 0.05), "loaded_rear_fold", placement)
	if version in [3, 4]:
		g.node(root).shape["loaded_upper_floor_off"] = 1
	if version == 4:
		for id: String in hosts:
			var node: Dictionary = g.node(id)
			var contact_id := belly if id == root else str(node.parent)
			var direction := Graph.vec(g.node(contact_id).position) - Graph.vec(node.position)
			var axis := ((Graph.node_basis(node).inverse() * direction) / Graph.vec(node.size)).normalized()
			var region := str(node.blob_region)
			node.shape["loaded_contact_profile"] = {"version": 1, "axis": Graph.arr(axis),
				"compression": 0.16 if region == "loaded_belly" else 0.12,
				"spread": 0.18 if region == "loaded_belly" else 0.15}
	g.dna.metadata["loaded_lobe_anatomy"] = {
		"version": version, "seed_stream": STREAM, "status": "unaccepted_stage1_experiment",
		"requested_primary_count": 4 + optional_count, "placed_primary_count": hosts.size(),
		"placement": placement, "surface_decoration": false,
		"layout": "dominant upper mass, settled belly, unequal descending flank compartments",
		"minimum_exposed_fraction": 0.30, "minimum_retained_fraction": 0.26,
		"minimum_overlap_depth_fraction": 0.38, "candidate_limit": CANDIDATE_LIMIT}
	return generator._semantic_regions(g, root, hosts)

static func _place(generator: RefCounted, g: RefCounted, hosts: Array, parent: String,
		target: Vector3, desired_size: Vector3, rotation: Vector3, adjustment: Vector3,
		region: String, audit: Array) -> String:
	var host: Dictionary = g.node(parent)
	var best: Dictionary = {}; var best_score := -INF
	# Small bounded moves preserve authored descending order. Unlike the old
	# radial placer, exposure is a gate rather than the quantity to maximize.
	for attempt in range(CANDIDATE_LIMIT):
		var step: float = [0.0, 1.0, -0.5, 2.0, 0.5, 1.5][attempt % 6]
		var point := target + adjustment * step
		var size := desired_size * (1.0 if attempt < 6 else 0.94)
		var proposed := {"position": Graph.arr(point), "size": Graph.arr(size), "rotation": Graph.arr(rotation), "kind": "mass"}
		var delta := point - Graph.vec(host.position)
		var direction := delta.normalized()
		var parent_radius := Graph.surface_radius(Graph.vec(host.size), Graph.node_basis(host).inverse() * direction)
		var own_radius := Graph.surface_radius(size, Basis.from_euler(rotation).inverse() * direction)
		var overlap := parent_radius + own_radius - delta.length()
		var overlap_fraction := overlap / minf(parent_radius, own_radius)
		if overlap_fraction < 0.38: continue
		var exposure: Dictionary = generator._surface_exposure(proposed, g.dna.nodes)
		if float(exposure.fraction) < 0.30: continue
		var swallowed := false
		for id: String in hosts:
			if id != parent and generator._covered_fraction(g.node(id), proposed) > 0.40:
				swallowed = true; break
			var remaining: Array = [proposed]
			for other: Dictionary in g.dna.nodes:
				if str(other.id) != id: remaining.append(other)
			if float(generator._surface_exposure(g.node(id), remaining).fraction) < 0.26:
				swallowed = true; break
		if swallowed: continue
		var score := -absf(float(exposure.fraction) - 0.52) * 0.10 - absf(step) * 0.025 - float(attempt / 6) * 0.04
		if score > best_score:
			best_score = score
			best = {"point": point, "size": size, "exposure": exposure.fraction,
				"overlap_fraction": overlap_fraction, "candidate": attempt}
	if best.is_empty():
		audit.append({"region": region, "parent": parent, "placed": false, "reason": "No broad overlapping, exposed, non-swallowing placement"})
		return ""
	var id: String = generator._mass(g, parent, "lobe", best.point, best.size, rotation, "flesh", region, 0.075)
	g.node(id)["primary_placement"] = {"exposed_fraction": best.exposure,
		"overlap_depth_fraction": best.overlap_fraction, "bounded_candidates": CANDIDATE_LIMIT,
		"candidate_index": best.candidate, "layout_version": int(g.settings.get("blob_loaded_lobe_version", 1))}
	hosts.append(id)
	audit.append({"region": region, "node": id, "parent": parent, "placed": true,
		"candidate": best.candidate, "exposed_fraction": best.exposure, "overlap_depth_fraction": best.overlap_fraction})
	return id
