extends RefCounted
## 201: one C2 anatomical shoulder envelope shared by two biological members.
## This is a coercive level field with finite-band first-order calibration, NOT
## a global metric SDF. 201b preserves the near-surface evaluator and replaces
## only the proved positive exterior by a bounded constant. Its far boundary
## may be discontinuous; it cannot participate in a final zero smooth union.
## Geometry is evaluated once; regional identity is separate.
const Certificate = preload("res://alien_foundry/scripts/geometry/BlobEnvelope201Certificate.gd")
const KEY := "body_envelope201"
const SETTING := "blob_body_envelope_mode"
const MODE := "shared_shoulder_envelope_v1"
const OFF := "off"
const PIN := "05660d57f762741abb100bd10c679b99e0d917ddd5d57161498192464ace9029"
const PROGRAM := [0.64, 0.90, 0.94, 0.90]
const ROUNDING := 128.0 * 0.00000011920928955078125
static var _certificate_cache: Dictionary = {}
var valid := false
var error := ""
var descriptor: Dictionary = {}
var owner_id := ""
var member_ids: Array = []
var origin := Vector3.ZERO
var frame := Basis.IDENTITY
var inverse_frame := Basis.IDENTITY
var length_scale := 1.0
var caps: Array = []
var profiles: Array = []
var blend := 0.0
var p := 0.0
var raw_scale := 0.0
var half_span := 1.0
var midpoint := 0.0
var qualification: Dictionary = {}
var support_low: Array = []
var support_high: Array = []
var support_box := AABB()
var halo := 0.0
var exterior := 0.0

static func _number(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))
static func _vector(v: Variant) -> bool:
	if not v is Array or v.size() != 3: return false
	for x: Variant in v:
		if not _number(x): return false
	return true
static func _vec(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))
static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
static func marked(node: Dictionary) -> bool:
	var shape: Variant = node.get("shape")
	return shape is Dictionary and shape.has(KEY)
static func selection(options: Dictionary) -> Dictionary:
	var mode: Variant = options.get(SETTING, OFF)
	if not mode is String or mode not in [OFF, MODE]: return {"error": "Unsupported explicit201 body envelope mode."}
	if mode == MODE:
		if options.get("blob_pipeline_mode") != "iterative_v2" or options.get("blob_body_profile") != "compact_body_v1" or options.get("blob_base_volume_mode") != "unequal_compartments_v1": return {"error": "201 requires iterative compact195 anatomy."}
		if options.get("blob_body_growth_mode", "off") != "off": return {"error": "201 cannot combine with198 deformation."}
	return {"mode": mode}

