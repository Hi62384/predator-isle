extends "res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd"
## 202 subordinate replacement sweep. The unchanged201 evaluator supplies the
## capped-section raw field, calibration and query operations. Only complete
## section profiles and their certificates differ. No duplicate core carrier.
## Proximal closure is C1, not C2, and must qualify as wholly buried.
const BranchCertificate = preload("res://alien_foundry/scripts/geometry/BlobBranch202Certificate.gd")
const BRANCH_PROGRAM := [0.45,0.78,0.74,0.62]
const ROOT_P_MULTIPLIER := 3.0

static func controls(cap_values: Array) -> Array:
	var out: Array=[]
	var root: float=cap_values[0][0]
	var radius: float=cap_values[1][0]
	for i in range(4):
		var end: float=cap_values[1][1 if i<2 else 2]
		var c3:=end*(1.0-1.0/(20.0*radius*radius))
		var c2:=root+float(BRANCH_PROGRAM[i])*(c3-root)
		out.append([root,root,c2,c3,end,end])
	return out

static func bernstein(values: Array,t: float,derivative: int=0) -> float:
	var c:=values.duplicate()
	for order in range(derivative):
		var degree:=c.size()-1
		var d: Array=[]
		for i in range(degree): d.append(float(degree)*(float(c[i+1])-float(c[i])))
		c=d
	for degree in range(c.size()-1,0,-1):
		for i in range(degree): c[i]=(1.0-t)*float(c[i])+t*float(c[i+1])
	return float(c[0])

static func branch_descriptor_ok(d: Variant) -> bool:
	if not d is Dictionary or d.size()!=7: return false
	if not d.get("id") is String or d.id.is_empty() or not d.get("feature_id") is String or d.feature_id.is_empty(): return false
	var f: Variant=d.get("frame")
	if not f is Dictionary or f.size()!=5: return false
	for key: String in ["origin","u","v","n"]:
		if not _vector(f.get(key)): return false
	if not _number(f.get("length")) or float(f.length)<=0.000001: return false
	var basis:=Basis(_vec(f.u),_vec(f.v),_vec(f.n))
	if not is_finite(basis.determinant()) or absf(basis.determinant()-1.0)>0.00001: return false
	for axis: Vector3 in [basis.x,basis.y,basis.z]:
		if absf(axis.length_squared()-1.0)>0.00001: return false
	if not d.get("caps") is Array or d.caps.size()!=2: return false
	for cap: Variant in d.caps:
		if not _vector(cap): return false
		for value: Variant in cap:
			if float(value)<=0.000001: return false
	if not _number(d.get("blend_ratio")) or float(d.blend_ratio)*float(f.length)<0.001: return false
	if d.get("program")!=BRANCH_PROGRAM: return false
	if not d.get("controls") is Array or d.controls.size()!=4: return false
	for row: Variant in d.controls:
		if not row is Array or row.size()!=6: return false
		for value: Variant in row:
			if not _number(value): return false
	return true

static func make(d: Dictionary,union_halo: float,exact_blend: float) -> RefCounted:
	var f=load("res://alien_foundry/scripts/geometry/BlobBodyBranchField.gd").new()
	if not branch_descriptor_ok(d) or not is_finite(union_halo) or not is_finite(exact_blend) or union_halo<=0.0 or exact_blend<0.001: f.error="Malformed202 branch descriptor or exact union blend."; return f
	f.descriptor=d.duplicate(true); f.owner_id=d.id; f.member_ids=[d.id]
	f.origin=_vec(d.frame.origin); f.length_scale=float(d.frame.length)
	f.frame=Basis(_vec(d.frame.u),_vec(d.frame.v),_vec(d.frame.n)); f.inverse_frame=f.frame.inverse()
	f.caps=d.caps.duplicate(true); f.profiles=d.controls.duplicate(true)
	f.blend=exact_blend; f.p=1.05*f.blend
	f.raw_scale=2.0*f.length_scale*maxf(float(d.caps[1][0]),maxf(float(d.caps[1][1]),float(d.caps[1][2])))
	f.half_span=(1.0+float(d.caps[0][0])+float(d.caps[1][0]))*0.5
	f.midpoint=(1.0+float(d.caps[1][0])-float(d.caps[0][0]))*0.5
	f.halo=union_halo; f.exterior=f.halo+f.p
	f._configure_support()
	f.qualification=f.qualify(); f.valid=bool(f.qualification.ok); f.error=str(f.qualification.get("error",""))
	return f

