extends RefCounted
## Bounded orchestration for the exact qualified183b host. This is not a
## generalized vascular grammar. Physical body inputs and keys remain separate.
const Generalized = preload("res://alien_foundry/scripts/pipeline/BlobBlueprintVascularPipeline.gd")
const Adapter = preload("res://alien_foundry/scripts/geometry/BlobVascularDirectAdapter.gd")
const Carrier = preload("res://alien_foundry/scripts/geometry/DirectSurfaceFeatureCarrier.gd")
const Vascular = preload("res://alien_foundry/scripts/geometry/BlobSurfaceVascularNetwork.gd")
const Codec = preload("res://alien_foundry/scripts/persistence/DirectSurfaceRecipeCodec.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const SETTING := "blob_direct_surface_profile"
const OFF := "off"
const MODE := "vascular_183b_v1"
const BODY_KEYS := ["d26a049df1d924230245318bbace25d3adeb30e7b2b75f3e6f756c0a475cebdf", "02e56eb1768a2e9ada3625120e870c5a8a053e17508104124adf66ea55ed09d5", "cc88352f7e676e06ad5e2891e8e1da3f3f67e851274aa218ec411d8819498602", "525fe799590739a592a693785a74d9692f3c72b3311009052baed77c6fbc86ef", "3fde6750430060950ad91f55d5c94201a940330f49c06eb2829b5a7918ab4f66", "2c70e41122088bc56075743fcced3b998a44e052033fde8ef6b40ece621e19d8"]
const HOST_PHYSICAL := {5: "7b040f8d21d71a6d19ea2f957cd378a76f5c1a03987582df76cd41e48cfd1a44", 6: "09826cfe94deabc40575cede7012a79a47c64c387f33ad0198a12db55f731092"}

static func enabled(dna: Dictionary) -> bool:
	if Generalized.requested(dna): return Generalized.enabled(dna)
	return dna.get("settings", {}).get(SETTING, OFF) == MODE

static func selection(dna: Dictionary) -> Dictionary:
	var settings: Dictionary = dna.get("settings", {})
	var mode: Variant = settings.get(SETTING, OFF)
	if mode == Generalized.MODE: return Generalized.selection(dna)
	if not mode is String or mode not in [OFF, MODE]: return Carrier.fail("direct_profile", "Unsupported direct surface profile; no fallback was used.")
	if mode == OFF: return {"ok": true, "enabled": false}
	if dna.get("type") != "Blob" or settings.get("blob_pipeline_mode") != "iterative_v2" or dna.get("seed") != 22 or settings.get("quality", 1) != 0:
		return Carrier.fail("direct_profile", "Vascular183b is a bounded Blob seed22, Low/Preview, iterative profile only.")
	if settings.get("blob_sac_group_mode", "off") != "off": return Carrier.fail("direct_host", "Vascular183b has not been qualified on the mapped185 sac host; that combination is explicitly unsupported.")
	return {"ok": true, "enabled": true}

static func install(plans: Dictionary, options: Dictionary) -> Dictionary:
	if options.get(SETTING, OFF) == Generalized.MODE: return Generalized.install(plans)
	if options.get(SETTING, OFF) == OFF: return plans
	var final: Dictionary = plans.final_dna
	var planned: Dictionary = Adapter.plan(final)
	if not planned.get("ok", false): return planned
	var registry: Dictionary = final.biological_blueprint.duplicate(true)
	for declaration: Dictionary in planned.feature_declarations: registry.features.append(declaration.duplicate(true))
	for update: Dictionary in planned.parent_child_updates: Blueprint.feature(registry, str(update.parent_id)).children.append(str(update.child_id))
	for i in range(6):
		var dna: Dictionary = plans.geometry_dnas[i]
		dna.settings[SETTING] = MODE
		dna["direct_surface_carriers"] = [planned.carrier.duplicate(true)]
		Blueprint.annotate_snapshot(dna, registry, i + 1)
	final.settings[SETTING] = MODE
	final["direct_surface_carriers"] = [planned.carrier.duplicate(true)]
	Blueprint.annotate_snapshot(final, registry, 6)
	plans["biological_blueprint"] = registry
	return plans

static func validate_plans(plans: Dictionary) -> Dictionary:
	if Generalized.requested(plans.final_dna): return Generalized.validate_plans(plans)
	var dna: Dictionary = plans.final_dna
	var selected := selection(dna)
	if not selected.ok: return selected
	if not selected.enabled:
		if not dna.get("direct_surface_carriers", []).is_empty(): return Carrier.fail("direct_profile", "This runtime requires an explicit supported direct-surface profile; plans were not silently ignored.")
		return selected
	var dependency := ""
	for i in range(6):
		dependency = Artifacts.geometry_key(plans.geometry_dnas[i], i + 1, dependency)
		if dependency != BODY_KEYS[i]: return Carrier.fail("direct_host", "Vascular183b requires its exact qualified physical body recipe; changed bodies need separate qualification.")
	var carriers: Array = dna.get("direct_surface_carriers", [])
	if carriers.size() != 1 or carriers[0].get("carrier_id") != Adapter.ID or carriers[0].get("adapter_id") != Adapter.ADAPTER_ID: return Carrier.fail("direct_profile", "Only one canonical vascular183b carrier is orchestrated in187.")
	# Reconstruct the canonical declaration without reinterpreting geometry.
	# Shape identity/part topology cannot be edited independently of this fixed
	# builder. Appearance rules are deliberately excluded from the comparison.
	var stripped: Dictionary = dna.duplicate(true)
	var direct_ids := {}
	for part: Dictionary in carriers[0].parts: direct_ids[str(part.feature_id)] = true
	var base_features: Array = []
	for feature: Dictionary in stripped.biological_blueprint.features:
		if direct_ids.has(str(feature.id)): continue
		var children: Array = []
		for child: String in feature.children:
			if not direct_ids.has(child): children.append(child)
		feature.children = children
		base_features.append(feature)
	stripped.biological_blueprint.features = base_features
	var canonical: Dictionary = Adapter.plan(stripped)
	if not canonical.get("ok", false): return canonical
	if Carrier.surface_key(carriers[0], {"ok": true, "digest": "canonical"}) != Carrier.surface_key(canonical.carrier, {"ok": true, "digest": "canonical"}): return Carrier.fail("direct_identity", "Edited carrier identity/part topology is unsupported by the canonical183b builder.")
	for expected: Dictionary in canonical.feature_declarations:
		var actual: Dictionary = Blueprint.feature(dna.biological_blueprint, str(expected.id))
		for field: String in ["id", "type", "subtype", "parent_id", "children", "stream_id", "tissue", "geometry_refs"]:
			if actual.get(field) != expected[field]: return Carrier.fail("direct_identity", "Direct feature declaration differs from canonical183b: " + str(expected.id) + "/" + field)
		if int(actual.get("created_stage", -1)) != int(expected.created_stage) or not _same_construction(actual.get("geometry_recipe"), expected.geometry_recipe): return Carrier.fail("direct_identity", "Direct feature construction identity changed.")
		var direction: Array = actual.get("growth_direction", [])
		if direction.size() != 3 or Vector3(float(direction[0]), float(direction[1]), float(direction[2])) != Vector3(float(expected.growth_direction[0]), float(expected.growth_direction[1]), float(expected.growth_direction[2])): return Carrier.fail("direct_identity", "Direct feature construction direction changed.")
	var decoded: Dictionary = Codec.decode(carriers[0].recipe, carriers[0].numeric_recipe)
	if not decoded.ok: return decoded
	var recipe: Dictionary = Vascular.validate_recipe(dna, decoded.recipe)
	if not recipe.get("valid", false): return Carrier.fail("direct_recipe", "Modified vascular recipes invalidate direct keys but are not supported by the bounded183b builder.")
	return {"ok": true, "enabled": true}

static func realize(dna: Dictionary, body: Dictionary, body_key: String, stage: int, cache: RefCounted, controls: RefCounted = null) -> Dictionary:
	if Generalized.requested(dna): return Generalized.realize(dna, body, body_key, stage, cache, controls)
	if not enabled(dna) or stage < 5: return {"ok": true, "geometry": body, "geometry_key": body_key, "surfaces": [], "hits": {}}
	var carrier: Dictionary = dna.direct_surface_carriers[0]
	var anatomy: Dictionary = Adapter.consumed_anatomy(dna, body)
	var signature: Dictionary = Carrier.host_signature(body, anatomy)
	if not signature.ok: return signature
	if signature.physical_sha256 != HOST_PHYSICAL[stage]: return Carrier.fail("direct_host", "Actual extracted host differs from the qualified183b physical surface; no stale surface was attached.")
	var surface_key: String = Carrier.surface_key(carrier, signature)
	var slot: String = Carrier.surface_cache_slot(stage, str(carrier.carrier_id))
	var surface: Dictionary = cache.lookup(slot, surface_key)
	var hit: bool = not surface.is_empty()
	if surface.is_empty():
		surface = Adapter.build(dna, body, carrier, stage, controls)
		if surface.has("error") or surface.get("cancelled", false): return surface
	var checked: Dictionary = Carrier.validate_result(dna, carrier, body, anatomy, surface, stage)
	if not checked.ok: return checked
	var composed: Dictionary = Carrier.append_result(dna, body, carrier, anatomy, surface, stage)
	if not composed.ok: return composed
	cache.store_value(slot, surface_key, surface)
	var surfaces := [{"carrier_id": str(carrier.carrier_id), "surface_key": surface_key, "host_signature": signature}]
	return {"ok": true, "geometry": composed.geometry, "geometry_key": Carrier.compose_geometry_key(body_key, [surface_key]), "surfaces": surfaces, "hits": {slot: hit}}

static func manifest_entry(stage: int, body_key: String, result: Dictionary) -> Dictionary:
	return {"stage": stage, "body_key": body_key, "geometry_key": result.geometry_key, "surfaces": result.surfaces.duplicate(true)}

static func validate_manifest(dna: Dictionary, records: Variant) -> Dictionary:
	if Generalized.requested(dna): return Generalized.validate_manifest(dna, records)
	if not records is Array or records.size() != 2: return Carrier.fail("direct_manifest", "Completed vascular save must preserve stage5/6 direct artifact identities.")
	var carrier: Dictionary = dna.direct_surface_carriers[0]
	var keys: Array = []
	for i in range(2):
		var record: Variant = records[i]
		if not record is Dictionary or record.get("stage") != i + 5 or record.get("body_key") != BODY_KEYS[i + 4] or not record.get("surfaces") is Array or record.surfaces.size() != 1: return Carrier.fail("direct_manifest", "Invalid completed direct artifact order/body identity.")
		var surface: Variant = record.surfaces[0]
		if not surface is Dictionary or surface.get("carrier_id") != Adapter.ID or not surface.get("host_signature") is Dictionary: return Carrier.fail("direct_manifest", "Missing direct host signature.")
		var signature: Dictionary = surface.host_signature
		if signature.get("ok") != true or signature.get("signature_version") != 1 or signature.get("physical_sha256") != HOST_PHYSICAL[i + 5]: return Carrier.fail("direct_manifest", "Unqualified saved direct host signature.")
		for field: String in ["physical_sha256", "provenance_sha256", "anatomy_key", "digest"]:
			if not signature.get(field) is String or signature[field].length() != 64 or signature[field].hex_decode().size() != 32: return Carrier.fail("direct_manifest", "Invalid saved host hash.")
		if signature.digest != Carrier._digest([1, signature.physical_sha256, signature.provenance_sha256, signature.anatomy_key]): return Carrier.fail("direct_manifest", "Conflicting saved host signature digest.")
		var key: String = Carrier.surface_key(carrier, signature)
		if key.is_empty() or surface.get("surface_key") != key or record.get("geometry_key") != Carrier.compose_geometry_key(str(record.body_key), [key]): return Carrier.fail("direct_manifest", "Conflicting completed direct geometry key.")
		keys.append(str(record.geometry_key))
	return {"ok": true, "geometry_key": keys[-1]}

static func runtime_realization(stage: Dictionary, feature_id: String) -> Dictionary:
	for carrier: Dictionary in stage.get("mesh_data", {}).get("direct_surface_realization", {}).values():
		for part: Dictionary in carrier.get("parts", {}).values():
			if part.get("feature_id") == feature_id: return part
	return stage.get("dna", {}).get("feature_realization", {}).get(feature_id, {})

static func _same_construction(actual: Variant, expected: Dictionary) -> bool:
	if not actual is Dictionary or actual.size() != expected.size(): return false
	for key: String in expected:
		if actual.get(key) != expected[key]: return false
	return true
