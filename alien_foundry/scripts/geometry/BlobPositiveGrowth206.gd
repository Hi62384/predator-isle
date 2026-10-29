extends RefCounted
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
##206 bounded positive-growth context. Shape payload is immutable203 anatomy.
const SETTING:="blob_positive_growth_mode"
const MODE:="positive_sacs_only_v1"
const IDENTITY:="positive_sacs_v1"
const KEY:="positive_growth206"
const OFF:="off"
const PIN:="51dcb37f8d429ce3de455039e3be6d5da12e83c6d2082eccb8c0957aadbfd199"
const Mass=preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const Group=preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const Host=preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const Outer=preload("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd")
const Surface=preload("res://alien_foundry/scripts/geometry/BlobSacSurface212.gd")
const PREREQUISITES={"blob_base_volume_mode":"unequal_compartments_v1","blob_body_envelope_mode":"shared_shoulder_envelope_v1","blob_body_group_mode":"branched_body_group_v1","blob_mass_reprofile_mode":"whole_mass_silhouette_v1","blob_isosurface_refinement_mode":"bracketed_field_edges_v1","blob_sac_group_mode":"sac_group_growth_final_v1"}
const SAC_IDS=["blob.sac.primary.0","blob.sac.primary.1","blob.sac.primary.2"]
static func marked(node: Dictionary)->bool:
	return node.get("shape") is Dictionary and node.shape.has(KEY)
static func selection(options: Dictionary)->Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE]:return {"error":"Invalid206 positive growth selector."}
	if mode==OFF:
		if options.get("blob_identity_profile")==IDENTITY:return {"error":"206 identity requires its explicit bounded growth mode."}
		return {"mode":OFF}
	if options.get("blob_identity_profile")!=IDENTITY:return {"error":"206 requires the separately named positive_sacs_v1 profile."}
	for key: String in PREREQUISITES:
		if options.get(key)!=PREREQUISITES[key]:return {"error":"206 missing explicit prerequisite: "+key}
	if options.get("secondary_enabled",true)!=false or options.get("blob_direct_surface_profile",OFF)!=OFF or options.get("surface_operations",[])!=[]:return {"error":"206 forbids secondary/direct/surface-operation combinations."}
	if options.get("quality",1)!=1 or options.get("size",1.0)!=1.0:return {"error":"206 initially permits Standard and size1 only."}
	return {"mode":MODE}
static func _number(value: Variant)->bool:return (value is float or value is int) and is_finite(float(value))
static func _context_ok(d: Variant)->bool:
	if d is Dictionary and ((_number(d.get("version")) and float(d.version) in [2.0,3.0,4.0]) or (_number(d.get("stage")) and float(d.stage)==5.0) or Surface.text_is(d.get("mode"),Surface.MODE) or Surface.text_is(d.get("pin"),Surface.PIN)):
		return Surface.context_ok(d)
	if not d is Dictionary or d.size()!=9 or not _number(d.get("version")) or float(d.version)!=1.0 or not d.get("mode") is String or not d.get("pin") is String or d.get("mode")!=MODE or d.get("pin")!=PIN:return false
	if not _number(d.get("stage")) or float(d.stage) not in [3.0,4.0]:return false
	if not d.get("owner_id") is String or not d.get("member_ids") is Array or d.member_ids.size()!=5 or not d.get("member_feature_ids") is Array or d.member_feature_ids.size()!=5:return false
	if d.owner_id!=d.member_ids[0] or d.get("scope")!="positive_stage_context_not_shape_reauthoring" or not d.get("union_context") is Array:return false
	var seen: Array=[]
	for e: Variant in d.union_context:
		if not e is Dictionary or e.size()!=5 or not e.get("id") is String or e.id in seen or e.get("kind") not in ["mass","curve"] or e.get("operation")!="union" or not _number(e.get("blend")) or float(e.blend)<0.001 or not _number(e.get("noise")) or float(e.noise)!=0.0:return false
		seen.append(e.id)
	return not seen.is_empty() and seen[0]==d.owner_id
