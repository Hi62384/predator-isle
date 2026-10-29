extends RefCounted
## Pure direct-surface identity/attachment contract. Does not extract, generate,
## skin, remap, render, or mutate the supplied host. Biological ownership and
## support/binding provenance are intentionally independent.
const Codec = preload("res://alien_foundry/scripts/persistence/DirectSurfaceRecipeCodec.gd")
const VERSION := 1
const ADAPTERS := {"blob.surface_vascular": 2, "blob.porous_sheet": 1, "blob.surface_vascular_blueprint": 1}
const MAX_CARRIERS := 8
const MAX_PARTS := 64
const MAX_VERTICES := 20000
const MAX_TRIANGLES := 20000

static func fail(code: String, message: String, path: String = "") -> Dictionary:
	return {"ok": false, "error_code": code, "error": message, "path": path}

static func validate_plan(dna: Dictionary, stage: int) -> Dictionary:
	var plans: Variant = dna.get("direct_surface_carriers", [])
	if not plans is Array or plans.size() > MAX_CARRIERS: return fail("carrier_plan", "Invalid direct carrier list.")
	if plans.is_empty(): return {"ok": true, "enabled": false}
	if stage < 1 or stage > 6: return fail("carrier_stage", "Direct carrier stage is out of range.")
	var registry := {}; var nodes := {}; var seen := {}; var part_owners := {}
	for feature: Dictionary in dna.get("biological_blueprint", {}).get("features", []): registry[str(feature.get("id", ""))] = feature
	for node: Dictionary in dna.get("nodes", []): nodes[str(node.get("id", ""))] = node
	for c: Variant in plans:
		if not c is Dictionary: return fail("carrier_plan", "A carrier must be an object.")
		if not _keys(c, ["schema_version", "carrier_id", "adapter_id", "adapter_version", "owner_feature_id", "created_stage", "host_feature_ids", "host_node_ids", "parts", "recipe", "numeric_recipe", "binding", "limits"], ["transition_from_node_id"]): return fail("carrier_plan", "Unsupported or missing carrier fields.")
		var id := str(c.get("carrier_id", "")); var owner := str(c.get("owner_feature_id", ""))
		if c.get("schema_version") != VERSION or not id.begins_with("blob.") or seen.has(id): return fail("carrier_identity", "Invalid or duplicate carrier identity.", id)
		seen[id] = true
		if not ADAPTERS.has(c.get("adapter_id")) or c.get("adapter_version") != ADAPTERS[c.adapter_id]: return fail("carrier_adapter", "Unsupported direct surface adapter/version.", id)
		if not registry.has(owner) or not _integer(c.get("created_stage"), 1, 6): return fail("carrier_owner", "Carrier requires an existing owner and creation stage.", id)
		if not c.get("parts") is Array or c.parts.is_empty() or c.parts.size() > MAX_PARTS: return fail("carrier_parts", "Invalid carrier parts.", id)
		if not c.get("host_feature_ids") is Array or not c.get("host_node_ids") is Array or c.host_feature_ids.is_empty() or c.host_node_ids.is_empty(): return fail("carrier_host", "Explicit host feature and node dependencies are required.", id)
		var dependency_ids := {}
		for host_id: Variant in c.host_feature_ids:
			if not host_id is String or not registry.has(host_id) or dependency_ids.has(host_id): return fail("carrier_host", "Missing or duplicate host feature.", id)
			dependency_ids[host_id] = true
		dependency_ids.clear()
		for host_id: Variant in c.host_node_ids:
			if not host_id is String or dependency_ids.has(host_id): return fail("carrier_host", "Invalid or duplicate host node.", id)
			dependency_ids[host_id] = true
			# A future-stage plan can name an already declared node not realized yet.
			if stage >= int(c.created_stage):
				if not nodes.has(host_id): return fail("carrier_host", "Required actual host node is missing.", id)
				var host_owner := str(nodes[host_id].get("feature_id", ""))
				if host_owner not in c.host_feature_ids or host_id not in registry[host_owner].get("geometry_refs", {}).get("node_ids", []): return fail("carrier_host", "Host node provenance disagrees with its biological owner.", id)
		if not c.get("binding") is Dictionary or not _keys(c.binding, ["method", "coverage", "create_bones"]) or c.binding.get("method") != "final_retained_host_triangle_weights" or c.binding.get("coverage") != "all_vertices" or c.binding.get("create_bones") != false: return fail("carrier_binding", "Only inherited retained-host binding without new bones is supported.", id)
		if not c.get("limits") is Dictionary or not _keys(c.limits, ["vertices", "triangles"]) or not _integer(c.limits.get("vertices"), 1, MAX_VERTICES) or not _integer(c.limits.get("triangles"), 1, MAX_TRIANGLES): return fail("carrier_limits", "Missing bounded direct geometry limits.", id)
		var decoded: Dictionary = Codec.decode(c.get("recipe"), c.get("numeric_recipe"))
		if not decoded.get("ok", false): return fail("carrier_recipe", str(decoded.get("error", "Invalid exact recipe.")), id)
		var parts := {}; var root_count := 0
		for p: Variant in c.parts:
			if not p is Dictionary or not _keys(p, ["part_id", "feature_id", "parent_part_id", "aggregate"]) or not p.get("part_id") is String or str(p.part_id).is_empty() or parts.has(p.part_id) or not p.get("aggregate") is bool: return fail("carrier_parts", "Invalid or duplicate part identity.", id)
			if not p.get("parent_part_id") is String or not registry.has(p.get("feature_id")): return fail("carrier_parts", "Part parent/feature is invalid.", id)
			var feature_id := str(p.feature_id); var feature: Dictionary = registry[feature_id]
			if part_owners.has(feature_id): return fail("carrier_parts", "A direct feature is claimed by multiple parts.", feature_id)
			part_owners[feature_id] = id
			var refs: Variant = feature.get("geometry_refs", {}).get("direct_surface_parts", [])
			if not refs is Array: return fail("carrier_parts", "Invalid direct Blueprint references.", feature_id)
			var matches := 0
			for ref: Variant in refs:
				if ref is Dictionary and ref.get("carrier_id") == id and ref.get("part_id") == p.part_id: matches += 1
			if matches != 1 or bool(feature.get("animation_rules", {}).get("create_bone", true)): return fail("carrier_parts", "Part must have one authoritative Blueprint reference and no new bone.", feature_id)
			if str(p.parent_part_id).is_empty():
				root_count += 1
				if feature_id != owner: return fail("carrier_owner", "Carrier root part must belong to its owner feature.", id)
				if feature.get("parent_id") not in c.host_feature_ids: return fail("carrier_owner", "Direct tissue origin must name a declared host feature.", id)
			if not _integer(feature.get("created_stage"), 1, int(c.created_stage)): return fail("carrier_parts", "Part feature is declared after its carrier.", feature_id)
			parts[p.part_id] = p
		if root_count != 1: return fail("carrier_parts", "Carrier requires exactly one rooted part hierarchy.", id)
		for pid: String in parts:
			var direct_parent := str(parts[pid].parent_part_id)
			if not direct_parent.is_empty() and (not parts.has(direct_parent) or registry[str(parts[pid].feature_id)].get("parent_id") != parts[direct_parent].feature_id): return fail("carrier_parts", "Part hierarchy disagrees with biological parent ownership.", pid)
			var visited := {}; var current := pid
			while not current.is_empty():
				if visited.has(current) or not parts.has(current): return fail("carrier_parts", "Part hierarchy contains a cycle or missing parent.", pid)
				visited[current] = true; current = str(parts[current].parent_part_id)
		var transition: String = str(c.get("transition_from_node_id", ""))
		if stage >= int(c.created_stage) and not transition.is_empty():
			if not nodes.has(transition) or str(nodes[transition].get("shape", {}).get("geometry", "")) != "detail": return fail("carrier_transition", "Mature direct carrier still has an extractable staged pad.", id)
	return {"ok": true, "enabled": true, "carriers": plans.size()}

