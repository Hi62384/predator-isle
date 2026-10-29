extends RefCounted
## A common invertible map for one typed sac and its owned neck/cavity group.
## Field values remain distance approximations. The algebraic map is NOT an SDF.
const KEY := "sac_group_warp"
const LINK := "sac_group_owner_id"
const SETTING := "blob_sac_group_mode"
const LEGACY_MODE := "sac_group_growth_v1"
const MODE := "sac_group_growth_v2"
const FINAL_MODE := "sac_group_growth_final_v1"
const SEED_LANE := LEGACY_MODE
const OFF := "off"
var origin := Vector3.ZERO
var basis := Basis.IDENTITY
var inverse_basis := Basis.IDENTITY
var radii := Vector3.ONE
var root_y := -0.3
var ramp := 0.3
var d: Dictionary = {}
var amplitude := 0.0
var minimum_scales := Vector2(0.88,0.60)
var maximum_scales := Vector2(1.30,1.50)
static func vec(a: Array) -> Vector3: return Vector3(float(a[0]),float(a[1]),float(a[2]))
static func arr(v: Vector3) -> Array: return [v.x,v.y,v.z]
static func number(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func vector(v: Variant) -> bool: return v is Array and v.size() == 3 and number(v[0]) and number(v[1]) and number(v[2])
static func unit(v: Variant) -> bool: return vector(v) and absf(vec(v).length()-1.0) < 0.000001
static func selection(settings: Dictionary) -> Dictionary:
	var mode: Variant = settings.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,LEGACY_MODE,MODE,FINAL_MODE]: return {"error": "Unsupported explicit sac group mode."}
	return {"mode": mode}
static func marked(n: Dictionary) -> bool: return n.get("shape") is Dictionary and n.shape.has(KEY)
static func descriptor_ok(v: Variant) -> bool:
	if not v is Dictionary or v.get("version") != 1 or not v.get("owner_id") is String or not v.get("feature_id") is String or not v.get("members") is Array: return false
	if v.members.is_empty() or v.members.size() > 8: return false
	var seen: Dictionary = {}
	for id: Variant in v.members:
		if not id is String or seen.has(id): return false
		seen[id] = true
	for name in ["across","axial","depth"]:
		if not unit(v.get(name)): return false
	if absf(vec(v.across).dot(vec(v.axial))) > 0.000001 or absf(vec(v.across).dot(vec(v.depth))) > 0.000001 or absf(vec(v.depth).dot(vec(v.axial))) > 0.000001: return false
	if vec(v.across).cross(vec(v.axial)).dot(vec(v.depth)) < 0.99999: return false
	for key in ["swell_x","swell_z","waist_x","waist_z","bend_x","bend_z","phase","fold_amplitude"]:
		if not number(v.get(key)): return false
	if float(v.swell_x) < 0.0 or float(v.swell_x) > 0.30 or float(v.swell_z) < 0.0 or float(v.swell_z) > 0.22: return false
	if float(v.waist_x) < 0.0 or float(v.waist_x) > 0.12 or float(v.waist_z) < 0.0 or float(v.waist_z) > 0.10: return false
	if absf(float(v.bend_x)) > 0.14 or absf(float(v.bend_z)) > 0.14 or absf(float(v.phase)) > PI: return false
	if float(v.fold_amplitude) < 0.0 or float(v.fold_amplitude) > 0.15 or not v.get("creases") is Array or v.creases.size() > 2: return false
	if v.has("bounds_version") and v.bounds_version != 2: return false
	var previous_end := -INF
	for crease: Variant in v.creases:
		if not crease is Dictionary or not number(crease.get("center")) or not number(crease.get("width")) or not number(crease.get("strength")): return false
		if absf(float(crease.center)) > 0.60 or float(crease.width) < 0.30 or float(crease.width) > 0.85 or float(crease.strength) < 0.75 or float(crease.strength) > 1.0: return false
		if float(crease.center)-float(crease.width) < previous_end + 0.02: return false
		previous_end = float(crease.center)+float(crease.width)
	return true
static func digest(v: Dictionary) -> String:
	var base := v.duplicate(true)
	for key in ["creases","fold_amplitude","fold_amplitude_hex"]: base.erase(key)
	return JSON.stringify(base,"",true,true).sha256_text()
