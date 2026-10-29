extends RefCounted
## One bounded refinement of the existing hanging organism, not a new grammar.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Tissue = preload("res://alien_foundry/scripts/geometry/BlobHangingTissueField.gd")
const Root = preload("res://alien_foundry/scripts/geometry/BlobHangingRootField.gd")
const SETTING := "blob_hanging_load_version"

static func selected(settings: Dictionary) -> bool:
	var value: Variant = settings.get(SETTING, 0)
	return (value is int or value is float) and float(value) in [1.0, 2.0]

static func apply(g: RefCounted, regions: Dictionary, m: Dictionary) -> void:
	if not selected(g.settings) or int(m.grammar_index) != 2: return
	var w := float(m.width); var h := float(m.height); var d := float(m.depth)
	var root_id := str(regions.root)
	var original: Dictionary = {}
	for node: Dictionary in g.dna.nodes: original[str(node.id)] = node.duplicate(true)
	# Reduce the spanning carrier and distribute its load into the same existing
	# compartments. The tallest pendant keeps its low pole, but no longer sends
	# its long upper ellipsoid pole through the crown as a horn.
	for i in range(regions.hosts.size()):
		var node: Dictionary = g.node(str(regions.hosts[i]))
		var p: Vector3 = Graph.vec(node.position); var s: Vector3 = Graph.vec(node.size)
		if i == 0:
			p += Vector3(0.0, -h * 0.03, 0.0); s *= Vector3(0.85, 0.75, 0.80)
		elif i == 1:
			p.y -= s.y * 0.15; s *= Vector3(1.27, 0.85, 1.20)
		elif i == 2:
			p += Vector3(0.0, h * 0.05, -d * 0.08); s *= Vector3(1.08, 1.32, 1.28)
		elif i == 3:
			p += Vector3(w * 0.06, h * 0.10, 0.0); s *= Vector3(1.50, 1.20, 1.28)
		else:
			p.y += h * 0.05; s *= Vector3(1.10, 1.16, 1.15)
		node["position"] = Graph.arr(p); node["size"] = Graph.arr(s)
		node["radius"] = minf(s.x, minf(s.y, s.z))
		node["blend"] = float(original[str(node.id)].blend) * (1.35 if i == 0 else 1.20)
		node["noise"] = 0.0
		var descriptor: Dictionary = _descriptor(node, i, g, regions, original)
		node["shape"] = {"hanging_tissue": descriptor}
		node["hanging_load_anatomy"] = {"version": 1, "existing_compartment_index": i, "no_added_mass": true}
	# No route reroll: only the buried origin and proximal radius change. The
	# last three controls and radii stay bit-identical to the completed baseline.
	var root_audits: Array = []
	for id in regions.support_ids:
		var node: Dictionary = g.node(str(id)); var old: Dictionary = original[str(id)]
		var host: Dictionary = g.node(str(node.parent))
		var old_host: Dictionary = original[str(node.parent)]
		var local_origin: Vector3 = Graph.vec(old.points[0]) - Graph.vec(old_host.position)
		var anchor: Vector3 = Graph.vec(host.position) + local_origin * 0.24
		node.points[0] = Graph.arr(anchor); node["position"] = Graph.arr(anchor)
		var host_size: Vector3 = Graph.vec(host.size)
		var shoulder: float = minf(float(old.radii[0]) * 1.38, minf(host_size.x, minf(host_size.y, host_size.z)) * 0.60)
		node.radii[0] = maxf(shoulder, float(old.radii[0]))
		node.radii[1] = float(old.radii[1]) * 1.03
		node["radius"] = node.radii[0]
		node["size"] = Graph.arr(Vector3.ONE * float(node.radius))
		node["blend"] = float(old.blend) * 1.22
		node["shape"] = {"hanging_root_version": 1, "width": 1.0, "depth": 0.95,
			"swelling": 0.0, "twist": 0.0, "taper": 0.0,
			"width_profile": [1.28, 1.08, 1.0, 1.0, 1.0],
			"depth_profile": [0.84, 0.96, 1.0, 1.0, 1.0]}
		node["hanging_load_anatomy"] = {"version": 1, "distal_controls_preserved": [2, 3, 4], "original_route_parent": str(old.parent)}
		root_audits.append({"id": str(id), "parent": str(node.parent), "original_anchor": old.points[0].duplicate(), "new_anchor": node.points[0].duplicate(), "baseline_clearance_is_not_reused_as_candidate_acceptance": true})
	g.dna.metadata["hanging_load_anatomy"] = {"version": 1, "stage1_only": true,
		"existing_mass_count": regions.hosts.size(), "existing_root_count": regions.support_ids.size(),
		"no_new_nodes": true, "parentage_preserved": true, "root_origins": root_audits,
		"construction": "redistribute_existing_compartments_into_sloping_crown_and_continuous_proximal_root_necks",
		"field": "separate_hanging_marker_reuses_unchanged_positive_radial_evaluator_per_existing_mass",
		"generic_core_floor_and_sine_sculpt": "not_applied_to_marked_tissue",
		"candidate_clearance_grounding_and_visual_acceptance": "pending_diagnostic"}
	if int(g.settings.get(SETTING, 0)) == 2: _transfer_axial_load(g, regions)