static func context_for(dna: Dictionary,stage: int)->Dictionary:
	if Cavity217.enabled(dna):
		var cavity_declaration: Dictionary=Cavity217.validate_declaration(dna)
		if not cavity_declaration.ok:return {"error":cavity_declaration.error}
		return context_for(Cavity217.positive_projection(dna),stage)
	if stage==5:
		if not Surface.enabled(dna):return {"error":"212 explicit same-sac mode is required for a Stage5 positive context."}
		var surface_choice: Dictionary=Surface.selection(dna.settings)
		if surface_choice.has("error"):return surface_choice
	if not dna.get("nodes") is Array:return {"error":"206 context requires an actual node array."}
	var nodes: Array=dna.nodes
	for n: Variant in nodes:
		if not n is Dictionary or not n.get("id") is String or n.get("kind") not in ["mass","curve"] or n.get("operation","union")!="union" or not _number(n.get("blend")) or float(n.blend)<0.001 or not _number(n.get("noise")) or float(n.noise)!=0.0:return {"error":"206 context refuses unsupported/nonfinite source operations."}
	if nodes.is_empty() or not nodes[0] is Dictionary or not Mass.marked(nodes[0]):return {"error":"206 requires original203 body owner first."}
	if not Mass.descriptor_ok(nodes[0].shape[Mass.KEY]):return {"error":"206 requires the existing valid203 shape descriptor."}
	var shape: Dictionary=nodes[0].shape[Mass.KEY]
	var result: Dictionary={"version":1,"mode":MODE,"pin":PIN,"stage":stage,"owner_id":shape.owner_id,"member_ids":shape.member_ids.duplicate(),"member_feature_ids":shape.member_feature_ids.duplicate(),"union_context":Host.union_context(nodes),"scope":"positive_stage_context_not_shape_reauthoring"}
	return Surface.adapt_context(result,dna) if stage==5 else result
static func validate_declaration(dna: Dictionary)->Dictionary:
	var cavity_declaration: Dictionary=Cavity217.validate_declaration(dna)
	if not cavity_declaration.ok:return cavity_declaration
	if Cavity217.enabled(dna):return validate_declaration(Cavity217.positive_projection(dna))
	var surface_declaration: Dictionary=Surface.validate_declaration(dna)
	if not surface_declaration.ok:return surface_declaration
	if not dna.get("settings",{}) is Dictionary:return {"ok":false,"error":"206 settings must be a dictionary."}
	var choice:=selection(dna.get("settings",{}))
	if choice.has("error"):return {"ok":false,"error":choice.error}
	if not dna.get("nodes",[]) is Array:return {"ok":false,"error":"206 requires a node array."}
	var marked_nodes: Array=[]
	for node: Variant in dna.get("nodes",[]):
		if node is Dictionary and marked(node):marked_nodes.append(node)
	if choice.mode==OFF:return {"ok":marked_nodes.is_empty(),"error":"206 marker requires explicit mode." if not marked_nodes.is_empty() else ""}
	var bad: Dictionary={"ok":false,"error":"Invalid206 stage-local positive context or unsupported operation."}
	if dna.get("type")!="Blob" or not _number(dna.get("seed")) or float(dna.seed)!=22.0 or not dna.get("metadata") is Dictionary:return bad
	var stage: Variant=dna.metadata.get("iteration_index")
	if not _number(stage) or (float(stage) not in [3.0,4.0] and not (float(stage)==5.0 and Surface.enabled(dna))) or marked_nodes.size()!=5 or not dna.get("modules",[]) is Array or not dna.get("modules",[]).is_empty():return bad
	var expected:=context_for(dna,int(stage))
	if expected.has("error") or not _context_ok(expected):return bad
	if dna.nodes.size()!=(10 if int(stage)==3 else 13):return bad
	var body: Dictionary=dna.nodes[0].shape[Mass.KEY]
	var original: Array=body.base_group.union_context
	# Existing body and support source operations cannot drift with integration.
	if original.size()!=7 or expected.union_context.slice(0,7)!=original:return bad
	var seen: Array=[]
	for node: Dictionary in marked_nodes:
		# Enabled212 contexts always enter its typed schema, even when several
		# forged tags together would otherwise resemble a legacy declaration.
		if Surface.enabled(dna) and not Surface.context_ok(node.shape[KEY]):return bad
		if not Mass.marked(node) or node.get("id") not in expected.member_ids or node.id in seen or not _context_ok(node.shape[KEY]):return bad
		# Only these schema-checked integral declaration tags have JSON float
		# shadows. Never normalize consumed blends or restored descriptor typing.
		var declaration: Dictionary=node.shape[KEY].duplicate(true)
		declaration.version=int(declaration.version);declaration.stage=int(declaration.stage)
		if declaration!=expected:return bad
		seen.append(node.id)
	var sacs: Array=[];var transitions:=0
	for node: Dictionary in dna.nodes.slice(7):
		if node.kind!="mass" or node.get("feature_id") not in SAC_IDS or node.get("parent") not in expected.member_ids:return bad
		if bool(node.get("derived_connector",false)):
			if int(stage) not in [4,5] or node.get("source_feature_id")!=node.feature_id: return bad
			transitions+=1
		else:
			if node.feature_id in sacs:return bad
			sacs.append(node.feature_id)
	if sacs!=SAC_IDS or transitions!=(0 if int(stage)==3 else 3):return bad
	for node: Dictionary in dna.nodes:
		if node.get("surface_opening",false) or node.has("contained_lip") or node.get("shape",{}).get("geometry","")=="detail":return bad
	return {"ok":true}