static func validate(dna: Dictionary) -> Dictionary:
	if not dna.get("settings") is Dictionary: return {"ok": false,"error": "Missing group settings."}
	var selected: Dictionary = selection(dna.settings)
	if selected.has("error"): return {"ok": false,"error": selected.error}
	if not dna.get("nodes") is Array: return {"ok": false,"error": "Missing group nodes."}
	var nodes: Dictionary = {}; var owners: Dictionary = {}
	for n: Variant in dna.nodes:
		if not n is Dictionary or not n.get("id") is String: return {"ok": false,"error": "Invalid group node."}
		nodes[n.id] = n
		if marked(n): owners[n.id] = n
	if selected.mode != OFF and (dna.get("type") != "Blob" or dna.settings.get("blob_pipeline_mode") != "iterative_v2"):
		return {"ok": false,"error": "Sac groups require iterative Blob mode."}
	if owners.is_empty():
		for n: Dictionary in dna.nodes:
			if n.has(LINK): return {"ok": false,"error": "Orphan group link."}
		return {"ok": true}
	if selected.mode not in [LEGACY_MODE,MODE,FINAL_MODE] or dna.get("type") != "Blob" or dna.settings.get("blob_pipeline_mode") != "iterative_v2": return {"ok": false,"error": "Sac group requires iterative Blob mode."}
	if not dna.get("biological_blueprint") is Dictionary or not dna.biological_blueprint.get("features") is Array: return {"ok": false,"error": "Missing typed group registry."}
	var features: Dictionary = {}
	for feature: Variant in dna.biological_blueprint.features:
		if not feature is Dictionary or not feature.get("id") is String: return {"ok": false,"error": "Malformed group feature."}
		features[feature.id] = feature
	var irregularity: Variant = dna.settings.get("irregularity",0.45)
	if not number(irregularity) or float(irregularity) < 0.0 or float(irregularity) > 1.0: return {"ok": false,"error": "Group sculpt domain requires irregularity in [0,1]."}
	var occupied: Dictionary = {}
	for id: String in owners:
		var owner: Dictionary = owners[id]; var desc: Variant = owner.shape[KEY]
		if not descriptor_ok(desc) or desc.owner_id != id or desc.feature_id != owner.get("feature_id"): return {"ok": false,"error": "Invalid common group descriptor."}
		if (selected.mode in [MODE,FINAL_MODE] and desc.get("bounds_version") != 2) or (selected.mode == LEGACY_MODE and desc.has("bounds_version")):
			return {"ok": false,"error": "Explicit bounds/cache profile disagrees with the group recipe."}
		if not nodes.has(owner.get("parent")) or not features.has(owner.feature_id): return {"ok": false,"error": "Missing group anatomical parent."}
		if not vector(nodes[owner.parent].get("position")): return {"ok": false,"error": "Malformed group host position."}
		var feature: Dictionary = features[owner.feature_id]
		if feature.get("type") != "sac" or not feature.get("geometry_refs") is Dictionary or not feature.geometry_refs.get("node_ids") is Array: return {"ok": false,"error": "Group owner must be a typed sac."}
		if not feature.get("geometry_recipe") is Dictionary or feature.geometry_recipe.get(KEY) != digest(desc): return {"ok": false,"error": "Group blueprint digest disagrees."}
		var expected: Array = feature.geometry_refs.node_ids.duplicate()
		for child: Dictionary in dna.nodes:
			if child.get("kind") == "cavity" and child.get("parent") == id: expected.append(child.id)
		expected.sort()
		if desc.members != expected: return {"ok": false,"error": "Group must contain every owned sac/neck/cavity carrier, no unrelated carrier."}
		for member: String in desc.members:
			if occupied.has(member) or not nodes.has(member): return {"ok": false,"error": "Missing or ambiguous group ownership."}
			occupied[member] = id
			var n: Dictionary = nodes[member]
			if n.get(LINK) != id or n.get("kind") not in ["mass","cavity"] or not vector(n.get("position")) or not vector(n.get("size")) or not vector(n.get("rotation",[0,0,0])) or not vec(n.get("rotation",[0,0,0])).is_zero_approx(): return {"ok": false,"error": "Unsupported group carrier geometry."}
			if float(n.get("noise",0.0)) != 0.0 or bool(n.get("surface_opening",false)) or minf(vec(n.size).x,minf(vec(n.size).y,vec(n.size).z)) < 0.04: return {"ok": false,"error": "Unsupported noisy, reseated or tiny group carrier."}
			if not n.get("shape",{}) is Dictionary or n.get("role") not in ["lobe","sac_transition","cavity"] or n.get("operation","union") != "union": return {"ok": false,"error": "Unsupported group carrier role/operation."}
			var sculpt: Variant = n.get("shape",{}).get("sculpt_strength",0.0)
			if not number(sculpt) or float(sculpt) < 0.0 or float(sculpt) > 1.0: return {"ok": false,"error": "Invalid group rest sculpt strength."}
			for key: String in n.get("shape",{}):
				if key not in ["sculpt_strength",KEY]: return {"ok": false,"error": "Conflicting group shape modifier."}
			if n.kind == "cavity" and (not features.has(n.get("feature_id")) or features[n.feature_id].get("type") != "cavity" or features[n.feature_id].get("parent_id") != owner.feature_id): return {"ok": false,"error": "Cavity lost its typed parent."}
		var stage: int = int(dna.get("metadata",{}).get("iteration_index",0))
		if stage < 4 or not feature.get("detail_rules") is Dictionary: return {"ok": false,"error": "Group stage/rules missing."}
		var rule: Dictionary = feature.detail_rules
		if not rule.get("enabled") is bool or not number(rule.get("density")) or float(rule.density) != floorf(float(rule.density)) or int(rule.density) not in [0,1,2]: return {"ok": false,"error": "Invalid group fold count rule."}
		var active: bool = stage >= 5 and rule.enabled and float(dna.settings.get("surface_detail",0.55)) > 0.0
		var count: int = int(rule.density) if active else 0
		if desc.creases.size() != count: return {"ok": false,"error": "Group crease count disagrees with actual rule."}
		if count == 0 and float(desc.fold_amplitude) != 0.0: return {"ok": false,"error": "Inactive creases must be a no-op."}
		if count > 0:
			var bits: PackedByteArray = str(desc.get("fold_amplitude_hex","")).hex_decode()
			if bits.size() != 8 or not number(rule.get("amplitude")): return {"ok": false,"error": "Missing exact fold amplitude."}
			var exact: float = bits.decode_double(0)
			if not is_finite(exact) or exact != float(desc.fold_amplitude) or (float(rule.amplitude) != exact and float(rule.amplitude) != float(JSON.parse_string(JSON.stringify(exact,"",true,true)))): return {"ok": false,"error": "Group amplitude rule differs from geometry."}
		var field: RefCounted = create(dna,owner)
		if field.amplitude > 0.28 or field.minimum_scales.x < 0.55 or field.minimum_scales.y < 0.55: return {"ok": false,"error": "Group map exceeds positive-scale bounds."}
	for n: Dictionary in dna.nodes:
		if n.has(LINK) and not occupied.has(n.id): return {"ok": false,"error": "Unowned group link."}
	return {"ok": true}
