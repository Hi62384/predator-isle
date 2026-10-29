extends RefCounted
const HighPreview2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const HighPreview=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
## Dependency projections are versioned separately from the biological schema.
const SacSurface=preload("res://alien_foundry/scripts/geometry/BlobSacSurface212.gd")
const SlabPolicy=preload("res://alien_foundry/scripts/geometry/BlobSlabPolicy210.gd")
const AdaptiveNormal = preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal207.gd")
const EdgeRefinement = preload("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement204.gd")
const MODE := "iterative_v2"
const VERSION := 2
const ARTIFACT_VERSION := 2
const IDS := ["primitive_blockout", "anatomical_development", "primary_features", "refined_clay", "feature_detail", "additional_anatomy", "materials", "feature_map"]
const LABELS := ["1 · Base Blockout", "2 · Anatomical Development", "3 · Primary Biological Features", "4 · Integrated Base Model", "5 · Geometry Detailing", "6 · Complete Geometry", "7 · Final Textured Model", "8 · Biological Feature Map"]

static func geometry_key(dna: Dictionary, stage: int, dependency: String = "") -> String:
	var decoded: Dictionary = decode_geometry_recipe(dna)
	if decoded.has("error"):
		return "invalid_recipe:" + JSON.stringify(_consumed_inputs(dna), "", true, true).sha256_text()
	var projected: Dictionary = decoded.inputs
	for node: Dictionary in projected.nodes:
		node.erase("surface"); node.erase("source")
	projected["mode"] = MODE
	projected["artifact_version"] = ARTIFACT_VERSION
	projected["iteration"] = stage
	projected["organism_id"] = dna.biological_blueprint.organism_id
	projected["dependency"] = dependency
	return JSON.stringify(projected, "", true, true).sha256_text()

static func material_key(dna: Dictionary, geometry: String) -> String:
	var rules := {}
	for feature: Dictionary in dna.biological_blueprint.features: rules[str(feature.id)] = feature.material_rules
	return JSON.stringify({"mode": MODE, "version": ARTIFACT_VERSION, "geometry": geometry,
		"materials": dna.materials, "rules": rules, "profile": dna.get("metadata", {}).get("blob_material_profile", "")}, "", true, true).sha256_text()

static func clean(dna: Dictionary) -> Dictionary:
	var result: Dictionary = dna.duplicate(true)
	result.erase("pipeline")
	return result

static func record(stage: int, dna: Dictionary, key: String, dependency: String) -> Dictionary:
	return {"id": IDS[stage - 1], "label": LABELS[stage - 1], "dna": clean(dna), "cache_key": key,
		"geometry_artifact_id": key, "artifact_version": ARTIFACT_VERSION, "depends_on": [] if dependency.is_empty() else [dependency],
		"available": true, "unavailable_reason": "", "iteration_index": stage,
		"default_view": "clay" if stage < 7 else ("material" if stage == 7 else "feature_map"),
		"changes_geometry": stage <= 6, "has_armature": false}

