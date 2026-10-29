extends RefCounted
## Explicit fixed-field live-generation recipe, never a legacy DNA selector.
const Quad = preload("res://alien_foundry/scripts/geometry/BlobQuadPolicy229.gd")
const FORMAT: String = "predator-isle-live-quad232-recipe"
const MODE: String = "live_fixed224_field_quad229_v1"
const PIN: String = "664464238b800112262fe33aa1f3c02f74c370e70ea50098122326015bd38cf1"
const ARTIFACT_KEY: String = "b8404250f3619b0750dd5f0030d9cf9dc5b8a7a392c8e55ab9c631db02351465"
const CACHE_SLOT: String = "blob.live_quad232.fixed_stage5"
const MAX_RECIPE_BYTES: int = 65536
const PRIOR_EDGES: int = 13930
const PRIOR_QUERIES: int = 498428
const PRIOR_LATTICE: int = 454936
const LATTICE_CAP: int = 522880
const SELECTED_QUALIFICATION_CAP: int = 4406
const SAC_QUALIFICATION_CAP: int = 2190
const NEW_EDGE_QUERY_CAP: int = 3881572
const ATTRIBUTION_DISTANCE_CAP: int = 951774
const ATTRIBUTION_BODY_CAP: int = 35916
const ATTRIBUTION_LATTICE_CAP: int = 53874

static func recipe() -> Dictionary:
	return {"format":FORMAT,"format_version":1,"experiment":"232","mode":MODE,"policy_pin232":PIN,"artifact_geometry_key":ARTIFACT_KEY,"cache_slot":CACHE_SLOT,"seed":22,"stage":5,"quality":1,"recipe229":Quad.recipe()}

static func validate_recipe(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"ok":false,"error":"232 recipe must be an explicit dictionary."}
	var expected: Dictionary = recipe()
	if value.size() != expected.size(): return {"ok":false,"error":"232 recipe has missing or unknown fields."}
	for key: String in expected:
		if not value.has(key): return {"ok":false,"error":"232 missing recipe field: " + key}
		var want: Variant = expected[key]; var got: Variant = value[key]
		if key == "recipe229":
			var declared: Dictionary = Quad.validate_recipe(got)
			if not declared.ok: return {"ok":false,"error":"232 nested chooser declaration: " + str(declared.error)}
		elif want is String:
			if not got is String or got != want: return {"ok":false,"error":"232 changed recipe string: " + key}
		elif want is int:
			if not (got is int or got is float) or not is_finite(float(got)) or float(got) != float(want): return {"ok":false,"error":"232 changed recipe integer: " + key}
		else: return {"ok":false,"error":"232 unsupported internal schema."}
	return {"ok":true,"error":"","recipe":expected}

static func save_recipe(path: String, value: Variant) -> Dictionary:
	var checked: Dictionary = validate_recipe(value)
	if not checked.ok: return checked
	var text: String = JSON.stringify(checked.recipe,"\t",true,true)
	if text.to_utf8_buffer().size() > MAX_RECIPE_BYTES: return {"ok":false,"error":"232 recipe byte cap."}
	var file: FileAccess = FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"232 cannot open recipe temporary file."}
	file.store_string(text); file.flush(); var status: Error = file.get_error(); file.close()
	if status != OK or DirAccess.rename_absolute(path + ".tmp",path) != OK: return {"ok":false,"error":"232 cannot finish recipe save."}
	return {"ok":true,"error":"","path":path}

static func load_recipe(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null: return {"ok":false,"error":"232 cannot open recipe."}
	if file.get_length() > MAX_RECIPE_BYTES: file.close(); return {"ok":false,"error":"232 recipe byte cap."}
	var parser: JSON = JSON.new(); var status: Error = parser.parse(file.get_as_text()); file.close()
	if status != OK: return {"ok":false,"error":"232 malformed recipe JSON."}
	return validate_recipe(parser.data)
