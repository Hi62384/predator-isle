extends "res://alien_foundry/scripts/geometry/BlobPorousSwathField.gd"
## One bounded successor profile. Old posed-ellipsoid decoding is unchanged.
## Three finite oval extrusions have a real spherical outer-edge offset.
const ROUNDED_COMPOSITION := "rounded_tissue_swath_v5"
var edge_rounding := 0.0
var overlap_clearance := 0.0
var overlap_proof: Array = []

static func create(mark: Dictionary, scaled_radii: Vector3, require_attachment: bool = true) -> RefCounted:
	var result := new()
	result.size = scaled_radii
	result._read(mark, require_attachment)
	return result

func _read(mark: Dictionary, require_attachment: bool) -> void:
	if mark.get("composition") != ROUNDED_COMPOSITION: _reject("Invalid rounded-swath composition."); return
	var minimum_size := minf(size.x, minf(size.y, size.z))
	for key: String in ["edge_rounding", "overlap_clearance"]:
		if not _finite(mark.get(key)) or float(mark[key]) <= 0.0 or float(mark[key]) > 0.45: _reject("Invalid physical rounding/overlap span."); return
	edge_rounding = _q(mark.edge_rounding) * minimum_size
	overlap_clearance = _q(mark.overlap_clearance) * minimum_size
	var converted := mark.duplicate(true)
	converted.composition = COMPOSITION
	converted.erase("edge_rounding")
	converted.erase("overlap_clearance")
	converted.erase("attachment_contract")
	super._read(converted, false)
	profile_version = 5
	if not valid: return
	if overlap_clearance >= edge_rounding: _reject("Overlap ball exceeds the physical tissue rounding."); return
	for index in range(1, 4):
		var radii: Vector3 = envelopes[index].radii
		if radii.z + minimum_size * 0.000002 < edge_rounding + minimum_wall * (0.5 / 2.8) or minf(radii.x, radii.y) <= edge_rounding * 2.0:
			_reject("A rounded oval lacks a resolved core beneath its physical edge radius."); return
	# A true signed-distance positive level expands each rounded extent by
	# exactly that level. Roots retain the conservative ellipsoid bound.
	var reach := union_blend * float(envelopes.size() - 1) * 0.25
	for index in range(envelopes.size()):
		var envelope: Dictionary = envelopes[index]
		var radius: Vector3 = _positive_isolevel_radii(envelope.radii, reach) if index == 0 or index == 4 else Vector3(envelope.radii) + Vector3.ONE * reach
		var basis: Basis = envelope.basis
		var extent := basis.x.abs() * radius.x + basis.y.abs() * radius.y + basis.z.abs() * radius.z
		var box := AABB(Vector3(envelope.center) - extent, extent * 2.0)
		local_bounds = box if index == 0 else local_bounds.merge(box)
	if require_attachment:
		if not mark.get("attachment_contract") is Dictionary: _reject("Missing rounded-swath support contract."); return
		_read_attachment(mark.attachment_contract, minimum_size)
		if not _attachment_valid: _reject("Rounded support zones lack certified continuous positive overlap.")

func _read_attachment(contract: Dictionary, minimum_size: float) -> void:
	if contract.get("layout") != "two_flared_zones_v2": return
	var previous := contract.duplicate(true)
	previous.layout = "two_flared_zones_v1"
	super._read_attachment(previous, minimum_size)
	if not _attachment_valid: return
	# This version certifies these full UV triangles, not an arbitrary set of
	# six points elsewhere in a loosely named zone. Height remains host-fitted.
	var required_uvs := [Vector2(-0.22, -0.78), Vector2(0.22, -0.78), Vector2(0, -0.94), Vector2(-0.22, 0.78), Vector2(0.22, 0.78), Vector2(0, 0.94)]
	for index in range(6):
		var recorded := Vector2(contract.samples[index].local_point[0], contract.samples[index].local_point[1])
		if recorded.distance_to(required_uvs[index]) > 0.000003: _attachment_valid = false; return
	overlap_proof.clear()
	for zone in range(2):
		var proof := support_overlap(zone)
		overlap_proof.append(proof)
		if not proof.ok: _attachment_valid = false

static func _ellipse_distance(point: Vector2, radii: Vector2) -> float:
	# Closest-point Lagrange multiplier, with an analytic major-axis limit.
	# The shifted multiplier is positive, avoiding the interior pole at -b².
	var p := point.abs()
	var r := radii
	if r.x < r.y: r = Vector2(r.y, r.x); p = Vector2(p.y, p.x)
	if absf(r.x - r.y) < r.y * 0.000001: return p.length() - r.x
	var delta := r.x * r.x - r.y * r.y
	var inside: bool = (p / r).length_squared() < 1.0
	if p.y < r.y * 0.0000001:
		if p.x >= delta / r.x: return p.x - r.x
		var x := r.x * r.x * p.x / delta
		var y := r.y * sqrt(maxf(1.0 - x * x / (r.x * r.x), 0.0))
		return -p.distance_to(Vector2(x, y))
	var ax := r.x * p.x
	var by := r.y * p.y
	var s := maxf(by, ax - delta)
	for iteration in range(28):
		var x := ax / (s + delta)
		var y := by / s
		var residual := x * x + y * y - 1.0
		if absf(residual) < 0.00000001: break
		var derivative := -2.0 * (x * x / (s + delta) + y * y / s)
		s -= residual / derivative
	var closest := Vector2(r.x * ax / (s + delta), r.y * by / s)
	return p.distance_to(closest) * (-1.0 if inside else 1.0)