static func host_signature(host: Dictionary, consumed_anatomy: Dictionary) -> Dictionary:
	if not host.get("vertices") is PackedVector3Array or not host.get("normals") is PackedVector3Array or not host.get("indices") is PackedInt32Array: return fail("carrier_host", "Host physical buffers are missing.")
	var vertices: PackedVector3Array = host.vertices; var indices: PackedInt32Array = host.indices
	if vertices.is_empty() or host.normals.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0: return fail("carrier_host", "Host physical buffer shape is invalid.")
	for point: Vector3 in vertices:
		if not point.is_finite(): return fail("carrier_host", "Host contains a non-finite point.")
	for normal: Vector3 in host.normals:
		if not normal.is_finite(): return fail("carrier_host", "Host contains a non-finite normal.")
	for index: int in indices:
		if index < 0 or index >= vertices.size(): return fail("carrier_host", "Host triangle index is invalid.")
	var sealed: Dictionary = Codec.seal(consumed_anatomy)
	if not sealed.get("ok", false): return sealed
	var physical := _digest([vertices, host.normals, indices])
	var provenance := _digest([host.get("node_ids", []), host.get("component_ids", PackedInt32Array()), host.get("component_indices", PackedInt32Array()), host.get("component_weights", PackedFloat32Array()), host.get("feature_ids", []), host.get("feature_indices", PackedInt32Array()), host.get("feature_weights", PackedFloat32Array())])
	return {"ok": true, "signature_version": VERSION, "physical_sha256": physical, "provenance_sha256": provenance,
		"anatomy_key": sealed.recipe_key, "digest": _digest([VERSION, physical, provenance, sealed.recipe_key]), "vertices": vertices.size(), "triangles": indices.size() / 3}

