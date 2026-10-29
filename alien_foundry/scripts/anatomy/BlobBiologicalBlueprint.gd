extends RefCounted
## Biological identity is authored before SDF-node realization. Packed influence
## maps are disposable, overlapping heuristic views of this persistent graph.
const VERSION := 1
const MODE := "iterative_v2"
const TYPES := ["body", "sac", "tendril", "membrane", "porous", "cavity", "face", "growth", "limb"]
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const DirectCarrier = preload("res://alien_foundry/scripts/geometry/DirectSurfaceFeatureCarrier.gd")
const DIRECT_METHOD := "authoritative_direct_surface_parts_v1"

static func create(seed_value: int) -> Dictionary:
	return {"schema": "blob-biological-blueprint", "version": VERSION, "mode": MODE,
		"organism_id": "blob:%s:%s" % [MODE, seed_value], "seed": seed_value,
		"seed_scheme": "SHA256 first52bits: blob_iterative_v2|seed|logical_feature|operation", "features": []}

static func stream_seed(seed_value: int, feature_id: String, operation: String) -> int:
	# 52 bits survive JSON number storage exactly.
	return ("0x" + ("blob_iterative_v2|%s|%s|%s" % [seed_value, feature_id, operation]).sha256_text().substr(0, 13)).hex_to_int()

static func feature(blueprint: Dictionary, id: String) -> Dictionary:
	for value: Dictionary in blueprint.get("features", []):
		if str(value.get("id", "")) == id: return value
	return {}

static func declare(blueprint: Dictionary, id: String, type: String, parent_id: String, stage: int, direction: Vector3, recipe: Dictionary = {}) -> Dictionary:
	assert(type in TYPES and feature(blueprint, id).is_empty())
	var material: String = "muscle" if type in ["tendril", "cavity"] else ("membrane" if type == "membrane" else "flesh")
	var tissue: String = "cartilage" if type == "porous" else ("sac_skin" if type == "sac" else material)
	var detail_rules := {"version": 1, "enabled": type == "sac", "operation": "longitudinal_folds" if type == "sac" else "none", "density": 3, "amplitude": 0.035}
	var value := {"id": id, "type": type, "subtype": str(recipe.get("role", type)), "parent_id": parent_id, "children": [],
		"created_stage": stage, "planning_status": "declared", "geometry_refs": {"node_ids": [], "module_ids": []},
		"growth_direction": Graph.arr(direction.normalized() if direction.length_squared() > 0.000001 else Vector3.UP),
		"tissue": tissue, "detail_rules": detail_rules,
		"material_rules": {"version": 1, "material": material, "tissue": tissue},
		"animation_rules": {"version": 1, "carrier_feature_id": id if type in ["body", "limb", "sac", "tendril"] else parent_id,
			"create_bone": type in ["body", "limb", "sac", "tendril"], "motion": "breathe" if type in ["body", "sac"] else "sway"},
		"stream_id": "feature." + id, "geometry_recipe": recipe.duplicate(true)}
	blueprint.features.append(value)
	if not parent_id.is_empty():
		var parent: Dictionary = feature(blueprint, parent_id)
		assert(not parent.is_empty())
		parent.children.append(id)
	return value

static func bind_node(blueprint: Dictionary, feature_id: String, node: Dictionary, stage: int) -> void:
	var owner: Dictionary = feature(blueprint, feature_id)
	assert(not owner.is_empty())
	node["feature_id"] = feature_id
	node["feature_organism_id"] = blueprint.organism_id
	node["iteration_stage"] = stage
	# The legacy stage tag is not reinterpreted as an eight-stage index.
	node["pipeline_stage"] = 1
	if str(node.id) not in owner.geometry_refs.node_ids: owner.geometry_refs.node_ids.append(str(node.id))
	owner["planning_status"] = "geometry_planned"