## V2 exact numeric recipe. Human-readable JSON numbers are shadows; the
## authored IEEE bits are restored BEFORE both extraction and cache projection.
## Only exact bits or their deterministic public JSON shadow are accepted.
## Other edits require seal_geometry_recipe() and cannot silently hit old cache.
static func _consumed_inputs(dna: Dictionary) -> Dictionary:
	var settings: Dictionary = dna.get("settings", {})
	var consumed := {"quality": settings.get("quality", 1), "size": settings.get("size", 1.0), "irregularity": settings.get("irregularity", 0.45)}
	if HighPreview2.enabled(dna):
		consumed[HighPreview2.SETTING]=settings.get(HighPreview2.SETTING);consumed[HighPreview2.PIN_SETTING]=settings.get(HighPreview2.PIN_SETTING)
	if HighPreview.enabled(dna):
		consumed[HighPreview.SETTING]=settings.get(HighPreview.SETTING);consumed[HighPreview.PIN_SETTING]=settings.get(HighPreview.PIN_SETTING)
	if Cavity217.enabled(dna):
		consumed[Cavity217.SETTING]=settings.get(Cavity217.SETTING);consumed[Cavity217.PIN_SETTING]=settings.get(Cavity217.PIN_SETTING)
	if SacSurface.enabled(dna):
		consumed[SacSurface.SETTING]=settings.get(SacSurface.SETTING);consumed[SacSurface.PIN_SETTING]=settings.get(SacSurface.PIN_SETTING)
	if SlabPolicy.enabled(dna):
		consumed[SlabPolicy.SETTING]=SlabPolicy.MODE;consumed[SlabPolicy.PIN_SETTING]=settings.get(SlabPolicy.PIN_SETTING)
	if settings.get(AdaptiveNormal.SETTING,AdaptiveNormal.OFF)!=AdaptiveNormal.OFF: consumed[AdaptiveNormal.SETTING]=settings.get(AdaptiveNormal.SETTING)
	if settings.get(EdgeRefinement.SETTING,EdgeRefinement.OFF)!=EdgeRefinement.OFF: consumed[EdgeRefinement.SETTING]=settings.get(EdgeRefinement.SETTING)
	for node: Dictionary in dna.get("nodes", []):
		if absf(float(node.get("noise", 0.0))) > 0.000001:
			consumed["surface_detail"] = settings.get("surface_detail", 0.55)
			break
	return {"seed": dna.get("seed", 1), "nodes": _structural_nodes(dna),
		"connections": dna.get("connections", []).duplicate(true), "modules": dna.get("modules", []).duplicate(true),
		"budget": dna.get("budget", {}).duplicate(true), "settings": consumed}

static func _structural_nodes(dna: Dictionary) -> Array:
	var nodes: Array = dna.get("nodes", []).duplicate(true)
	for node in nodes:
		if node is Dictionary:
			# Authoring trace only. Extraction consumes the resulting position,
			# size and shape, not the explanatory integration-growth record.
			node.erase("integration_growth")
	return nodes

static func _numbers(value: Variant, path: Array, output: Array) -> void:
	if value is Dictionary:
		var keys: Array = value.keys(); keys.sort()
		for key in keys:
			if path.size() == 2 and path[0] == "nodes" and key in ["surface", "source"]: continue
			_numbers(value[key], path + [key], output)
	elif value is Array:
		for i in range(value.size()): _numbers(value[i], path + [i], output)
	elif value is int:
		output.append({"path": path, "kind": "i64", "value": str(value)})
	elif value is float:
		var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, value)
		output.append({"path": path, "kind": "f64", "value": bytes.hex_encode()})

static func seal_geometry_recipe(dna: Dictionary) -> void:
	var entries: Array = []
	_numbers(_consumed_inputs(dna), [], entries)
	dna["geometry_numeric_recipe"] = {"version": 2, "encoding": "exact_i64_decimal_and_little_endian_ieee754_f64_hex", "shadow_contract": "exact_or_godot_full_precision_json_v1", "numbers": entries}

static func _same_recipe_path(authored: Array, actual: Array) -> bool:
	if authored.size() != actual.size(): return false
	for i in range(actual.size()):
		if actual[i] is int:
			if not (authored[i] is int or authored[i] is float): return false
			if not is_finite(float(authored[i])) or float(authored[i]) != float(int(authored[i])) or int(authored[i]) != actual[i]: return false
		elif not authored[i] is String or authored[i] != actual[i]: return false
	return true

