extends RefCounted
## Explicit extraction-budget tier, never a new field, anatomy or game LOD.
## Intentionally preload-free: parent validators own the existing shape laws.
const SETTING: String = "blob_isosurface_preview_budget_mode"
const PIN_SETTING: String = "blob_preview_budget_pin224"
const MODE: String = "bounded_high_preview_v1"
const OFF: String = "off"
const PIN: String = "69f5ffe11ed3c6aad5994ba4d37501e968fa410d25df7ac2f9cfd55c510ac09e"
const MAX_NEW_PLANES: int = 12
const MAX_NEW_PLANES_PER_AXIS: int = 4
const MAX_EXTRA_SAMPLES: int = 80000
const MAX_TOTAL_SAMPLES: int = 560000
const MAX_COARSE_SAMPLES: int = 480000
const EDGE_CAP: int = 60000
const QUERY_CAP: int = 4380000
const TRIANGLE_CAP: int = 100000
const PER_EDGE_QUERY_CAP: int = 73
const REFINEMENT_PASS_CAP: int = 1
const RETAINED_SHA: String = "2a3afd17ebaedb7cb19535da37bc765f461935dfeccb1f6df0788843e8de4d27"
const RETAINED_KEY: String = "84a7d43331e0d5fdc89040f8e1435dbf849bd1119ae891cede0f438825a16a6c"
const RETAINED_DEPENDENCY: String = "cf33780f55a7d8b0f8a6aa98f7eefdcc573cfe076bedd250e2ebda5cffadb464"
const RETAINED_SPEC_PIN: String = "d601192b5f21a5a48e47ea2e579f46940cd3285dafaf7d503487acf6fd6b700c"
const RETAINED_CELL_BITS: String = "8d0a65a2ae65af3f"
const RETAINED_ORIGIN_BITS: String = "364a14c07a33ccbfa67329c0"
const RETAINED_GRID: Vector3i = Vector3i(76, 73, 82)
const RETAINED_EDGES: int = 13930
const RETAINED_QUERIES: int = 498428
const RETAINED_LATTICE_VISITS: int = 454936
const SLAB_PIN: String = "1fc055748a6a45c05f3c91e7379e416767742aeee3f5a150c691670fa0adaf8d"
const NORMAL_PIN: String = "5eb7722334a080e7fdd428f17f732877ac15b7c41defb2604d2c9fe95cc1ac00"
const ROOT_PIN: String = "505802d0b619bd74bf45c312800eda4e16e0a802de3a92d10397f73f2d80ca02"
const SURFACE_PIN: String = "5c42b591ff02a08fe7f96cdb4e9f1c6891c70b248669f8db15246449f7446532"
const FACE_ERROR: String = "204 refined face/field-normal inconsistency; no normal or topology repair."
const OUTER_ERROR: String = "210 selected shared planes exceed the complete-plan cap; no truncation or respacing."
const PREREQUISITES: Dictionary = {
	"blob_pipeline_mode": "iterative_v2",
	"blob_identity_profile": "positive_sacs_v1",
	"blob_positive_growth_mode": "positive_sacs_only_v1",
	"blob_mantle_cavity_mode": "territory_primary_blind_chamber_v1",
	"blob_sac_surface_mode": "central_keel_pleat_v1",
	"blob_isosurface_grid_mode": "conflict_slabs_v1",
	"blob_isosurface_normal_mode": "adaptive_field_gradient_v2",
	"blob_isosurface_refinement_mode": "bracketed_field_edges_v1"
}
const PREREQUISITE_PINS: Dictionary = {
	"blob_mantle_cavity_pin217": RETAINED_SPEC_PIN,
	"blob_sac_surface_pin212": SURFACE_PIN,
	"blob_grid_policy_pin210": SLAB_PIN
}