static func surface_key(carrier: Dictionary, signature: Dictionary) -> String:
	if not _integer(carrier.get("schema_version"), 1, 1) or not _integer(carrier.get("adapter_version"), 1, 16) or not _integer(carrier.get("created_stage"), 1, 6) or not carrier.get("limits") is Dictionary: return ""
	if not _integer(carrier.limits.get("vertices"), 1, MAX_VERTICES) or not _integer(carrier.limits.get("triangles"), 1, MAX_TRIANGLES): return ""
	var recipe_key: String = Codec.canonical_key(carrier.get("recipe"), carrier.get("numeric_recipe"))
	if recipe_key.is_empty() or not signature.get("ok", false): return ""
	var identity := carrier.duplicate(true); identity.erase("recipe"); identity.erase("numeric_recipe")
	# Normalize schema/count integers after public JSON transport. Recipe numeric
	# kinds are restored by its exact seal; identity integers are validated first.
	identity.schema_version = int(identity.schema_version); identity.adapter_version = int(identity.adapter_version); identity.created_stage = int(identity.created_stage)
	identity.limits.vertices = int(identity.limits.vertices); identity.limits.triangles = int(identity.limits.triangles)
	var sealed: Dictionary = Codec.seal(identity)
	if not sealed.get("ok", false): return ""
	return _digest(["direct-surface-v1", str(sealed.recipe_key), recipe_key, str(signature.get("digest", ""))])

static func compose_geometry_key(body_key: String, ordered_surface_keys: Array) -> String:
	# This never replaces the body extraction key or its six-stage dependency chain.
	if ordered_surface_keys.is_empty(): return body_key
	if body_key.is_empty() or ordered_surface_keys.size() > MAX_CARRIERS: return ""
	var seen := {}; var surfaces: Array = []
	for key: Variant in ordered_surface_keys:
		if not key is String or key.is_empty() or seen.has(key): return ""
		seen[key] = true; surfaces.append(key)
	return _digest(["direct-completed-geometry-v1", body_key, surfaces])

static func binding_key(host_rig_identity: String, composed_key: String = "", binding_abi: String = "explicit_surface_root_binding_v1") -> String:
	# Caller passes empty composed_key only on the no-direct path. A hash cannot
	# itself reveal whether it contains direct layers; never guess or rekey off.
	if composed_key.is_empty(): return host_rig_identity
	if host_rig_identity.is_empty() or binding_abi != "explicit_surface_root_binding_v1": return ""
	return _digest(["direct-final-binding-v1", host_rig_identity, composed_key, binding_abi])

static func surface_cache_slot(stage: int, carrier_id: String) -> String:
	if stage < 1 or stage > 6 or not carrier_id.begins_with("blob."): return ""
	return "direct_surface:%s:%s" % [stage, carrier_id]