static func descriptor_ok(d: Variant) -> bool:
	if not d is Dictionary or d.size() != 13: return false
	if not _number(d.get("version")) or float(d.version) != 2.0 or d.get("mode") != MODE or d.get("pin") != PIN: return false
	if not d.get("owner_id") is String or not d.get("member_ids") is Array or d.member_ids.size() != 2 or d.owner_id != d.member_ids[0] or d.member_ids[0] == d.member_ids[1]: return false
	if not d.get("member_feature_ids") is Array or d.member_feature_ids.size() != 2: return false
	for id: Variant in d.member_ids + d.member_feature_ids:
		if not id is String or id.is_empty(): return false
	var f: Variant = d.get("frame")
	if not f is Dictionary or f.size() != 5: return false
	for key: String in ["origin", "u", "v", "n"]:
		if not _vector(f.get(key)): return false
	if not _number(f.get("length")) or float(f.length) <= 0.000001: return false
	var basis := Basis(_vec(f.u), _vec(f.v), _vec(f.n))
	if not is_finite(basis.determinant()) or absf(basis.determinant() - 1.0) > 0.00001: return false
	for axis: Vector3 in [basis.x, basis.y, basis.z]:
		if absf(axis.length_squared() - 1.0) > 0.00001: return false
	if not d.get("caps") is Array or d.caps.size() != 2: return false
	for cap: Variant in d.caps:
		if not _vector(cap): return false
		for v: Variant in cap:
			if float(v) <= 0.000001: return false
	if not d.get("profiles") is Array or d.profiles.size() != 4: return false
	for extent: Variant in d.profiles:
		if not extent is Array or extent.size() != 2: return false
		for span: Variant in extent:
			if not span is Array or span.size() != 6: return false
			for value: Variant in span:
				if not _number(value): return false
	if not _number(d.get("blend_ratio")) or float(d.blend_ratio) <= 0.0 or float(d.blend_ratio) * float(f.length) < 0.001: return false
	if not _number(d.get("pair_nominal_volume_ratio")) or float(d.pair_nominal_volume_ratio) <= 0.0: return false
	if d.get("program") != PROGRAM: return false
	var context: Variant=d.get("union_context")
	if not context is Array or context.size()<2: return false
	var seen: Array=[]
	for entry: Variant in context:
		if not entry is Dictionary or entry.size()!=5 or not entry.get("id") is String or entry.id.is_empty() or entry.id in seen or entry.get("kind") not in ["mass","curve"] or entry.get("operation")!="union" or not _number(entry.get("blend")) or float(entry.blend)<0.001 or not _number(entry.get("noise")) or float(entry.noise)!=0.0: return false
		seen.append(entry.id)
	if seen[0]!=d.owner_id or not d.member_ids[1] in seen: return false
	return true

static func validate_declaration(dna: Dictionary) -> Dictionary:
	var chosen := selection(dna.get("settings", {}))
	if chosen.has("error"): return {"ok": false, "error": chosen.error}
	var marked_nodes: Array = []
	for n: Variant in dna.get("nodes", []):
		if n is Dictionary and marked(n): marked_nodes.append(n)
	if chosen.mode == OFF:
		return {"ok": marked_nodes.is_empty(), "error": "201 marker requires its explicit mode." if not marked_nodes.is_empty() else ""}
	var bad := {"ok": false, "error": "Malformed201 declared shared envelope; metadata is not anatomical qualification."}
	if dna.get("type") != "Blob" or int(dna.get("metadata", {}).get("iteration_index", 0)) < 2 or marked_nodes.size() != 2: return bad
	var report: Variant = dna.get("metadata", {}).get("body_envelope201")
	if not report is Dictionary or not _number(report.get("version")) or float(report.version) != 1.0 or report.get("mode") != MODE or report.get("pin") != PIN or not _number(report.get("stage")) or float(report.stage) != 2.0: return bad
	for key: String in ["supports_unchanged", "other_masses_unchanged", "actual_volume_pending", "visual_acceptance_pending"]:
		if not report.get(key) is bool or not report[key]: return bad
	if not report.get("scalar_evaluations") is int and not report.get("scalar_evaluations") is float: return bad
	if float(report.scalar_evaluations) != 1.0 or not report.get("anatomical_acceptance") is bool or report.anatomical_acceptance: return bad
	var d: Variant = marked_nodes[0].shape[KEY]
	if not descriptor_ok(d) or report.get("member_ids") != d.member_ids or report.get("member_feature_ids") != d.member_feature_ids: return bad
	var ids: Array = []; var feature_ids: Array = []
	for n: Dictionary in marked_nodes:
		if not descriptor_ok(n.shape[KEY]) or n.shape[KEY] != d or n.get("kind") != "mass" or n.get("operation", "union") != "union" or n.get("id") not in d.member_ids: return bad
		if not _number(n.get("noise")) or float(n.noise) != 0.0: return bad
		ids.append(n.id); feature_ids.append(n.get("feature_id"))
	if ids != d.member_ids or feature_ids != d.member_feature_ids or marked_nodes[1].get("parent") != d.owner_id: return bad
	var old: Variant = dna.get("metadata", {}).get("base_volume_development")
	if not old is Dictionary or old.get("witness_pair") != d.member_feature_ids or not old.get("body_node_ids") is Array or old.body_node_ids[0] != d.owner_id: return bad
	return {"ok": true}

