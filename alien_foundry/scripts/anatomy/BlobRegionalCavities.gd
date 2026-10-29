extends RefCounted
## Regional dispatch, not a new cutter or weakened containment rule.
## The grown sac supplies the target surface and anatomical ownership. The full
## production field, global sampling estimate, wall floor and support guards
## remain those of the established deep-cavity operator.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Cavities = preload("res://alien_foundry/scripts/anatomy/BlobPorousGrowth.gd")
const MAX_TARGETS := 2

static func grow(g: RefCounted, anatomy: Dictionary, morphology: Dictionary, records: Array) -> Dictionary:
	var candidates: Array = []
	for node: Dictionary in g.dna.nodes:
		if str(node.get("surface_operation", "")) != "sacs": continue
		for record: Dictionary in records:
			if str(node.get("surface_region_id", "")) != str(record.id) or "cavities" not in record.allowed_detail_types: continue
			var size := Graph.vec(node.size)
			candidates.append({"node": node, "record": record, "footprint": minf(size.x, size.y)})
			break
	# Stable largest-supported target first; no draw from anatomy's RNG.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.footprint) > float(b.footprint) if not is_equal_approx(float(a.footprint), float(b.footprint)) else str(a.node.id) < str(b.node.id))
	var targets: Array = []
	for index in range(mini(candidates.size(), MAX_TARGETS)):
		var target: Dictionary = candidates[index]
		var node: Dictionary = target.node
		var record: Dictionary = target.record
		var size := Graph.vec(node.size)
		var regional_morphology: Dictionary = morphology.duplicate(true)
		# Retain original global width/height/depth deliberately: local targeting
		# must not lower the existing feature/wall floor to a sac-only resolution.
		regional_morphology.merge({"region_origin": node.position.duplicate(), "region_normal": Graph.arr(Graph.node_basis(node).z.normalized()),
			"region_extent": Graph.arr(Vector3(size.x, size.y, size.z)), "exact_region_extent": true,
			"cavity_radius_scale": 2.0 * minf(size.x, size.y), "maximum_cavities": 1, "fit_convex_collar": true,
			"stream_id": str(morphology.get("stream_id", "surface.cavities")) + ".grown." + str(node.id),
			"application_id": str(morphology.get("application_id", "primary_body.cavities")) + ".grown." + str(node.id)}, true)
		var carrier := {"root": str(node.id), "hosts": [str(node.id)], "support_ids": anatomy.get("support_ids", []).duplicate()}
		var result := Cavities.grow(g, carrier, regional_morphology)
		targets.append({"region_id": str(record.id), "grown_host_id": str(node.id), "anatomical_parent": str(node.parent),
			"enabled": bool(result.get("enabled", false)), "accepted_cavities": int(result.get("accepted_cavities", 0)),
			"skip_reason": str(result.get("skip_reason", "")), "placement_report": result.duplicate(true)})
		if not bool(result.get("enabled", false)): continue
		for id: String in result.pore_nodes:
			var cavity: Dictionary = g.node(id)
			cavity["surface_region_id"] = str(record.id)
			cavity["surface_grown_host"] = str(node.id)
			cavity["surface_anatomical_parent"] = str(node.parent)
			cavity["host_tissue_identity"] = str(node.material)
			# Cavities expose inner tissue, but retain the actual carrier lineage.
			cavity["surface"] = {"growth": float(node.get("surface", {}).get("growth", 0.0)), "exposure": 0.76,
				"tissue_identity": str(cavity.material), "host_tissue_identity": str(node.material), "detail_type": "cavities"}
		result["regional_targets"] = targets
		result["targeting_mode"] = "grown_sac_surface"
		result["target_region_id"] = str(record.id)
		result["grown_host_id"] = str(node.id)
		result["original_host_fallback"] = false
		return result
	# Preserve the exact legacy call if no grown target can satisfy containment.
	# A fallback success is NOT reported as a successful hole inside a new sac.
	var fallback := Cavities.grow(g, anatomy, morphology)
	fallback["regional_targets"] = targets
	fallback["targeting_mode"] = "original_host_fallback"
	fallback["original_host_fallback"] = true
	return fallback
