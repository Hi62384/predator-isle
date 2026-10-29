extends RefCounted
## Explicit real Stage5 API. Does not replay retained faces or invoke legacy UI.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadPolicy232.gd")
const Volume232 = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadVolume232.gd")
const FORMAT: String = "predator-isle-live-stage5-request232"
const ARTIFACT_FORMAT: String = "predator-isle-live-stage5-artifact232"

static func request(source224_path: String, recipe_value: Variant) -> Dictionary:
	return {"format":FORMAT,"source224_path":source224_path,"recipe232":recipe_value}

static func validate_request(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 3: return {"ok":false,"error":"232 request must contain exactly format, source224_path and recipe232."}
	if not value.get("format") is String or value.format != FORMAT: return {"ok":false,"error":"232 requires the explicit live Stage5 request format."}
	if not value.get("source224_path") is String or value.source224_path.is_empty(): return {"ok":false,"error":"232 requires the exact224 source path."}
	var declared: Dictionary = Policy.validate_recipe(value.get("recipe232"))
	if not declared.ok: return declared
	return {"ok":true,"error":"","source224_path":value.source224_path,"recipe":declared.recipe}

func build(input: Variant, cache: RefCounted = null, controls: RefCounted = null) -> Dictionary:
	var checked: Dictionary = validate_request(input)
	if not checked.ok: return {"error":checked.error}
	# Identity is allocated now, but cache reuse awaits fresh-output qualification.
	# Never allow a retained229 or ordinary224 cache entry to masquerade as232.
	if cache != null: return {"error":"232 initial live API forbids cache reuse; explicit fresh build only."}
	var volume: RefCounted = Volume232.new()
	var mesh: Dictionary = volume.build_selected_stage5(checked.source224_path,checked.recipe,controls)
	if mesh.has("error") or mesh.get("cancelled",false): return mesh
	return {"format":ARTIFACT_FORMAT,"artifact_version":1,"status":"live_stage5_generated232_unqualified","recipe232":checked.recipe,"geometry_key":Policy.ARTIFACT_KEY,"field_geometry_key":Policy.Quad.SOURCE_KEY,"reference224_raw_sha256":Policy.Quad.SOURCE_RAW_SHA,"cache_slot":Policy.CACHE_SLOT,"cache_hit":false,"seed":22,"stage":5,"dna":volume.source_dna.duplicate(true),"mesh_data":mesh,"live_extraction232":true,"retained_retriangulation":false,"old224_rejection_preserved":true,"retained229_artifact_unchanged":true,"late_qualification_pending":true,"fresh_parity_qualified":false,"artistic_acceptance":false,"general_seed_claim":false,"ui_default_enabled":false}