static func union_context(nodes: Array) -> Array:
	var result: Array=[]
	for n: Dictionary in nodes:
		result.append({"id":str(n.get("id","")),"kind":str(n.get("kind","mass")),"operation":str(n.get("operation","union")),"blend":maxf(float(n.get("blend",0.15)),0.001),"noise":float(n.get("noise",0.0))})
	return result
static func validate_compilation_context(dna: Dictionary) -> Dictionary:
	if dna.get("settings",{}).get(SETTING,OFF)==OFF: return {"ok":true}
	var nodes: Array=dna.get("nodes",[])
	if nodes.is_empty() or not marked(nodes[0]): return {"ok":false,"error":"201b group must be the first evaluated union."}
	var d: Dictionary=nodes[0].shape[KEY]
	if not descriptor_ok(d) or union_context(nodes)!=d.union_context: return {"ok":false,"error":"201b bounded halo invalidated by changed node/blend/operation context; downstream extraction is not approved."}
	if not dna.get("modules",[]).is_empty(): return {"ok":false,"error":"201b bounded experiment does not compile downstream modules."}
	return {"ok":true}

static func validate(dna: Dictionary) -> Dictionary:
	var declared := validate_declaration(dna)
	if not declared.ok or dna.get("settings", {}).get(SETTING, OFF) == OFF: return declared
	for n: Dictionary in dna.nodes:
		if marked(n):
			var f := create(n)
			if not f.valid: return {"ok": false, "error": f.error}
			return {"ok": true, "qualification": f.qualification}
	return {"ok": false, "error": "201 missing shared group."}

static func hermite(a: float, b: float, second_a: float, second_b: float) -> Array:
	# Derivatives supplied with respect to normalized span coordinate.
	var d := b - a
	return [a, 0.0, second_a * 0.5, 10.0*d - 1.5*second_a + 0.5*second_b, -15.0*d + 1.5*second_a - second_b, 6.0*d - 0.5*second_a + 0.5*second_b]
static func authored_profiles(cap_values: Array) -> Array:
	var result: Array = []
	for i in range(4):
		var axis := 1 if i < 2 else 2
		var a := float(cap_values[0][axis]); var b := float(cap_values[1][axis])
		var m := minf(a, b); var middle := float(PROGRAM[i]) * m
		var left_second := -a / pow(float(cap_values[0][0]), 2.0) * 0.25
		var right_second := -b / pow(float(cap_values[1][0]), 2.0) * 0.25
		result.append([hermite(a, middle, left_second, m * 0.25), hermite(middle, b, m * 0.25, right_second)])
	return result
static func _poly(coeff: Array, t: float, derivative: int = 0) -> float:
	var value := 0.0
	for i in range(coeff.size() - 1, derivative - 1, -1):
		var multiplier := 1.0
		for j in range(derivative): multiplier *= float(i - j)
		value = value * t + float(coeff[i]) * multiplier
	return value
static func _choose(n: int, k: int) -> float:
	var value := 1.0
	for i in range(1, k + 1): value *= float(n - i + 1) / float(i)
	return value
static func _bernstein_derivative(coeff: Array, derivative: int) -> Array:
	var degree := coeff.size() - 1 - derivative
	var powers: Array = []
	for i in range(degree + 1):
		var multiplier := 1.0
		for j in range(derivative): multiplier *= float(i + derivative - j)
		powers.append(float(coeff[i + derivative]) * multiplier)
	var result: Array = []
	for k in range(degree + 1):
		var value := 0.0
		for i in range(k + 1): value += float(powers[i]) * _choose(k, i) / _choose(degree, i)
		result.append(value)
	return result

