extends RefCounted
## Versioned, bounded Blob compound influence. No height warp or generic CSG tree.
## Five broad posed volumes form one curved tissue swath; two bores affect it only.
const SDF = preload("res://alien_foundry/scripts/geometry/SDFOperations.gd")
const COMPOSITION := "oriented_tissue_swath_v4"
const QUANTIZATION := 1000000
var valid := false
var error := ""
var size := Vector3.ONE
var local_bounds := AABB()
var profile_version := 4
var envelopes: Array[Dictionary] = []
var pores: Array[Dictionary] = []
var union_blend := 0.0
var pore_rounding := 0.0
var minimum_wall := 0.0
var arch_lift := 0.0
var _samples: Array[Dictionary] = []
var _attachment_valid := false

static func create(mark: Dictionary, scaled_radii: Vector3, require_attachment: bool = true) -> RefCounted:
	var result := new()
	result.size = scaled_radii
	result._read(mark, require_attachment)
	return result

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _numbers(value: Variant, count: int, low: float, high: float) -> bool:
	if not value is Array or value.size() != count: return false
	for v: Variant in value:
		if not _finite(v) or float(v) < low or float(v) > high: return false
	return true

static func _q(value: Variant) -> float:
	return roundf(float(value) * QUANTIZATION) / QUANTIZATION

static func _vec(value: Array) -> Vector3:
	return Vector3(_q(value[0]), _q(value[1]), _q(value[2]))

func _reject(reason: String) -> void:
	error = reason
	valid = false

func _read(mark: Dictionary, require_attachment: bool) -> void:
	if not size.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0.0: _reject("Invalid swath size."); return
	var allowed := ["enabled", "version", "composition", "coordinate_space", "envelopes", "pores", "union_blend", "pore_rounding", "minimum_wall", "maximum_lift", "attachment_contract"]
	for key: Variant in mark:
		if str(key) not in allowed: _reject("Unknown swath field: " + str(key)); return
	if mark.get("enabled") != true or mark.get("version") != 1 or mark.get("composition") != COMPOSITION or mark.get("coordinate_space") != "normalized_node_size": _reject("Invalid swath schema/version."); return
	var minimum_size := minf(size.x, minf(size.y, size.z))
	for key: String in ["union_blend", "pore_rounding", "minimum_wall", "maximum_lift"]:
		if not _finite(mark.get(key)) or float(mark[key]) <= 0.0 or float(mark[key]) > 0.45: _reject("Invalid physical swath span."); return
	union_blend = _q(mark.union_blend) * minimum_size
	pore_rounding = _q(mark.pore_rounding) * minimum_size
	minimum_wall = _q(mark.minimum_wall) * minimum_size
	arch_lift = _q(mark.maximum_lift) * minimum_size
	if not mark.get("envelopes") is Array or mark.envelopes.size() != 5: _reject("The swath requires exactly five broad posed volumes."); return
	for source: Variant in mark.envelopes:
		if not source is Dictionary or source.size() != 3 or not _numbers(source.get("center"), 3, -1.5, 1.5) or not _numbers(source.get("radii"), 3, 0.025, 1.1) or not _numbers(source.get("rotation"), 3, -PI, PI): _reject("Invalid posed tissue volume."); return
		var center := _vec(source.center) * size
		var radii := _vec(source.radii) * size
		var basis := Basis.from_euler(_vec(source.rotation))
		if radii.max_axis_index() == 2 or maxf(radii.x, radii.y) / radii.z > 12.0: _reject("A swath volume must be broad but not sub-resolution wire."); return
		envelopes.append({"center": center, "radii": radii, "basis": basis, "inverse": basis.transposed()})
	if not mark.get("pores") is Array or mark.pores.size() != 2: _reject("The prototype requires exactly two scoped bores."); return
	for source: Variant in mark.pores:
		if not source is Dictionary or source.size() != 2 or not source.get("lobes") is Array or source.lobes.is_empty() or source.lobes.size() > 2 or not _finite(source.get("blend")) or float(source.blend) < 0.0 or float(source.blend) > 0.1: _reject("Invalid scoped bore."); return
		var lobes: Array[Dictionary] = []
		for lobe: Variant in source.lobes:
			if not lobe is Dictionary or lobe.size() != 3 or not _numbers(lobe.get("center"), 2, -0.7, 0.7) or not _numbers(lobe.get("radii"), 2, 0.045, 0.45) or not _finite(lobe.get("angle")) or absf(float(lobe.angle)) > PI: _reject("Invalid bounded bore lobe."); return
			var angle := _q(lobe.angle)
			lobes.append({"center": Vector2(_q(lobe.center[0]) * size.x, _q(lobe.center[1]) * size.y), "radii": Vector2(_q(lobe.radii[0]) * size.x, _q(lobe.radii[1]) * size.y), "cos": cos(angle), "sin": sin(angle)})
		pores.append({"lobes": lobes, "blend": _q(source.blend) * minimum_size, "mouth_radius": pore_rounding, "neck_shift": 0.0})
	# Each polynomial union can lower its operands by at most k/4.
	# Bound each ellipsoid's positive isolevel conservatively before rotation.
	var reach := union_blend * float(envelopes.size() - 1) * 0.25
	for i in range(envelopes.size()):
		var e: Dictionary = envelopes[i]
		var r := _positive_isolevel_radii(e.radii, reach)
		var basis: Basis = e.basis
		var extent := basis.x.abs() * r.x + basis.y.abs() * r.y + basis.z.abs() * r.z
		var box := AABB(Vector3(e.center) - extent, extent * 2.0)
		local_bounds = box if i == 0 else local_bounds.merge(box)
	valid = true
	if mark.get("attachment_contract") is Dictionary: _read_attachment(mark.attachment_contract, minimum_size)
	if require_attachment and not _attachment_valid: _reject("The two actual broad root zones are absent or invalid.")

