extends RefCounted
## isolated203, fixed whole-mass outer profiles. The sealed base remains the
## actual evaluator on closed protected domains. No coefficient search.
## A failed radial-crown heuristic is reported separately from technical gates.
const C = preload("res://alien_foundry/scripts/geometry/BlobEnvelope201Certificate.gd")
const Q202 = preload("res://alien_foundry/scripts/geometry/BlobBodyGroup202Qualification.gd")
const PIN := "760cc9be7bcdf46153a9e7a2fc4e763b47ff9bb9ed47cb387f3d5f056c769a9b"
const ROUNDING := 128.0 * 0.00000011920928955078125
const U64 := 0.00000000000000011102230246251565
const ROLE_TABLE := {
	"mantle":[1.12,0.42,0.88,1.20,-0.10,-0.16,0.80,0.78,true],
	"swelling":[1.18,0.46,1.04,0.92,-0.16,-0.24,0.62,0.70,false],
	"lateral":[1.15,0.57,0.80,1.12,-0.08,-0.10,0.78,0.74,true],
	"pear":[1.20,0.60,0.86,0.90,-0.12,-0.24,0.55,0.60,false],
	"pad":[1.10,0.54,0.90,1.14,-0.04,-0.04,0.84,0.82,true]
}
const PROFILE_KEYS := ["version","pin","role","cut","direction","old_cap_index","reach","belly","distal_span","join_jets","belly_jets","shoulder","distal_centers","height_taper","breadth_taper"]
static var _certificate_cache: Dictionary = {}
var base: RefCounted
var valid := false
var error := ""
var descriptor: Dictionary = {}
var profile_descriptors: Array = []
var owner_id := ""
var member_ids: Array = []
var origin := Vector3.ZERO
var frame := Basis.IDENTITY
var inverse_frame := Basis.IDENTITY
var length_scale := 1.0
var raw_scale := 0.0
var halo := 0.0
var exterior := 0.0
var p := 0.0
var blend := 0.0
var caps: Array = []
var half_span := 1.0
var midpoint := 0.0
var support_low: Array = []
var support_high: Array = []
var support_box := AABB()
var qualification: Dictionary = {}

static func _float(v: Variant) -> bool:
	return v is float and is_finite(v)
static func _matrix(v: Variant,rows: int,columns: int) -> bool:
	if not v is Array or v.size()!=rows: return false
	for row: Variant in v:
		if not row is Array or row.size()!=columns: return false
		for value: Variant in row:
			if not _float(value): return false
	return true
static func profile_ok(d: Variant) -> bool:
	if not d is Dictionary or d.size()!=PROFILE_KEYS.size(): return false
	for key: String in PROFILE_KEYS:
		if not d.has(key): return false
	if not (d.version is int or d.version is float) or not is_finite(float(d.version)) or float(d.version)!=1.0 or d.pin!=PIN or not d.role is String or not ROLE_TABLE.has(d.role): return false
	if not (d.old_cap_index is int or d.old_cap_index is float) or not is_finite(float(d.old_cap_index)) or float(d.old_cap_index) not in [0.0,1.0]: return false
	for key: String in ["cut","direction","reach","belly","distal_span","height_taper","breadth_taper"]:
		if not _float(d[key]): return false
	if d.direction not in [-1.0,1.0] or d.reach<=0.0 or d.belly<=0.0 or d.distal_span<=0.0 or d.height_taper<=0.0 or d.breadth_taper<=0.0: return false
	return _matrix(d.join_jets,3,5) and _matrix(d.belly_jets,3,5) and _matrix(d.shoulder,5,6) and _matrix(d.distal_centers,2,6)