static func create(node: Dictionary) -> RefCounted:
	var field = load("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd").new()
	if not marked(node) or not descriptor_ok(node.shape[KEY]): field.error = "Invalid typed201 descriptor."; return field
	field.descriptor = node.shape[KEY].duplicate(true)
	var d: Dictionary = field.descriptor
	field.owner_id = d.owner_id; field.member_ids = d.member_ids.duplicate()
	field.origin = _vec(d.frame.origin); field.length_scale = float(d.frame.length)
	field.frame = Basis(_vec(d.frame.u), _vec(d.frame.v), _vec(d.frame.n)); field.inverse_frame = field.frame.inverse()
	field.caps = d.caps.duplicate(true); field.profiles = d.profiles.duplicate(true)
	field.blend = float(d.blend_ratio) * field.length_scale; field.p = 1.05 * field.blend
	field.half_span = (1.0 + float(d.caps[0][0]) + float(d.caps[1][0])) * 0.5
	field.midpoint = (1.0 + float(d.caps[1][0]) - float(d.caps[0][0])) * 0.5
	var minimum := INF
	for row: Array in d.caps:
		for value: Variant in row: minimum = minf(minimum, float(value))
	minimum = minf(minimum, 0.77 * minf(float(d.caps[0][1]), float(d.caps[1][1])))
	minimum = minf(minimum, 0.92 * minf(float(d.caps[0][2]), float(d.caps[1][2])))
	field.raw_scale = 2.0 * field.length_scale * minimum
	field.halo = 0.0
	for entry: Dictionary in d.union_context:
		if entry.id==field.member_ids[1]: continue
		field.halo += field.blend if entry.id==field.owner_id else float(entry.blend)
	field.halo=maxf(field.halo,2.0*field.p)
	field.exterior=field.halo+field.p
	field._configure_support()
	var certificate_key:=var_to_bytes(d).hex_encode()
	if _certificate_cache.has(certificate_key):
		field.qualification=_certificate_cache[certificate_key].qualification.duplicate(true)
		field.support_box=_certificate_cache[certificate_key].box
	else:
		field.qualification=field.qualify()
		if field.qualification.ok:
			if _certificate_cache.size()>=16: _certificate_cache.clear()
			_certificate_cache[certificate_key]={"qualification":field.qualification.duplicate(true),"box":field.support_box}
	field.valid = bool(field.qualification.ok)
	field.error = str(field.qualification.get("error", ""))
	return field

func qualify() -> Dictionary:
	var bad := {"ok": false, "error": "Fixed201 profile failed analytic qualification; no coefficient search or fallback."}
	if profiles != authored_profiles(caps): return bad
	if not is_finite(raw_scale) or not is_finite(p) or p <= 0.0 or 2.0*p >= raw_scale*0.5: return bad
	var numerical := numerical_certificate()
	if not numerical.ok: return {"ok":false,"error":"201 numerical containment allowance rejected conditioning.","numerical":numerical}
	var certificates: Array = []
	for i in range(4):
		var axis := 1 if i < 2 else 2
		var maximum := maxf(float(caps[0][axis]), float(caps[1][axis]))
		for span in range(2):
			var c: Array = profiles[i][span]
			# Exact endpoint jets imply derivative endpoint zeros. Compute the
			# three interior Bernstein coefficients directly, avoiding cancellation
			# falsely reporting a tiny endpoint overshoot from a power conversion.
			var ea := _poly(c, 0.0); var eb := _poly(c, 1.0)
			var k0 := _poly(c, 0.0, 2); var k1 := _poly(c, 1.0, 2)
			var bd := [0.0, k0/4.0, 5.0*(eb-ea)-k0/4.0+k1/4.0, -k1/4.0, 0.0]
			var exact:=Certificate.profile(self,i,span)
			if not exact.ok: return {"ok":false,"error":"201b exact intended profile certificate or storage enclosure rejected.","certificate":exact}
			var second: Array = _bernstein_derivative(c, 2)
			for value: Variant in bd:
				if absf(float(value)) * 2.0 > 12.0 * maximum: return bad
			for value: Variant in second:
				if absf(float(value)) * 4.0 > 64.0 * maximum: return bad
			exact["derivative_bernstein"]=bd; exact["second_bernstein"]=second
			certificates.append(exact)
	var volume := isolated_volume()
	var nominal := float(descriptor.pair_nominal_volume_ratio) * pow(length_scale, 3.0)
	if not is_finite(volume) or volume <= 0.0 or volume > nominal * 1.20: return bad
	return {"ok": true, "derivative_certificates": certificates, "minimum_area_factor": 0.7084, "required_area_factor": 0.70, "isolated_volume": volume, "pair_nominal_volume": nominal, "isolated_volume_ratio": volume/nominal, "raw_critical_value": -raw_scale*0.5, "calibration_band_outer": 2.0*p, "surface_regular": true, "exact_intended_hermite_only":true, "rounded_power_strict_monotonicity_claimed":false, "artistic_acceptance": false, "world_up_valley_not_proved": true, "numerical":numerical}

