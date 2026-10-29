extends RefCounted
## 202: ONE composite body group, not one primitive. Accepted201 core/dominant
## carrier once, then three subordinate replacement sweeps in original order.
## All five biological IDs survive; actual internal smooth-min coefficients
## determine regional ownership. The bounded field is not a global metric SDF.
const Host=preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const Branch=preload("res://alien_foundry/scripts/geometry/BlobBodyBranchField.gd")
const KEY:="body_group202"
const SETTING:="blob_body_group_mode"
const MODE:="branched_body_group_v1"
const OFF:="off"
const PIN:="f22fa92749ca21944fd70f74619573081a48adfe934f6db8350d37d11990f3b4"
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
	if not mode is String or mode not in [OFF,MODE]: return {"error":"Unsupported explicit202 body group mode."}
	if mode==MODE and options.get(Host.SETTING)!=Host.MODE: return {"error":"202 requires the unchanged explicit201 host mode."}
	return {"mode":mode}
static func descriptor_ok(d: Variant) -> bool:
	if not d is Dictionary or d.size()!=10: return false
	if not Host._number(d.get("version")) or float(d.version)!=1.0 or d.get("mode")!=MODE or d.get("pin")!=PIN or d.get("program")!=Branch.BRANCH_PROGRAM: return false
	if not d.get("owner_id") is String or not d.get("member_ids") is Array or d.member_ids.size()!=5 or d.member_ids[0]!=d.owner_id: return false
	if not d.get("member_feature_ids") is Array or d.member_feature_ids.size()!=5: return false
	var seen: Array=[]
	for id: Variant in d.member_ids+d.member_feature_ids:
		if not id is String or id.is_empty() or id in seen: return false
		seen.append(id)
	if not Host.descriptor_ok(d.get("host")) or d.host.owner_id!=d.owner_id or d.host.member_ids!=d.member_ids.slice(0,2) or d.host.member_feature_ids!=d.member_feature_ids.slice(0,2): return false
	if d.get("union_context")!=d.host.union_context or not d.get("branches") is Array or d.branches.size()!=3: return false
	var context_ids: Array=[]
	for entry: Dictionary in d.union_context: context_ids.append(entry.id)
	for id: String in d.member_ids:
		if id not in context_ids: return false
	for i in range(3):
		var branch: Variant=d.branches[i]
		if not Branch.branch_descriptor_ok(branch) or branch.id!=d.member_ids[i+2] or branch.feature_id!=d.member_feature_ids[i+2] or branch.frame.origin!=d.host.frame.origin: return false
	return true
static func validate_declaration(dna: Dictionary) -> Dictionary:
	var choice:=selection(dna.get("settings",{}))
	if choice.has("error"): return {"ok":false,"error":choice.error}
	var nodes: Array=[]
	for n: Variant in dna.get("nodes",[]):
		if n is Dictionary and marked(n): nodes.append(n)
	if choice.mode==OFF: return {"ok":nodes.is_empty(),"error":"202 marker requires explicit mode." if not nodes.is_empty() else ""}
	var bad: Dictionary={"ok":false,"error":"Malformed202 typed body group declaration; metadata is not geometric qualification."}
	if dna.get("type")!="Blob" or int(dna.get("metadata",{}).get("iteration_index",0))<2 or nodes.size()!=5: return bad
	var d: Variant=nodes[0].shape[KEY]
	if not descriptor_ok(d): return bad
	var report: Variant=dna.get("metadata",{}).get(KEY)
	if not report is Dictionary or not Host._number(report.get("version")) or float(report.version)!=1.0 or report.get("mode")!=MODE or report.get("pin")!=PIN or report.get("member_ids")!=d.member_ids or report.get("member_feature_ids")!=d.member_feature_ids: return bad
	for key: String in ["stage","external_group_evaluations","internal_carriers"]:
		if not Host._number(report.get(key)): return bad
	if float(report.stage)!=2.0 or float(report.external_group_evaluations)!=1.0 or float(report.internal_carriers)!=4.0: return bad
	for key: String in ["supports_unchanged","host201_unchanged","finite_witnesses_only","actual_volume_pending","visual_acceptance_pending"]:
		if not report.get(key) is bool or not report[key]: return bad
	if not report.get("anatomical_acceptance") is bool or report.anatomical_acceptance: return bad
	var seen: Array=[]
	for n: Dictionary in nodes:
		if n.shape[KEY]!=d or n.get("id") not in d.member_ids or n.get("kind")!="mass" or n.get("operation","union")!="union" or not Host._number(n.get("noise")) or float(n.noise)!=0.0: return bad
		var index: int=d.member_ids.find(n.id)
		if n.get("feature_id")!=d.member_feature_ids[index] or n.id in seen: return bad
		seen.append(n.id)
		if index<2 and (not Host.marked(n) or n.shape[Host.KEY]!=d.host): return bad
		if index>=2 and (Host.marked(n) or n.get("parent")!=d.owner_id): return bad
	return {"ok":true}