func complete_section(z: float,derivative: int=0) -> Vector4:
	var out:=Vector4.ZERO
	for i in range(4): out[i]=bernstein(profiles[i],clampf(z,0.0,1.0),derivative)
	return out

func qualify() -> Dictionary:
	var bad: Dictionary={"ok":false,"error":"Fixed202 branch failed positive monotone complete-section qualification; no fallback."}
	if profiles!=controls(caps) or not is_finite(halo) or not is_finite(p) or not is_finite(raw_scale) or halo<2.0*p or p<=0.0 or 2.0*p>=raw_scale*0.5: return bad
	if caps[0][0]!=caps[0][1] or caps[0][0]!=caps[0][2] or float(caps[0][0])!=ROOT_P_MULTIPLIER*(1.05*float(descriptor.blend_ratio)): return bad
	var certificates: Array=[]
	for extent in range(4):
		var c: Array=profiles[extent]
		var maximum: float=c[5]
		var first: Array=[]; var second: Array=[]
		for i in range(5):
			if float(c[i])<=0.0 or float(c[i])>float(c[i+1]): return bad
			first.append(5.0*(float(c[i+1])-float(c[i])))
		for i in range(4): second.append(4.0*(float(first[i+1])-float(first[i])))
		for value: float in first:
			if value>12.0*maximum: return bad
		for value: float in second:
			if absf(value)>64.0*maximum: return bad
		certificates.append({"extent":extent,"positive_floor":c[0],"monotone_controls":true,"first_controls":first,"second_controls":second,"proximal_join":"C1 only, whole active proximal region must be buried","distal_join":"exact intended cap second jet; binary64 arithmetic residual reported in contract"})
	var numerical:=numerical_certificate()
	if not numerical.ok: return {"ok":false,"error":"202 bounded branch boundary/preimage qualification failed.","numerical":numerical}
	return {"ok":true,"profiles":certificates,"numerical":numerical,"isolated_volume":isolated_volume(),"global_metric_sdf":false,"root_burial_pending":true,"artistic_acceptance":false}

func numerical_certificate() -> Dictionary:
	var boundary:=BranchCertificate.boundary(self,support_low,support_high,halo)
	if not boundary.ok: return {"ok":false,"boundary":boundary}
	var preimage:=Certificate.preimage_box(self,support_low,support_high)
	if not preimage.ok: return {"ok":false,"boundary":boundary,"preimage":preimage}
	support_box=preimage.box; preimage.erase("box")
	return {"ok":true,"boundary":boundary,"preimage":preimage,"halo":halo,"exterior":exterior,"support_low":support_low,"support_high":support_high,"far_boundary_may_be_discontinuous":true,"global_metric_sdf":false}

func isolated_volume() -> float:
	var value:=0.0
	for cap: Array in caps: value+=2.0*PI*float(cap[0])*float(cap[1])*float(cap[2])/3.0
	for i in range(6):
		for j in range(6):
			var a: float=(float(profiles[0][i])+float(profiles[1][i]))*0.5
			var b: float=(float(profiles[2][j])+float(profiles[3][j]))*0.5
			value+=PI*a*b*_choose(5,i)*_choose(5,j)/(11.0*_choose(10,i+j))
	return value*pow(length_scale,3.0)*absf(frame.determinant())