static func annotate_snapshot(dna: Dictionary, blueprint: Dictionary, stage: int) -> void:
	dna["biological_blueprint"] = blueprint.duplicate(true)
	var active: Array = []
	var realization := {}
	for item: Dictionary in blueprint.features:
		realization[str(item.id)] = {"status": "planned" if int(item.created_stage) > stage else "skipped", "node_ids": [], "module_ids": []}
	for node: Dictionary in dna.nodes:
		var id := str(node.get("feature_id", ""))
		if id.is_empty() or not realization.has(id): continue
		if id not in active: active.append(id)
		realization[id].status = "realized_geometry"
		realization[id].node_ids.append(str(node.id))
	# A saved plan is not a built surface artifact. Node history remains intact,
	# including an earlier porous pad, but direct parts remain independently pending.
	var direct_states: Dictionary = _planned_direct_states(dna, blueprint, stage)
	for id: String in direct_states:
		realization[id]["direct_surface_parts"] = direct_states[id]
		if realization[id].status != "realized_geometry" and _has_pending_surface(direct_states[id]): realization[id].status = "pending_surface"
	dna["active_feature_ids"] = active
	dna["feature_realization"] = realization
	dna.metadata["iteration_index"] = stage

static func validate(dna: Dictionary) -> Dictionary:
	if not dna.get("modules") is Array or not dna.modules.is_empty():
		return {"ok": false, "error": "Iterative Blob modules are not implemented; no unmapped module geometry is accepted."}
	var b: Variant = dna.get("biological_blueprint")
	if not b is Dictionary or b.get("schema") != "blob-biological-blueprint" or b.get("version") != VERSION or b.get("mode") != MODE:
		return {"ok": false, "error": "Missing or unsupported Blob biological blueprint."}
	if str(dna.get("type", "")) != "Blob" or b.get("seed") != dna.get("seed") or b.get("organism_id") != "blob:%s:%s" % [MODE, int(dna.get("seed", 0))]:
		return {"ok": false, "error": "Biological blueprint belongs to another organism."}
	if not b.get("features") is Array or b.features.is_empty() or b.features.size() > 512:
		return {"ok": false, "error": "Invalid biological feature registry."}
	var ids := {}
	var geometry_owners := {}
	for item in b.features:
		if not item is Dictionary: return {"ok": false, "error": "Invalid biological feature record."}
		var id := str(item.get("id", ""))
		if not id.begins_with("blob.") or ids.has(id) or str(item.get("type", "")) not in TYPES:
			return {"ok": false, "error": "Invalid or duplicated biological feature identity."}
		for field: String in ["geometry_refs", "detail_rules", "material_rules", "animation_rules", "geometry_recipe"]:
			if not item.get(field) is Dictionary: return {"ok": false, "error": "Missing feature contract: " + field}
		if not item.get("children") is Array or not item.get("growth_direction") is Array or item.growth_direction.size() != 3:
			return {"ok": false, "error": "Invalid feature hierarchy or growth direction."}
		var created: Variant = item.get("created_stage", 0)
		if not (created is int or created is float) or float(created) != float(int(created)) or int(created) < 1 or int(created) > 6:
			return {"ok": false, "error": "Invalid biological feature creation stage."}
		if not item.geometry_refs.get("node_ids") is Array or not item.geometry_refs.get("module_ids") is Array:
			return {"ok": false, "error": "Invalid feature geometry references."}
		if not item.geometry_refs.module_ids.is_empty():
			return {"ok": false, "error": "Iterative Blob module ownership is not implemented."}
		for node_id in item.geometry_refs.node_ids:
			if not node_id is String or node_id.is_empty() or geometry_owners.has(node_id):
				return {"ok": false, "error": "Geometry carrier is missing or claimed by multiple biological features."}
			geometry_owners[node_id] = id
		for direction_value in item.growth_direction:
			if not (direction_value is int or direction_value is float) or not is_finite(float(direction_value)):
				return {"ok": false, "error": "Invalid biological growth direction."}
		if Graph.vec(item.growth_direction).length_squared() < 0.000001:
			return {"ok": false, "error": "Biological growth direction cannot be zero."}
		if str(item.material_rules.get("material", "")) not in ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]:
			return {"ok": false, "error": "Unsupported biological appearance category."}
		ids[id] = item
	for id: String in ids:
		var item: Dictionary = ids[id]
		var parent := str(item.get("parent_id", ""))
		if not parent.is_empty() and (not ids.has(parent) or id not in ids[parent].children):
			return {"ok": false, "error": "Broken biological parent link."}
		var seen := {id: true}
		while not parent.is_empty():
			if seen.has(parent) or not ids.has(parent): return {"ok": false, "error": "Cyclic biological feature hierarchy."}
			seen[parent] = true
			parent = str(ids[parent].get("parent_id", ""))
		for child in item.children:
			if not ids.has(str(child)) or str(ids[str(child)].parent_id) != id: return {"ok": false, "error": "Broken biological child link."}
	var direct_check: Dictionary = _validate_direct_refs(dna, ids)
	if not direct_check.get("ok", false): return direct_check
	var active := {}
	var owned_nodes := {}
	var stage := int(dna.get("metadata", {}).get("iteration_index", 0))
	var direct_states: Dictionary = _planned_direct_states(dna, b, stage)
	for node: Dictionary in dna.get("nodes", []):
		var owner := str(node.get("feature_id", ""))
		if not ids.has(owner) or str(node.get("feature_organism_id", "")) != str(b.organism_id) or str(node.id) not in ids[owner].geometry_refs.node_ids:
			return {"ok": false, "error": "An anatomical carrier has no authoritative biological owner: " + str(node.get("id", ""))}
		if int(node.get("iteration_stage", 0)) > int(dna.get("metadata", {}).get("iteration_index", 0)):
			return {"ok": false, "error": "A later biological feature leaked into an earlier iteration."}
		if int(ids[owner].created_stage) > stage:
			return {"ok": false, "error": "Planned biological feature has geometry before its creation stage."}
		active[owner] = true
		if not owned_nodes.has(owner): owned_nodes[owner] = []
		owned_nodes[owner].append(str(node.id))
	if not dna.get("active_feature_ids") is Array or dna.active_feature_ids.size() != active.size():
		return {"ok": false, "error": "Active biological feature list is incomplete or duplicated."}
	var seen_active := {}
	for id in dna.get("active_feature_ids", []):
		if seen_active.has(str(id)): return {"ok": false, "error": "Duplicate active biological feature."}
		seen_active[str(id)] = true
		if not active.has(str(id)): return {"ok": false, "error": "A planned feature is incorrectly marked realized."}
	if not dna.get("feature_realization") is Dictionary or dna.feature_realization.size() != ids.size():
		return {"ok": false, "error": "Missing biological realization states."}
	for id: String in ids:
		var state: Variant = dna.feature_realization.get(id)
		if not state is Dictionary or not state.get("node_ids") is Array or not state.get("module_ids") is Array:
			return {"ok": false, "error": "Invalid biological realization state."}
		if not state.module_ids.is_empty():
			return {"ok": false, "error": "Iterative Blob module realization is not implemented."}
		var actual: Array = owned_nodes.get(id, [])
		var declared: Array = state.node_ids.duplicate()
		actual.sort(); declared.sort()
		if actual != declared:
			return {"ok": false, "error": "Biological realization state does not match its actual geometry carriers."}
		var expected := "realized_geometry" if active.has(id) else ("planned" if int(ids[id].created_stage) > stage else "skipped")
		if direct_states.has(id):
			if not _same_direct_states(state.get("direct_surface_parts"), direct_states[id]): return {"ok": false, "error": "Direct-surface realization must remain planned or pending until a current runtime artifact is validated."}
			if not active.has(id) and _has_pending_surface(direct_states[id]): expected = "pending_surface"
		elif state.has("direct_surface_parts") and (not state.direct_surface_parts is Array or not state.direct_surface_parts.is_empty()):
			return {"ok": false, "error": "Biological realization references an undeclared direct-surface part."}
		if str(state.get("status", "")) != expected:
			return {"ok": false, "error": "Biological feature realization status is not truthful."}
	return {"ok": true}

