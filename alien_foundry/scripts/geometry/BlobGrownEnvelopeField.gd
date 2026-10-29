extends RefCounted
## One bounded primary envelope, not a union of lobes or a height/ellipse loft.
## Six smooth angular pressure patches deform one radial zero set. Three add
## unequal macro loads and three recess directional folds. A positive radial
## lower bound proves a single sphere-topology surface before a monotone Y map.
const KEY := "grown_envelope"
const PATCH_COUNT := 6
const GATE_WIDTH := 0.50
const COMPRESSION_SOFTNESS := 0.25
var valid := false
var radii := Vector3.ONE
var compression := 0.62
var patches: Array = []
var minimum_radius := 1.0
var maximum_radius := 1.0
var local_bounds := AABB()

static func marked(node: Dictionary) -> bool:
	return node.get("shape", {}).has(KEY)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_descriptor(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3: return false
	if not _number(value.get("version")) or float(value.version) != 1.0: return false
	if not _number(value.get("compression")) or float(value.compression) < 0.5 or float(value.compression) > 1.0: return false
	if not value.get("patches") is Array or value.patches.size() != PATCH_COUNT: return false
	var positive := 0.0; var negative := 0.0
	for i in range(PATCH_COUNT):
		var row: Variant = value.patches[i]
		if not row is Array or row.size() != 9: return false
		for v in row:
			if not _number(v): return false
		var direction := Vector3(float(row[0]), float(row[1]), float(row[2]))
		var tangent := Vector3(float(row[3]), float(row[4]), float(row[5]))
		if direction.length() < 0.5 or direction.length() > 2.0 or tangent.length() < 0.5 or tangent.length() > 2.0: return false
		if direction.normalized().cross(tangent.normalized()).length() < 0.30: return false
		for j in [6, 7]:
			if float(row[j]) < 0.18 or float(row[j]) > 1.05: return false
		var amplitude := float(row[8])
		if (i < 3 and (amplitude < 0.05 or amplitude > 0.55)) or (i >= 3 and (amplitude > -0.05 or amplitude < -0.40)): return false
		positive += maxf(amplitude, 0.0); negative += maxf(-amplitude, 0.0)
	return positive <= 1.25 and negative <= 0.82

static func valid_host(dna: Dictionary, node: Dictionary) -> bool:
	if str(dna.get("type", "")) != "Blob" or str(node.get("kind", "")) != "mass" or str(node.get("role", "")) != "core": return false
	if str(node.get("operation", "union")) != "union": return false
	if not _number(node.get("pipeline_stage")) or float(node.pipeline_stage) != 1.0: return false
	if not _number(node.get("noise")) or float(node.noise) != 0.0: return false
	if node.has("porous_patch") or not node.get("points", []) is Array or not node.get("points", []).is_empty(): return false
	# Match the production volume's legacy minimum-radius domain exactly.
	# Smaller marked hosts are rejected, never silently enlarged on replay.
	var size: Variant = node.get("size")
	if not size is Array or size.size() != 3: return false
	for axis in size:
		if not _number(axis) or float(axis) < 0.006: return false
	var shape: Dictionary = node.get("shape", {})
	return shape.size() == 1 and valid_descriptor(shape.get(KEY))

static func create(descriptor: Dictionary, size: Vector3) -> RefCounted:
	var field = load("res://alien_foundry/scripts/geometry/BlobGrownEnvelopeField.gd").new()
	if not valid_descriptor(descriptor) or not size.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0.0: return field
	field.radii = size
	field.compression = float(descriptor.compression)
	for row in descriptor.patches:
		var direction := Vector3(float(row[0]), float(row[1]), float(row[2])).normalized()
		var along := Vector3(float(row[3]), float(row[4]), float(row[5]))
		along = (along - direction * along.dot(direction)).normalized()
		var across := direction.cross(along).normalized()
		var amplitude := float(row[8])
		field.patches.append({"direction": direction, "along": along, "across": across,
			"across_inverse_squared": 1.0 / pow(float(row[6]), 2.0), "along_inverse_squared": 1.0 / pow(float(row[7]), 2.0), "amplitude": amplitude})
		field.minimum_radius += minf(amplitude, 0.0)
		field.maximum_radius += maxf(amplitude, 0.0)
	# Every patch is in [0,1], so these are conservative analytic bounds,
	# deliberately independent of sampling resolution or authoring seed.
	var extent: float = field.maximum_radius
	var low := Vector3(-extent * size.x, field.compress_y(-extent) * size.y, -extent * size.z)
	var high := Vector3(extent * size.x, field.compress_y(extent) * size.y, extent * size.z)
	field.local_bounds = AABB(low, high - low)
	field.valid = true
	return field

func compress_y(y: float) -> float:
	var a := (1.0 + compression) * 0.5; var b := (1.0 - compression) * 0.5
	return a * y + b * (sqrt(y*y + COMPRESSION_SOFTNESS*COMPRESSION_SOFTNESS) - COMPRESSION_SOFTNESS)

func uncompress_y(y: float) -> float:
	var a := (1.0 + compression) * 0.5; var b := (1.0 - compression) * 0.5
	var t := y + b * COMPRESSION_SOFTNESS
	return (a*t - b*sqrt(t*t + compression*COMPRESSION_SOFTNESS*COMPRESSION_SOFTNESS)) / compression

func radial_gradient(direction: Vector3) -> Vector4:
	var radius := 1.0; var gradient := Vector3.ZERO
	for patch: Dictionary in patches:
		var across: Vector3 = patch.across; var along: Vector3 = patch.along; var axis: Vector3 = patch.direction
		var x: float = direction.dot(across); var y: float = direction.dot(along); var back: float = direction.dot(axis) - 1.0
		var q: float = x*x*float(patch.across_inverse_squared) + y*y*float(patch.along_inverse_squared) + back*back/(GATE_WIDTH*GATE_WIDTH)
		var value: float = float(patch.amplitude) * exp(-0.5*q)
		radius += value
		gradient -= value * (across*x*float(patch.across_inverse_squared) + along*y*float(patch.along_inverse_squared) + axis*back/(GATE_WIDTH*GATE_WIDTH))
	return Vector4(gradient.x, gradient.y, gradient.z, radius)

func level_gradient(point: Vector3) -> Vector4:
	var q := point / radii
	q.y = uncompress_y(q.y)
	var length := q.length()
	if length < 0.0000001: return Vector4(0.0, 0.0, 0.0, -minimum_radius)
	var direction := q / length
	var radial := radial_gradient(direction)
	var angular_gradient := Vector3(radial.x, radial.y, radial.z)
	var gradient := direction - (angular_gradient - direction*angular_gradient.dot(direction))/length
	var a := (1.0 + compression) * 0.5; var b := (1.0 - compression) * 0.5
	gradient.y /= a + b*q.y/sqrt(q.y*q.y + COMPRESSION_SOFTNESS*COMPRESSION_SOFTNESS)
	gradient /= radii
	return Vector4(gradient.x, gradient.y, gradient.z, length-radial.w)

func distance(point: Vector3) -> float:
	var value := level_gradient(point)
	var gradient := Vector3(value.x, value.y, value.z).length()
	# First-order distance close to the surface, NOT an exact global SDF.
	return value.w / gradient if gradient > 0.0000001 else -minimum_radius*minf(radii.x, minf(radii.y, radii.z))

func surface(direction: Vector3) -> Vector3:
	var n := direction.normalized()
	var p := n * radial_gradient(n).w
	p.y = compress_y(p.y)
	return p * radii

func minimum_surface_y(basis: Basis = Basis.IDENTITY) -> Dictionary:
	# Bounded deterministic authoring search. Saved translation is authoritative;
	# this numerical minimum is not described as an analytic global proof.
	var best := Vector3.DOWN; var point := basis * surface(best)
	for j in range(512):
		var y := 1.0 - 2.0 * (float(j)+0.5)/512.0; var angle := float(j)*2.399963229728653
		var direction := Vector3(sqrt(1.0-y*y)*cos(angle), y, sqrt(1.0-y*y)*sin(angle))
		var p := basis * surface(direction)
		if p.y < point.y: best = direction; point = p
	var step := 0.10
	for iteration in range(24):
		var across := best.cross(Vector3.RIGHT if absf(best.x)<0.8 else Vector3.BACK).normalized()
		var along := best.cross(across).normalized()
		var next := best; var next_point := point
		for i in range(8):
			var angle := TAU*float(i)/8.0
			var trial := (best + (across*cos(angle)+along*sin(angle))*step).normalized()
			var p := basis*surface(trial)
			if p.y < next_point.y: next = trial; next_point = p
		if next == best: step *= 0.5
		else: best = next; point = next_point
	return {"minimum_y": point.y, "point": [point.x,point.y,point.z], "direction": [best.x,best.y,best.z], "search_step": step,
		"method": "512_sphere_samples_then_24_bounded_direction_refinements", "numerical_not_global_proof": true}
