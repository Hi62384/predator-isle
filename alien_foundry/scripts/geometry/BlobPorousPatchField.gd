extends RefCounted
## Blob-only compound tissue influence. Local voids subtract from this influence,
## never from the host. All authored data is normalized to the owning node.size.
## The 5x5 host-height grid is quantized to 1e-6 of size.z and interpolated with
## tensor Catmull-Rom cubics. There are no bilinear seams or texture/noise details.
const RoundedSwath = preload("res://alien_foundry/scripts/geometry/BlobRoundedSwathField.gd")
const Swath = preload("res://alien_foundry/scripts/geometry/BlobPorousSwathField.gd")
const SDF = preload("res://alien_foundry/scripts/geometry/SDFOperations.gd")
const QUANTIZATION := 1000000
const COMPOSITION := "two_zone_saddle_tissue_v3"
const DISK_COMPOSITION := "curved_compound_tissue_v2"
const LEGACY_COMPOSITION := "curved_compound_tissue_v1"
const MAX_ENVELOPES := 3
const MAX_PORES := 3
var valid := false
var error := ""
var local_bounds := AABB()
var size := Vector3.ONE
var height_values: Array[float] = []
var envelopes: Array[Dictionary] = []
var pores: Array[Dictionary] = []
var union_blend := 0.0
var pore_rounding := 0.0
var arch_lift := 0.0
var root_bury := 0.0
var minimum_wall := 0.0
var profile_version := 1
var arch_metric := Vector3(1, 0, 1)
var arch_center := Vector2.ZERO
var _samples: Array[Dictionary] = []
var _attachment_valid := false

static func create(mark: Dictionary, scaled_radii: Vector3, require_attachment: bool = true) -> RefCounted:
	if mark.get("composition") == RoundedSwath.ROUNDED_COMPOSITION:
		return RoundedSwath.create(mark, scaled_radii, require_attachment)
	if mark.get("composition") == Swath.COMPOSITION:
		return Swath.create(mark, scaled_radii, require_attachment)
	var result := new()
	result.size = scaled_radii
	result._read(mark, require_attachment)
	return result