static func attach_influences(dna: Dictionary, mesh: Dictionary, controls: RefCounted = null) -> Dictionary:
	var b: Dictionary = dna.biological_blueprint
	var ids := PackedStringArray()
	var lookup := {}
	for item: Dictionary in b.features:
		lookup[str(item.id)] = ids.size()
		ids.append(str(item.id))
	var node_lookup := {}
	var cavities: Array = []
	for node: Dictionary in dna.nodes:
		node_lookup[str(node.id)] = int(lookup.get(str(node.get("feature_id", "")), -1))
		if str(node.get("kind", "")) == "cavity": cavities.append(node)
	var output: Dictionary = _map_mesh(mesh, ids, node_lookup, cavities, controls)
	if output.has("error") or output.has("cancelled"): return output
	for detail: Dictionary in mesh.get("detail_meshes", []):
		# Explicit direct ownership wins over host/component membership. Never
		# relabel a branch as the body or sac to which it is attached.
		if detail.has("direct_surface_carrier") or str(detail.get("feature_influence_method", "")) == DIRECT_METHOD:
			output = _validate_direct_map(dna, detail, mesh, controls)
		else:
			output = _map_mesh(detail, ids, node_lookup, cavities, controls)
		if output.has("error") or output.has("cancelled"): return output
	return {"ok": true}

