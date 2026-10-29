extends RefCounted
## A single closed height-loft, not a union of masses or a bent capsule.
## The inverse map is triangular: y is unchanged, positive widths guarantee
## one-to-one sections, even when the x/z centerline leans and changes slope.
## All authored coefficients are dimensionless and persist inside node.shape.
const KEY := "mantle_envelope"
const KNOT_COUNT := 7
var valid := false
var radii := Vector3.ONE
var knots: Array[Vector4] = []
var slopes: Array[Vector4] = []
var local_bounds := AABB()

static func marked(node: Dictionary) -> bool:
	return node.get("shape", {}).has(KEY)

static func valid_descriptor(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	if not value.has("version") or not value.has("sections"): return false
	if not _number(value.version) or float(value.version) != 1.0: return false
	if not value.sections is Array or value.sections.size() != KNOT_COUNT: return false
	for section in value.sections:
		if not section is Array or section.size() != 4: return false
		for v in section:
			if not _number(v): return false
		if absf(float(section[0])) > 0.8 or absf(float(section[1])) > 0.8: return false
		if float(section[2]) < 0.30 or float(section[2]) > 1.40: return false
		if float(section[3]) < 0.30 or float(section[3]) > 1.20: return false
	return true

static func valid_host(dna: Dictionary, item: Dictionary, buttress: bool = false) -> bool:
	if str(dna.get("type",""))!="Blob" or str(item.get("operation","union"))!="union": return false
	if not _number(item.get("pipeline_stage")) or float(item.pipeline_stage)!=1.0: return false
	if str(item.get("kind","")) != ("curve" if buttress else "mass"): return false
	if str(item.get("role","")) != ("limb" if buttress else "core"): return false
	if not _number(item.get("noise")) or float(item.noise)!=0.0: return false
	if item.has("porous_patch"): return false
	var points: Variant = item.get("points",[])
	if not points is Array or (not buttress and not points.is_empty()): return false
	var shape: Dictionary = item.get("shape",{})
	var allowed: Array = ["mantle_buttress_version","swelling","twist","width","depth","width_profile","depth_profile"] if buttress else ["mantle_envelope"]
	for key in shape:
		if key not in allowed: return false
	if not buttress: return valid_descriptor(shape.get(KEY))
	if not _number(shape.get("mantle_buttress_version")) or float(shape.mantle_buttress_version)!=1.0 or points.size()!=4: return false
	for key in ["swelling","twist"]:
		if not _number(shape.get(key)) or float(shape[key])!=0.0: return false
	for key in ["width","depth"]:
		if not _number(shape.get(key)) or float(shape[key])<0.5 or float(shape[key])>1.5: return false
	for key in ["width_profile","depth_profile"]:
		var values: Variant = shape.get(key)
		if not values is Array or values.size()!=4: return false
		for value in values:
			if not _number(value) or float(value)<0.5 or float(value)>1.5: return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func create(descriptor: Dictionary, size: Vector3) -> RefCounted:
	var field = load("res://alien_foundry/scripts/geometry/BlobMantleField.gd").new()
	field.radii = size
	if not valid_descriptor(descriptor) or not size.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0.0: return field
	for row in descriptor.sections: field.knots.append(Vector4(float(row[0]), float(row[1]), float(row[2]), float(row[3])))
	for i in range(KNOT_COUNT):
		var slope := Vector4.ZERO
		for c in range(4):
			if i == 0: slope[c] = field.knots[1][c] - field.knots[0][c]
			elif i == KNOT_COUNT - 1: slope[c] = field.knots[-1][c] - field.knots[-2][c]
			else:
				var a: float = field.knots[i][c] - field.knots[i - 1][c]
				var b: float = field.knots[i + 1][c] - field.knots[i][c]
				slope[c] = 2.0 * a * b / (a + b) if a * b > 0.0 else 0.0
		field.slopes.append(slope)
	# A monotone cubic stays in each pair's endpoint range. The sphere's
	# radial factor is <= 1, so these interval bounds are conservative.
	var low := Vector3(INF, -size.y, INF)
	var high := Vector3(-INF, size.y, -INF)
	for i in range(KNOT_COUNT - 1):
		var a: Vector4 = field.knots[i]; var b: Vector4 = field.knots[i + 1]
		var t0 := float(i) / 6.0; var t1 := float(i + 1) / 6.0
		var nearest := clampf(0.5, t0, t1)
		var cap := sqrt(maxf(0.0, 1.0 - pow(nearest * 2.0 - 1.0, 2.0)))
		low.x = minf(low.x, (minf(a.x, b.x) - maxf(a.z, b.z) * cap) * size.x)
		high.x = maxf(high.x, (maxf(a.x, b.x) + maxf(a.z, b.z) * cap) * size.x)
		low.z = minf(low.z, (minf(a.y, b.y) - maxf(a.w, b.w) * cap) * size.z)
		high.z = maxf(high.z, (maxf(a.y, b.y) + maxf(a.w, b.w) * cap) * size.z)
	field.local_bounds = AABB(low, high - low)
	field.valid = true
	return field

func section(t: float, derivative: bool = false) -> Vector4:
	var f := clampf(t, 0.0, 1.0) * 6.0
	var i := mini(floori(f), 5); var u := f - float(i)
	var a := knots[i]; var b := knots[i + 1]; var m := slopes[i]; var n := slopes[i + 1]
	if derivative:
		if t < 0.0 or t > 1.0: return Vector4.ZERO
		return ((6.0*u*u-6.0*u)*a + (3.0*u*u-4.0*u+1.0)*m + (-6.0*u*u+6.0*u)*b + (3.0*u*u-2.0*u)*n) * 6.0
	return (2.0*u*u*u-3.0*u*u+1.0)*a + (u*u*u-2.0*u*u+u)*m + (-2.0*u*u*u+3.0*u*u)*b + (u*u*u-u*u)*n

func level_gradient(point: Vector3) -> Vector4:
	var u := point.y / radii.y; var t := (u + 1.0) * 0.5
	var s := section(t); var ds := section(t, true) / (2.0 * radii.y)
	var x := (point.x / radii.x - s.x) / s.z
	var z := (point.z / radii.z - s.y) / s.w
	var gx := 2.0 * x / (radii.x * s.z)
	var gz := 2.0 * z / (radii.z * s.w)
	var gy := 2.0 * u / radii.y - 2.0*x*(ds.x+x*ds.z)/s.z - 2.0*z*(ds.y+z*ds.w)/s.w
	return Vector4(gx, gy, gz, x*x + z*z + u*u - 1.0)

func distance(point: Vector3) -> float:
	var value := level_gradient(point)
	var gradient := Vector3(value.x, value.y, value.z).length()
	# First-order world-distance field at the zero set; finite interior branch.
	# It is not claimed to be an exact global Euclidean signed distance.
	return value.w / gradient if gradient > 0.0000001 else -minf(radii.x,minf(radii.y,radii.z))

func surface(t: float, angle: float) -> Vector3:
	var s := section(t); var u := t * 2.0 - 1.0
	var cap := sqrt(maxf(0.0, 1.0 - u*u))
	return Vector3((s.x + cos(angle)*s.z*cap)*radii.x, u*radii.y, (s.y + sin(angle)*s.w*cap)*radii.z)

func centerline(t: float) -> Vector3:
	var s := section(t)
	return Vector3(s.x*radii.x, (t*2.0-1.0)*radii.y, s.y*radii.z)

func mapping_determinant(t: float) -> float:
	var s := section(t)
	return radii.x * radii.y * radii.z * s.z * s.w