static func text_is(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func integral(value: Variant) -> bool:
	return number(value) and float(value) == floor(float(value))

static func enabled(dna: Dictionary) -> bool:
	var settings: Variant = dna.get("settings", {})
	return settings is Dictionary and text_is(settings.get(SETTING), MODE)

static func selection(options: Dictionary) -> Dictionary:
	var mode: Variant = options.get(SETTING, OFF)
	if not mode is String or mode not in [OFF, MODE]:
		return {"error": "224 preview-budget selector must be an explicit supported string."}
	if options.has(PIN_SETTING) and (mode == OFF or not text_is(options.get(PIN_SETTING), PIN)):
		return {"error": "224 supplied preview-budget pin is stale, malformed or inactive."}
	if mode == OFF:
		return {"mode": OFF}
	for key: String in PREREQUISITES:
		var expected: String = PREREQUISITES[key]
		if not text_is(options.get(key), expected):
			return {"error": "224 requires the unchanged selected223/215/210/208v2/204 profile: " + key}
	for key: String in PREREQUISITE_PINS:
		var expected: String = PREREQUISITE_PINS[key]
		if options.has(key) and not text_is(options.get(key), expected):
			return {"error": "224 supplied prerequisite pin is stale or malformed: " + key}
	for pair: Array in [["quality", 1.0], ["size", 1.0], ["surface_detail", 0.55]]:
		var key: String = pair[0]
		var expected: float = pair[1]
		var value: Variant = options.get(key, expected)
		if not number(value) or float(value) != expected:
			return {"error": "224 requires the unchanged Standard/size1/detail0.55 field profile."}
	var secondary: Variant = options.get("secondary_enabled", false)
	if not secondary is bool or secondary:
		return {"error": "224 secondary anatomy remains disabled."}
	if not text_is(options.get("blob_direct_surface_profile", OFF), OFF):
		return {"error": "224 direct surface layers remain disabled."}
	for key: String in ["surface_operations", "modules", "direct_surface_carriers"]:
		var items: Variant = options.get(key, [])
		if not items is Array or not items.is_empty():
			return {"error": "224 does not enable modules, direct layers or surface operations."}
	# Authoring options need not carry a stage, but an explicit stage cannot lie.
	for key: String in ["stage", "iteration_index"]:
		if options.has(key):
			var stage: Variant = options.get(key)
			if not integral(stage) or float(stage) != 5.0:
				return {"error": "224 preview budget is restricted to partial Stage5."}
	if options.has("seed"):
		var seed: Variant = options.get("seed")
		if not integral(seed) or float(seed) != 22.0:
			return {"error": "224 retained preview budget is restricted to seed22."}
	if options.has("type") and not text_is(options.get("type"), "Blob"):
		return {"error": "224 retained preview budget is restricted to Blob."}
	return {"mode": MODE}

static func validate(dna: Dictionary) -> Dictionary:
	var settings_value: Variant = dna.get("settings", {})
	if not settings_value is Dictionary:
		return {"ok": false, "error": "224 requires dictionary settings."}
	var settings: Dictionary = settings_value
	var selected: Dictionary = selection(settings)
	if selected.has("error"):
		return {"ok": false, "error": selected.error}
	if selected.mode == OFF:
		return {"ok": true}
	if not text_is(settings.get(PIN_SETTING), PIN):
		return {"ok": false, "error": "224 enabled DNA requires its exact saved preview-budget pin."}
	for key: String in PREREQUISITE_PINS:
		var expected: String = PREREQUISITE_PINS[key]
		if not text_is(settings.get(key), expected):
			return {"ok": false, "error": "224 enabled DNA requires the existing exact policy pin: " + key}
	var seed: Variant = dna.get("seed")
	if not text_is(dna.get("type"), "Blob") or not integral(seed) or float(seed) != 22.0:
		return {"ok": false, "error": "224 supports only the retained seed22 Blob."}
	var metadata: Variant = dna.get("metadata")
	if not metadata is Dictionary:
		return {"ok": false, "error": "224 requires partial Stage5 metadata."}
	var stage: Variant = metadata.get("iteration_index")
	if not integral(stage) or float(stage) != 5.0:
		return {"ok": false, "error": "224 requires finite integral partial Stage5 metadata."}
	for key: String in ["modules", "direct_surface_carriers"]:
		var items: Variant = dna.get(key, [])
		if not items is Array or not items.is_empty():
			return {"ok": false, "error": "224 does not support modules or direct layers."}
	return {"ok": true}

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