static func _validate_direct_refs(dna: Dictionary, features: Dictionary) -> Dictionary:
	var refs := {}
	for id: String in features:
		var authored: Variant = features[id].geometry_refs.get("direct_surface_parts", [])
		if not authored is Array: return {"ok": false, "error": "Invalid direct-surface biological references."}
		for ref in authored:
			if not ref is Dictionary or ref.size() != 2 or not ref.get("carrier_id") is String or not ref.get("part_id") is String or ref.carrier_id.is_empty() or ref.part_id.is_empty(): return {"ok": false, "error": "Malformed direct-surface biological reference."}
			var key: String = JSON.stringify([ref.carrier_id, ref.part_id])
			if refs.has(key): return {"ok": false, "error": "Direct-surface part has duplicate biological ownership."}
			refs[key] = id
	var checked: Dictionary = DirectCarrier.validate_plan(dna, int(dna.get("metadata", {}).get("iteration_index", 0)))
	if not checked.get("ok", false): return checked
	var declared := {}
	for carrier: Dictionary in dna.get("direct_surface_carriers", []):
		for part: Dictionary in carrier.parts:
			var key: String = JSON.stringify([str(carrier.carrier_id), str(part.part_id)])
			if declared.has(key) or not refs.has(key) or refs[key] != str(part.feature_id): return {"ok": false, "error": "Direct-surface part lacks its unique authoritative blueprint reference."}
			declared[key] = true
	if refs.size() != declared.size(): return {"ok": false, "error": "Biological blueprint references an undeclared direct-surface part."}
	return {"ok": true}

static func _planned_direct_states(dna: Dictionary, blueprint: Dictionary, stage: int) -> Dictionary:
	var carriers := {}
	for carrier in dna.get("direct_surface_carriers", []):
		if carrier is Dictionary: carriers[str(carrier.get("carrier_id", ""))] = carrier
	var states := {}
	for item: Dictionary in blueprint.get("features", []):
		var refs: Variant = item.get("geometry_refs", {}).get("direct_surface_parts", [])
		if not refs is Array or refs.is_empty(): continue
		var records: Array = []
		for ref in refs:
			if not ref is Dictionary: continue
			var carrier: Dictionary = carriers.get(str(ref.get("carrier_id", "")), {})
			records.append({"carrier_id": str(ref.get("carrier_id", "")), "part_id": str(ref.get("part_id", "")), "status": "planned" if int(carrier.get("created_stage", 7)) > stage else "pending_surface"})
		states[str(item.id)] = records
	return states

static func _has_pending_surface(states: Array) -> bool:
	for state: Dictionary in states:
		if state.status == "pending_surface": return true
	return false

static func _same_direct_states(authored: Variant, expected: Array) -> bool:
	if not authored is Array or authored.size() != expected.size(): return false
	var expected_by_key := {}
	for state: Dictionary in expected: expected_by_key[JSON.stringify([state.carrier_id, state.part_id])] = state.status
	var seen := {}
	for state in authored:
		if not state is Dictionary or state.size() != 3 or not state.get("carrier_id") is String or not state.get("part_id") is String: return false
		var key: String = JSON.stringify([state.carrier_id, state.part_id])
		if seen.has(key) or not expected_by_key.has(key) or state.get("status") != expected_by_key[key]: return false
		seen[key] = true
	return true