static func validate(dna: Dictionary)->Dictionary:
	if Cavity217.enabled(dna):
		var cavity_restored: Dictionary=Cavity217.validate_restored(dna)
		if not cavity_restored.ok:return cavity_restored
		return validate(Cavity217.positive_projection(dna))
	var surface_restored: Dictionary=Surface.validate_restored(dna)
	if not surface_restored.ok:return surface_restored
	var declared:=validate_declaration(dna)
	if not declared.ok or dna.get("settings",{}).get(SETTING,OFF)==OFF:return declared
	var expected:=context_for(dna,int(dna.metadata.iteration_index))
	for n: Dictionary in dna.nodes:
		if marked(n) and not Outer.typed_equal(n.shape[KEY],expected):return {"ok":false,"error":"206 restored context differs in exact scalar types/bits."}
	var field:=compile(dna.nodes[0])
	return {"ok":field.valid,"error":field.error,"qualification":field.qualification}
static func author(dna: Dictionary,stage: int)->Dictionary:
	if stage not in [3,4] and not (stage==5 and Surface.enabled(dna)):return {"error":"206 authors only Stage3/4, or explicit212 partial Stage5."}
	dna.metadata["iteration_index"]=stage
	dna.settings[SETTING]=MODE;dna.settings["blob_identity_profile"]=IDENTITY;dna.settings["secondary_enabled"]=false
	# Group growth is introduced at4; retain its already-authorized intent at3.
	dna.settings["blob_sac_group_mode"]="sac_group_growth_final_v1"
	var d:=context_for(dna,stage)
	if d.has("error"):return d
	for n: Dictionary in dna.nodes:
		if Mass.marked(n):n.shape[KEY]=d.duplicate(true)
	var checked:=validate_declaration(dna)
	if not checked.ok:return {"error":checked.error}
	dna.metadata[KEY]={"version":Surface.context_version_for_mode(str(dna.settings.get(Surface.SETTING,Surface.MODE))) if stage==5 else 1,"pin":Surface.pin_for_mode(str(dna.settings.get(Surface.SETTING,Surface.MODE))) if stage==5 else PIN,"stage":stage,"profile":IDENTITY,"shape_payload_unchanged":true,"stage_context_reauthored":true,"actual_geometry_pending":true,"final_rig_supported":false}
	return {"ok":true}
static func compile(node: Dictionary)->RefCounted:
	var failed=load("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd").new()
	if not marked(node) or not Mass.marked(node) or not _context_ok(node.shape[KEY]):failed.error="Malformed206 contextual body field.";return failed
	var d: Dictionary=node.shape[KEY]
	if not d.version is int or not d.stage is int:failed.error="206 requires restored typed context.";return failed
	var source: Dictionary=node.shape[Mass.KEY]
	if d.owner_id!=source.owner_id or d.member_ids!=source.member_ids or d.member_feature_ids!=source.member_feature_ids:failed.error="206 context/body identity mismatch.";return failed
	# Compile a fresh effective descriptor, never mutate the authored payload.
	var n:=node.duplicate(true);n.shape.erase(KEY)
	var effective: Dictionary=n.shape[Mass.KEY].base_group
	effective.union_context=d.union_context.duplicate(true);effective.host.union_context=d.union_context.duplicate(true)
	n.shape[Group.KEY]=effective.duplicate(true)
	if Host.marked(n):n.shape[Host.KEY]=effective.host.duplicate(true)
	return Mass.create(n)
static func scale_context(node: Dictionary,scale: float)->void:
	if marked(node):
		for entry: Dictionary in node.shape[KEY].union_context:entry.blend=float(entry.blend)*scale
