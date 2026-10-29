extends RefCounted
##203: same four carriers/five identities, changed whole outer mass profiles.
## Exact202 middle/root calls remain; historical descriptors are developmental
## inputs, not a claim that the203 outer host is unchanged. No metric-SDF claim.
const Group=preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const Host=preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const Outer=preload("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd")
const KEY:="mass_reprofile203"
const SETTING:="blob_mass_reprofile_mode"
const MODE:="whole_mass_silhouette_v1"
const OFF:="off"
const PIN:="760cc9be7bcdf46153a9e7a2fc4e763b47ff9bb9ed47cb387f3d5f056c769a9b"
const VALLEY_Z:=[0.25,0.375,0.5,0.625,0.75]
const VALLEY_ANGLES:=[PI/3.0,PI/2.0,2.0*PI/3.0]
const CLOSURE_AXIAL_STEPS:=16
const CLOSURE_ANGLE_STEPS:=32
const NORMAL_RELATIVE_STEP:=0.0001
static var _fields: Dictionary={}
var valid:=false
var error:=""
var descriptor: Dictionary={}
var owner_id:=""
var member_ids: Array=[]
var baseline: RefCounted=null
var host: RefCounted=null
var branches: Array=[]
var blend:=0.0
var halo:=0.0
var qualification: Dictionary={}
var support_box:=AABB()
var geometry_evaluations:=0
var host_evaluations:=0

static func marked(node: Dictionary) -> bool:
	var shape: Variant=node.get("shape")
	return shape is Dictionary and shape.has(KEY)
static func selection(options: Dictionary) -> Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE]: return {"error":"Unsupported explicit203 mass reprofile mode."}
	if mode==MODE and (options.get(Group.SETTING)!=Group.MODE or options.get(Host.SETTING)!=Host.MODE or options.get("blob_base_volume_mode")!="unequal_compartments_v1"): return {"error":"203 requires the explicit202 body group over195/201."}
	return {"mode":mode}
static func role_map(dna: Dictionary,base: Dictionary) -> Dictionary:
	var nodes: Dictionary={}
	for n: Variant in dna.get("nodes",[]):
		if n is Dictionary and n.get("id") is String: nodes[n.id]=n
	var ids: Array=base.member_ids
	var support_ids: Variant=dna.get("metadata",{}).get("compact_body_anatomy",{}).get("support_node_ids")
	if not support_ids is Array: return {"error":"203 lacks fixed support ownership."}
	var pads: Array=[]
	for id: Variant in support_ids:
		if not nodes.has(id): return {"error":"203 missing unchanged support."}
		var parent: Variant=nodes[id].get("parent")
		if parent in ids.slice(2) and parent not in pads: pads.append(parent)
	if pads.size()!=1: return {"error":"203 requires exactly one support-bearing subordinate."}
	var free: Array=[]
	for id: String in ids.slice(2):
		if not nodes.has(id): return {"error":"203 missing body identity."}
		if id!=pads[0]:
			var size: Variant=nodes[id].get("size")
			if not Host._vector(size): return {"error":"203 malformed authored size reference."}
			free.append({"id":id,"feature_id":str(nodes[id].get("feature_id","")),"volume":float(size[0])*float(size[1])*float(size[2])})
	if free.size()!=2: return {"error":"203 requires two unsupported subordinate identities."}
	free.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.volume>b.volume if a.volume!=b.volume else a.feature_id<b.feature_id)
	return {ids[0]:"mantle",ids[1]:"swelling",pads[0]:"pad",free[0].id:"lateral",free[1].id:"pear"}
static func descriptor_ok(d: Variant) -> bool:
	if not d is Dictionary or d.size()!=9: return false
	if not Host._number(d.get("version")) or float(d.version)!=1.0 or d.get("mode")!=MODE or d.get("pin")!=PIN: return false
	if not Group.descriptor_ok(d.get("base_group")): return false
	if d.get("owner_id")!=d.base_group.owner_id or d.get("member_ids")!=d.base_group.member_ids or d.get("member_feature_ids")!=d.base_group.member_feature_ids: return false
	if not d.get("profile_entries") is Array or d.profile_entries.size()!=5: return false
	if d.get("crown_policy")!="failed_aesthetic_diagnostic_not_geometry_gate": return false
	var roles: Array=[]
	for i in range(5):
		var e: Variant=d.profile_entries[i]
		if not e is Dictionary or e.size()!=4 or e.get("id")!=d.member_ids[i] or e.get("feature_id")!=d.member_feature_ids[i] or e.get("role") not in ["mantle","swelling","lateral","pear","pad"] or e.role in roles: return false
		if not Outer.profile_ok(e.get("profile")) or e.profile.role!=e.role: return false
		roles.append(e.role)
	return roles[0]=="mantle" and roles[1]=="swelling"