static func normalize_result(dna: Dictionary, carrier: Dictionary, host: Dictionary, consumed_anatomy: Dictionary, mesh: Dictionary, vertex_part_ids: PackedStringArray, stage: int, skipped_parts: Dictionary = {}, generated_signature: Dictionary = {}) -> Dictionary:
	var plan_check := validate_plan(dna, stage)
	if not plan_check.ok: return plan_check
	if stage != int(dna.get("metadata", {}).get("iteration_index", -1)): return fail("carrier_stage", "Current runtime stage differs from the DNA snapshot.")
	if not _registered(dna, carrier): return fail("carrier_plan", "Result carrier is not the exact registered plan.")
	if stage < int(carrier.created_stage): return fail("carrier_stage", "Cannot realize a future direct carrier.")
	var signature := host_signature(host, consumed_anatomy)
	if not signature.ok: return signature
	if generated_signature.get("digest") != signature.digest or generated_signature.get("surface_key") != surface_key(carrier, signature): return fail("stale_surface", "Missing or changed generation-input host signature; raw caches cannot be recertified.")
	if mesh.has("direct_surface_carrier") and (mesh.direct_surface_carrier.get("host_signature", {}).get("digest") != signature.digest or mesh.direct_surface_carrier.get("surface_key") != surface_key(carrier, signature)): return fail("stale_surface", "Existing direct surface has stale host provenance.")
	var result_mesh := mesh.duplicate(true); var part_features := {}; var statuses := {}; var counts := {}
	for p: Dictionary in carrier.parts:
		part_features[str(p.part_id)] = str(p.feature_id); counts[str(p.part_id)] = 0
	for pid: String in vertex_part_ids:
		if not counts.has(pid): return fail("carrier_owner", "Vertex refers to an undeclared part.", pid)
		counts[pid] += 1
	for p: Dictionary in carrier.parts:
		var pid := str(p.part_id); var count: int = counts[pid]
		if bool(p.aggregate):
			for child: String in counts:
				var current := child
				while not current.is_empty() and current != pid: current = _parent(carrier, current)
				if current == pid: count += int(counts[child])
		if count == 0 and not skipped_parts.has(pid): return fail("carrier_realization", "Absent declared part needs an explicit skipped reason.", pid)
		statuses[pid] = {"feature_id": str(p.feature_id), "status": "realized_geometry" if count > 0 else "skipped", "vertices": count, "reason": str(skipped_parts.get(pid, ""))}
	result_mesh["feature_influence_method"] = "authoritative_direct_surface_parts_v1"
	result_mesh["direct_surface_carrier"] = {"schema_version": VERSION, "organism_id": str(dna.biological_blueprint.organism_id), "carrier_id": str(carrier.carrier_id), "adapter_id": str(carrier.adapter_id), "adapter_version": int(carrier.adapter_version), "owner_feature_id": str(carrier.owner_feature_id), "stage": stage, "surface_key": surface_key(carrier, signature), "host_signature": signature, "part_feature_ids": part_features, "vertex_part_ids": vertex_part_ids}
	var result := {"ok": true, "mesh": result_mesh, "part_statuses": statuses, "body_extractions": 0, "new_bones": 0}
	var checked := validate_result(dna, carrier, host, consumed_anatomy, result, stage)
	if not checked.ok: return checked
	return result