static func _finite(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _numbers(value: Variant, count: int, lower: float, upper: float) -> bool:
	if not value is Array or value.size() != count: return false
	for number: Variant in value:
		if not _finite(number) or float(number) < lower or float(number) > upper: return false
	return true

static func _q(value: Variant) -> float:
	return roundf(float(value) * QUANTIZATION) / QUANTIZATION

func _reject(reason: String) -> void:
	error = reason
	valid = false

func _read(mark: Dictionary, require_attachment: bool) -> void:
	if not size.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0.0:
		_reject("Invalid owning node size."); return
	profile_version = 3 if mark.get("composition") == COMPOSITION else (2 if mark.get("composition") == DISK_COMPOSITION else 1)
	var allowed := ["enabled", "version", "composition", "coordinate_space", "height_resolution", "height_quantization", "height_q", "envelopes", "pores", "union_blend", "pore_rounding", "arch_lift", "root_bury", "minimum_wall", "attachment_contract"]
	if profile_version == 2: allowed.append_array(["arch_metric", "arch_center"])
	for key: Variant in mark:
		if str(key) not in allowed: _reject("Unknown compound patch schema field: " + str(key)); return
	if mark.get("enabled") != true or mark.get("version") != 1 or mark.get("composition") not in [COMPOSITION, DISK_COMPOSITION, LEGACY_COMPOSITION] or mark.get("coordinate_space") != "normalized_node_size":
		_reject("Unsupported compound patch marker."); return
	if mark.get("height_resolution") != 5 or mark.get("height_quantization") != QUANTIZATION or not _numbers(mark.get("height_q"), 25, -1250000, 1250000):
		_reject("The host-height grid must contain exactly 25 bounded quantized heights."); return
	if profile_version == 2:
		if not _numbers(mark.get("arch_metric"), 3, -1.75, 1.75) or not _numbers(mark.get("arch_center"), 2, -0.25, 0.25):
			_reject("Invalid asymmetric arch profile."); return
		arch_metric = Vector3(_q(mark.arch_metric[0]), _q(mark.arch_metric[1]), _q(mark.arch_metric[2]))
		arch_center = Vector2(_q(mark.arch_center[0]), _q(mark.arch_center[1]))
		if arch_metric.x < 0.5 or arch_metric.z < 0.5 or absf(arch_metric.y) > 0.45 or arch_metric.x * arch_metric.z - arch_metric.y * arch_metric.y < 0.12:
			_reject("The arch metric must be bounded positive definite."); return
	var minimum_size := minf(size.x, minf(size.y, size.z))
	for height: Variant in mark.height_q:
		if float(height) != roundf(float(height)): _reject("Host heights must be quantized integers."); return
		height_values.append(float(height) / QUANTIZATION * size.z)
	for key: String in ["union_blend", "pore_rounding", "arch_lift", "root_bury", "minimum_wall"]:
		if not _finite(mark.get(key)) or float(mark[key]) <= 0.0 or float(mark[key]) > 0.85: _reject("Invalid bounded patch length: " + key); return
	union_blend = _q(mark.union_blend) * minimum_size
	pore_rounding = _q(mark.pore_rounding) * minimum_size
	arch_lift = _q(mark.arch_lift) * size.z
	root_bury = _q(mark.root_bury) * size.z
	minimum_wall = _q(mark.minimum_wall) * minimum_size
	if not mark.get("envelopes") is Array or mark.envelopes.size() != MAX_ENVELOPES:
		_reject("Exactly three bounded tissue envelopes are required."); return
	for source: Variant in mark.envelopes:
		if not source is Dictionary or not _numbers(source.get("center"), 3, -0.65, 0.65) or not _numbers(source.get("radii"), 3, 0.025, 1.1) or not _finite(source.get("angle")) or absf(float(source.angle)) > PI:
			_reject("Invalid tissue envelope."); return
		var center := Vector3(_q(source.center[0]), _q(source.center[1]), _q(source.center[2])) * size
		var radii := Vector3(_q(source.radii[0]), _q(source.radii[1]), _q(source.radii[2])) * size
		var angle := _q(source.angle)
		envelopes.append({"center": center, "radii": radii, "cos": cos(angle), "sin": sin(angle)})
	if not mark.get("pores") is Array or mark.pores.size() != (2 if profile_version == 3 else MAX_PORES):
		_reject("The versioned profile requires its exact scoped pore count."); return
	for source: Variant in mark.pores:
		if not source is Dictionary or not source.get("lobes") is Array or source.lobes.is_empty() or source.lobes.size() > 2 or not _finite(source.get("blend")) or float(source.blend) < 0.0 or float(source.blend) > 0.10:
			_reject("Invalid scoped pore profile."); return
		var lobes: Array[Dictionary] = []
		for lobe: Variant in source.lobes:
			if not lobe is Dictionary or not _numbers(lobe.get("center"), 2, -0.65, 0.65) or not _numbers(lobe.get("radii"), 2, 0.045, 0.40) or not _finite(lobe.get("angle")) or absf(float(lobe.angle)) > PI:
				_reject("Invalid elliptical pore lobe."); return
			var angle := _q(lobe.angle)
			lobes.append({"center": Vector2(_q(lobe.center[0]) * size.x, _q(lobe.center[1]) * size.y), "radii": Vector2(_q(lobe.radii[0]) * size.x, _q(lobe.radii[1]) * size.y), "cos": cos(angle), "sin": sin(angle)})
		var pore := {"lobes": lobes, "blend": _q(source.blend) * minimum_size, "flare_front": 0.0, "flare_back": 0.0, "flare_depth": size.z, "mouth_radius": 0.0, "neck_shift": 0.0}
		if profile_version == 2:
			for key: String in ["flare_front", "flare_back", "flare_depth"]:
				if not _finite(source.get(key)) or float(source[key]) < 0.0 or float(source[key]) > 0.45:
					_reject("Invalid bounded pore flare."); return
			if float(source.flare_depth) < 0.06: _reject("A pore flare requires finite normal depth."); return
			pore.flare_front = _q(source.flare_front)
			pore.flare_back = _q(source.flare_back)
			pore.flare_depth = _q(source.flare_depth) * size.z
		if profile_version == 3:
			for key: String in ["mouth_radius", "neck_shift"]:
				if not _finite(source.get(key)) or float(source[key]) <= 0.0 or float(source[key]) > 0.35:
					_reject("Invalid absolute circular mouth profile."); return
			pore.mouth_radius = _q(source.mouth_radius) * minimum_size
			pore.neck_shift = _q(source.neck_shift) * minimum_size
			if pore.neck_shift > pore.mouth_radius * 0.4: _reject("Neck shift exceeds the bounded mouth profile."); return
		pores.append(pore)
	# Two cubic passes have bounded overshoot below half the full sample range.
	var low: float = height_values.min()
	var high: float = height_values.max()
	var overshoot := (high - low) * 0.5
	var first := true
	for envelope: Dictionary in envelopes:
		var r: Vector3 = envelope.radii
		var planar := Vector3(absf(envelope.cos) * r.x + absf(envelope.sin) * r.y, absf(envelope.sin) * r.x + absf(envelope.cos) * r.y, r.z)
		var box := AABB(envelope.center - planar, planar * 2.0)
		if first: local_bounds = box; first = false
		else: local_bounds = local_bounds.merge(box)
	local_bounds.position.z += low - overshoot - root_bury
	local_bounds.size.z += high - low + overshoot * 2.0 + arch_lift + root_bury
	local_bounds = local_bounds.grow(union_blend * MAX_ENVELOPES)
	valid = true
	if mark.get("attachment_contract") is Dictionary: _read_attachment(mark.attachment_contract, minimum_size)
	if require_attachment and not _attachment_valid: _reject("The six-margin attachment contract is absent, malformed, or not genuinely inside the patch.")

func _read_attachment(contract: Dictionary, minimum_size: float) -> void:
	if contract.get("field_contract") != "production_authoring_v1" or not contract.get("samples") is Array or contract.samples.size() != 6: return
	if profile_version == 3 and contract.get("layout") != "two_flared_zones_v1": return
	var accepted: Array[Dictionary] = []
	var zones: Array = [[], []]
	var sectors: Dictionary = {}
	for sample: Variant in contract.samples:
		if not sample is Dictionary or str(sample.get("host_id", "")).is_empty() or not _numbers(sample.get("local_point"), 3, -2.5, 2.5): return
		for key: String in ["required_clearance", "host_clearance", "patch_clearance"]:
			if not _finite(sample.get(key)) or absf(float(sample[key])) > 5.0: return
		var required := _q(sample.required_clearance) * minimum_size
		if required <= 0.0 or required > minimum_size * 0.25: return
		if float(sample.host_clearance) > -float(sample.required_clearance) or float(sample.patch_clearance) > -float(sample.required_clearance): return
		var p := Vector3(_q(sample.local_point[0]), _q(sample.local_point[1]), _q(sample.local_point[2])) * size
		var uv := Vector2(p.x / size.x, p.y / size.y)
		if profile_version == 3:
			var raw_zone: Variant = sample.get("zone")
			# JSON decodes numeric IDs as floats; accept exactly integral 0/1, never truncation.
			if not _finite(raw_zone) or float(raw_zone) < 0.0 or float(raw_zone) > 1.0 or float(raw_zone) != floorf(float(raw_zone)): return
			var zone := int(raw_zone)
			if zone not in [0, 1] or absf(uv.x) > 0.36 or absf(uv.y) < 0.72 or absf(uv.y) > 1.02: return
			if (zone == 0 and uv.y >= 0.0) or (zone == 1 and uv.y <= 0.0): return
			zones[zone].append(Vector2(p.x, p.y))
		else:
			if uv.length() < 0.68 or uv.length() > 1.10: return
			var sector := posmod(floori((atan2(uv.y, uv.x) + PI) / (TAU / 6.0)), 6)
			if sectors.has(sector): return
			sectors[sector] = true
		if distance(p) > -required: return
		accepted.append({"host_id": str(sample.host_id), "local_point": p, "required_clearance": required})
	if profile_version == 3:
		for zone: Array in zones:
			if zone.size() != 3: return
			var edge_a: Vector2 = zone[1] - zone[0]
			var edge_b: Vector2 = zone[2] - zone[0]
			if absf(edge_a.cross(edge_b)) * 0.5 < minimum_wall * minimum_wall * 0.4: return
	_samples = accepted
	_attachment_valid = true

func validated_attachment_contract() -> bool:
	return valid and _attachment_valid

func attachment_samples() -> Array[Dictionary]:
	return _samples.duplicate(true)

static func _cubic(a: float, b: float, c: float, d: float, t: float) -> float:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)