func _configure_support() -> void:
	var r2:=1.0+2.0*halo/raw_scale
	var zlow:=midpoint-half_span*sqrt(r2); var zhigh:=midpoint+half_span*sqrt(r2)
	var r0:=float(caps[0][0]); var r1:=float(caps[1][0]); var sr:=1.0+r1
	var kl:=sqrt(1.0+half_span*half_span*(r2-1.0)/(r0*r0)*maxf((r0-zlow)/(sr-zlow),r0/sr))
	var kr:=sqrt(1.0+half_span*half_span*(r2-1.0)/(r1*r1)*maxf((zhigh-1.0+r1)/(zhigh+r0),r1/(1.0+r0)))
	var kc:=sqrt(1.0+(r2-1.0)/(minf(r0*(1.0+r1),r1*(1.0+r0))/(half_span*half_span)))
	var x:=maxf(maxf(float(caps[0][2])*kl,float(caps[1][2])*kr),maxf(float(caps[0][2]),float(caps[1][2]))*kc)
	var y:=maxf(maxf(float(caps[0][1])*kl,float(caps[1][1])*kr),maxf(float(caps[0][1]),float(caps[1][1]))*kc)
	var margin:=0.25*p/length_scale
	support_low=[-x-margin,-y-margin,zlow-margin]
	support_high=[x+margin,y+margin,zhigh+margin]
func numerical_certificate() -> Dictionary:
	var boundary:=Certificate.boundary(self,support_low,support_high,halo)
	if not boundary.ok: return {"ok":false,"boundary":boundary}
	var preimage:=Certificate.preimage_box(self,support_low,support_high)
	if not preimage.ok: return {"ok":false,"boundary":boundary,"preimage":preimage}
	support_box=preimage.box
	preimage.erase("box")
	return {"ok":true,"boundary":boundary,"preimage":preimage,"halo":halo,"exterior":exterior,"support_low":support_low,"support_high":support_high,"far_boundary_may_be_discontinuous":true,"global_metric_sdf":false}
func _outside_support(point: Vector3) -> bool:
	var q:=inverse_frame*(point-origin)/length_scale
	if not q.is_finite(): return true
	for k in range(3):
		if float(q[k])<float(support_low[k]) or float(q[k])>float(support_high[k]): return true
	return false

func complete_section(z: float, derivative: int = 0) -> Vector4:
	var span := 0 if z <= 0.5 else 1
	var t := clampf((z - float(span)*0.5) * 2.0, 0.0, 1.0)
	var value := Vector4.ZERO
	for i in range(4): value[i] = _poly(profiles[i][span], t, derivative) * pow(2.0, derivative)
	return value