func positive_distance(index: int, point: Vector3) -> float:
	var envelope: Dictionary = envelopes[index]
	var q: Vector3 = envelope.inverse * (point - Vector3(envelope.center))
	var radii: Vector3 = envelope.radii
	if index == 0 or index == 4: return SDF.ellipsoid(q, radii)
	var core := radii - Vector3.ONE * edge_rounding
	var section := Vector2(_ellipse_distance(Vector2(q.x, q.y), Vector2(core.x, core.y)), absf(q.z) - core.z)
	return minf(maxf(section.x, section.y), 0.0) + section.max(Vector2.ZERO).length() - edge_rounding

func carrier_distance(point: Vector3) -> float:
	var tissue := 1e10
	for index in range(envelopes.size()): tissue = SDF.smooth_union(tissue, positive_distance(index, point), union_blend)
	return tissue

func root_ball_clearance(index: int, point: Vector3) -> float:
	var envelope: Dictionary = envelopes[index]
	var radii: Vector3 = envelope.radii
	var q: Vector3 = envelope.inverse * (point - Vector3(envelope.center))
	# The ellipsoid norm is 1/min_radius-Lipschitz. This lower bound
	# certifies the entire ball, unlike the approximate ellipsoid SDF.
	return (1.0 - (q / radii).length()) * minf(radii.x, minf(radii.y, radii.z))

func positive_interval(index: int, xy: Vector2, inset: float = 0.0) -> Array:
	var envelope: Dictionary = envelopes[index]
	var radii: Vector3 = envelope.radii
	var origin := Vector3(xy.x, xy.y, 0.0)
	var q: Vector3 = envelope.inverse * (origin - Vector3(envelope.center))
	var direction: Vector3 = envelope.inverse * Vector3.BACK
	if index == 0 or index == 4:
		# Analytic eroded ellipsoid contained in the exact clearance-ball set.
		var scale_factor := 1.0 - inset / minf(radii.x, minf(radii.y, radii.z))
		if scale_factor <= 0.0: return []
		var eroded := radii * scale_factor
		q /= eroded; direction /= eroded
		var a := direction.length_squared()
		var b := q.dot(direction)
		var discriminant := b * b - a * (q.length_squared() - 1.0)
		if discriminant < 0.0: return []
		return [(-b - sqrt(discriminant)) / a, (-b + sqrt(discriminant)) / a]
	var basis: Basis = envelope.basis
	var half := absf(basis.x.z) * radii.x + absf(basis.y.z) * radii.y + absf(basis.z.z) * radii.z
	var low := float(envelope.center.z) - half
	var high := float(envelope.center.z) + half
	var middle := clampf(-q.z / direction.z, low, high) if absf(direction.z) > 0.00001 else (low + high) * 0.5
	if positive_distance(index, origin + Vector3.BACK * middle) > -inset:
		var left := low; var right := high
		for iteration in range(14):
			var a := lerpf(left, right, 1.0 / 3.0)
			var b := lerpf(left, right, 2.0 / 3.0)
			if positive_distance(index, origin + Vector3.BACK * a) < positive_distance(index, origin + Vector3.BACK * b): right = b
			else: left = a
		middle = (left + right) * 0.5
	if positive_distance(index, origin + Vector3.BACK * middle) > -inset: return []
	var back := low; var front := middle
	for iteration in range(18):
		var value := (back + front) * 0.5
		if positive_distance(index, origin + Vector3.BACK * value) <= -inset: front = value
		else: back = value
	var lower := front
	back = middle; front = high
	for iteration in range(18):
		var value := (back + front) * 0.5
		if positive_distance(index, origin + Vector3.BACK * value) <= -inset: back = value
		else: front = value
	return [lower, back]

func mid_height(uv: Vector2) -> float:
	var xy := uv * Vector2(size.x, size.y)
	var width := -1.0
	var middle := 0.0
	for index in range(envelopes.size()):
		var interval := positive_interval(index, xy)
		if interval.size() == 2 and float(interval[1]) - float(interval[0]) > width:
			width = float(interval[1]) - float(interval[0]); middle = (float(interval[0]) + float(interval[1])) * 0.5
	return middle