static func validate(dna: Dictionary) -> Dictionary:
	var declared:=validate_declaration(dna)
	if not declared.ok or dna.get("settings",{}).get(SETTING,OFF)==OFF: return declared
	for n: Dictionary in dna.nodes:
		if marked(n):
			var f:=create(n)
			return {"ok":f.valid,"error":f.error,"qualification":f.qualification}
	return {"ok":false,"error":"Missing202 owner."}
static func validate_compilation_context(dna: Dictionary) -> Dictionary:
	if dna.get("settings",{}).get(SETTING,OFF)==OFF: return {"ok":true}
	var nodes: Array=dna.get("nodes",[])
	if nodes.is_empty() or not nodes[0] is Dictionary or not marked(nodes[0]) or not descriptor_ok(nodes[0].shape[KEY]): return {"ok":false,"error":"202 compilation requires a typed first group descriptor."}
	if str(nodes[0].get("id",""))!=str(nodes[0].shape[KEY].owner_id): return {"ok":false,"error":"202 group must be first evaluated union."}
	if Host.union_context(nodes)!=nodes[0].shape[KEY].union_context or not dna.get("modules",[]).is_empty(): return {"ok":false,"error":"202 actual bounded union context changed; downstream extraction unapproved."}
	return {"ok":true}
static func create(node: Dictionary) -> RefCounted:
	var f=load("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd").new()
	if not marked(node) or not descriptor_ok(node.shape[KEY]): f.error="Invalid202 body group descriptor."; return f
	var key:=var_to_bytes(node.shape[KEY]).hex_encode()
	if _fields.has(key): return _fields[key]
	f.descriptor=node.shape[KEY].duplicate(true); f.owner_id=f.descriptor.owner_id; f.member_ids=f.descriptor.member_ids.duplicate()
	f.host=Host.create({"shape":{Host.KEY:f.descriptor.host}})
	if not f.host.valid: f.error=f.host.error; return f
	f.blend=f.host.blend; f.halo=f.host.halo; f.support_box=f.host.support_box
	for d: Dictionary in f.descriptor.branches:
		var exact_blend:=NAN
		for entry: Dictionary in f.descriptor.union_context:
			if entry.id==d.id: exact_blend=float(entry.blend)
		var branch:=Branch.make(d,f.halo,exact_blend)
		if not branch.valid: f.error=branch.error; f.qualification={"ok":false,"branch":d.id,"detail":branch.qualification}; return f
		f.branches.append(branch); f.support_box=merge_bounds(f.support_box,branch.support_box)
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
	for branch: RefCounted in branches: box=merge_bounds(box,branch.fit_bounds())
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
	# Completed by the focused fixed closure/valley helper, never a mesh job.
	return preload("res://alien_foundry/scripts/geometry/BlobBodyGroup202Qualification.gd").evaluate(self)

static func scale_descriptor(node: Dictionary,scale: float) -> void:
	if not marked(node): return
	var d: Dictionary=node.shape[KEY]
	Host.scale_descriptor({"shape":{Host.KEY:d.host}},scale)
	for branch: Dictionary in d.branches:
		branch.frame.origin=Host._arr(Host._vec(branch.frame.origin)*scale)
		branch.frame.length=float(branch.frame.length)*scale
	for entry: Dictionary in d.union_context: entry.blend=float(entry.blend)*scale
static func translate_descriptor(node: Dictionary,delta: Vector3) -> void:
	if not marked(node): return
	var d: Dictionary=node.shape[KEY]
	Host.translate_descriptor({"shape":{Host.KEY:d.host}},delta)
	for branch: Dictionary in d.branches: branch.frame.origin=Host._arr(Host._vec(branch.frame.origin)+delta)


static func merge_bounds(a: AABB,b: AABB) -> AABB:
	var low:=Vector3.ZERO; var high:=Vector3.ZERO; var size:=Vector3.ZERO
	for i in range(3):
		low[i]=minf(a.position[i],b.position[i])
		high[i]=Host.Certificate._out32(maxf(float(a.position[i])+float(a.size[i]),float(b.position[i])+float(b.size[i])),1)
		size[i]=Host.Certificate._out32(Host.Certificate.next64(float(high[i])-float(low[i]),1),1)
	var result:=AABB(low,size)
	for i in range(3):
		if result.end[i]<high[i]: size[i]=Host.Certificate._out32(Host.Certificate.next64(float(size[i]),1),1)
	return AABB(low,size)
