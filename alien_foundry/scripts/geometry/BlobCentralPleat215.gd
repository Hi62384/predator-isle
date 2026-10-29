extends RefCounted
## One fixed central primary pleat; no new field, amplitude policy or solver.
## Author only the Stage5 owner and its already-copied registry rule.
const MODE: String="central_keel_pleat_v1"
const PIN: String="5c42b591ff02a08fe7f96cdb4e9f1c6891c70b248669f8db15246449f7446532"
const SETTING: String="blob_sac_surface_mode"
const PRIMARY_FEATURE: String="blob.sac.primary.0"
const Primary=preload("res://alien_foundry/scripts/geometry/BlobPrimaryPleat214.gd")
const Field=preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const NORMALIZED_AMPLITUDE: float=Primary.NORMALIZED_AMPLITUDE

static func enabled(dna: Dictionary)->bool:
	var settings: Variant=dna.get("settings",{})
	return settings is Dictionary and settings.get(SETTING) is String and settings.get(SETTING)==MODE

static func creases()->Array:
	return [{"center":0.0,"width":0.78,"strength":1.0}]

static func author_nodes(dna: Dictionary)->Dictionary:
	if not enabled(dna):return {"error":"215 authoring requires its explicit central primary role."}
	var owner: Dictionary=Primary.primary_owner(dna)
	if owner.is_empty():return {"error":"215 primary owner is missing or ambiguous."}
	# Use214's unchanged parameter-only derivation and exact float64 encoding.
	var derived: Dictionary=Primary.expected_amplitude(dna,owner)
	if not derived.ok:return {"error":derived.error}
	owner.shape[Field.KEY]["creases"]=creases()
	owner.shape[Field.KEY]["fold_amplitude"]=derived.amplitude
	owner.shape[Field.KEY]["fold_amplitude_hex"]=Primary.bits(float(derived.amplitude))
	return {"ok":true,"owner_id":owner.id,"feature_id":PRIMARY_FEATURE,"amplitude":derived.amplitude,"depth_radius":derived.depth_radius}

static func author_rules(dna: Dictionary)->Dictionary:
	if not enabled(dna):return {"error":"215 registry authoring requires its explicit central primary role."}
	var blueprint: Variant=dna.get("biological_blueprint")
	if not blueprint is Dictionary or not blueprint.get("features") is Array:return {"error":"215 requires the Stage5 registry copy before rule authoring."}
	var owner: Dictionary=Primary.primary_owner(dna)
	if owner.is_empty():return {"error":"215 primary owner is missing or ambiguous."}
	var derived: Dictionary=Primary.expected_amplitude(dna,owner)
	if not derived.ok:return {"error":derived.error}
	var target: Dictionary={}
	var target_found: bool=false
	for feature: Variant in blueprint.features:
		if not feature is Dictionary or not feature.get("id") is String:return {"error":"215 registry contains a malformed feature."}
		if feature.id==PRIMARY_FEATURE:
			if target_found or not feature.get("detail_rules") is Dictionary:return {"error":"215 primary detail rule is missing or ambiguous."}
			target_found=true
			target=feature.detail_rules
	if target.is_empty():return {"error":"215 primary detail rule was not found."}
	# The caller owns this Stage5 copy. Preserve every other rule and registry
	# field, and retain214's exact amplitude on repeated authoring calls.
	target["density"]=1
	target["amplitude"]=derived.amplitude
	return {"ok":true}
