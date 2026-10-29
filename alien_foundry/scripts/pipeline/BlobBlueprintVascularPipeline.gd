extends RefCounted
## New policy only. No fixed183b/off behavior is routed through this module.
const Adapter = preload("res://alien_foundry/scripts/geometry/BlobBlueprintVascularAdapter.gd")
const Vascular = preload("res://alien_foundry/scripts/geometry/BlobBlueprintVascularNetwork.gd")
const Carrier = preload("res://alien_foundry/scripts/geometry/DirectSurfaceFeatureCarrier.gd")
const Codec = preload("res://alien_foundry/scripts/persistence/DirectSurfaceRecipeCodec.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const MODE := "vascular_blueprint_v1"
const SETTING := "blob_direct_surface_profile"

static func requested(dna: Dictionary) -> bool:
	return dna.get("settings", {}).get(SETTING, "off") == MODE

static func enabled(dna: Dictionary) -> bool:
	return requested(dna) and dna.get("direct_surface_carriers") is Array and not dna.direct_surface_carriers.is_empty()

static func selection(dna: Dictionary) -> Dictionary:
	var settings: Dictionary = dna.get("settings", {})
	if dna.get("type") != "Blob" or settings.get("blob_pipeline_mode") != "iterative_v2" or settings.get("quality", 1) != 0:
		return Carrier.fail("direct_profile", "Blueprint vascular adaptation currently supports iterative Blob Low/Preview only.")
	if settings.get("blob_sac_group_mode", "off") != "off": return Carrier.fail("direct_host", "Mapped185 sac hosts are not qualified for blueprint vascular adaptation.")
	return {"ok": true, "enabled": true, "policy": MODE}

static func install(plans: Dictionary) -> Dictionary:
	var planned := Adapter.plan(plans.final_dna)
	if not planned.ok: return planned
	var registry: Dictionary = plans.final_dna.biological_blueprint.duplicate(true)
	for declaration: Dictionary in planned.feature_declarations: registry.features.append(declaration.duplicate(true))
	for update: Dictionary in planned.parent_child_updates: Blueprint.feature(registry, str(update.parent_id)).children.append(str(update.child_id))
	for i in range(7):
		var dna: Dictionary = plans.geometry_dnas[i] if i < 6 else plans.final_dna
		dna.settings[SETTING] = MODE
		dna.metadata["direct_surface_planning"] = planned.planning_outcome.duplicate(true)
		if not planned.carrier.is_empty(): dna["direct_surface_carriers"] = [planned.carrier.duplicate(true)]
		Blueprint.annotate_snapshot(dna, registry, mini(i + 1, 6))
	plans["biological_blueprint"] = registry
	return plans

static func _stripped(dna: Dictionary) -> Dictionary:
	var stripped := dna.duplicate(true); var ids := {}
	for carrier: Dictionary in dna.get("direct_surface_carriers", []):
		for part: Dictionary in carrier.parts: ids[str(part.feature_id)] = true
	var features: Array = []
	for feature: Dictionary in stripped.biological_blueprint.features:
		if ids.has(str(feature.id)): continue
		var children: Array = []
		for child: String in feature.children:
			if not ids.has(child): children.append(child)
		feature.children = children; features.append(feature)
	stripped.biological_blueprint.features = features
	stripped.erase("direct_surface_carriers")
	return stripped

static func _equal(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size(): return false
		for key: String in expected:
			if not actual.has(key) or not _equal(actual[key], expected[key]): return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size(): return false
		for i in range(expected.size()):
			if not _equal(actual[i], expected[i]): return false
		return true
	if expected is int or expected is float:
		return (actual is int or actual is float) and is_finite(float(actual)) and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected

static func validate_plans(plans: Dictionary) -> Dictionary:
	var dna: Dictionary = plans.final_dna
	var selected := selection(dna)
	if not selected.ok: return selected
	var checked := Carrier.validate_plan(dna, 6)
	if not checked.ok: return checked
	var canonical := Adapter.plan(_stripped(dna))
	if not canonical.ok: return canonical
	if not plans.get("geometry_dnas") is Array or plans.geometry_dnas.size() != 6: return Carrier.fail("direct_plan", "Six physical snapshots are required.")
	var actual: Array = dna.get("direct_surface_carriers", [])
	if canonical.carrier.is_empty():
		if not actual.is_empty(): return Carrier.fail("direct_plan", "No-sac policy cannot declare invented vascular carriers.")
	else:
		if actual.size() != 1 or Carrier.surface_key(actual[0], {"ok": true, "digest": "canonical"}) != Carrier.surface_key(canonical.carrier, {"ok": true, "digest": "canonical"}): return Carrier.fail("direct_identity", "Blueprint vascular recipe/identity differs from its declared authoring policy.")
	for stage in range(7):
		var snapshot: Dictionary = plans.geometry_dnas[stage] if stage < 6 else dna
		if not requested(snapshot) or not _equal(snapshot.get("metadata", {}).get("direct_surface_planning"), canonical.planning_outcome): return Carrier.fail("direct_plan", "Missing or false explicit vascular planning outcome.")
		var carriers: Array = snapshot.get("direct_surface_carriers", [])
		if carriers.size() != actual.size(): return Carrier.fail("direct_plan", "Direct plan changed between snapshots.")
		if not carriers.is_empty() and Carrier.surface_key(carriers[0], {"ok": true, "digest": "canonical"}) != Carrier.surface_key(canonical.carrier, {"ok": true, "digest": "canonical"}): return Carrier.fail("direct_identity", "Vascular carrier construction changed between snapshots.")
		for expected: Dictionary in canonical.feature_declarations:
			var feature := Blueprint.feature(snapshot.biological_blueprint, str(expected.id))
			for field: String in ["id", "type", "subtype", "parent_id", "children", "stream_id", "tissue", "geometry_refs", "created_stage", "geometry_recipe"]:
				if not _equal(feature.get(field), expected[field]): return Carrier.fail("direct_identity", "Vascular biological construction changed: " + str(expected.id) + "/" + field)
			var direction: Variant = feature.get("growth_direction")
			if not direction is Array or direction.size() != 3 or Vector3(float(direction[0]), float(direction[1]), float(direction[2])) != Vector3(float(expected.growth_direction[0]), float(expected.growth_direction[1]), float(expected.growth_direction[2])): return Carrier.fail("direct_identity", "Vascular biological direction changed.")
	return {"ok": true, "enabled": not actual.is_empty(), "planning_outcome": canonical.planning_outcome}

static func realize(dna: Dictionary, body: Dictionary, body_key: String, stage: int, cache: RefCounted, controls: RefCounted = null) -> Dictionary:
	var outcome: Dictionary = dna.metadata.direct_surface_planning
	if stage < 5 or not enabled(dna): return {"ok": true, "geometry": body, "geometry_key": body_key, "surfaces": [], "hits": {}, "planning_outcome": outcome}
	var carrier: Dictionary = dna.direct_surface_carriers[0]
	var anatomy := Adapter.consumed_anatomy(dna, body)
	var signature := Carrier.host_signature(body, anatomy)
	if not signature.ok: return signature
	var key := Carrier.surface_key(carrier, signature)
	var slot := Carrier.surface_cache_slot(stage, str(carrier.carrier_id))
	var result: Dictionary = cache.lookup(slot, key)
	var hit := not result.is_empty()
	if result.is_empty(): result = Adapter.build(dna, body, carrier, stage, controls)
	if result.has("error") or result.get("cancelled", false): return result
	var skipped: bool = result.get("skipped", false)
	var checked: Dictionary = Carrier.validate_skipped(dna, carrier, body, anatomy, result, stage) if skipped else Carrier.validate_result(dna, carrier, body, anatomy, result, stage)
	if not checked.ok: return checked
	var appended: Dictionary = Carrier.append_skipped(dna, body, carrier, anatomy, result, stage) if skipped else Carrier.append_result(dna, body, carrier, anatomy, result, stage)
	if not appended.ok: return appended
	cache.store_value(slot, key, result)
	var surfaces := [{"carrier_id": str(carrier.carrier_id), "surface_key": key, "host_signature": signature, "status": "skipped" if skipped else "realized_geometry"}]
	return {"ok": true, "geometry": appended.geometry, "geometry_key": Carrier.compose_geometry_key(body_key, [key]), "surfaces": surfaces,
		"hits": {slot: hit}, "changes_geometry": not skipped, "planning_outcome": outcome}

static func validate_manifest(dna: Dictionary, records: Variant) -> Dictionary:
	if not records is Array or records.size() != 2: return Carrier.fail("direct_manifest", "Completed blueprint vascular save must preserve both stage5/6 artifact identities.")
	var carrier: Dictionary = dna.direct_surface_carriers[0]
	var bodies: Array = []; var dependency := ""
	for i in range(6):
		dependency = Artifacts.geometry_key(dna.pipeline.geometry_dnas[i], i + 1, dependency); bodies.append(dependency)
	var keys: Array = []
	for i in range(2):
		var record: Variant = records[i]
		if not record is Dictionary or record.get("stage") != i + 5 or record.get("body_key") != bodies[i + 4] or not record.get("surfaces") is Array or record.surfaces.size() != 1: return Carrier.fail("direct_manifest", "Invalid current-body artifact identity.")
		var surface: Variant = record.surfaces[0]
		if not surface is Dictionary or surface.get("carrier_id") != Adapter.ID or surface.get("status") not in ["realized_geometry", "skipped"] or not surface.get("host_signature") is Dictionary: return Carrier.fail("direct_manifest", "Invalid direct artifact declaration.")
		var signature: Dictionary = surface.host_signature
		if signature.get("ok") != true or signature.get("signature_version") != 1: return Carrier.fail("direct_manifest", "Invalid direct host signature.")
		for field: String in ["physical_sha256", "provenance_sha256", "anatomy_key", "digest"]:
			if not signature.get(field) is String or signature[field].length() != 64 or signature[field].hex_decode().size() != 32: return Carrier.fail("direct_manifest", "Invalid saved host hash.")
		if signature.digest != Carrier._digest([1, signature.physical_sha256, signature.provenance_sha256, signature.anatomy_key]): return Carrier.fail("direct_manifest", "Conflicting saved host signature.")
		var key := Carrier.surface_key(carrier, signature)
		if key.is_empty() or surface.get("surface_key") != key or record.get("geometry_key") != Carrier.compose_geometry_key(str(record.body_key), [key]): return Carrier.fail("direct_manifest", "Conflicting direct geometry key.")
		keys.append(str(record.geometry_key))
	return {"ok": true, "geometry_key": keys[-1]}