static func typed_equal(a: Variant,b: Variant) -> bool:
	if typeof(a)!=typeof(b): return false
	if a is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not typed_equal(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not typed_equal(a[i],b[i]): return false
		return true
	if a is float:
		var left:=PackedByteArray(); var right:=PackedByteArray()
		left.resize(8); right.resize(8)
		left.encode_double(0,a); right.encode_double(0,b)
		return left==right
	return var_to_bytes(a)==var_to_bytes(b)

static func _controls(first: Array,last: Array,h: float) -> Array:
	var v0: float=first[0]; var d0: float=first[1]; var dd0: float=first[2]
	var v1: float=last[0]; var d1: float=last[1]; var dd1: float=last[2]
	return [v0,v0+h*d0/5.0,v0+2.0*h*d0/5.0+h*h*dd0/20.0,v1-2.0*h*d1/5.0+h*h*dd1/20.0,v1-h*d1/5.0,v1]
static func author(old: RefCounted,role: String,cut: float,direction: float,old_cap_index: int) -> Dictionary:
	if old==null or not old.valid or not ROLE_TABLE.has(role): return {}
	if (role=="mantle" and (cut!=0.25 or direction!=-1.0 or old_cap_index!=0)) or (role=="swelling" and (cut!=0.75 or direction!=1.0 or old_cap_index!=1)) or (role in ["lateral","pear","pad"] and (cut!=0.5 or direction!=1.0 or old_cap_index!=1)): return {}
	var row: Array=ROLE_TABLE[role]
	var h: float=old.caps[old_cap_index][1]; var b: float=old.caps[old_cap_index][2]
	var old_tip: float=-float(old.caps[0][0]) if old_cap_index==0 else 1.0+float(old.caps[1][0])
	var reach: float=float(row[0])*direction*(old_tip-cut)
	var belly: float=float(row[1])*reach; var distal: float=reach-belly
	if not is_finite(distal) or distal<=0.0: return {}
	var join: Array=[]
	# complete_section returns actual Vector4 binary32 values, not ideal jets.
	for order in range(3):
		var section: Vector4=old.complete_section(cut,order)
		var sign_value: float=direction if order==1 else 1.0
		join.append([(section.x+section.y)*0.5*sign_value,(section.z+section.w)*0.5*sign_value,(section.z-section.w)*0.5*sign_value,(section.x-section.y)*0.5*sign_value])
	var t: float=(cut-old.midpoint)/old.half_span
	join[0].append(1.0-t*t)
	join[1].append(-2.0*(cut-old.midpoint)/(old.half_span*old.half_span)*direction)
	join[2].append(-2.0/(old.half_span*old.half_span))
	var a1: float=h*float(row[2]); var b1: float=b*float(row[3])
	var belly_jets: Array=[[a1,b1,0.0,h*float(row[4]),1.0],[0.0,0.0,0.0,0.0,0.0],[-a1/(distal*distal),-b1/(distal*distal),0.0,-a1/(distal*distal) if bool(row[8]) else 0.0,-2.0/(distal*distal)]]
	var shoulder: Array=[]
	for channel in range(5):
		shoulder.append(_controls([join[0][channel],join[1][channel],join[2][channel]],[belly_jets[0][channel],belly_jets[1][channel],belly_jets[2][channel]],belly))
	var centers: Array=[]
	for channel in [2,3]:
		centers.append(_controls([belly_jets[0][channel],belly_jets[1][channel],belly_jets[2][channel]],[0.0 if channel==2 else h*float(row[5]),0.0,0.0],distal))
	return {"version":1,"pin":PIN,"role":role,"cut":cut,"direction":direction,"old_cap_index":old_cap_index,"reach":reach,"belly":belly,"distal_span":distal,"join_jets":join,"belly_jets":belly_jets,"shoulder":shoulder,"distal_centers":centers,"height_taper":float(row[6]),"breadth_taper":float(row[7])}

static func bernstein(values: Array,t: float,derivative: int=0) -> float:
	var c: Array=values.duplicate()
	for order in range(derivative):
		var degree: int=c.size()-1; var next: Array=[]
		for i in range(degree): next.append(float(degree)*(float(c[i+1])-float(c[i])))
		c=next
	for degree in range(c.size()-1,0,-1):
		for i in range(degree): c[i]=(1.0-t)*float(c[i])+t*float(c[i+1])
	return float(c[0])
static func _parameter(s: float,span: float) -> float:
	# No empirical clamps or altered profile endpoints.
	if s==0.0: return 0.0
	if s==span: return 1.0
	return s/span
static func profile_channels(d: Dictionary,s: float) -> Dictionary:
	var values: Array=[]; var first: Array=[]
	if s<=float(d.belly):
		var t: float=_parameter(s,float(d.belly))
		for c: Array in d.shoulder:
			values.append(bernstein(c,t)); first.append(bernstein(c,t,1)/float(d.belly))
		return {"values":values,"first":first,"piece":"shoulder"}
	var span: float=d.distal_span; var w: float=(s-float(d.belly))/span
	var D: float=1.0-w*w; var dD: float=-2.0*w/span
	var centers: Array=[]; var dc: Array=[]
	for c: Array in d.distal_centers:
		centers.append(float(c[5]) if w>=1.0 else bernstein(c,w))
		dc.append(0.0 if w>=1.0 else bernstein(c,w,1)/span)
	var smoother: float=1.0 if w>=1.0 else w*w*w*(10.0-15.0*w+6.0*w*w)
	var ds: float=0.0 if w>=1.0 else 30.0*w*w*(1.0-w)*(1.0-w)/span
	var ta: float=1.0+(float(d.height_taper)-1.0)*smoother
	var tb: float=1.0+(float(d.breadth_taper)-1.0)*smoother
	var a: float=d.belly_jets[0][0]; var b: float=d.belly_jets[0][1]
	var U: float=b*b*tb*tb; var V: float=a*a*ta*ta
	return {"U":U,"V":V,"dU":2.0*b*b*tb*(float(d.breadth_taper)-1.0)*ds,"dV":2.0*a*a*ta*(float(d.height_taper)-1.0)*ds,"D":D,"dD":dD,"cx":centers[0],"cy":centers[1],"dcx":dc[0],"dcy":dc[1],"piece":"beyond_pole" if w>1.0 else "distal"}
static func profile_coefficients(d: Dictionary,s: float) -> Dictionary:
	var q: Dictionary=profile_channels(d,s)
	if q.piece=="shoulder":
		var v: Array=q["values"]; var j: Array=q.first
		var a: float=v[0]; var b: float=v[1]; var D: float=v[4]
		return {"px":D/(b*b),"py":D/(a*a),"dx":float(j[4])/(b*b)-2.0*D*float(j[1])/(b*b*b),"dy":float(j[4])/(a*a)-2.0*D*float(j[0])/(a*a*a),"cx":v[2],"cy":v[3],"dcx":j[2],"dcy":j[3],"D":D,"dD":j[4]}
	return {"px":1.0/float(q.U),"py":1.0/float(q.V),"dx":-float(q.dU)/(float(q.U)*float(q.U)),"dy":-float(q.dV)/(float(q.V)*float(q.V)),"cx":q.cx,"cy":q.cy,"dcx":q.dcx,"dcy":q.dcy,"D":q.D,"dD":q.dD}

static func make(old: RefCounted,profiles: Array) -> RefCounted:
	var f=load("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd").new()
	f.base=old
	if old==null or not old.valid or profiles.size() not in [1,2]: f.error="203 requires qualified unchanged base and one branch or two host profiles."; return f
	for d: Variant in profiles:
		if not profile_ok(d) or not typed_equal(d,author(old,d.role,d.cut,d.direction,int(d.old_cap_index))): f.error="203 malformed or noncanonical fixed outer-profile descriptor."; return f
	if profiles.size()==2:
		if profiles[0].role!="mantle" or profiles[1].role!="swelling" or old.member_ids.size()!=2: f.error="203 host must have ordered mantle and swelling profiles."; return f
	elif profiles[0].role not in ["lateral","pear","pad"] or old.member_ids.size()!=1:
		f.error="203 branch must have exactly its authored subordinate role."; return f
	f.profile_descriptors=profiles.duplicate(true)
	f.descriptor={"version":1,"pin":PIN,"base":old.descriptor.duplicate(true),"profiles":profiles.duplicate(true)}
	f.owner_id=old.owner_id; f.member_ids=old.member_ids.duplicate()
	f.origin=old.origin; f.frame=old.frame; f.inverse_frame=old.inverse_frame; f.length_scale=old.length_scale
	f.raw_scale=old.raw_scale; f.halo=old.halo; f.exterior=old.exterior; f.p=old.p; f.blend=old.blend
	f.caps=old.caps.duplicate(true); f.half_span=old.half_span; f.midpoint=old.midpoint
	# Complete typed profiles plus complete actual original union context/scales.
	var key: String=var_to_bytes([f.descriptor,f.raw_scale,f.halo,f.exterior,f.p,f.blend,old.support_low,old.support_high]).hex_encode()
	if _certificate_cache.has(key):
		var saved: Dictionary=_certificate_cache[key]
		f.qualification=saved.qualification.duplicate(true); f.support_low=saved.low.duplicate(); f.support_high=saved.high.duplicate(); f.support_box=saved.box
	else:
		f.qualification=f.qualify()
		if f.qualification.ok:
			if _certificate_cache.size()>=16: _certificate_cache.clear()
			_certificate_cache[key]={"qualification":f.qualification.duplicate(true),"low":f.support_low.duplicate(),"high":f.support_high.duplicate(),"box":f.support_box}
	f.valid=bool(f.qualification.ok); f.error=str(f.qualification.get("error",""))
	return f

func _profile_for_z(z: float) -> Dictionary:
	for d: Dictionary in profile_descriptors:
		if (float(d.direction)<0.0 and z<float(d.cut)) or (float(d.direction)>0.0 and z>float(d.cut)): return d
	return {}
func _local(point: Vector3) -> Vector3:
	return inverse_frame*(point-origin)/length_scale
func _outside_support(point: Vector3) -> bool:
	var q: Vector3=_local(point)
	if not q.is_finite(): return true
	for axis in range(3):
		if float(q[axis])<float(support_low[axis]) or float(q[axis])>float(support_high[axis]): return true
	return false
func _outer_raw(point: Vector3,d: Dictionary) -> Vector4:
	var local: Vector3=_local(point)
	var direction: float=d.direction; var s: float=direction*(float(local.z)-float(d.cut))
	var c: Dictionary=profile_coefficients(d,s)
	var x: float=float(local.x)-float(c.cx); var y: float=float(local.y)-float(c.cy)
	var gx: float=float(c.px)*x; var gy: float=float(c.py)*y
	var gs: float=(float(c.dx)*x*x+float(c.dy)*y*y-float(c.dD))*0.5-float(c.px)*x*float(c.dcx)-float(c.py)*y*float(c.dcy)
	var gradient: Vector3=inverse_frame.transposed()*Vector3(gx,gy,direction*gs)*(raw_scale/length_scale)
	return Vector4(gradient.x,gradient.y,gradient.z,raw_scale*0.5*(float(c.px)*x*x+float(c.py)*y*y-float(c.D)))
func raw_value_gradient(point: Vector3) -> Vector4:
	var d: Dictionary=_profile_for_z(_local(point).z)
	if d.is_empty(): return base.raw_value_gradient(point)
	return _outer_raw(point,d)
func distance(point: Vector3) -> float:
	if not valid or not point.is_finite(): return NAN
	if _profile_for_z(_local(point).z).is_empty(): return base.distance(point)
	if _outside_support(point): return exterior
	var value: Vector4=raw_value_gradient(point); var raw: float=value.w
	if not is_finite(raw): return NAN
	if absf(raw)>=2.0*p: return raw
	var gradient: float=Vector3(value.x,value.y,value.z).length()
	if not is_finite(gradient) or gradient<=0.000000000001: return NAN
	var x: float=clampf((absf(raw)-p)/p,0.0,1.0)
	var w: float=1.0-x*x*(3.0-2.0*x)
	return raw*((1.0-w)+w/gradient)
func normal(point: Vector3) -> Vector3:
	if not valid or not point.is_finite(): return Vector3.ZERO
	if _profile_for_z(_local(point).z).is_empty(): return base.normal(point)
	if _outside_support(point): return Vector3.ZERO
	var value: Vector4=raw_value_gradient(point)
	return Vector3(value.x,value.y,value.z).normalized()
func weights(point: Vector3) -> Vector2:
	return base.weights(point)
func local_surface(z: float,angle: float) -> Vector3:
	var d: Dictionary=_profile_for_z(z)
	if d.is_empty(): return base.local_surface(z,angle)
	var s: float=float(d.direction)*(z-float(d.cut)); var q: Dictionary=profile_channels(d,s)
	if q.piece=="shoulder":
		return Vector3(float(q["values"][2])+float(q["values"][1])*cos(angle),float(q["values"][3])+float(q["values"][0])*sin(angle),z)
	return Vector3(float(q.cx)+sqrt(maxf(0.0,float(q.D)*float(q.U)))*cos(angle),float(q.cy)+sqrt(maxf(0.0,float(q.D)*float(q.V)))*sin(angle),z)
func surface(z: float,angle: float) -> Vector3:
	if _profile_for_z(z).is_empty(): return base.surface(z,angle)
	return origin+frame*local_surface(z,angle)*length_scale
func fit_bounds() -> AABB:
	# Conservative by design; no boundary shrink or mesh-resolution adaptation.
	return support_box
func bounds_for_padding(padding: float) -> AABB:
	if not valid or not is_finite(padding) or padding<0.0 or padding>halo: return AABB(Vector3(NAN,NAN,NAN),Vector3.ZERO)
	return support_box
func axial_breakpoints() -> Array:
	var result: Array=[0.0,0.5,1.0]
	for d: Dictionary in profile_descriptors:
		for s: float in [0.0,float(d.belly),float(d.reach)]:
			var z: float=float(d.cut)+float(d.direction)*s
			if not z in result: result.append(z)
	result.sort(); return result

static func _control_hull(c: Array) -> Array:
	# Fifteen degree5 de Casteljau nodes, each with subtraction, two
	# multiplications and addition: fixed gamma60 binary64 allowance.
	var magnitude: float=maxf(absf(float(c.min())),absf(float(c.max())))
	var gamma60: float=C.div(C.point(60.0*U64),C.sub(C.point(1.0),C.point(60.0*U64)))[1]
	var allowance: float=C.mul(C.point(gamma60),C.point(magnitude))[1]
	return C.add([float(c.min()),float(c.max())],[-allowance,allowance])
static func _taper_hull(tip: float) -> Array:
	# Fixed smootherstep expression has coefficient absolute sum31 and
	# fewer than24 scalar operations including formation of the taper.
	var gamma24: float=C.div(C.point(24.0*U64),C.sub(C.point(1.0),C.point(24.0*U64)))[1]
	var allowance: float=C.mul(C.point(gamma24),C.point(1.0+31.0*absf(tip-1.0)))[1]
	return C.add([minf(1.0,tip),maxf(1.0,tip)],[-allowance,allowance])
func _outer_support(d: Dictionary) -> Dictionary:
	var hulls: Array=[]
	for controls: Array in d.shoulder: hulls.append(_control_hull(controls))
	for channel in [0,1,4]:
		if not C.finite(hulls[channel]) or hulls[channel][0]<=0.0: return {"ok":false,"reason":"Fixed shoulder positive control hull rejected."}
	var th: Array=_taper_hull(float(d.height_taper)); var tb: Array=_taper_hull(float(d.breadth_taper))
	if th[0]<=0.0 or tb[0]<=0.0: return {"ok":false,"reason":"Fixed distal taper hull rejected."}
	var shoulder_px: Array=C.div(hulls[4],C.square(hulls[1])); var shoulder_py: Array=C.div(hulls[4],C.square(hulls[0]))
	var distal_U: Array=C.mul(C.mul(C.point(float(d.belly_jets[0][1])*float(d.belly_jets[0][1])),tb),tb)
	var distal_V: Array=C.mul(C.mul(C.point(float(d.belly_jets[0][0])*float(d.belly_jets[0][0])),th),th)
	var distal_px: Array=C.div(C.point(1.0),distal_U); var distal_py: Array=C.div(C.point(1.0),distal_V)
	var cx: Array=_control_hull(d.distal_centers[0]); var cy: Array=_control_hull(d.distal_centers[1])
	var pieces: Array=[{"px":shoulder_px,"py":shoulder_py,"cx":hulls[2],"cy":hulls[3],"Dmax":hulls[4][1]},{"px":distal_px,"py":distal_py,"cx":cx,"cy":cy,"Dmax":1.0}]
	var margin: float=0.25*p/length_scale
	var low: Array=[INF,INF,0.0]; var high: Array=[-INF,-INF,0.0]
	for piece: Dictionary in pieces:
		for axis in range(2):
			var coefficient: Array=piece.px if axis==0 else piece.py
			var center: Array=piece.cx if axis==0 else piece.cy
			if coefficient[0]<=0.0 or not C.finite(coefficient): return {"ok":false,"reason":"Fixed positive outer coefficient enclosure rejected."}
			var radial_squared: Array=C.div(C.add(C.point(float(piece.Dmax)),C.div(C.point(2.0*halo),C.point(raw_scale))),C.point(float(coefficient[0])))
			var radius: float=C.next64(sqrt(radial_squared[1]),1)
			low[axis]=minf(float(low[axis]),C.sub(C.sub(C.point(float(center[0])),C.point(radius)),C.point(margin))[0])
			high[axis]=maxf(float(high[axis]),C.add(C.add(C.point(float(center[1])),C.point(radius)),C.point(margin))[1])
	var wfar: float=C.next64(sqrt(C.add(C.point(1.0),C.div(C.point(2.0*halo),C.point(raw_scale)))[1]),1)
	var sfar: float=C.add(C.add(C.point(float(d.belly)),C.mul(C.point(float(d.distal_span)),C.point(wfar))),C.point(margin))[1]
	var zfar: Array=C.add(C.point(float(d.cut)),C.mul(C.point(float(d.direction)),C.point(sfar)))
	low[2]=zfar[0] if float(d.direction)<0.0 else float(d.cut)
	high[2]=float(d.cut) if float(d.direction)<0.0 else zfar[1]
	var minima: Array=[INF,INF,INF,INF]
	for piece: Dictionary in pieces:
		for face in range(4):
			var axis: int=0 if face<2 else 1
			var center: Array=piece.cx if axis==0 else piece.cy
			var coefficient: Array=piece.px if axis==0 else piece.py
			var coord: float=low[axis] if face%2==0 else high[axis]
			var delta: Array=C.sub(C.point(coord),center)
			# Other transverse term is nonnegative; match px*x*x ordering.
			var transverse: Array=C.mul(C.mul(coefficient,delta),delta)
			var raw: Array=C.round32(C.mul(C.point(raw_scale*0.5),C.sub(transverse,C.point(float(piece.Dmax)))))
			minima[face]=minf(float(minima[face]),float(raw[0]))
	var far: float=low[2] if float(d.direction)<0.0 else high[2]
	var ss: Array=C.mul(C.point(float(d.direction)),C.sub(C.point(far),C.point(float(d.cut))))
	var ww: Array=C.div(C.sub(ss,C.point(float(d.belly))),C.point(float(d.distal_span)))
	var axial: Array=C.round32(C.mul(C.point(raw_scale*0.5),C.sub(C.square(ww),C.point(1.0))))
	var critical_raw: Array=C.round32(C.mul(C.point(-raw_scale*0.5),hulls[4]))
	return {"ok":float(minima.min())>halo and axial[0]>halo and critical_raw[1]<-2.0*p,"low":low,"high":high,"face_lower_bounds":minima,"far_axial_lower":axial[0],"required_halo":halo,"critical_raw_upper":critical_raw[1],"calibration_band_outer":2.0*p,"shoulder_control_hulls":hulls,"distal_taper_hulls":[th,tb],"shoulder_Umax":C.div(C.square(hulls[1]),hulls[4])[1],"shoulder_Vmax":C.div(C.square(hulls[0]),hulls[4])[1],"distal_Umax":distal_U[1],"distal_Vmax":distal_V[1],"fixed_margin":margin,"de_casteljau_operation_count":60,"includes_vector4_binary32_rounding":true,"reason":"" if float(minima.min())>halo and axial[0]>halo and critical_raw[1]<-2.0*p else "Fixed outer boundary or critical-region enclosure rejected; no fallback."}

func _join_report(d: Dictionary) -> Dictionary:
	var residuals: Array=[]; var jet_ok:=true
	for endpoint in range(2):
		var expected: Array=d.join_jets if endpoint==0 else d.belly_jets
		for order in range(3):
			for channel in range(5):
				var actual: float=bernstein(d.shoulder[channel],float(endpoint),order)/pow(float(d.belly),order)
				var frozen: float=expected[order][channel]
				var residual: float=absf(actual-frozen)
				var tolerance: float=128.0*C.U32*maxf(1.0,absf(frozen))
				jet_ok=jet_ok and residual<=tolerance
				residuals.append({"endpoint":endpoint,"order":order,"channel":channel,"new":actual,"frozen":frozen,"residual":residual,"spatial_precision_reference":tolerance})
	var raw_residual:=0.0; var gradient_residual:=0.0; var old_gradient_max:=1.0
	for angular in range(16):
		var point: Vector3=base.surface(float(d.cut),TAU*float(angular)/16.0)
		var old_value: Vector4=base.raw_value_gradient(point)
		var new_value: Vector4=_outer_raw(point,d)
		raw_residual=maxf(raw_residual,absf(float(old_value.w)-float(new_value.w)))
		var old_g:=Vector3(old_value.x,old_value.y,old_value.z); var new_g:=Vector3(new_value.x,new_value.y,new_value.z)
		gradient_residual=maxf(gradient_residual,float((old_g-new_g).length())); old_gradient_max=maxf(old_gradient_max,float(old_g.length()))
	var raw_tolerance: float=128.0*C.U32*maxf(1.0,raw_scale)
	var gradient_tolerance: float=128.0*C.U32*maxf(old_gradient_max,raw_scale/length_scale)
	return {"ok":jet_ok and raw_residual<=raw_tolerance and gradient_residual<=gradient_tolerance,"frozen_section_return":"actual binary32 Vector4 complete_section jets","jet_residuals":residuals,"fixed_world_join_witnesses":16,"actual_raw_residual":raw_residual,"actual_gradient_residual":gradient_residual,"raw_spatial_precision_reference":raw_tolerance,"gradient_spatial_precision_reference":gradient_tolerance,"symbolic_identity_claimed":false,"boundary_world_points_may_round_outside_protected_z":true}

static func _shape_diagnostic(d: Dictionary) -> Dictionary:
	var samples: Array=[]; var negative: Dictionary={"a":[],"b":[]}; var finite_profile:=true
	var span: float=d.belly
	var max_extent: float=maxf(1.0,maxf(float(d.shoulder[0].max()),float(d.shoulder[1].max())))
	var tolerance: float=128.0*C.U32*max_extent/span
	for piece in range(2):
		for i in range(65):
			var t: float=float(i)/64.0
			var s: float=t*span if piece==0 else span+t*float(d.distal_span)
			var channels: Dictionary=profile_channels(d,s)
			var a: float; var b: float; var cx: float; var cy: float; var D: float
			var da: Variant=null; var db: Variant=null
			if piece==0:
				a=channels["values"][0]; b=channels["values"][1]; cx=channels["values"][2]; cy=channels["values"][3]; D=channels["values"][4]
				da=channels.first[0]; db=channels.first[1]
				if da < -tolerance: negative.a.append({"sample":i,"s":s,"derivative":da})
				if db < -tolerance: negative.b.append({"sample":i,"s":s,"derivative":db})
			else:
				# At shared belly profile_channels takes the identical shoulder jets.
				if channels.piece=="shoulder":
					a=channels["values"][0]; b=channels["values"][1]; cx=channels["values"][2]; cy=channels["values"][3]; D=channels["values"][4]; da=channels.first[0]; db=channels.first[1]
				else:
					D=channels.D; a=sqrt(maxf(0.0,D*float(channels.V))); b=sqrt(maxf(0.0,D*float(channels.U))); cx=channels.cx; cy=channels.cy
					if D>0.0:
						da=(float(channels.dD)*float(channels.V)+D*float(channels.dV))/(2.0*a)
						db=(float(channels.dD)*float(channels.U)+D*float(channels.dU))/(2.0*b)
			for value: float in [a,b,cx,cy,D]: finite_profile=finite_profile and is_finite(value)
			samples.append({"piece":"shoulder" if piece==0 else "distal","sample":i,"s":s,"z":float(d.cut)+float(d.direction)*s,"a":a,"b":b,"D":D,"centerline":[cx,cy],"upper":cy+a,"lower":cy-a,"front":cx+b,"back":cx-b,"da":da,"db":db})
	return {"role":d.role,"finite_profile":finite_profile,"samples_per_piece":65,"samples":samples,"derivative_tolerance":tolerance,"negative_shoulder_derivative_witnesses":negative,"crown_heuristic_pass":negative.a.is_empty() and negative.b.is_empty(),"crown_is_separate_aesthetic_diagnostic":true,"finite_witnesses_only":true,"global_shape_proof_claimed":false}

func qualify() -> Dictionary:
	if not is_finite(halo) or not is_finite(p) or not is_finite(raw_scale) or halo<2.0*p or p<=0.0 or raw_scale<=0.0: return {"ok":false,"error":"203 invalid unchanged raw/calibration/union context."}
	support_low=base.support_low.duplicate(); support_high=base.support_high.duplicate()
	if profile_descriptors.size()==2:
		support_low[2]=0.25; support_high[2]=0.75
	else: support_high[2]=0.5
	var numerical: Array=[]; var diagnostics: Array=[]; var crown_pass:=true
	for d: Dictionary in profile_descriptors:
		var bounds: Dictionary=_outer_support(d)
		if not bounds.ok: return {"ok":false,"error":"203 fixed positive support/critical-region certificate failed.","numerical":bounds}
		numerical.append(bounds)
		for axis in range(3):
			support_low[axis]=minf(float(support_low[axis]),float(bounds.low[axis])); support_high[axis]=maxf(float(support_high[axis]),float(bounds.high[axis]))
		var diagnostic: Dictionary=_shape_diagnostic(d)
		diagnostic["joins"]=_join_report(d)
		if not diagnostic.finite_profile or not diagnostic.joins.ok: return {"ok":false,"error":"203 fixed finite-profile or actual spatial join check failed.","profile_diagnostics":[diagnostic]}
		crown_pass=crown_pass and bool(diagnostic.crown_heuristic_pass); diagnostics.append(diagnostic)
	var preimage: Dictionary=C.preimage_box(self,support_low,support_high)
	if not preimage.ok: return {"ok":false,"error":"203 actual binary32 preimage enclosure failed.","numerical":preimage}
	support_box=preimage.box; preimage.erase("box")
	return {"ok":true,"profile_diagnostics":diagnostics,"crown_heuristic_pass":crown_pass,"crown_is_separate_aesthetic_diagnostic":true,"numerical":{"profiles":numerical,"preimage":preimage,"support_low":support_low,"support_high":support_high,"halo":halo,"exterior":exterior,"protected_old_bounds_reused":true},"protected_actual_old_call_path":true,"regular_implicit_poles":true,"positive_elliptical_sections":true,"global_metric_sdf":false,"root_burial_pending":true,"artistic_acceptance":false}

static func _bernstein_interval(c: Array,t: Array) -> Array:
	var values: Array=[]
	for coefficient: float in c: values.append(C.point(coefficient))
	for degree in range(values.size()-1,0,-1):
		for i in range(degree): values[i]=C.add(C.mul(C.sub(C.point(1.0),t),values[i]),C.mul(t,values[i+1]))
	return values[0]
static func _intersection(a: Array,b: Array) -> Array:
	return [maxf(float(a[0]),float(b[0])),minf(float(a[1]),float(b[1]))]
static func _hull(a: Array,b: Array) -> Array:
	return [minf(float(a[0]),float(b[0])),maxf(float(a[1]),float(b[1]))]
func _outer_raw_interval_piece(d: Dictionary,low: Array,high: Array,s: Array,shoulder: bool) -> Array:
	var px: Array; var py: Array; var cx: Array; var cy: Array; var D: Array
	if shoulder:
		var t: Array=C.div(s,C.point(float(d.belly)))
		t=_intersection(t,[0.0,1.0])
		var channels: Array=[]
		for controls: Array in d.shoulder: channels.append(_intersection(_bernstein_interval(controls,t),_control_hull(controls)))
		D=channels[4]; px=C.div(D,C.square(channels[1])); py=C.div(D,C.square(channels[0])); cx=channels[2]; cy=channels[3]
	else:
		var w: Array=C.div(C.sub(s,C.point(float(d.belly))),C.point(float(d.distal_span)))
		D=C.sub(C.point(1.0),C.square(w))
		# Actual beyond-pole path uses exact constant tip centers/tapers.
		var wc: Array=[clampf(float(w[0]),0.0,1.0),clampf(float(w[1]),0.0,1.0)]
		cx=_intersection(_bernstein_interval(d.distal_centers[0],wc),_control_hull(d.distal_centers[0]))
		cy=_intersection(_bernstein_interval(d.distal_centers[1],wc),_control_hull(d.distal_centers[1]))
		var smooth: Array=C.mul(C.mul(C.mul(wc,wc),wc),C.add(C.sub(C.point(10.0),C.mul(C.point(15.0),wc)),C.mul(C.mul(C.point(6.0),wc),wc)))
		var ta: Array=_intersection(C.add(C.point(1.0),C.mul(C.point(float(d.height_taper)-1.0),smooth)),_taper_hull(float(d.height_taper)))
		var tb: Array=_intersection(C.add(C.point(1.0),C.mul(C.point(float(d.breadth_taper)-1.0),smooth)),_taper_hull(float(d.breadth_taper)))
		var a: float=d.belly_jets[0][0]; var b: float=d.belly_jets[0][1]
		# Exact scalar evaluator order: b*b*tb*tb and a*a*ta*ta.
		var U: Array=C.mul(C.mul(C.point(b*b),tb),tb); var V: Array=C.mul(C.mul(C.point(a*a),ta),ta)
		px=C.div(C.point(1.0),U); py=C.div(C.point(1.0),V)
	if not C.finite(px) or not C.finite(py) or px[0]<=0.0 or py[0]<=0.0 or not C.finite(D): return [-INF,INF]
	var x: Array=C.sub([low[0],high[0]],cx); var y: Array=C.sub([low[1],high[1]],cy)
	return C.round32(C.mul(C.point(raw_scale*0.5),C.sub(C.add(C.mul(C.mul(px,x),x),C.mul(C.mul(py,y),y)),D)))
func _outer_raw_interval(d: Dictionary,low: Array,high: Array,z: Array) -> Array:
	var s: Array=C.mul(C.point(float(d.direction)),C.sub(z,C.point(float(d.cut))))
	var result: Array=[INF,-INF]
	if s[0]<=float(d.belly):
		var domain: Array=[maxf(0.0,float(s[0])),minf(float(d.belly),float(s[1]))]
		if domain[0]<=domain[1]: result=_hull(result,_outer_raw_interval_piece(d,low,high,domain,true))
	if s[1]>=float(d.belly):
		var domain: Array=[maxf(float(d.belly),float(s[0])),float(s[1])]
		if domain[0]<=domain[1]: result=_hull(result,_outer_raw_interval_piece(d,low,high,domain,false))
	return result
func _old_raw_interval(low: Array,high: Array,z: Array) -> Array:
	var piece: int=0 if z[1]<=0.0 else (3 if z[0]>=1.0 else (1 if z[1]<=0.5 else 2))
	if not base.descriptor.has("controls") or piece==0 or piece==3: return Q202._raw_interval(base,low,high,z,piece)
	# Branch protected inner Bernstein profile uses actual Vector4 rounding.
	var t: Array=C.div(C.sub(z,C.point(base.midpoint)),C.point(base.half_span))
	var values: Array=[]
	for controls: Array in base.profiles: values.append(C.round32(_bernstein_interval(controls,[maxf(0.0,float(z[0])),minf(1.0,float(z[1]))])))
	var a: Array=C.mul(C.add(values[0],values[1]),C.point(0.5)); var b: Array=C.mul(C.add(values[2],values[3]),C.point(0.5))
	var cx: Array=C.mul(C.sub(values[2],values[3]),C.point(0.5)); var cy: Array=C.mul(C.sub(values[0],values[1]),C.point(0.5))
	var q: Array=C.sub(C.point(1.0),C.mul(t,t))
	var px: Array=C.div(q,C.mul(b,b)); var py: Array=C.div(q,C.mul(a,a))
	if not C.finite(px) or not C.finite(py) or px[0]<=0.0 or py[0]<=0.0: return [-INF,INF]
	var x: Array=C.sub([low[0],high[0]],cx); var y: Array=C.sub([low[1],high[1]],cy)
	return C.round32(C.mul(C.point(raw_scale*0.5),C.sub(C.add(C.add(C.square(t),C.mul(C.mul(px,x),x)),C.mul(C.mul(py,y),y)),C.point(1.0))))
func raw_local_interval(low: Array,high: Array,z: Array) -> Array:
	if low.size()!=3 or high.size()!=3 or z.size()!=2 or not C.finite(z): return [-INF,INF]
	var cuts: Array=[float(z[0])]
	for split: float in axial_breakpoints():
		if split>float(z[0]) and split<float(z[1]): cuts.append(split)
	if float(z[1])!=float(z[0]): cuts.append(float(z[1]))
	cuts.sort()
	var result: Array=[INF,-INF]
	for i in range(cuts.size()-1):
		var zz: Array=[cuts[i],cuts[i+1]]
		var d: Dictionary=_profile_for_z((float(zz[0])+float(zz[1]))*0.5)
		var enclosure: Array=_old_raw_interval(low,high,zz) if d.is_empty() else _outer_raw_interval(d,low,high,zz)
		result=_hull(result,enclosure)
	# Include exact dispatch at all split endpoints, especially protected cuts.
	for value: float in cuts:
		var d: Dictionary=_profile_for_z(value)
		var enclosure: Array=_old_raw_interval(low,high,[value,value]) if d.is_empty() else _outer_raw_interval(d,low,high,[value,value])
		result=_hull(result,enclosure)
	return result