static func validate_result(dna: Dictionary, carrier: Dictionary, host: Dictionary, consumed_anatomy: Dictionary, result: Dictionary, stage: int) -> Dictionary:
	var plan_check := validate_plan(dna, stage)
	if not plan_check.ok: return plan_check
	if stage != int(dna.get("metadata", {}).get("iteration_index", -1)): return fail("carrier_stage", "Current runtime stage differs from the DNA snapshot.")
	if not _registered(dna, carrier): return fail("carrier_plan", "Result carrier is not the exact registered plan.")
	if not result.get("mesh") is Dictionary: return fail("carrier_result", "Missing direct surface mesh.")
	var mesh: Dictionary = result.mesh; var meta: Variant = mesh.get("direct_surface_carrier")
	if not meta is Dictionary or meta.get("schema_version") != VERSION or meta.get("organism_id") != dna.biological_blueprint.organism_id or meta.get("stage") != stage: return fail("carrier_result", "Mismatched direct carrier metadata.")
	for field: String in ["carrier_id", "adapter_id", "adapter_version", "owner_feature_id"]:
		if meta.get(field) != carrier.get(field): return fail("carrier_result", "Carrier identity mismatch: " + field)
	var signature := host_signature(host, consumed_anatomy)
	if not signature.ok: return signature
	if not _same_signature(meta.get("host_signature"), signature) or meta.get("surface_key") != surface_key(carrier, signature): return fail("stale_surface", "Recipe or actual host signature changed; rebuild direct surface.")
	if not mesh.get("vertices") is PackedVector3Array or not mesh.get("normals") is PackedVector3Array or not mesh.get("indices") is PackedInt32Array: return fail("carrier_mesh", "Missing direct geometry buffers.")
	var count: int = mesh.vertices.size()
	if count == 0 or count > int(carrier.limits.vertices) or mesh.normals.size() != count or mesh.indices.size() % 3 != 0 or mesh.indices.size() / 3 > int(carrier.limits.triangles): return fail("carrier_mesh", "Direct geometry exceeds finite buffer limits.")
	for point: Vector3 in mesh.vertices:
		if not point.is_finite(): return fail("carrier_mesh", "Non-finite direct vertex.")
	for normal: Vector3 in mesh.normals:
		if not normal.is_finite() or normal.length_squared() < 0.000001: return fail("carrier_mesh", "Invalid direct normal.")
	for index: int in mesh.indices:
		if index < 0 or index >= count: return fail("carrier_mesh", "Out-of-range direct triangle index.")
	if not meta.get("vertex_part_ids") is PackedStringArray or meta.vertex_part_ids.size() != count or not meta.get("part_feature_ids") is Dictionary: return fail("carrier_owner", "Missing per-vertex direct ownership.")
	var expected := {}; var aggregate := {}
	for p: Dictionary in carrier.parts: expected[str(p.part_id)] = str(p.feature_id); aggregate[str(p.part_id)] = bool(p.aggregate)
	if meta.part_feature_ids != expected: return fail("carrier_owner", "Part mapping differs from the authored plan.")
	if not mesh.get("feature_indices") is PackedInt32Array or not mesh.get("feature_weights") is PackedFloat32Array or not mesh.get("feature_ids") is PackedStringArray: return fail("carrier_owner", "Invalid typed ownership buffers.")
	if mesh.feature_indices.size() != count * 4 or mesh.feature_weights.size() != count * 4: return fail("carrier_owner", "Biological ownership needs one authoritative four-slot mirror per vertex.")
	for vi in range(count):
		var pid: String = meta.vertex_part_ids[vi]
		if not expected.has(pid) or bool(aggregate[pid]): return fail("carrier_owner", "Unknown/aggregate part owns a physical vertex.", pid)
		var owner_index: int = mesh.feature_indices[vi * 4]
		if owner_index < 0 or owner_index >= mesh.get("feature_ids", []).size() or mesh.feature_ids[owner_index] != expected[pid] or mesh.feature_weights[vi * 4] != 1.0: return fail("carrier_owner", "Primary feature ownership was overwritten by host influences.", pid)
		for slot in range(1, 4):
			if mesh.feature_indices[vi * 4 + slot] != -1 or mesh.feature_weights[vi * 4 + slot] != 0.0: return fail("carrier_owner", "Host overlaps must be separate from direct ownership.", pid)
	var witnesses: Variant = mesh.get("surface_root_samples")
	if not witnesses is Array or witnesses.size() != count: return fail("carrier_attachment", "Every direct vertex needs an actual host witness.")
	var witnessed := {}; var host_indices: PackedInt32Array = host.indices
	for sample: Variant in witnesses:
		if not sample is Dictionary or not _integer(sample.get("vertex_id"), 0, count - 1) or not _integer(sample.get("triangle"), 0, host_indices.size() / 3 - 1): return fail("carrier_attachment", "Invalid support vertex/triangle.")
		var vi := int(sample.vertex_id)
		if witnessed.has(vi): return fail("carrier_attachment", "Duplicate support witness.")
		witnessed[vi] = true
		var bary := _vec(sample.get("barycentric"))
		if not bary.is_finite() or absf(bary.x + bary.y + bary.z - 1.0) > 0.0001 or minf(bary.x, minf(bary.y, bary.z)) < -0.0001: return fail("carrier_attachment", "Invalid actual host barycentric witness.")
		if sample.has("point"):
			var support := Vector3.ZERO
			for corner in range(3): support += Vector3(host.vertices[host_indices[int(sample.triangle) * 3 + corner]]) * bary[corner]
			if not _vec(sample.point).is_finite() or support.distance_to(_vec(sample.point)) > 0.00001: return fail("carrier_attachment", "Support witness no longer reconstructs on the actual host.")
			if sample.has("normal") and sample.has("height"):
				if not (sample.height is int or sample.height is float) or not is_finite(float(sample.height)) or not _vec(sample.normal).is_finite(): return fail("carrier_attachment", "Invalid attachment offset.")
				if Vector3(mesh.vertices[vi]).distance_to(support + _vec(sample.normal) * float(sample.height)) > 0.00001: return fail("carrier_attachment", "Direct vertex differs from its actual support/offset witness.")
	return {"ok": true, "vertices": count, "triangles": mesh.indices.size() / 3, "surface_key": meta.surface_key}