static func _transfer_axial_load(g: RefCounted, regions: Dictionary) -> void:
	# Version 2 starts from the completed v1 organism. No root, pressure patch,
	# transverse axis, rotation or blend is reauthored. The numerical envelope
	# pins concern isolated fields, not exact bounds of the blended native mesh.
	var audit: Array = []
	for specification in [[0, 1.18, false], [1, 0.80, true]]:
		var node: Dictionary = g.node(str(regions.hosts[int(specification[0])]))
		var old_size: Vector3 = Graph.vec(node.size)
		var size := old_size; size.y *= float(specification[1])
		var upper: bool = bool(specification[2])
		var old_limit := _isolated_limit_y(node, old_size, upper)
		var new_limit := _isolated_limit_y(node, size, upper)
		var old_position: Vector3 = Graph.vec(node.position)
		var position := old_position; position.y += old_limit - new_limit
		node["size"] = Graph.arr(size); node["position"] = Graph.arr(position)
		node["radius"] = minf(size.x, minf(size.y, size.z))
		audit.append({"id": str(node.id), "local_y_multiplier": float(specification[1]),
			"pinned_envelope": "upper" if upper else "lower", "before_size": Graph.arr(old_size),
			"after_size": Graph.arr(size), "before_position": Graph.arr(old_position),
			"after_position": Graph.arr(position), "position_y_delta": position.y - old_position.y,
			"before_numerical_world_limit_y": old_position.y + old_limit,
			"after_numerical_world_limit_y": position.y + new_limit})
	g.dna.metadata.hanging_load_anatomy["version"] = 2
	g.dna.metadata.hanging_load_anatomy["axial_transfer"] = {"nodes": audit,
		"unchanged": "all_roots_other_masses_transverse_axes_rotations_blends_pressure_descriptors",
		"pin_method": "unchanged_radial_field_512_sphere_samples_then_24_direction_refinements",
		"numerical_not_global_proof": true, "merged_native_volume_bounds_and_contacts": "pending_diagnostic"}

static func _isolated_limit_y(node: Dictionary, size: Vector3, upper: bool) -> float:
	var field: RefCounted = Tissue.create(node.shape.hanging_tissue, size)
	var basis: Basis = Graph.node_basis(node)
	# Reflect world Y to reuse the unchanged lower-surface search for maxima.
	if upper: basis = Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.BACK) * basis
	var result: Dictionary = field.minimum_surface_y(basis)
	return -float(result.minimum_y) if upper else float(result.minimum_y)

static func _descriptor(node: Dictionary, index: int, g: RefCounted, regions: Dictionary, original: Dictionary) -> Dictionary:
	var inverse := Graph.node_basis(node).inverse()
	var axes: Array = []
	var amplitudes: Array
	if index == 0:
		# Crown pressure follows the two existing heavy root axes and the large
		# pendant, with broad upper recessions between those three load paths.
		for id in regions.support_ids:
			var old: Dictionary = original[str(id)]
			if str(old.parent) == str(regions.root): axes.append((Graph.vec(old.points[1]) - Graph.vec(node.position)).normalized())
		while axes.size() < 2: axes.append(Vector3(-1.0 if axes.is_empty() else 1.0, -0.7, -0.3).normalized())
		axes.resize(2)
		axes.append(Vector3(-0.65, -0.55, 0.40).normalized())
		axes.append(Vector3(0.10, 0.45, -0.90).normalized())
		axes.append(Vector3(0.40, 0.55, 0.75).normalized())
		axes.append(Vector3(-0.35, 0.92, -0.10).normalized())
		amplitudes = [0.22, 0.17, 0.14, -0.25, -0.14, -0.12]
	else:
		var outward: Vector3 = (Graph.vec(node.position) - g.center(str(regions.root)))
		outward.y = 0.0; outward = outward.normalized()
		var across := Vector3(-outward.z, 0.0, outward.x)
		axes = [(outward * 0.8 + Vector3.DOWN * 0.6).normalized(),
			(outward * 0.35 + across * 0.65 + Vector3.DOWN * 0.30).normalized(),
			(-outward * 0.5 + Vector3.UP * 0.55).normalized(),
			(outward * 0.25 + Vector3.UP).normalized(),
			(-across + Vector3.DOWN * 0.15).normalized(),
			(-outward + Vector3.DOWN * 0.30).normalized()]
		amplitudes = [0.22 if index == 1 else 0.17, 0.10, 0.07, -0.19, -0.11, -0.07]
	var patches: Array = []
	for i in range(6):
		var axis: Vector3 = inverse * axes[i]
		var long_axis: Vector3 = inverse * (Vector3.UP if absf(Vector3(axes[i]).y) < 0.85 else Vector3.FORWARD)
		patches.append([axis.x, axis.y, axis.z, long_axis.x, long_axis.y, long_axis.z,
			0.60 if i < 3 else 0.46, 0.90 if i < 3 else 0.86, amplitudes[i]])
	return {"version": 1, "compression": 1.0, "patches": patches}
