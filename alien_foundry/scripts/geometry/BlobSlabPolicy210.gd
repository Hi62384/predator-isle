extends RefCounted
const HighPreview2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const HighPreview=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
## One bounded conforming extraction pass. No field or normal policy changes.
const SacSurface=preload("res://alien_foundry/scripts/geometry/BlobSacSurface212.gd")
const SETTING: String="blob_isosurface_grid_mode"
const PIN_SETTING: String="blob_grid_policy_pin210"
const MODE: String="conflict_slabs_v1"
const OFF: String="off"
const PIN: String="1fc055748a6a45c05f3c91e7379e416767742aeee3f5a150c691670fa0adaf8d"
const EDGE_CAP: int=60000
const QUERY_CAP: int=4380000
const TRIANGLE_CAP: int=100000
const RETAINED_SHA: String="1f5d9299866e4092670637ef9af8d5f7da18ab095503b64902014f495c831864"
const RETAINED_KEY: String="6328001281c45a73b12a322c62437e47da98f0bc59427232e2fb59225dd2be29"
const RETAINED_DEPENDENCY: String="7a323983f077641383836c1de4ca080b60667af10aa978261652ec755ab8fa14"
const RETAINED_CELL_BITS: String="8d0a65a2ae65af3f"
const RETAINED_ORIGIN_BITS: String="364a14c07a33ccbfa67329c0"
const RETAINED_GRID: Vector3i=Vector3i(76,73,82)
const FACE_ERROR: String="204 refined face/field-normal inconsistency; no normal or topology repair."

static func enabled(dna: Dictionary)->bool:
	var settings: Variant=dna.get("settings",{})
	return settings is Dictionary and settings.get(SETTING) is String and settings.get(SETTING)==MODE

static func text_is(value: Variant,expected: String)->bool:return value is String and value==expected

static func selection(options: Dictionary)->Dictionary:
	var preview2_choice: Dictionary=HighPreview2.selection(options)
	if preview2_choice.has("error"):return preview2_choice
	var preview_choice: Dictionary=HighPreview.selection(options)
	if preview_choice.has("error"):return preview_choice
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE]:return {"error":"210 grid selector must be an explicit supported string."}
	if options.has(PIN_SETTING) and (mode==OFF or not text_is(options.get(PIN_SETTING),PIN)):return {"error":"210 supplied policy descriptor is stale, malformed or inactive."}
	if mode==OFF:return {"mode":OFF}
	if not text_is(options.get("blob_positive_growth_mode"),"positive_sacs_only_v1") or not text_is(options.get("blob_isosurface_normal_mode"),"adaptive_field_gradient_v2") or not text_is(options.get("blob_isosurface_refinement_mode"),"bracketed_field_edges_v1"):return {"error":"210 requires positive-sacs growth and the unchanged208v2/204 extraction policies."}
	var quality: Variant=options.get("quality",1)
	if not (quality is int or quality is float) or not is_finite(float(quality)) or float(quality)!=1.0:return {"error":"210 is explicitly Standard-only."}
	return {"mode":MODE}

static func validate(dna: Dictionary)->Dictionary:
	var preview2_check: Dictionary=HighPreview2.validate(dna)
	if not preview2_check.ok:return preview2_check
	if dna.get("settings",{}) is Dictionary:
		var preview_check: Dictionary=HighPreview.validate(dna)
		if not preview_check.ok:return preview_check
	var cavity_declaration: Dictionary=Cavity217.validate_declaration(dna)
	if not cavity_declaration.ok:return cavity_declaration
	if not dna.get("settings",{}) is Dictionary:return {"ok":false,"error":"210 requires dictionary settings."}
	var settings: Dictionary=dna.get("settings",{})
	var surface_check: Dictionary=SacSurface.validate_declaration(dna)
	if not surface_check.ok:return surface_check
	var selected: Dictionary=selection(settings)
	if selected.has("error"):return {"ok":false,"error":selected.error}
	if selected.mode==OFF:
		if settings.has(PIN_SETTING):return {"ok":false,"error":"210 inactive selector cannot carry a policy descriptor."}
		return {"ok":true}
	if not text_is(settings.get(PIN_SETTING),PIN):return {"ok":false,"error":"210 enabled DNA requires the exact saved policy pin."}
	var metadata: Variant=dna.get("metadata",{})
	if not metadata is Dictionary:return {"ok":false,"error":"210 requires Stage4 metadata."}
	var stage: Variant=metadata.get("iteration_index")
	if not (stage is int or stage is float) or not is_finite(float(stage)) or not text_is(dna.get("type"),"Blob"):return {"ok":false,"error":"210 requires finite Blob stage metadata."}
	if float(stage)!=4.0 and not (float(stage)==5.0 and SacSurface.enabled(dna)):return {"ok":false,"error":"210 permits Blob Stage4, or the explicit212 partial Stage5 extension only."}
	if not dna.get("modules",[]) is Array or not dna.get("modules",[]).is_empty():return {"ok":false,"error":"210 initial profile does not support modules."}
	var secondary: Variant=settings.get("secondary_enabled",false)
	if not secondary is bool or secondary or not settings.get("surface_operations",[]) is Array or not settings.get("surface_operations",[]).is_empty():return {"ok":false,"error":"210 requires the unchanged positive-only/direct-layer-off profile."}
	if not dna.get("direct_surface_carriers",[]) is Array or not dna.get("direct_surface_carriers",[]).is_empty():return {"ok":false,"error":"210 does not enable direct layers."}
	return {"ok":true}

static func scalar_bits(value: float)->String:
	var bytes: PackedByteArray=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