static func append_result(dna: Dictionary, geometry: Dictionary, carrier: Dictionary, consumed_anatomy: Dictionary, result: Dictionary, stage: int) -> Dictionary:
	var checked := validate_result(dna, carrier, geometry, consumed_anatomy, result, stage)
	if not checked.ok: return checked
	if not result.get("part_statuses") is Dictionary or result.part_statuses.size() != carrier.parts.size(): return fail("carrier_realization", "Missing current checked part realization states.")
	for part: Dictionary in carrier.parts:
		var pid := str(part.part_id); var expected_count := 0
		for owned: String in result.mesh.direct_surface_carrier.vertex_part_ids:
			var current := owned
			if bool(part.aggregate):
				while not current.is_empty() and current != pid: current = _parent(carrier, current)
			if current == pid: expected_count += 1
		var state: Variant = result.part_statuses.get(pid)
		if not state is Dictionary or state.get("feature_id") != part.feature_id or state.get("vertices") != expected_count or state.get("status") != ("realized_geometry" if expected_count > 0 else "skipped"): return fail("carrier_realization", "Current part state disagrees with actual direct ownership.", pid)
		if expected_count == 0 and str(state.get("reason", "")).is_empty(): return fail("carrier_realization", "Skipped direct part lacks an explicit reason.", pid)
	var details: Array = geometry.get("detail_meshes", []).duplicate(true)
	for old: Dictionary in details:
		if str(old.get("direct_surface_carrier", {}).get("carrier_id", "")) == str(carrier.carrier_id):
			var replay_check := validate_result(dna, carrier, geometry, consumed_anatomy, {"mesh": old}, stage)
			if not replay_check.ok: return replay_check
			return {"ok": true, "already_realized": true, "geometry": geometry}
	# Copy only the dictionary. Physical packed arrays are neither edited nor
	# replaced. Existing detail layers remain intact; bounds include new detail.
	var composed := geometry.duplicate(false); details.append(result.mesh); composed["detail_meshes"] = details
	var realization: Dictionary = geometry.get("direct_surface_realization", {}).duplicate(true)
	realization[str(carrier.carrier_id)] = {"surface_key": checked.surface_key, "stage": stage, "parts": result.part_statuses.duplicate(true)}
	composed["direct_surface_realization"] = realization
	if composed.get("bounds") is AABB and result.mesh.get("bounds") is AABB: composed.bounds = composed.bounds.merge(result.mesh.bounds)
	return {"ok": true, "geometry": composed, "already_realized": false}