func support_overlap(zone: int, subdivisions: int = 0) -> Dictionary:
	var cell := minimum_wall / 2.8
	var sign_value := -1.0 if zone == 0 else 1.0
	var a := Vector2(-0.22 * size.x, sign_value * 0.78 * size.y)
	var b := Vector2(0.22 * size.x, sign_value * 0.78 * size.y)
	var c := Vector2(0.0, sign_value * 0.94 * size.y)
	var longest := maxf(a.distance_to(b), maxf(a.distance_to(c), b.distance_to(c)))
	var count := subdivisions if subdivisions > 0 else clampi(ceili(longest / (cell * 0.32)), 4, 40)
	var root_index := 0 if zone == 0 else 4
	var inner_index := 1 if zone == 0 else 3
	var witnesses: Array = []
	var grid: Dictionary = {}
	var minimum_clearance := INF
	var maximum_edge := 0.0
	for i in range(count + 1):
		for j in range(count + 1 - i):
			var xy := a + (b - a) * (float(i) / count) + (c - a) * (float(j) / count)
			var root := positive_interval(root_index, xy, overlap_clearance)
			var inner := positive_interval(inner_index, xy, overlap_clearance)
			if root.is_empty() or inner.is_empty(): return {"ok": false, "zone": zone, "uv": [xy.x / size.x, xy.y / size.y], "reason": "A raw positive support section has no clearance-ball interval.", "root_interval": root, "inner_interval": inner}
			var low: float = maxf(root[0], inner[0])
			var high: float = minf(root[1], inner[1])
			if low > high: return {"ok": false, "zone": zone, "uv": [xy.x / size.x, xy.y / size.y], "reason": "Raw root and bridge clearance-ball intervals do not overlap.", "gap": low - high, "root_interval": root, "inner_interval": inner}
			var point := Vector3(xy.x, xy.y, (low + high) * 0.5)
			var clearance := minf(root_ball_clearance(root_index, point), -positive_distance(inner_index, point))
			if distance(point) > -overlap_clearance: return {"ok": false, "zone": zone, "reason": "A scoped pore cuts the certified positive overlap.", "point": [point.x, point.y, point.z]}
			minimum_clearance = minf(minimum_clearance, clearance)
			grid[Vector2i(i, j)] = point
			witnesses.append(point)
	for key: Vector2i in grid:
		for delta: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, -1)]:
			if grid.has(key + delta): maximum_edge = maxf(maximum_edge, Vector3(grid[key]).distance_to(Vector3(grid[key + delta])))
	# The convex hull of each witness triangle is covered by the clearance
	# balls when all its edges are <=.75 cell and ball radius >=.5 cell.
	var covered := subdivisions > 0 or maximum_edge <= cell * 0.75
	return {"ok": covered, "zone": zone, "subdivisions": count, "witness_count": witnesses.size(), "minimum_clearance": minimum_clearance, "maximum_edge": maximum_edge, "clearance_ball_radius": overlap_clearance, "coverage": "piecewise-linear witness triangles covered by conservative interior balls", "witnesses": witnesses}

func support_height_interval(zone: int) -> Dictionary:
	# Translating a root by dz translates both endpoints of every eroded
	# vertical interval by dz. Intersect all interval inequalities directly.
	var cell := minimum_wall / 2.8
	var sign_value := -1.0 if zone == 0 else 1.0
	var a := Vector2(-0.22 * size.x, sign_value * 0.78 * size.y)
	var b := Vector2(0.22 * size.x, sign_value * 0.78 * size.y)
	var c := Vector2(0.0, sign_value * 0.94 * size.y)
	var longest := maxf(a.distance_to(b), maxf(a.distance_to(c), b.distance_to(c)))
	var count := clampi(ceili(longest / (cell * 0.32)), 4, 40)
	var root_index := 0 if zone == 0 else 4
	var inner_index := 1 if zone == 0 else 3
	var minimum_shift := -INF
	var maximum_shift := INF
	var limiting_uv := Vector2.ZERO
	var witnesses := 0
	for i in range(count + 1):
		for j in range(count + 1 - i):
			var xy := a + (b - a) * (float(i) / count) + (c - a) * (float(j) / count)
			var root := positive_interval(root_index, xy, overlap_clearance)
			var inner := positive_interval(inner_index, xy, overlap_clearance)
			if root.is_empty() or inner.is_empty(): return {"ok": false, "zone": zone, "reason": "No vertical root translation can create the required raw clearance-ball section.", "uv": [xy.x / size.x, xy.y / size.y]}
			var required: float = float(inner[0]) - float(root[1])
			if required > minimum_shift: minimum_shift = required; limiting_uv = xy / Vector2(size.x, size.y)
			maximum_shift = minf(maximum_shift, float(inner[1]) - float(root[0]))
			witnesses += 1
	return {"ok": minimum_shift <= maximum_shift, "zone": zone, "required_shift": maxf(minimum_shift, 0.0), "maximum_feasible_shift": maximum_shift, "limiting_uv": [limiting_uv.x, limiting_uv.y], "witnesses": witnesses}