func _coefficients(z: float) -> Dictionary:
	var t := (z-midpoint)/half_span
	var px: float; var py: float; var dx: float; var dy: float
	var cx := 0.0; var cy := 0.0; var dcx := 0.0; var dcy := 0.0
	if z <= 0.0:
		var r := float(caps[0][0]); var numerator := 1.0 + float(caps[1][0]) - z; var denominator := r-z
		var derivative := (numerator-denominator)/(denominator*denominator)
		var factor := r*r/(half_span*half_span)
		px = factor / pow(float(caps[0][2]),2.0) * numerator/denominator
		py = factor / pow(float(caps[0][1]),2.0) * numerator/denominator
		dx = factor / pow(float(caps[0][2]),2.0) * derivative
		dy = factor / pow(float(caps[0][1]),2.0) * derivative
	elif z >= 1.0:
		var r := float(caps[1][0]); var numerator := z + float(caps[0][0]); var denominator := z-1.0+r
		var derivative := (denominator-numerator)/(denominator*denominator)
		var factor := r*r/(half_span*half_span)
		px = factor / pow(float(caps[1][2]),2.0) * numerator/denominator
		py = factor / pow(float(caps[1][1]),2.0) * numerator/denominator
		dx = factor / pow(float(caps[1][2]),2.0) * derivative
		dy = factor / pow(float(caps[1][1]),2.0) * derivative
	else:
		var s := complete_section(z); var ds := complete_section(z,1)
		var a := (s.x+s.y)*0.5; var b := (s.z+s.w)*0.5
		var da := (ds.x+ds.y)*0.5; var db := (ds.z+ds.w)*0.5
		cx = (s.z-s.w)*0.5; cy = (s.x-s.y)*0.5
		dcx = (ds.z-ds.w)*0.5; dcy = (ds.x-ds.y)*0.5
		var q := 1.0-t*t; var dq := -2.0*t/half_span
		px = q/(b*b); py = q/(a*a)
		dx = dq/(b*b)-2.0*q*db/(b*b*b); dy = dq/(a*a)-2.0*q*da/(a*a*a)
	return {"t":t,"px":px,"py":py,"dx":dx,"dy":dy,"cx":cx,"cy":cy,"dcx":dcx,"dcy":dcy}

func raw_value_gradient(point: Vector3) -> Vector4:
	var local := inverse_frame*(point-origin)/length_scale
	var c := _coefficients(local.z)
	var x := local.x-float(c.cx); var y := local.y-float(c.cy); var t := float(c.t)
	var gx := float(c.px)*x; var gy := float(c.py)*y
	var gz := t/half_span-float(c.px)*x*float(c.dcx)-float(c.py)*y*float(c.dcy)+(float(c.dx)*x*x+float(c.dy)*y*y)*0.5
	var g := inverse_frame.transposed()*Vector3(gx,gy,gz)*(raw_scale/length_scale)
	return Vector4(g.x,g.y,g.z,raw_scale*0.5*(t*t+float(c.px)*x*x+float(c.py)*y*y-1.0))

func distance(point: Vector3) -> float:
	if not valid or not point.is_finite(): return NAN
	if _outside_support(point): return exterior
	var value := raw_value_gradient(point); var raw := value.w
	if not is_finite(raw): return NAN
	if absf(raw) >= 2.0*p: return raw
	var gradient := Vector3(value.x,value.y,value.z).length()
	if not is_finite(gradient) or gradient <= 0.000000000001: return NAN
	var x := clampf((absf(raw)-p)/p,0.0,1.0)
	var w := 1.0-x*x*(3.0-2.0*x)
	return raw*((1.0-w)+w/gradient)
func normal(point: Vector3) -> Vector3:
	if not valid or not point.is_finite() or _outside_support(point): return Vector3.ZERO
	var value := raw_value_gradient(point)
	return Vector3(value.x,value.y,value.z).normalized()
func weights(point: Vector3) -> Vector2:
	var z := (inverse_frame*(point-origin)/length_scale).z
	var t := clampf((z-0.25)/0.50,0.0,1.0)
	var child := t*t*t*(10.0+t*(-15.0+6.0*t))
	return Vector2(1.0-child,child)