static func validate_binding(mesh: Dictionary, skin: Dictionary, host: Dictionary, host_skin: Dictionary, bone_count: int) -> Dictionary:
	# Called only after final generic skinning + ExplicitSurfaceRootBinding.bind.
	var count: int = mesh.get("vertices", []).size()
	if skin.get("bones", []).size() != count * 4 or skin.get("weights", []).size() != count * 4: return fail("carrier_binding", "Incomplete final direct skin.")
	if host_skin.get("bones", []).size() != host.vertices.size() * 4 or host_skin.get("weights", []).size() != host.vertices.size() * 4: return fail("carrier_binding", "Missing final host skin.")
	if not mesh.get("surface_root_samples") is Array or mesh.surface_root_samples.size() != count: return fail("carrier_binding", "Incomplete final attachment coverage.")
	var maximum_error := 0.0
	for sample: Dictionary in mesh.get("surface_root_samples", []):
		var total := {}; var bary := _vec(sample.barycentric); var offset := int(sample.triangle) * 3
		for corner in range(3):
			var hvi: int = host.indices[offset + corner]
			for slot in range(4):
				var bone: int = host_skin.bones[hvi * 4 + slot]; var weight: float = host_skin.weights[hvi * 4 + slot] * bary[corner]
				if weight > 0.000001: total[bone] = float(total.get(bone, 0.0)) + weight
		var pairs: Array = []
		for bone: int in total: pairs.append([bone, float(total[bone])])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] if a[1] != b[1] else a[0] < b[0])
		var sum := 0.0
		for pair: Array in pairs.slice(0, 4): sum += float(pair[1])
		if sum <= 0.0: return fail("carrier_binding", "Unbound host triangle.")
		var expected := {}
		for pair: Array in pairs.slice(0, 4): expected[int(pair[0])] = float(pair[1]) / sum
		var actual := {}; var vi := int(sample.vertex_id); var actual_sum := 0.0
		for slot in range(4):
			var bone: int = skin.bones[vi * 4 + slot]; var weight: float = skin.weights[vi * 4 + slot]
			if bone < 0 or bone >= bone_count or not is_finite(weight) or weight < 0.0: return fail("carrier_binding", "Invalid inherited bone/weight.")
			actual_sum += weight
			if weight > 0.0: actual[bone] = float(actual.get(bone, 0.0)) + weight
		if absf(actual_sum - 1.0) > 0.00001 or actual.size() != expected.size(): return fail("carrier_binding", "Inherited weights differ from actual host support.")
		for bone: int in expected:
			maximum_error = maxf(maximum_error, absf(float(actual.get(bone, 0.0)) - float(expected[bone])))
	if maximum_error > 0.00001: return fail("carrier_binding", "Final inherited host weight tolerance exceeded.")
	return {"ok": true, "maximum_weight_error": maximum_error, "vertices": count}

static func _same_signature(candidate: Variant, expected: Dictionary) -> bool:
	if not candidate is Dictionary: return false
	for key: String in ["ok", "signature_version", "physical_sha256", "provenance_sha256", "anatomy_key", "digest", "vertices", "triangles"]:
		if candidate.get(key) != expected.get(key): return false
	return true

static func _keys(value: Dictionary, required: Array, optional: Array = []) -> bool:
	for key: Variant in value:
		if not key is String or (key not in required and key not in optional): return false
	for key: String in required:
		if not value.has(key): return false
	return true

static func _registered(dna: Dictionary, carrier: Dictionary) -> bool:
	for authored: Dictionary in dna.get("direct_surface_carriers", []):
		if authored.get("carrier_id") == carrier.get("carrier_id"):
			return surface_key(authored, {"ok": true, "digest": "plan"}) == surface_key(carrier, {"ok": true, "digest": "plan"})
	return false