static func validate_declaration(dna: Dictionary) -> Dictionary:
	var choice:=selection(dna.get("settings",{}))
	if choice.has("error"): return {"ok":false,"error":choice.error}
	var nodes: Array=[]
	for n: Variant in dna.get("nodes",[]):
		if n is Dictionary and marked(n): nodes.append(n)
	if choice.mode==OFF: return {"ok":nodes.is_empty(),"error":"203 marker requires explicit mode." if not nodes.is_empty() else ""}
	var bad: Dictionary={"ok":false,"error":"Malformed203 typed reprofile declaration; metadata is not geometric acceptance."}
	if dna.get("type")!="Blob" or int(dna.get("metadata",{}).get("iteration_index",0))<2 or nodes.size()!=5: return bad
	var d: Variant=nodes[0].shape[KEY]
	if not descriptor_ok(d): return bad
	var roles:=role_map(dna,d.base_group)
	if roles.has("error"): return bad
	var report: Variant=dna.get("metadata",{}).get(KEY)
	if not report is Dictionary or not Host._number(report.get("version")) or float(report.version)!=1.0 or report.get("mode")!=MODE or report.get("pin")!=PIN or report.get("member_ids")!=d.member_ids or report.get("member_feature_ids")!=d.member_feature_ids: return bad
	for key: String in ["stage","external_group_evaluations","internal_carriers"]:
		if not Host._number(report.get(key)): return bad
	if float(report.stage)!=2.0 or float(report.external_group_evaluations)!=1.0 or float(report.internal_carriers)!=4.0: return bad
	for key: String in ["supports_unchanged","protected_calls_unchanged","outer_host_changed","aesthetic_diagnostic_retained","actual_volume_pending","visual_acceptance_pending"]:
		if not report.get(key) is bool or not report[key]: return bad
	if not report.get("anatomical_acceptance") is bool or report.anatomical_acceptance: return bad
	var seen: Array=[]
	for n: Dictionary in nodes:
		if n.shape[KEY]!=d or not Group.marked(n) or n.shape[Group.KEY]!=d.base_group or n.get("id") not in d.member_ids or n.get("kind")!="mass" or n.get("operation","union")!="union" or not Host._number(n.get("noise")) or float(n.noise)!=0.0: return bad
		var i: int=d.member_ids.find(n.id)
		if n.get("feature_id")!=d.member_feature_ids[i] or n.id in seen or d.profile_entries[i].role!=roles[n.id]: return bad
		seen.append(n.id)
	return {"ok":true}
static func validate(dna: Dictionary) -> Dictionary:
	var declared:=validate_declaration(dna)
	if not declared.ok or dna.get("settings",{}).get(SETTING,OFF)==OFF: return declared
	var owner: Dictionary={}
	for n: Dictionary in dna.nodes:
		if not marked(n): continue
		if owner.is_empty(): owner=n
		if not Outer.typed_equal(n.shape[KEY],owner.shape[KEY]) or not Outer.typed_equal(n.shape[Group.KEY],n.shape[KEY].base_group):
			return {"ok":false,"error":"203 restored member/embedded descriptors differ in exact scalar types or bits."}
	if owner.is_empty(): return {"ok":false,"error":"Missing203 owner."}
	var f:=create(owner)
	return {"ok":f.valid,"error":f.error,"qualification":f.qualification}
static func validate_compilation_context(dna: Dictionary) -> Dictionary:
	if dna.get("settings",{}).get(SETTING,OFF)==OFF: return {"ok":true}
	var declared:=validate_declaration(dna)
	if not declared.ok: return declared
	return Group.validate_compilation_context(dna)
static func make_entries(base: RefCounted,roles: Dictionary) -> Array:
	var result: Array=[]
	for i in range(5):
		var source: RefCounted=base.host if i<2 else base.branches[i-2]
		var role: String=roles[base.member_ids[i]]
		var cut:=0.25 if i==0 else (0.75 if i==1 else 0.5)
		var direction:=-1.0 if i==0 else 1.0
		var profile: Dictionary=Outer.author(source,role,cut,direction,0 if i==0 else 1)
		result.append({"id":base.member_ids[i],"feature_id":base.descriptor.member_feature_ids[i],"role":role,"profile":profile})
	return result
static func create(node: Dictionary) -> RefCounted:
	if node.get("shape") is Dictionary and node.shape.has("positive_growth206"):
		return load("res://alien_foundry/scripts/geometry/BlobPositiveGrowth206.gd").compile(node)
	var f=load("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd").new()
	if not marked(node) or not descriptor_ok(node.shape[KEY]) or not Group.marked(node) or not node.shape[KEY].version is int or not Outer.typed_equal(node.shape[Group.KEY],node.shape[KEY].base_group): f.error="Invalid203 exact development descriptor."; return f
	var key:=var_to_bytes(node.shape[KEY]).hex_encode()
	if _fields.has(key): return _fields[key]
	f.descriptor=node.shape[KEY].duplicate(true); f.owner_id=f.descriptor.owner_id; f.member_ids=f.descriptor.member_ids.duplicate()
	f.baseline=Group.create({"shape":{Group.KEY:f.descriptor.base_group}})
	if not f.baseline.valid: f.error=f.baseline.error; return f
	var roles: Dictionary={}
	for e: Dictionary in f.descriptor.profile_entries: roles[e.id]=e.role
	if not Outer.typed_equal(make_entries(f.baseline,roles),f.descriptor.profile_entries): f.error="203 profile differs from immutable one-shot role/jet program."; return f
	f.host=Outer.make(f.baseline.host,[f.descriptor.profile_entries[0].profile,f.descriptor.profile_entries[1].profile])
	if not f.host.valid: f.error=f.host.error; f.qualification=f.host.qualification; return f
	f.blend=f.baseline.blend; f.halo=f.baseline.halo; f.support_box=f.host.support_box
	for i in range(3):
		var branch:=Outer.make(f.baseline.branches[i],[f.descriptor.profile_entries[i+2].profile])
		if not branch.valid: f.error=branch.error; f.qualification=branch.qualification; return f
		f.branches.append(branch); f.support_box=Group.merge_bounds(f.support_box,branch.support_box)
	f.qualification=f.qualify(); f.valid=bool(f.qualification.ok); f.error=str(f.qualification.get("error",""))
	if f.valid:
		if _fields.size()>=16: _fields.clear()
		_fields[key]=f
	return f