static func _validate_direct_map(dna: Dictionary, mesh: Dictionary, host: Dictionary, controls: RefCounted) -> Dictionary:
	var checked: Dictionary = DirectCarrier.validate_plan(dna, int(dna.get("metadata", {}).get("iteration_index", 0)))
	if not checked.get("ok", false): return checked
	var record: Variant = mesh.get("direct_surface_carrier")
	if not record is Dictionary or record.get("schema_version") != 1 or record.get("organism_id") != dna.biological_blueprint.organism_id: return {"error": "Missing or foreign direct-surface mesh identity."}
	var carrier: Dictionary = {}
	for item: Dictionary in dna.get("direct_surface_carriers", []):
		if item.carrier_id == record.get("carrier_id"): carrier = item; break
	if carrier.is_empty() or record.get("owner_feature_id") != carrier.owner_feature_id or record.get("adapter_id") != carrier.adapter_id or record.get("adapter_version") != carrier.adapter_version: return {"error": "Direct-surface mesh does not match its declared carrier."}
	if not record.get("surface_key") is String or record.surface_key.is_empty() or not record.get("host_signature") is Dictionary or record.host_signature.is_empty() or record.get("stage") != dna.get("metadata", {}).get("iteration_index") or int(record.stage) < int(carrier.created_stage): return {"error": "Direct-surface mesh lacks a current surface/host identity."}
	# The adapter's full validation owns consumed-anatomy identity. This dispatch
	# independently rejects stale physical/provenance witnesses before bypassing
	# host remapping; dictionary insertion order is never a signature comparison.
	var current_host: Dictionary = DirectCarrier.host_signature(host, {})
	if not current_host.get("ok", false): return current_host
	for key: String in ["signature_version", "physical_sha256", "provenance_sha256"]:
		if record.host_signature.get(key) != current_host.get(key): return {"error": "Direct-surface attachment witnesses belong to a different retained host."}
	if record.surface_key != DirectCarrier.surface_key(carrier, record.host_signature): return {"error": "Direct-surface mesh belongs to a stale carrier recipe."}
	var part_features := {}; var aggregates := {}
	for part: Dictionary in carrier.parts:
		part_features[str(part.part_id)] = str(part.feature_id)
		if bool(part.get("aggregate", false)): aggregates[str(part.part_id)] = true
	if not record.get("part_feature_ids") is Dictionary or record.part_feature_ids.size() != part_features.size(): return {"error": "Direct-surface mesh has an incomplete biological part map."}
	for part_id: String in part_features:
		if record.part_feature_ids.get(part_id) != part_features[part_id]: return {"error": "Direct-surface mesh changed a biological part owner."}
	if not mesh.get("vertices") is PackedVector3Array or not record.get("vertex_part_ids") is PackedStringArray or record.vertex_part_ids.size() != mesh.vertices.size(): return {"error": "Direct-surface vertex ownership is incomplete."}
	if not mesh.get("surface_root_samples") is Array or mesh.surface_root_samples.size() != mesh.vertices.size(): return {"error": "Direct-surface attachment coverage is incomplete."}
	var witnesses := {}
	for sample in mesh.surface_root_samples:
		if not sample is Dictionary or not _direct_integer(sample.get("vertex_id"), mesh.vertices.size()) or not _direct_integer(sample.get("triangle"), int(host.indices.size() / 3)): return {"error": "Malformed direct-surface support witness."}
		if witnesses.has(int(sample.vertex_id)): return {"error": "Duplicate direct-surface support witness."}
		witnesses[int(sample.vertex_id)] = true
		var bary: Variant = sample.get("barycentric")
		var value := Vector3(INF, INF, INF)
		if bary is Vector3: value = bary
		elif bary is Array and bary.size() == 3:
			if not _direct_number(bary[0]) or not _direct_number(bary[1]) or not _direct_number(bary[2]): return {"error": "Malformed direct-surface barycentric witness."}
			value = Vector3(float(bary[0]), float(bary[1]), float(bary[2]))
		if not value.is_finite() or absf(value.x + value.y + value.z - 1.0) > 0.0001 or minf(value.x, minf(value.y, value.z)) < -0.0001: return {"error": "Invalid direct-surface barycentric witness."}
	if mesh.get("feature_influence_method") != DIRECT_METHOD or not mesh.get("feature_ids") is PackedStringArray or not mesh.get("feature_indices") is PackedInt32Array or not mesh.get("feature_weights") is PackedFloat32Array: return {"error": "Direct-surface mesh lacks typed authoritative biological influences."}
	if mesh.feature_indices.size() != mesh.vertices.size() * 4 or mesh.feature_weights.size() != mesh.vertices.size() * 4: return {"error": "Direct-surface biological influence buffer size mismatch."}
	var registry := {}; var declared_features := {}
	for item: Dictionary in dna.biological_blueprint.features: registry[str(item.id)] = true
	for id: String in mesh.feature_ids:
		if declared_features.has(id) or not registry.has(id): return {"error": "Direct-surface map has duplicate or foreign feature IDs."}
		declared_features[id] = true
	for vertex in range(mesh.vertices.size()):
		if vertex % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		var part_id: String = record.vertex_part_ids[vertex]
		if not part_features.has(part_id) or aggregates.has(part_id): return {"error": "Direct-surface vertex has no concrete biological owner."}
		var owner_slots := 0
		for slot in range(4):
			var index: int = mesh.feature_indices[vertex * 4 + slot]
			var weight: float = mesh.feature_weights[vertex * 4 + slot]
			if not is_finite(weight) or weight < 0.0: return {"error": "Invalid direct-surface biological influence weight."}
			if weight == 0.0:
				if index != -1: return {"error": "Unused direct-surface biological influence must be empty."}
				continue
			if weight != 1.0 or index < 0 or index >= mesh.feature_ids.size() or mesh.feature_ids[index] != part_features[part_id]: return {"error": "Direct-surface biological influence was replaced by host identity."}
			owner_slots += 1
		if owner_slots != 1: return {"error": "Direct-surface vertex must have one authoritative biological owner."}
	return {"ok": true}