static func create(dna: Dictionary, owner: Dictionary) -> RefCounted:
	var field := new(); field.d = owner.shape[KEY].duplicate(true); field.origin = vec(owner.position)
	field.basis = Basis(vec(field.d.across),vec(field.d.axial),vec(field.d.depth)).orthonormalized(); field.inverse_basis = field.basis.inverse()
	var r: Vector3 = vec(owner.size)
	field.radii = Vector3((r*field.basis.x).length(),(r*field.basis.y).length(),(r*field.basis.z).length())
	var host: Dictionary = {}
	for n: Dictionary in dna.nodes:
		if n.id == owner.parent: host = n; break
	field.root_y = (vec(host.position)-field.origin).dot(field.basis.y)*0.65 + minf(r.x,minf(r.y,r.z))*0.06
	field.ramp = 0.85*field.radii.y
	field.amplitude = float(field.d.fold_amplitude)*float(dna.settings.get("size",1.0))/field.radii.z
	field.minimum_scales = Vector2(1.0-float(field.d.waist_x),1.0-float(field.d.waist_z)-field.amplitude)
	field.maximum_scales = Vector2(1.0+float(field.d.swell_x),1.0+float(field.d.swell_z)+field.amplitude)
	return field
func gate(y: float) -> float: return smoothstep(root_y,root_y+ramp,y)
func coefficients(y: float, x: float, detailed: bool = true) -> Vector4:
	var t: float = y/radii.y; var g: float = gate(y)
	var sx: float = 1.0+g*(float(d.swell_x)*exp(-pow((t-0.15)/0.65,2.0))-float(d.waist_x)*exp(-pow((t+0.65)/0.38,2.0)))
	var sz: float = 1.0+g*(float(d.swell_z)*exp(-pow((t-0.55)/0.50,2.0))-float(d.waist_z)*exp(-pow((t+0.15)/0.45,2.0)))
	if detailed and amplitude > 0.0:
		var fold: float = 0.0
		for crease: Dictionary in d.creases:
			var q: float = (x/radii.x-float(crease.center))/float(crease.width)
			if absf(q) < 1.0: fold = float(crease.strength)*pow(1.0-q*q,3.0)*(1.0-5.0*q*q); break
		sz += g*amplitude*exp(-pow((t-0.18)/0.85,4.0))*fold
	return Vector4(sx,sz,g*radii.x*float(d.bend_x)*sin(t*1.15+float(d.phase)),g*radii.z*float(d.bend_z)*sin(t*1.30))