func sample(point: Vector3,with_weights: bool=true) -> Dictionary:
	if not point.is_finite(): return {"distance":NAN,"weights":[]}
	host_evaluations+=1; geometry_evaluations+=1
	var value: float=host.distance(point)
	var coefficients: Array=[1.0,0.0,0.0,0.0]
	for i in range(3):
		geometry_evaluations+=1
		var other: float=branches[i].distance(point)
		var k: float=branches[i].blend
		var h:=clampf(0.5+0.5*(other-value)/k,0.0,1.0)
		value=lerpf(other,value,h)-k*h*(1.0-h)
		if with_weights:
			for j in range(i+1): coefficients[j]=float(coefficients[j])*h
			coefficients[i+1]=1.0-h
	if not with_weights: return {"distance":value}
	var regional: Vector2=host.weights(point)
	return {"distance":value,"weights":[coefficients[0]*regional.x,coefficients[0]*regional.y,coefficients[1],coefficients[2],coefficients[3]],"carrier_weights":coefficients}
func distance(point: Vector3) -> float:
	return float(sample(point,false).distance) if valid else NAN
func weights(point: Vector3) -> Array:
	return sample(point,true).weights if valid else []
func normal(point: Vector3) -> Vector3:
	if not valid or not point.is_finite(): return Vector3(NAN,NAN,NAN)
	var epsilon: float=NORMAL_RELATIVE_STEP*host.length_scale
	var result:=Vector3(distance(point+Vector3.RIGHT*epsilon)-distance(point-Vector3.RIGHT*epsilon),distance(point+Vector3.UP*epsilon)-distance(point-Vector3.UP*epsilon),distance(point+Vector3.BACK*epsilon)-distance(point-Vector3.BACK*epsilon))
	return result.normalized() if result.is_finite() and result.length_squared()>0.0 else Vector3(NAN,NAN,NAN)
func bounds_for_padding(padding: float) -> AABB:
	return support_box if valid and is_finite(padding) and padding>=0.0 and padding<=halo else AABB(Vector3(NAN,NAN,NAN),Vector3.ZERO)
func fit_bounds() -> AABB:
	var box: AABB=host.fit_bounds()
	for branch: RefCounted in branches: box=Group.merge_bounds(box,branch.fit_bounds())
	return box
func ray_surface(start: Vector3,outward: Vector3,fraction: float=1.0) -> Vector3:
	if not valid or not start.is_finite() or not outward.is_finite() or outward.length_squared()<0.00000001 or not is_finite(fraction) or fraction<0.0 or fraction>1.0 or distance(start)>=0.0: return Vector3(NAN,NAN,NAN)
	var direction:=outward.normalized(); var reach:=fit_bounds().size.length()*2.0
	var low:=0.0; var high:=0.0; var found:=false
	for i in range(1,257):
		high=reach*float(i)/256.0
		var value:=distance(start+direction*high)
		if not is_finite(value): return Vector3(NAN,NAN,NAN)
		if value>=0.0: found=true; break
		low=high
	if not found: return Vector3(NAN,NAN,NAN)
	for i in range(40):
		var mid:=(low+high)*0.5
		if distance(start+direction*mid)>0.0: high=mid
		else: low=mid
	var hit:=start+direction*((low+high)*0.5)
	if absf(distance(hit))>Host.ROUNDING*host.length_scale*8.0: return Vector3(NAN,NAN,NAN)
	return start+(hit-start)*fraction

func qualify() -> Dictionary:
	return preload("res://alien_foundry/scripts/geometry/BlobMassReprofile203Qualification.gd").evaluate(self)
static func scale_descriptor(node: Dictionary,scale: float) -> void:
	if not marked(node): return
	Group.scale_descriptor({"shape":{Group.KEY:node.shape[KEY].base_group}},scale)
	if node.shape.has("positive_growth206"): load("res://alien_foundry/scripts/geometry/BlobPositiveGrowth206.gd").scale_context(node,scale)
static func translate_descriptor(node: Dictionary,delta: Vector3) -> void:
	if not marked(node): return
	Group.translate_descriptor({"shape":{Group.KEY:node.shape[KEY].base_group}},delta)