static func _direct_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _direct_integer(value: Variant, count: int) -> bool:
	return _direct_number(value) and float(value) == floor(float(value)) and float(value) >= 0.0 and float(value) < float(count)

static func _map_mesh(mesh: Dictionary, ids: PackedStringArray, lookup: Dictionary, cavities: Array, controls: RefCounted) -> Dictionary:
	var vertices: PackedVector3Array = mesh.get("vertices", PackedVector3Array())
	var node_ids: PackedStringArray = mesh.get("node_ids", PackedStringArray())
	var components: PackedInt32Array = mesh.get("component_indices", PackedInt32Array())
	var weights: PackedFloat32Array = mesh.get("component_weights", PackedFloat32Array())
	var indices := PackedInt32Array()
	var mapped_weights := PackedFloat32Array()
	indices.resize(vertices.size() * 4); indices.fill(-1)
	mapped_weights.resize(vertices.size() * 4)
	var uncovered := 0
	var maximum := 0
	for i in range(vertices.size()):
		if i % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		var sums := {}
		for slot in range(4):
			var at := i * 4 + slot
			if at >= components.size() or at >= weights.size() or weights[at] <= 0.000001: continue
			var component := components[at]
			if component < 0 or component >= node_ids.size(): continue
			var feature_id := int(lookup.get(str(node_ids[component]), -1))
			if feature_id >= 0: sums[feature_id] = float(sums.get(feature_id, 0.0)) + weights[at]
		# A subtraction is not an independent positive skinning component. Its
		# authored analytic wall contributes semantic cavity ownership only.
		for cavity: Dictionary in cavities:
			var size: Vector3 = Graph.vec(cavity.size)
			var local: Vector3 = Graph.node_basis(cavity).inverse() * (vertices[i] - Graph.vec(cavity.position))
			var unit := Vector3(local.x / maxf(size.x, 0.001), local.y / maxf(size.y, 0.001), local.z / maxf(size.z, 0.001))
			var wall_distance := absf(unit.length() - 1.0) * minf(size.x, minf(size.y, size.z))
			var band := maxf(0.025, minf(size.x, minf(size.y, size.z)) * 0.30)
			if wall_distance >= band: continue
			var feature_id := int(lookup.get(str(cavity.id), -1))
			if feature_id >= 0: sums[feature_id] = maxf(float(sums.get(feature_id, 0.0)), 1.6 * (1.0 - wall_distance / band))
		if sums.is_empty():
			uncovered += 1
			continue
		var ranked: Array = sums.keys()
		ranked.sort_custom(func(a: int, b: int) -> bool: return float(sums[a]) > float(sums[b]) if float(sums[a]) != float(sums[b]) else a < b)
		var count := mini(4, ranked.size())
		maximum = maxi(maximum, count)
		var total := 0.0
		for slot in range(count): total += float(sums[ranked[slot]])
		for slot in range(count):
			indices[i * 4 + slot] = int(ranked[slot])
			mapped_weights[i * 4 + slot] = float(sums[ranked[slot]]) / total
	mesh["feature_ids"] = ids
	mesh["feature_indices"] = indices
	mesh["feature_weights"] = mapped_weights
	mesh["feature_influence_method"] = "anatomical_component_blend_and_authored_cavity_wall_heuristic_not_sdf_derivative"
	mesh["feature_influence_slots"] = 4
	mesh["feature_uncovered_vertices"] = uncovered
	mesh["feature_max_retained_influences"] = maximum
	mesh["feature_truncation_status"] = "upstream_top_four_component_provenance; total_overlap_unknown"
	if uncovered > 0: return {"error": "Biological map contains %d unowned vertices; no inferred IDs were assigned." % uncovered}
	return {"ok": true}