static func _positive_isolevel_radii(radii: Vector3, level: float) -> Vector3:
	var result := radii
	for axis in range(3):
		var other_min := minf(radii[(axis + 1) % 3], radii[(axis + 2) % 3])
		var a := 1.0 / (other_min * other_min)
		var b := 1.0 / (radii[axis] * radii[axis])
		var u := clampf(a / (2.0 * (a - b)), 0.0, 1.0) if a > b else 1.0
		var maximum := sqrt(maxf(a * u + (b - a) * u * u, 0.0))
		result[axis] += radii[axis] * level * maximum
	return result

func _read_attachment(contract: Dictionary, minimum_size: float) -> void:
	if contract.get("field_contract") != "production_authoring_v1" or contract.get("layout") != "two_flared_zones_v1" or not contract.get("samples") is Array or contract.samples.size() != 6: return
	var zones: Array = [[], []]
	var accepted: Array[Dictionary] = []
	for sample: Variant in contract.samples:
		if not sample is Dictionary or not sample.get("host_id") is String or str(sample.host_id).is_empty() or not _numbers(sample.get("local_point"), 3, -1.5, 1.5): return
		for key: String in ["required_clearance", "host_clearance", "patch_clearance", "zone"]:
			if not _finite(sample.get(key)): return
		var zone_value := float(sample.zone)
		if zone_value < 0.0 or zone_value > 1.0 or zone_value != floorf(zone_value): return
		var zone := int(zone_value)
		var p := _vec(sample.local_point) * size
		var uv := Vector2(p.x / size.x, p.y / size.y)
		var required := _q(sample.required_clearance) * minimum_size
		if required <= 0.0 or required > minimum_size * 0.25 or float(sample.host_clearance) > -float(sample.required_clearance) or float(sample.patch_clearance) > -float(sample.required_clearance): return
		if absf(uv.x) > 0.36 or absf(uv.y) < 0.72 or absf(uv.y) > 1.02 or (zone == 0 and uv.y >= 0.0) or (zone == 1 and uv.y <= 0.0): return
		if distance(p) > -required: return
		for prior: Dictionary in accepted:
			if p.distance_to(prior.local_point) < minimum_size * 0.02: return
		zones[zone].append(Vector2(p.x, p.y))
		accepted.append({"host_id": str(sample.host_id), "local_point": p, "required_clearance": required})
	for zone: Array in zones:
		if zone.size() != 3: return
		var a: Vector2 = zone[1] - zone[0]
		var b: Vector2 = zone[2] - zone[0]
		if absf(a.cross(b)) * 0.5 < minimum_wall * minimum_wall * 0.4: return
	_samples = accepted
	_attachment_valid = true

func validated_attachment_contract() -> bool:
	return valid and _attachment_valid

func attachment_samples() -> Array[Dictionary]:
	return _samples.duplicate(true)

func mid_height(uv: Vector2) -> float:
	# Interior carrier hint, found from actual posed ellipsoids. Never a height warp.
	var point := Vector3(uv.x * size.x, uv.y * size.y, 0.0)
	var best_width := -1.0
	var middle := 0.0
	for envelope: Dictionary in envelopes:
		var q: Vector3 = (envelope.inverse * (point - Vector3(envelope.center))) / Vector3(envelope.radii)
		var direction: Vector3 = (envelope.inverse * Vector3.BACK) / Vector3(envelope.radii)
		var a := direction.length_squared()
		var b := q.dot(direction)
		var discriminant := b * b - a * (q.length_squared() - 1.0)
		if discriminant < 0.0: continue
		var half_width := sqrt(discriminant) / a
		if half_width > best_width: best_width = half_width; middle = -b / a
	return middle

func gradient(point: Vector3, epsilon: float) -> Vector3:
	return Vector3(distance(point + Vector3.RIGHT * epsilon) - distance(point - Vector3.RIGHT * epsilon), distance(point + Vector3.UP * epsilon) - distance(point - Vector3.UP * epsilon), distance(point + Vector3.BACK * epsilon) - distance(point - Vector3.BACK * epsilon)) / (2.0 * epsilon)

func carrier_distance(point: Vector3) -> float:
	var tissue := 1e10
	for envelope: Dictionary in envelopes:
		var q: Vector3 = envelope.inverse * (point - Vector3(envelope.center))
		tissue = SDF.smooth_union(tissue, SDF.ellipsoid(q, envelope.radii), union_blend)
	return tissue

func distance(point: Vector3) -> float:
	var tissue := carrier_distance(point)
	for pore: Dictionary in pores:
		var bore := 1e10
		for lobe: Dictionary in pore.lobes:
			var delta := Vector2(point.x, point.y) - Vector2(lobe.center)
			var q := Vector2(lobe.cos * delta.x + lobe.sin * delta.y, -lobe.sin * delta.x + lobe.cos * delta.y)
			var r: Vector2 = lobe.radii
			var k0 := (q / r).length()
			var k1 := (q / (r * r)).length()
			var d := -minf(r.x, r.y) if k1 < 0.000001 else k0 * (k0 - 1.0) / k1
			bore = SDF.smooth_union(bore, d, pore.blend)
		# Rounded intersection of living tissue and bore exterior. Unlike a
		# capped radius-vs-depth curve, it joins the actual tissue surface C1.
		var outside_bore := -bore
		var q := Vector2(pore_rounding + tissue, pore_rounding + outside_bore).max(Vector2.ZERO)
		tissue = minf(-pore_rounding, maxf(tissue, outside_bore)) + q.length()
	return tissue