static func _parent(carrier: Dictionary, part_id: String) -> String:
	for p: Dictionary in carrier.parts:
		if str(p.part_id) == part_id: return str(p.parent_part_id)
	return ""

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _vec(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size() == 3:
		for scalar: Variant in value:
			if not (scalar is int or scalar is float): return Vector3(INF, INF, INF)
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(INF, INF, INF)

static func _digest(value: Variant) -> String:
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(var_to_bytes(value)); return digest.finish().hex_encode()

## Separate zero-surface contract. Existing nonempty mesh validation is unchanged.
## A skipped result cannot masquerade as a realized mesh or acquire fresh inputs.
static func normalize_skipped(dna: Dictionary, carrier: Dictionary, host: Dictionary, consumed_anatomy: Dictionary, stage: int, reasons: Dictionary, generated_signature: Dictionary) -> Dictionary:
	var signature := host_signature(host, consumed_anatomy)
	if not signature.ok: return signature
	if generated_signature.get("digest") != signature.digest or generated_signature.get("surface_key") != surface_key(carrier, signature): return fail("stale_surface", "Skipped result lacks its original current-host signature.")
	var states := {}
	for part: Dictionary in carrier.get("parts", []):
		var pid := str(part.part_id)
		if not reasons.get(pid) is String or str(reasons[pid]).strip_edges().is_empty(): return fail("carrier_realization", "Every skipped part needs its own explicit reason.", pid)
		states[pid] = {"feature_id": str(part.feature_id), "status": "skipped", "vertices": 0, "reason": str(reasons[pid])}
	var result := {"ok": true, "skipped": true, "skip_contract": "direct_surface_skipped_v1", "stage": stage,
		"organism_id": str(dna.biological_blueprint.organism_id), "carrier_id": str(carrier.carrier_id),
		"surface_key": surface_key(carrier, signature), "host_signature": signature, "part_statuses": states, "body_extractions": 0, "new_bones": 0}
	var checked := validate_skipped(dna, carrier, host, consumed_anatomy, result, stage)
	return result if checked.ok else checked

static func validate_skipped(dna: Dictionary, carrier: Dictionary, host: Dictionary, consumed_anatomy: Dictionary, result: Dictionary, stage: int) -> Dictionary:
	var planned := validate_plan(dna, stage)
	if not planned.ok: return planned
	if not _registered(dna, carrier) or stage != int(dna.get("metadata", {}).get("iteration_index", -1)) or stage < int(carrier.created_stage): return fail("carrier_stage", "Skipped artifact differs from current registered stage.")
	if result.get("ok") != true or result.get("skipped") != true or result.get("skip_contract") != "direct_surface_skipped_v1" or result.has("mesh"): return fail("carrier_skip", "A skipped artifact is not an empty realized mesh.")
	if result.get("organism_id") != dna.biological_blueprint.organism_id or result.get("carrier_id") != carrier.carrier_id or result.get("stage") != stage: return fail("carrier_skip", "Skipped identity/stage differs from source.")
	var signature := host_signature(host, consumed_anatomy)
	if not signature.ok: return signature
	if not _same_signature(result.get("host_signature"), signature) or result.get("surface_key") != surface_key(carrier, signature): return fail("stale_surface", "Skipped artifact was made for another recipe or actual host.")
	if not result.get("part_statuses") is Dictionary or result.part_statuses.size() != carrier.parts.size(): return fail("carrier_skip", "Missing skipped part states.")
	for part: Dictionary in carrier.parts:
		var state: Variant = result.part_statuses.get(str(part.part_id))
		if not state is Dictionary or state.get("feature_id") != part.feature_id or state.get("status") != "skipped" or state.get("vertices") != 0 or not state.get("reason") is String or str(state.reason).strip_edges().is_empty(): return fail("carrier_skip", "Skipped state claims geometry or omits its reason.", str(part.part_id))
	return {"ok": true, "surface_key": str(result.surface_key), "vertices": 0, "triangles": 0, "skipped": true}

static func append_skipped(dna: Dictionary, geometry: Dictionary, carrier: Dictionary, consumed_anatomy: Dictionary, result: Dictionary, stage: int) -> Dictionary:
	var checked := validate_skipped(dna, carrier, geometry, consumed_anatomy, result, stage)
	if not checked.ok: return checked
	for detail: Dictionary in geometry.get("detail_meshes", []):
		if detail.get("direct_surface_carrier", {}).get("carrier_id") == carrier.carrier_id: return fail("carrier_skip", "Cannot mark an already present direct surface as skipped.")
	var composed := geometry.duplicate(false)
	var states: Dictionary = geometry.get("direct_surface_realization", {}).duplicate(true)
	states[str(carrier.carrier_id)] = {"surface_key": checked.surface_key, "stage": stage, "parts": result.part_statuses.duplicate(true), "status": "skipped", "skip_contract": "direct_surface_skipped_v1"}
	composed["direct_surface_realization"] = states
	return {"ok": true, "geometry": composed, "skipped": true}
