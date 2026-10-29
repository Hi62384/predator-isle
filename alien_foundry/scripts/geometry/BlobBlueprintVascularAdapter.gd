extends RefCounted
const Carrier = preload("res://alien_foundry/scripts/geometry/DirectSurfaceFeatureCarrier.gd")
const Codec = preload("res://alien_foundry/scripts/persistence/DirectSurfaceRecipeCodec.gd")
const Vascular = preload("res://alien_foundry/scripts/geometry/BlobBlueprintVascularNetwork.gd")
const Base = preload("res://alien_foundry/scripts/geometry/BlobVascularDirectAdapter.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const ID := "blob.vascular.surface.0"
const ADAPTER_ID := "blob.surface_vascular_blueprint"
const ADAPTER_VERSION := 1

static func plan(dna: Dictionary) -> Dictionary:
	var recipe: Dictionary = Vascular.plan(dna)
	if recipe.has("error"): return Carrier.fail("vascular_plan", str(recipe.error))
	var outcome := {"version": 1, "policy": "vascular_blueprint_v1", "seed": int(dna.seed),
		"status": str(recipe.planning_status), "target_feature_ids": [], "declared_branches": 0}
	if recipe.targets.is_empty(): return {"ok": true, "carrier": {}, "feature_declarations": [], "parent_child_updates": [], "planning_outcome": outcome}
	var seal: Dictionary = Codec.seal(recipe)
	if not seal.ok: return seal
	var blueprint: Dictionary = dna.biological_blueprint.duplicate(true)
	if not Blueprint.feature(blueprint, ID).is_empty(): return Carrier.fail("vascular_plan", "Vascular owner already exists.")
	var original_count: int = blueprint.features.size()
	var parts: Array = [{"part_id": "whole", "feature_id": ID, "parent_part_id": "", "aggregate": true}]
	Base._declare(blueprint, ID, str(recipe.core_feature_id), "whole", Vector3.UP, 0)
	var host_features: Array = [str(recipe.core_feature_id)]; var host_nodes: Array = [str(recipe.core_node_id)]
	for target: Dictionary in recipe.targets:
		host_features.append(str(target.feature_id)); host_nodes.append(str(target.node_id)); outcome.target_feature_ids.append(str(target.feature_id))
		var direction := Graph.vec(Blueprint.feature(blueprint, str(target.feature_id)).growth_direction)
		_declare(blueprint, parts, str(target.feeder_id), ID, "whole", direction, 0, target)
		for child: Dictionary in target.children:
			_declare(blueprint, parts, str(child.id), str(target.feeder_id), str(target.feeder_id), direction, 1, target)
			if child.twig: _declare(blueprint, parts, str(child.id) + ".branch.0", str(child.id), str(child.id), direction, 2, target)
	outcome.declared_branches = parts.size() - 1
	var carrier := {"schema_version": 1, "carrier_id": ID, "adapter_id": ADAPTER_ID, "adapter_version": ADAPTER_VERSION,
		"owner_feature_id": ID, "created_stage": 5, "host_feature_ids": host_features, "host_node_ids": host_nodes,
		"parts": parts, "recipe": recipe, "numeric_recipe": seal.numeric_recipe,
		"binding": {"method": "final_retained_host_triangle_weights", "coverage": "all_vertices", "create_bones": false}, "limits": {"vertices": 6000, "triangles": 10000}}
	return {"ok": true, "carrier": carrier, "feature_declarations": blueprint.features.slice(original_count),
		"parent_child_updates": [{"parent_id": str(recipe.core_feature_id), "child_id": ID}], "planning_outcome": outcome}

static func _declare(blueprint: Dictionary, parts: Array, id: String, parent: String, parent_part: String, direction: Vector3, level: int, target: Dictionary) -> void:
	Base._declare(blueprint, id, parent, id, direction, level)
	var feature := Blueprint.feature(blueprint, id)
	feature.geometry_recipe["target_feature_id"] = str(target.feature_id)
	feature.geometry_recipe["target_node_id"] = str(target.node_id)
	parts.append({"part_id": id, "feature_id": id, "parent_part_id": parent_part, "aggregate": false})

static func consumed_anatomy(dna: Dictionary, host: Dictionary) -> Dictionary:
	var projection := Base.consumed_anatomy(dna, host)
	projection["blueprint_policy_version"] = 1
	var selected: Array = []
	for node: Dictionary in dna.nodes:
		if str(node.kind) == "mass": selected.append({"id": str(node.id), "role": str(node.get("role", "")), "rotation": Graph.arr(Graph.vec(node.rotation))})
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	projection["mass_selection_and_orientation"] = selected
	return projection

static func _skip_reasons(carrier: Dictionary, report: Dictionary, present: Dictionary) -> Dictionary:
	var failed := {}
	for rejected: Dictionary in report.get("rejected_paths", []):
		if rejected.has("id"): failed[str(rejected.id)] = str(rejected.get("reason", "unsupported_route"))
	var reasons := {}
	for part: Dictionary in carrier.parts:
		var pid := str(part.part_id)
		if present.has(pid) or bool(part.aggregate) and not present.is_empty(): continue
		if bool(part.aggregate): reasons[pid] = "skipped_no_safe_routes"; continue
		var ancestor := pid
		while not ancestor.is_empty() and not failed.has(ancestor): ancestor = Carrier._parent(carrier, ancestor)
		reasons[pid] = ("ancestor_route_rejected:" + ancestor + ":" + str(failed[ancestor])) if not ancestor.is_empty() else "not_realized_by_declared_bounded_routes"
	return reasons

static func build(dna: Dictionary, host: Dictionary, carrier: Dictionary, stage: int, controls: RefCounted = null) -> Dictionary:
	var valid: Dictionary = Carrier.validate_plan(dna, stage)
	if not valid.ok: return valid
	if carrier.get("adapter_id") != ADAPTER_ID or carrier.get("adapter_version") != ADAPTER_VERSION: return Carrier.fail("vascular_adapter", "Wrong blueprint vascular adapter/version.")
	var decoded: Dictionary = Codec.decode(carrier.get("recipe"), carrier.get("numeric_recipe"))
	if not decoded.ok: return decoded
	var anatomy := consumed_anatomy(dna, host)
	var signature := Carrier.host_signature(host, anatomy)
	if not signature.ok: return signature
	signature["surface_key"] = Carrier.surface_key(carrier, signature)
	var built: Dictionary = Vascular.build(dna, host, decoded.recipe, controls)
	if built.has("error") or built.get("cancelled", false): return built
	var report: Dictionary = built.get("report", {})
	if built.get("skipped", false):
		var skipped := Carrier.normalize_skipped(dna, carrier, host, anatomy, stage, _skip_reasons(carrier, report, {}), signature)
		if skipped.ok: skipped["adapter_report"] = report
		return skipped
	if not built.get("mesh") is Dictionary: return Carrier.fail("vascular_build", "Missing checked vascular realization or explicit skip.")
	var mesh: Dictionary = built.mesh; var ids := PackedStringArray(); var present := {}
	for vi in range(mesh.vertices.size()):
		var id: String = mesh.feature_ids[mesh.feature_indices[vi * 4]]
		ids.append(id); present[id] = true
	var normalized := Carrier.normalize_result(dna, carrier, host, anatomy, mesh, ids, stage, _skip_reasons(carrier, report, present), signature)
	if normalized.ok:
		normalized["adapter_report"] = report; normalized["adapter_descriptor"] = built.descriptor
	return normalized
