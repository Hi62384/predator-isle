extends RefCounted
## Adapter only: original183b sweep/routes remain untouched. This file adds
## persistent declarations, exact recipe transport, direct ownership metadata,
## current host signatures and checked result normalization. No new geometry math.
const Carrier = preload("res://alien_foundry/scripts/geometry/DirectSurfaceFeatureCarrier.gd")
const Codec = preload("res://alien_foundry/scripts/persistence/DirectSurfaceRecipeCodec.gd")
const Vascular = preload("res://alien_foundry/scripts/geometry/BlobSurfaceVascularNetwork.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const ID := "blob.vascular.surface.0"
const ADAPTER_ID := "blob.surface_vascular"
const ADAPTER_VERSION := 2

static func plan(dna: Dictionary) -> Dictionary:
	var recipe: Dictionary = Vascular.plan(dna)
	if recipe.has("error"): return Carrier.fail("vascular_plan", str(recipe.error))
	var seal: Dictionary = Codec.seal(recipe)
	if not seal.ok: return seal
	var blueprint: Dictionary = dna.biological_blueprint.duplicate(true)
	if not Blueprint.feature(blueprint, ID).is_empty(): return Carrier.fail("vascular_plan", "Vascular owner is already declared; use its saved plan rather than duplicating it.")
	var original_count: int = blueprint.features.size()
	var parts: Array = [{"part_id": "whole", "feature_id": ID, "parent_part_id": "", "aggregate": true}]
	_declare(blueprint, ID, str(recipe.core_feature_id), "whole", Vector3.UP, 0)
	var host_features: Array = [str(recipe.core_feature_id)]; var host_nodes: Array = [str(recipe.core_node_id)]
	for target_index in range(recipe.targets.size()):
		var target: Dictionary = recipe.targets[target_index]
		host_features.append(str(target.feature_id)); host_nodes.append(str(target.node_id))
		var direction: Array = Blueprint.feature(blueprint, str(target.feature_id)).growth_direction
		var vector := Vector3(float(direction[0]), float(direction[1]), float(direction[2]))
		var feeder := ID + ".feeder.%s" % target_index
		_declare(blueprint, feeder, ID, feeder, vector, 0)
		parts.append({"part_id": feeder, "feature_id": feeder, "parent_part_id": "whole", "aggregate": false})
		for child_index in range(2):
			var branch := feeder + ".branch.%s" % child_index; var twig := branch + ".branch.0"
			_declare(blueprint, branch, feeder, branch, vector, 1)
			_declare(blueprint, twig, branch, twig, vector, 2)
			parts.append({"part_id": branch, "feature_id": branch, "parent_part_id": feeder, "aggregate": false})
			parts.append({"part_id": twig, "feature_id": twig, "parent_part_id": branch, "aggregate": false})
	var carrier := {"schema_version": 1, "carrier_id": ID, "adapter_id": ADAPTER_ID, "adapter_version": ADAPTER_VERSION,
		"owner_feature_id": ID, "created_stage": 5, "host_feature_ids": host_features, "host_node_ids": host_nodes,
		"parts": parts, "recipe": recipe, "numeric_recipe": seal.numeric_recipe,
		"binding": {"method": "final_retained_host_triangle_weights", "coverage": "all_vertices", "create_bones": false}, "limits": {"vertices": 6000, "triangles": 10000}}
	return {"ok": true, "carrier": carrier, "feature_declarations": blueprint.features.slice(original_count), "parent_child_updates": [{"parent_id": str(recipe.core_feature_id), "child_id": ID}]}

static func _declare(blueprint: Dictionary, feature_id: String, parent: String, part_id: String, direction: Vector3, level: int) -> void:
	var record: Dictionary = Blueprint.declare(blueprint, feature_id, "tendril", parent, 5, direction, {"role": "surface_vascular_fiber", "carrier_id": ID, "part_id": part_id, "branch_level": level})
	record.geometry_refs["direct_surface_parts"] = [{"carrier_id": ID, "part_id": part_id}]
	record.tissue = "vascular_fibrous"; record.material_rules.tissue = "vascular_fibrous"
	record.animation_rules = {"version": 1, "carrier_feature_id": "blob.body.core", "create_bone": false, "motion": "inherited_host", "binding": "retained_triangle_barycentric"}

static func consumed_anatomy(dna: Dictionary, host: Dictionary) -> Dictionary:
	# Every anatomy leaf read by the original recipe/build/routes, excluding
	# appearance-only rules, new owner records, and unrelated rig placement.
	var features: Array = []; var selection: Array = []; var nodes: Array = []; var shape_nodes := {}
	for feature: Dictionary in dna.biological_blueprint.features:
		if str(feature.id) == "blob.body.core" or str(feature.type) == "sac":
			selection.append({"id": str(feature.id), "type": str(feature.type), "parent_id": str(feature.parent_id), "node_ids": feature.geometry_refs.node_ids})
			for node_id: String in feature.geometry_refs.node_ids: shape_nodes[node_id] = true
		if str(feature.id) not in host.get("feature_ids", []): continue
		features.append({"id": str(feature.id), "type": str(feature.type), "parent_id": str(feature.parent_id),
			"growth_direction": _consumed_vector(feature.growth_direction), "node_ids": feature.geometry_refs.node_ids})
	for node: Dictionary in dna.nodes:
		var data := {"id": str(node.id), "kind": str(node.kind), "feature_id": str(node.get("feature_id", ""))}
		if str(node.kind) == "cavity" or shape_nodes.has(str(node.id)):
			data["position"] = _consumed_vector(node.position); data["size"] = _consumed_vector(node.size)
		if str(node.kind) == "cavity":
			data["rotation"] = _consumed_vector(node.rotation); data["blend"] = node.get("blend", 0.0); data["warp"] = node.get("deformation", {}).get("warp", 0.0)
		nodes.append(data)
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	selection.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return {"projection_version": 1, "type": dna.get("type"), "seed": dna.get("seed"), "recipe_selection": selection, "features": features, "nodes": nodes}

static func build(dna: Dictionary, host: Dictionary, carrier: Dictionary, stage: int, controls: RefCounted = null) -> Dictionary:
	var valid: Dictionary = Carrier.validate_plan(dna, stage)
	if not valid.ok: return valid
	if str(carrier.get("adapter_id", "")) != ADAPTER_ID or carrier.get("adapter_version") != ADAPTER_VERSION: return Carrier.fail("vascular_adapter", "Wrong vascular adapter/version.")
	var decoded: Dictionary = Codec.decode(carrier.get("recipe"), carrier.get("numeric_recipe"))
	if not decoded.ok: return decoded
	var anatomy := consumed_anatomy(dna, host)
	var generated_signature := Carrier.host_signature(host, anatomy)
	if not generated_signature.ok: return generated_signature
	generated_signature["surface_key"] = Carrier.surface_key(carrier, generated_signature)
	var built: Dictionary = Vascular.build(dna, host, decoded.recipe, controls)
	if built.has("cancelled"): return built
	if built.has("error") or not built.has("mesh"): return Carrier.fail("vascular_build", str(built.get("error", "No supported vascular surface; see source report: " + str(built.get("report", {})))))
	var wrapped: Dictionary = _normalize_build(dna, host, carrier, built.mesh, stage, generated_signature, built.report)
	if wrapped.ok:
		wrapped["adapter_descriptor"] = built.descriptor; wrapped["adapter_report"] = built.report
	return wrapped

static func _normalize_build(dna: Dictionary, host: Dictionary, carrier: Dictionary, mesh: Dictionary, stage: int, generated_signature: Dictionary, report: Dictionary = {}) -> Dictionary:
	# Only used immediately after generation with the input signature captured
	# BEFORE the build. Raw legacy cached meshes cannot acquire fresh provenance.
	var part_ids := PackedStringArray(); var present := {}; var skipped := {}
	for vi in range(mesh.get("vertices", []).size()):
		if mesh.get("feature_indices", []).size() != mesh.vertices.size() * 4: return Carrier.fail("vascular_owner", "Missing existing183b branch ownership.")
		var index: int = mesh.feature_indices[vi * 4]
		if index < 0 or index >= mesh.get("feature_ids", []).size(): return Carrier.fail("vascular_owner", "Invalid existing branch owner.")
		var id: String = mesh.feature_ids[index]; part_ids.append(id); present[id] = true
	for part: Dictionary in carrier.parts:
		if not bool(part.aggregate) and not present.has(str(part.part_id)):
			skipped[str(part.part_id)] = "not_realized_by_bounded183b_routes; source_report=" + JSON.stringify(report.get("rejected_paths", []), "", true, true)
	return Carrier.normalize_result(dna, carrier, host, consumed_anatomy(dna, host), mesh, part_ids, stage, skipped, generated_signature)

static func _consumed_vector(value: Array) -> Array:
	# Match Graph.vec/engine float32 consumption, not incidental JSON f64 shadows.
	var v := Vector3(float(value[0]), float(value[1]), float(value[2]))
	return [v.x, v.y, v.z]