func host_height(uv: Vector2) -> float:
	var grid := (uv * 0.5 + Vector2.ONE * 0.5).clamp(Vector2.ZERO, Vector2.ONE) * 4.0
	var ix := mini(floori(grid.x), 3)
	var iy := mini(floori(grid.y), 3)
	var values: Array[float] = []
	for y in range(iy - 1, iy + 3):
		var row := clampi(y, 0, 4) * 5
		values.append(_cubic(height_values[row + clampi(ix - 1, 0, 4)], height_values[row + ix], height_values[row + ix + 1], height_values[row + clampi(ix + 2, 0, 4)], grid.x - ix))
	return _cubic(values[0], values[1], values[2], values[3], grid.y - iy)

func mid_height(uv: Vector2) -> float:
	if profile_version == 3:
		# A flat-topped, low asymmetric saddle. Only two end zones are buried;
		# mid-span side margins remain free and cannot form an attached disk.
		var rise := 1.0 - smoothstep(0.52, 0.84, absf(uv.y))
		var asymmetric := 0.92 + 0.08 * clampf(uv.x, -1.0, 1.0)
		return host_height(uv) + arch_lift * rise * asymmetric - root_bury * smoothstep(0.64, 0.87, absf(uv.y))
	var radius := uv.length()
	# Keep the exact original arithmetic for archived V3 descriptors.
	var interior := maxf(1.0 - radius * radius, 0.0)
	if profile_version == 2:
		var offset := uv - arch_center
		var squared := arch_metric.x * offset.x * offset.x + 2.0 * arch_metric.y * offset.x * offset.y + arch_metric.z * offset.y * offset.y
		interior = maxf(1.0 - squared, 0.0)
	return host_height(uv) + arch_lift * interior * interior - root_bury * smoothstep(0.52, 0.84, radius)