func forward(point: Vector3, detailed: bool = true) -> Vector3:
	var q: Vector3 = inverse_basis*(point-origin)
	if q.y <= root_y: return point
	var c: Vector4 = coefficients(q.y,q.x,detailed)
	return origin+basis*Vector3(q.x*c.x+c.z,q.y,q.z*c.y+c.w)
func inverse(point: Vector3) -> Vector3:
	var q: Vector3 = inverse_basis*(point-origin)
	if q.y <= root_y: return point
	var c: Vector4 = coefficients(q.y,0.0,false)
	q.x = (q.x-c.z)/c.x
	c = coefficients(q.y,q.x,true)
	q.z = (q.z-c.w)/c.y
	return origin+basis*q
func _legacy_forward_bounds(box: AABB) -> AABB:
	var local := AABB(inverse_basis*(box.position-origin),Vector3.ZERO)
	for i in range(8): local = local.expand(inverse_basis*(box.get_endpoint(i)-origin))
	if local.end.y <= root_y: return box
	var xx: Array[float] = [local.position.x*minimum_scales.x,local.position.x*maximum_scales.x,local.end.x*minimum_scales.x,local.end.x*maximum_scales.x]
	var zz: Array[float] = [local.position.z*minimum_scales.y,local.position.z*maximum_scales.y,local.end.z*minimum_scales.y,local.end.z*maximum_scales.y]
	var low := Vector3(xx.min()-radii.x*absf(float(d.bend_x)),local.position.y,zz.min()-radii.z*absf(float(d.bend_z)))
	var high := Vector3(xx.max()+radii.x*absf(float(d.bend_x)),local.end.y,zz.max()+radii.z*absf(float(d.bend_z)))
	var transformed := AABB(origin+basis*low,Vector3.ZERO); var bound := AABB(low,high-low)
	for i in range(8): transformed = transformed.expand(origin+basis*bound.get_endpoint(i))
	return transformed.grow(0.00001)

static func product_interval(a: float, b: float, c: float, e: float) -> Vector2:
	var products: Array[float] = [a*c,a*e,b*c,b*e]
	return Vector2(products.min(),products.max())
func forward_bounds(box: AABB) -> AABB:
	if int(d.get("bounds_version",1)) == 1: return _legacy_forward_bounds(box)
	# F(p)=p+across*((sx-1)*x+cx)+depth*((sz-1)*z+cz).
	# Keep p in its ORIGINAL world interval. Only the displacement is boxed
	# in the group frame, avoiding |B|*|B^T| inflation of an identity map.
	var local := AABB(inverse_basis*(box.position-origin),Vector3.ZERO)
	for i in range(8): local = local.expand(inverse_basis*(box.get_endpoint(i)-origin))
	if local.end.y <= root_y: return box
	var dx: Vector2 = product_interval(local.position.x,local.end.x,minimum_scales.x-1.0,maximum_scales.x-1.0)
	var dz: Vector2 = product_interval(local.position.z,local.end.z,minimum_scales.y-1.0,maximum_scales.y-1.0)
	dx += Vector2(-1.0,1.0)*radii.x*absf(float(d.bend_x))
	dz += Vector2(-1.0,1.0)*radii.z*absf(float(d.bend_z))
	var low: Vector3 = (basis.x*dx.x).min(basis.x*dx.y)+(basis.z*dz.x).min(basis.z*dz.y)
	var high: Vector3 = (basis.x*dx.x).max(basis.x*dx.y)+(basis.z*dz.x).max(basis.z*dz.y)
	if low == Vector3.ZERO and high == Vector3.ZERO: return box
	# Covers float32 coordinate operations for the declared bounded specimen.
	return AABB(box.position+low,box.size+high-low).grow(0.00001)
