extends RefCounted
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
## Explicit partial Stage5 eligibility and persistence schema. This helper does
## not author geometry or certify roots/fold visibility. The existing shared sac
## map and its unchanged finite qualification remain authoritative.
const Pleat=preload("res://alien_foundry/scripts/geometry/BlobPrimaryPleat214.gd")
const Central=preload("res://alien_foundry/scripts/geometry/BlobCentralPleat215.gd")
const SETTING: String="blob_sac_surface_mode"
const PIN_SETTING: String="blob_sac_surface_pin212"
const MODE: String="same_sac_creases_v1"
const OFF: String="off"
const PIN: String="9e666b03b626bfa13bd7576e7f54835c80f4095f4d5bb9d20fe50b4334553384"
const SAC_IDS: Array[String]=["blob.sac.primary.0","blob.sac.primary.1","blob.sac.primary.2"]
const SAC_KEY: String="sac_group_warp"
const SAC_SEED_LANE: String="sac_group_growth_v1"
const AMPLITUDE: float=0.065
const CONTEXT_SCOPE: String="positive_stage_context_not_shape_reauthoring"
const PREREQUISITES: Dictionary={
	"blob_pipeline_mode":"iterative_v2", "blob_identity_profile":"positive_sacs_v1",
	"blob_body_profile":"compact_body_v1", "blob_base_volume_mode":"unequal_compartments_v1",
	"blob_body_envelope_mode":"shared_shoulder_envelope_v1", "blob_body_group_mode":"branched_body_group_v1",
	"blob_mass_reprofile_mode":"whole_mass_silhouette_v1", "blob_positive_growth_mode":"positive_sacs_only_v1",
	"blob_sac_group_mode":"sac_group_growth_final_v1", "blob_isosurface_refinement_mode":"bracketed_field_edges_v1",
	"blob_isosurface_normal_mode":"adaptive_field_gradient_v2", "blob_isosurface_grid_mode":"conflict_slabs_v1"
}

static func text_is(value: Variant, expected: String)->bool:
	return value is String and value==expected

static func number(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))

static func integral_is(value: Variant, expected: int)->bool:
	return number(value) and float(value)==float(expected)

static func enabled(dna: Dictionary)->bool:
	var settings: Variant=dna.get("settings",{})
	return settings is Dictionary and (text_is(settings.get(SETTING),MODE) or text_is(settings.get(SETTING),Pleat.MODE) or text_is(settings.get(SETTING),Central.MODE))

static func pin_for_mode(mode: String)->String:
	if mode==Central.MODE:return Central.PIN
	return Pleat.PIN if mode==Pleat.MODE else PIN

static func context_version_for_mode(mode: String)->int:
	if mode==Central.MODE:return 4
	return 3 if mode==Pleat.MODE else 2

static func selection(options: Dictionary)->Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE,Pleat.MODE,Central.MODE]:return {"error":"212 sac surface selector must be a supported explicit string."}
	if options.has(PIN_SETTING) and (mode==OFF or not text_is(options.get(PIN_SETTING),pin_for_mode(mode))):
		return {"error":"212 supplied descriptor is stale, malformed or inactive."}
	if mode==OFF:return {"mode":OFF}
	for key: String in PREREQUISITES:
		if not text_is(options.get(key),str(PREREQUISITES[key])):return {"error":"212 missing explicit prerequisite: "+key}
	for pair: Array in [["quality",1.0],["size",1.0],["surface_detail",0.55]]:
		var value: Variant=options.get(str(pair[0]),pair[1])
		if not number(value) or float(value)!=float(pair[1]):return {"error":"212 fixed Standard/size1/surface_detail0.55 declaration required."}
	var secondary: Variant=options.get("secondary_enabled",true)
	if not secondary is bool or secondary:return {"error":"212 does not enable secondary anatomy."}
	if not text_is(options.get("blob_direct_surface_profile",OFF),OFF):return {"error":"212 does not enable direct surface layers."}
	var operations: Variant=options.get("surface_operations",[])
	if not operations is Array or not operations.is_empty():return {"error":"212 permits only the existing same-sac map, not surface operations."}
	return {"mode":mode}