static func decode_geometry_recipe(dna: Dictionary) -> Dictionary:
	var preview2_check: Dictionary=HighPreview2.validate(dna)
	if not preview2_check.ok:return {"error":preview2_check.error}
	if dna.get("settings",{}) is Dictionary:
		var preview_check: Dictionary=HighPreview.validate(dna)
		if not preview_check.ok:return {"error":preview_check.error}
	var surface_check: Dictionary=SacSurface.validate_declaration(dna)
	if not surface_check.ok:return {"error":surface_check.error}
	var slab_check: Dictionary=SlabPolicy.validate(dna)
	if not slab_check.ok:return {"error":slab_check.error}
	var edge_validation: Dictionary=EdgeRefinement.validate(dna)
	if not edge_validation.ok: return {"error":edge_validation.error}
	for field: String in ["settings", "budget"]:
		if not dna.get(field) is Dictionary: return {"error": "Invalid numeric recipe input object."}
	for field: String in ["nodes", "connections", "modules"]:
		if not dna.get(field) is Array: return {"error": "Invalid numeric recipe input array."}
	for node in dna.nodes:
		if not node is Dictionary: return {"error": "Invalid numeric recipe node."}
	var recipe: Variant = dna.get("geometry_numeric_recipe")
	if not recipe is Dictionary or recipe.get("version") != 2 or recipe.get("encoding") != "exact_i64_decimal_and_little_endian_ieee754_f64_hex" or recipe.get("shadow_contract") != "exact_or_godot_full_precision_json_v1" or not recipe.get("numbers") is Array:
		return {"error": "Missing exact iterative geometry numeric recipe."}
	var inputs: Dictionary = _consumed_inputs(dna)
	var observed_entries: Array = []
	_numbers(inputs, [], observed_entries)
	if observed_entries.size() != recipe.numbers.size(): return {"error": "Iterative geometry numeric recipe has stale or missing fields."}
	for i in range(observed_entries.size()):
		var item: Variant = recipe.numbers[i]
		if not item is Dictionary or not item.get("path") is Array or not _same_recipe_path(item.path, observed_entries[i].path) or not item.get("value") is String:
			return {"error": "Invalid exact iterative recipe path."}
		var target: Variant = inputs
		for step in observed_entries[i].path.slice(0, -1): target = target[int(step)] if target is Array else target[step]
		var key: Variant = int(observed_entries[i].path[-1]) if target is Array else observed_entries[i].path[-1]
		var observed: Variant = target[key]
		if str(item.get("kind", "")) == "i64":
			if not item.value.is_valid_int(): return {"error": "Invalid exact integer recipe."}
			var exact: int = item.value.to_int()
			if str(exact) != item.value: return {"error": "Non-canonical or overflowing exact integer recipe."}
			if (observed is int and observed != exact) or (observed is float and (not is_finite(observed) or observed != float(exact))):
				return {"error": "Integer geometry input differs from its exact recipe; reauthor it explicitly."}
			target[key] = exact
		elif str(item.get("kind", "")) == "f64":
			var bytes: PackedByteArray = item.value.hex_decode()
			if bytes.size() != 8: return {"error": "Invalid exact floating recipe."}
			var exact: float = bytes.decode_double(0)
			var actual := float(observed)
			if not is_finite(exact) or not is_finite(actual): return {"error": "Non-finite iterative recipe number."}
			var shadow := PackedByteArray(); shadow.resize(8); shadow.encode_double(0, actual)
			var matches := shadow == bytes
			if not matches:
				# Only the exact public serializer/parser transform is permitted.
				# This is a discrete encoding agreement, not a geometric tolerance.
				var public_value: Variant = JSON.parse_string(JSON.stringify(exact, "", true, true))
				if public_value is int or public_value is float:
					var public_bytes := PackedByteArray(); public_bytes.resize(8)
					public_bytes.encode_double(0, float(public_value))
					matches = shadow == public_bytes
			if not matches: return {"error": "Floating geometry input differs from its exact recipe; reauthor it explicitly.", "path": observed_entries[i].path, "exact_hex": bytes.hex_encode(), "observed_hex": shadow.hex_encode()}
			target[key] = exact
		else: return {"error": "Unsupported exact iterative recipe number kind."}
	return {"inputs": inputs}

static func geometry_input(dna: Dictionary) -> Dictionary:
	var decoded: Dictionary = decode_geometry_recipe(dna)
	if decoded.has("error"): return decoded
	var result: Dictionary = dna.duplicate(true)
	for field: String in ["seed", "nodes", "connections", "modules", "budget"]: result[field] = decoded.inputs[field]
	for i in range(result.nodes.size()):
		if dna.nodes[i].has("integration_growth"):
			result.nodes[i]["integration_growth"] = dna.nodes[i].integration_growth.duplicate(true)
	for setting: String in decoded.inputs.settings: result.settings[setting] = decoded.inputs.settings[setting]
	return result