func distance(local_point: Vector3) -> float:
	var p := local_point
	p.z -= mid_height(Vector2(p.x / size.x, p.y / size.y))
	var tissue := 1e10
	for envelope: Dictionary in envelopes:
		var q: Vector3 = p - envelope.center
		q = Vector3(envelope.cos * q.x + envelope.sin * q.y, -envelope.sin * q.x + envelope.cos * q.y, q.z)
		tissue = SDF.smooth_union(tissue, SDF.ellipsoid(q, envelope.radii), union_blend)
	for pore: Dictionary in pores:
		var void_distance := 1e10
		for lobe: Dictionary in pore.lobes:
			var delta := Vector2(p.x, p.y) - Vector2(lobe.center)
			var q := Vector2(lobe.cos * delta.x + lobe.sin * delta.y, -lobe.sin * delta.x + lobe.cos * delta.y)
			var radii: Vector2 = lobe.radii
			if profile_version == 2:
				# Quarter-ellipse depth profile, not a sharp conical widening.
				# The central neck remains finite; the mouth bends toward the
				# membrane surface across a bounded normal span.
				var depth := clampf(absf(p.z) / float(pore.flare_depth), 0.0, 1.0)
				var flare := float(pore.flare_front if p.z >= 0.0 else pore.flare_back)
				radii *= 1.0 + flare * (1.0 - sqrt(maxf(1.0 - depth * depth, 0.0)))
			if profile_version == 3:
				# Add an absolute circular-arc mouth displacement, not a percentage
				# of a small pore. The throat is slightly behind the mid surface.
				var depth := p.z + float(pore.neck_shift)
				var radius := float(pore.mouth_radius) * (1.0 if depth >= 0.0 else 0.55)
				var travel := minf(absf(depth), radius)
				var offset := radius - sqrt(maxf(radius * radius - travel * travel, 0.0))
				radii += Vector2.ONE * offset
			var k0 := (q / radii).length()
			var k1 := (q / (radii * radii)).length()
			var d := -minf(radii.x, radii.y) if k1 < 0.000001 else k0 * (k0 - 1.0) / k1
			void_distance = SDF.smooth_union(void_distance, d, pore.blend)
		tissue = SDF.smooth_subtraction(tissue, void_distance, pore_rounding)
	return tissue