static func validate_declaration(dna: Dictionary)->Dictionary:
	var cavity_declaration: Dictionary=Cavity217.validate_declaration(dna)
	if not cavity_declaration.ok:return cavity_declaration
	if Cavity217.enabled(dna):return validate_declaration(Cavity217.positive_projection(dna))
	var settings: Variant=dna.get("settings",{})
	if not settings is Dictionary:return {"ok":false,"error":"212 requires dictionary settings."}
	var selected: Dictionary=selection(settings)
	if selected.has("error"):return {"ok":false,"error":selected.error}
	if selected.mode==OFF:return {"ok":true}
	if not text_is(settings.get(PIN_SETTING),pin_for_mode(selected.mode)):return {"ok":false,"error":"212 enabled DNA requires its exact saved pin."}
	var metadata: Variant=dna.get("metadata")
	if not metadata is Dictionary or not integral_is(metadata.get("iteration_index"),5):return {"ok":false,"error":"212 is a partial Stage5 declaration only."}
	if not text_is(dna.get("type"),"Blob") or not integral_is(dna.get("seed"),22):return {"ok":false,"error":"212 initial specimen is Blob seed22 only."}
	var nodes: Variant=dna.get("nodes")
	if not nodes is Array or nodes.size()!=13:return {"ok":false,"error":"212 preserves the existing thirteen carriers."}
	for key: String in ["modules","direct_surface_carriers"]:
		var values: Variant=dna.get(key,[])
		if not values is Array or not values.is_empty():return {"ok":false,"error":"212 forbids modules and direct carriers."}
	var seen: Array=[]
	for node: Variant in nodes:
		if not node is Dictionary or not node.get("id") is String or node.id in seen or not node.get("shape",{}) is Dictionary:
			return {"ok":false,"error":"212 requires uniquely identified anatomical carriers."}
		if not node.get("kind") is String or node.kind not in ["mass","curve"] or not text_is(node.get("operation","union"),"union"):
			return {"ok":false,"error":"212 cannot enable subtractive or unsupported carriers."}
		if not number(node.get("blend")) or float(node.blend)<0.001 or not number(node.get("noise")) or float(node.noise)!=0.0:
			return {"ok":false,"error":"212 requires the unchanged finite positive-union operations."}
		seen.append(node.id)
	var folds: Dictionary=_validate_folds(dna,false)
	if not folds.ok:return folds
	# PositiveGrowth validates the complete matching body context after authoring;
	# this eligibility check deliberately does not pretend to qualify that field.
	return {"ok":true}

static func _float_bits(value: float)->String:
	var bytes: PackedByteArray=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	return bytes.hex_encode()

static func _recipe_number(value: Variant,expected: float,restored: bool)->bool:
	if restored:return value is float and _float_bits(value)==_float_bits(expected)
	if not number(value):return false
	# The raw JSON declaration has no exact codec yet. Accept its deterministic
	# decimal shadow only, never a geometric or numeric tolerance.
	var shadow: Variant=JSON.parse_string(JSON.stringify(expected,"",true,true))
	return float(value)==expected or (number(shadow) and float(value)==float(shadow))

static func expected_creases(ordinal: int)->Array:
	if ordinal==0:return [{"center":-0.48,"width":0.47,"strength":1.0},{"center":0.46,"width":0.40,"strength":0.82}]
	if ordinal==1:
		# Identical SHA256 stream definition and legacy sac lane used by the
		# unchanged BlobBiologicalBlueprint/BlobSacGroupGrowth authoring path.
		# Kept local to avoid a geometry -> blueprint -> geometry preload cycle.
		var stream: String="blob_iterative_v2|22|"+SAC_IDS[1]+"|"+SAC_SEED_LANE
		var rng: RandomNumberGenerator=RandomNumberGenerator.new()
		rng.seed=("0x"+stream.sha256_text().substr(0,13)).hex_to_int()
		return [{"center":rng.randf_range(-0.16,0.16),"width":0.78,"strength":1.0}]
	return []