func local_surface(z: float, angle: float) -> Vector3:
	if z <= 0.0:
		var q := sqrt(maxf(0.0,1.0-pow(z/float(caps[0][0]),2.0)))
		return Vector3(float(caps[0][2])*cos(angle)*q,float(caps[0][1])*sin(angle)*q,z)
	if z >= 1.0:
		var q := sqrt(maxf(0.0,1.0-pow((z-1.0)/float(caps[1][0]),2.0)))
		return Vector3(float(caps[1][2])*cos(angle)*q,float(caps[1][1])*sin(angle)*q,z)
	var s := complete_section(z)
	return Vector3((s.z-s.w)*0.5+(s.z+s.w)*0.5*cos(angle),(s.x-s.y)*0.5+(s.x+s.y)*0.5*sin(angle),z)
func surface(z: float, angle: float) -> Vector3:
	return origin+frame*local_surface(z,angle)*length_scale

func _world_box(low: Vector3,high: Vector3) -> AABB:
	var result:=Certificate.preimage_box(self,_arr(low),_arr(high))
	return result.box if result.ok else AABB(Vector3(NAN,NAN,NAN),Vector3.ZERO)
func fit_bounds() -> AABB:
	var b:=maxf(float(caps[0][2]),float(caps[1][2])); var h:=maxf(float(caps[0][1]),float(caps[1][1]))
	var margin:=ROUNDING*maxf(1.0,maxf(b,h))
	var result:=Certificate.preimage_box(self,[-b-margin,-h-margin,-float(caps[0][0])-margin],[b+margin,h+margin,1.0+float(caps[1][0])+margin])
	return result.box if result.ok else AABB(Vector3(NAN,NAN,NAN),Vector3.ZERO)
func bounds_for_padding(padding: float) -> AABB:
	if not valid or not is_finite(padding) or padding<0.0 or padding>halo: return AABB(Vector3(NAN,NAN,NAN),Vector3.ZERO)
	return support_box

func isolated_volume() -> float:
	var value := 0.0
	for cap: Array in caps: value += 2.0*PI*float(cap[0])*float(cap[1])*float(cap[2])/3.0
	for span in range(2):
		for i in range(6):
			for j in range(6):
				var a := (float(profiles[0][span][i])+float(profiles[1][span][i]))*0.5
				var b := (float(profiles[2][span][j])+float(profiles[3][span][j]))*0.5
				value += PI*0.5*a*b/float(i+j+1)
	return value*pow(length_scale,3.0)*absf(frame.determinant())

func ray_surface(start: Vector3, outward: Vector3, fraction: float = 1.0) -> Vector3:
	if not valid or not start.is_finite() or not outward.is_finite() or outward.length_squared()<0.00000001 or not is_finite(fraction) or fraction<0.0 or fraction>1.0 or distance(start)>=0.0: return Vector3(NAN,NAN,NAN)
	var direction := outward.normalized()
	var reach := fit_bounds().size.length()*2.0
	var low := 0.0; var high := 0.0; var found := false
	for i in range(1,257):
		high=reach*float(i)/256.0
		var value := distance(start+direction*high)
		if not is_finite(value): return Vector3(NAN,NAN,NAN)
		if value>=0.0: found=true; break
		low=high
	if not found: return Vector3(NAN,NAN,NAN)
	for i in range(40):
		var mid := (low+high)*0.5
		if distance(start+direction*mid)>0.0: high=mid
		else: low=mid
	var hit := start+direction*((low+high)*0.5)
	if absf(distance(hit))>ROUNDING*length_scale*8.0: return Vector3(NAN,NAN,NAN)
	return start+(hit-start)*fraction

static func scale_descriptor(node: Dictionary, scale: float) -> void:
	if not marked(node): return
	var f: Dictionary = node.shape[KEY].frame
	f.origin=_arr(_vec(f.origin)*scale); f.length=float(f.length)*scale
	for entry: Dictionary in node.shape[KEY].union_context: entry.blend=float(entry.blend)*scale
static func translate_descriptor(node: Dictionary, delta: Vector3) -> void:
	if not marked(node): return
	var f: Dictionary = node.shape[KEY].frame
	f.origin=_arr(_vec(f.origin)+delta)
