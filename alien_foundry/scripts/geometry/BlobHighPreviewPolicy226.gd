extends RefCounted
## Explicit bounded second conforming pass, never a field or normal change.
## This supplemental selector requires the immutable224 HighPreview profile.
const High = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const SETTING: String = "blob_isosurface_preview_pass_mode"
const PIN_SETTING: String = "blob_preview_pass_pin226"
const MODE: String = "bounded_high_preview2_v1"
const OFF: String = "off"
const PIN: String = "46735202dba8a4b7b528378ec4c140dd7c92cbe22750e0bbe599c4569e8c5b59"
const MAX_REFINEMENT_PASSES: int = 2
const MAX_NEW_PLANES: int = 16
const MAX_NEW_PLANES_PER_AXIS: int = 6
const MAX_EXTRA_SAMPLES: int = 100000
const MAX_TOTAL_SAMPLES: int = 560000
const EDGE_CAP: int = 60000
const QUERY_CAP: int = 4380000
const TRIANGLE_CAP: int = 100000
const PER_EDGE_QUERY_CAP: int = 73

static func text_is(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func enabled(dna: Dictionary) -> bool:
	var settings: Variant = dna.get("settings", {})
	return settings is Dictionary and text_is(settings.get(SETTING), MODE)

static func selection(options: Dictionary) -> Dictionary:
	var mode: Variant = options.get(SETTING, OFF)
	if not mode is String or mode not in [OFF, MODE]:
		return {"error": "226 preview-pass selector must be an explicit supported string."}
	if options.has(PIN_SETTING) and (mode == OFF or not text_is(options.get(PIN_SETTING), PIN)):
		return {"error": "226 supplied preview-pass pin is stale, malformed or inactive."}
	if mode == OFF:
		return {"mode": OFF}
	var old: Dictionary = High.selection(options)
	if old.has("error"):
		return old
	if old.mode != High.MODE or not text_is(options.get(High.PIN_SETTING), High.PIN):
		return {"error": "226 requires the exact explicit224 HighPreview selector and pin."}
	return {"mode": MODE}

static func validate(dna: Dictionary) -> Dictionary:
	var settings_value: Variant = dna.get("settings", {})
	if not settings_value is Dictionary:
		return {"ok": false, "error": "226 requires dictionary settings."}
	var settings: Dictionary = settings_value
	var selected: Dictionary = selection(settings)
	if selected.has("error"):
		return {"ok": false, "error": selected.error}
	if selected.mode == OFF:
		return {"ok": true}
	if not text_is(settings.get(PIN_SETTING), PIN):
		return {"ok": false, "error": "226 enabled DNA requires its exact saved preview-pass pin."}
	return High.validate(dna)

static func field_projection(dna: Dictionary) -> Dictionary:
	var declaration: Dictionary = validate(dna)
	if not declaration.ok:
		return {"error": declaration.error}
	var result: Dictionary = dna.duplicate(true)
	if not enabled(dna):
		return result
	var settings: Dictionary = result.settings
	settings.erase(SETTING)
	settings.erase(PIN_SETTING)
	# Filter only matching extraction-setting entries. Never reseal rounded JSON
	# shadows or omit unrelated settings, nodes, metadata or unknown recipe paths.
	var recipe_value: Variant = result.get("geometry_numeric_recipe")
	if recipe_value is Dictionary:
		var recipe: Dictionary = recipe_value
		var numbers_value: Variant = recipe.get("numbers")
		if numbers_value is Array:
			var kept: Array = []
			for entry: Variant in numbers_value:
				if entry is Dictionary:
					var path: Variant = entry.get("path")
					if path is Array and path.size() == 2 and text_is(path[0], "settings") and (text_is(path[1], SETTING) or text_is(path[1], PIN_SETTING)):
						continue
				kept.append(entry)
			recipe.numbers = kept
	return result

static func scalar_bits(value: float) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()