static func _validate_folds(dna: Dictionary,restored: bool)->Dictionary:
	var reinforced: bool=Pleat.enabled(dna)
	var central: bool=Central.enabled(dna)
	var primary_amplitude: float=AMPLITUDE
	if reinforced or central:
		var primary: Dictionary=Pleat.primary_owner(dna)
		var derived: Dictionary=Pleat.expected_amplitude(dna,primary)
		if not derived.ok:return derived
		primary_amplitude=float(derived.amplitude)
	var owners: Dictionary={}
	for node: Dictionary in dna.nodes:
		var shape: Dictionary=node.get("shape",{})
		if not shape.has(SAC_KEY):continue
		var feature: Variant=node.get("feature_id")
		if not feature is String or feature not in SAC_IDS or owners.has(feature):return {"ok":false,"error":"212 requires exactly one same-sac map per declared sac."}
		if not shape[SAC_KEY] is Dictionary:return {"ok":false,"error":"212 requires an actual shared sac descriptor."}
		owners[feature]=shape[SAC_KEY]
	if owners.size()!=3:return {"ok":false,"error":"212 requires all three existing sac maps."}
	for ordinal: int in range(3):
		var d: Dictionary=owners[SAC_IDS[ordinal]]
		var expected: Array=Pleat.creases() if reinforced and ordinal==0 else expected_creases(ordinal)
		if central and ordinal==0:expected=Central.creases()
		var creases: Variant=d.get("creases")
		if not creases is Array or creases.size()!=expected.size():return {"ok":false,"error":"215 pinned crease counts are [1,1,0]." if central else "212 pinned crease counts are [2,1,0]."}
		var amplitude: float=primary_amplitude if ordinal==0 else (AMPLITUDE if ordinal==1 else 0.0)
		if not _recipe_number(d.get("fold_amplitude"),amplitude,restored):return {"ok":false,"error":"212 pinned same-sac amplitude differs."}
		if ordinal<2 and not text_is(d.get("fold_amplitude_hex"),_float_bits(amplitude)):return {"ok":false,"error":"212 active amplitude requires its exact original bits."}
		if ordinal==2 and d.has("fold_amplitude_hex"):return {"ok":false,"error":"212 smooth third sac must retain its inactive descriptor."}
		for index: int in range(expected.size()):
			var crease: Variant=creases[index]
			if not crease is Dictionary or crease.size()!=3:return {"ok":false,"error":"212 pinned crease schema differs."}
			for key: String in ["center","width","strength"]:
				if not _recipe_number(crease.get(key),float(expected[index][key]),restored):return {"ok":false,"error":"212 pinned crease table differs."}
	# The generator can author context before final blueprint annotation. When
	# present, its declared rules must match this exact program, not arbitrary
	# otherwise-valid folds. The ordinary blueprint validator owns completeness.
	var blueprint: Variant=dna.get("biological_blueprint")
	if blueprint is Dictionary and blueprint.get("features") is Array:
		for feature: Variant in blueprint.features:
			if not feature is Dictionary or not feature.get("id") is String or feature.id not in SAC_IDS:continue
			var ordinal: int=SAC_IDS.find(feature.id)
			var rule: Variant=feature.get("detail_rules")
			var counts: Array=[1,1,0] if central else [2,1,0]
			var count: int=counts[ordinal]
			if not rule is Dictionary or not integral_is(rule.get("version"),3) or not integral_is(rule.get("density"),count):return {"ok":false,"error":"212 fixed detail rule version/count differs."}
			if not rule.get("enabled") is bool or rule.enabled!=(count>0) or not text_is(rule.get("operation"),"sac_group_growth_final_v1") or not text_is(rule.get("amplitude_units"),"organism_scale"):return {"ok":false,"error":"212 fixed detail rule semantics differ."}
			# Blueprint rules are unconsumed explanatory metadata, not restored by
			# the exact geometry codec. Their exact JSON shadow remains legitimate.
			var rule_amplitude: float=primary_amplitude if ordinal==0 else AMPLITUDE
			if not _recipe_number(rule.get("amplitude"),rule_amplitude,false):return {"ok":false,"error":"212 fixed detail-rule amplitude differs."}
	return {"ok":true}

static func validate_restored(dna: Dictionary)->Dictionary:
	var declared: Dictionary=validate_declaration(dna)
	if not declared.ok or not enabled(dna):return declared
	return _validate_folds(dna,true)

static func context_ok(value: Variant)->bool:
	if not value is Dictionary or value.size()!=9:return false
	var mode: Variant=value.get("mode")
	if not mode is String or mode not in [MODE,Pleat.MODE,Central.MODE]:return false
	if not integral_is(value.get("version"),context_version_for_mode(mode)) or not integral_is(value.get("stage"),5):return false
	if not text_is(value.get("pin"),pin_for_mode(mode)) or not text_is(value.get("scope"),CONTEXT_SCOPE):return false
	if not value.get("owner_id") is String:return false
	for key: String in ["member_ids","member_feature_ids"]:
		var ids: Variant=value.get(key)
		if not ids is Array or ids.size()!=5:return false
		var seen_ids: Array=[]
		for id: Variant in ids:
			if not id is String or id.is_empty() or id in seen_ids:return false
			seen_ids.append(id)
	if value.owner_id!=value.member_ids[0] or not value.get("union_context") is Array or value.union_context.size()!=13:return false
	var seen: Array=[]
	for entry: Variant in value.union_context:
		if not entry is Dictionary or entry.size()!=5 or not entry.get("id") is String or entry.id in seen:return false
		if not entry.get("kind") is String or entry.kind not in ["mass","curve"] or not text_is(entry.get("operation"),"union"):return false
		if not number(entry.get("blend")) or float(entry.blend)<0.001 or not number(entry.get("noise")) or float(entry.noise)!=0.0:return false
		seen.append(entry.id)
	return seen[0]==value.owner_id

static func adapt_context(existing_context: Dictionary,dna: Dictionary={})->Dictionary:
	var mode: String=Pleat.MODE if Pleat.enabled(dna) else MODE
	if Central.enabled(dna):mode=Central.MODE
	var result: Dictionary=existing_context.duplicate(true)
	result["version"]=context_version_for_mode(mode);result["stage"]=5;result["mode"]=mode;result["pin"]=pin_for_mode(mode)
	result["scope"]=CONTEXT_SCOPE
	return result

static func validate_pilot_path(dna: Dictionary,path: Variant)->Dictionary:
	if not path is String:return {"ok":false,"error":"212 retained pilot path must be a string."}
	if enabled(dna) and not path.is_empty():return {"ok":false,"error":"212 changed Stage5 field requires fresh coarse evaluation; retained Stage4 pilot reuse is forbidden."}
	return {"ok":true}
