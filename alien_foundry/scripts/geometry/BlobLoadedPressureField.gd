extends RefCounted
## Stage-1 loaded-tissue experiment. No added components, noise or cut planes.
## Contact shoulders broaden while both axial endpoints remain unchanged.
const PROFILE_VERSION := 1
const MAX_COMPRESSION := 0.18
const MAX_SPREAD := 0.20
const CONTACT_LOW := -0.35
const CONTACT_HIGH := 0.75

var radii := Vector3.ONE
var inverse_radii := Vector3.ONE
var axis := Vector3.UP
var compression := 0.0
var spread := 0.0
var sculpt_strength := 0.0
var sculpt_phase := 0.0
var local_bounds := AABB()
var valid := false
# Test-only observation; disabled in production builds. Each field is job-local.
var diagnostics_enabled := false
var last_implicit_level := 0.0
var last_implicit_gradient := Vector3.ZERO
var last_mapping_determinant := 1.0

static func create(mark: Dictionary, size: Vector3, strength: float, phase: float) -> RefCounted:
	var field = new()
	if int(mark.get("version", 0)) != PROFILE_VERSION: return field
	var direction: Variant = mark.get("axis", [])
	if not direction is Array or direction.size() != 3: return field
	field.axis = Vector3(float(direction[0]), float(direction[1]), float(direction[2]))
	if not field.axis.is_finite() or field.axis.length_squared() < 0.01: return field
	field.axis = field.axis.normalized()
	field.radii = size.abs().max(Vector3.ONE * 0.006)
	field.inverse_radii = Vector3.ONE / field.radii
	field.compression = clampf(float(mark.get("compression", 0.0)), 0.0, MAX_COMPRESSION)
	field.spread = clampf(float(mark.get("spread", 0.0)), 0.0, MAX_SPREAD)
	# This is the same bounded strength that OrganicVolume uses for these nodes.
	field.sculpt_strength = clampf(strength, 0.0, 0.29)
	field.sculpt_phase = phase
	# c is a convex combination of a and 1, so c² <= (1-u)a²+u.
	# This gives |q|² <= compression+(1+spread)² on the zero set.
	var radius_bound := sqrt(field.compression + pow(1.0 + field.spread, 2.0))
	var s: float = field.sculpt_strength
	# Invert each bounded legacy warp in reverse order. These are conservative
	# local extents, not sampled bounds or an unverified fixed padding factor.
	var q_extent := Vector3(radius_bound / (1.0 - s * 0.65) + s * 1.24,
		radius_bound + s * 0.30, radius_bound / (1.0 - s * 0.60) + s * 1.04)
	var extent: Vector3 = q_extent * field.radii
	field.local_bounds = AABB(-extent, extent * 2.0)
	field.valid = true
	return field

func distance(point: Vector3) -> float:
	var q := point * inverse_radii
	# Derivatives of the unchanged low-frequency sculpt map with respect to
	# the original normalized coordinate. They preserve world-distance units.
	var dx := Vector3.RIGHT
	var dy := Vector3.UP
	var dz := Vector3.BACK
	var s := sculpt_strength
	if s > 0.0001:
		var phase_sine := sin(sculpt_phase)
		var angle := q.y * 2.7 + sculpt_phase
		q.x += s * 0.62 * (sin(angle) - phase_sine)
		dx += dy * (s * 0.62 * 2.7 * cos(angle))
		angle = q.y * 3.3 - sculpt_phase
		q.z += s * 0.52 * (sin(angle) + phase_sine)
		dz += dy * (s * 0.52 * 3.3 * cos(angle))
		angle = q.x * 2.4 + q.z * 1.8
		q.y += s * 0.30 * sin(angle)
		dy += (dx * 2.4 + dz * 1.8) * (s * 0.30 * cos(angle))
		angle = q.y * 4.1 + sculpt_phase
		var scale := 1.0 + s * 0.65 * cos(angle)
		dx = dx * scale - dy * (q.x * s * 0.65 * 4.1 * sin(angle))
		q.x *= scale
		angle = q.y * 3.2 + q.x * 1.6 + sculpt_phase
		scale = 1.0 + s * 0.60 * sin(angle)
		dz = dz * scale + (dy * 3.2 + dx * 1.6) * (q.z * s * 0.60 * cos(angle))
		q.z *= scale
	var c := q.dot(axis)
	var radial := q - axis * c
	var u := clampf((c - CONTACT_LOW) / (CONTACT_HIGH - CONTACT_LOW), 0.0, 1.0)
	var t := u * u * (3.0 - 2.0 * u)
	var dt := 6.0 * u * (1.0 - u) / (CONTACT_HIGH - CONTACT_LOW)
	var denominator := 1.0 - compression * t
	var a := (c - compression * t) / denominator
	var da := (denominator + compression * dt * (c - 1.0)) / (denominator * denominator)
	var b := 1.0 + spread * t
	var db := spread * dt
	var radial_squared := radial.length_squared()
	var k := sqrt(a * a + radial_squared / (b * b))
	if k < 0.000001: return -minf(radii.x, minf(radii.y, radii.z))
	var gradient := radial / (b * b * k) + axis * ((a * da - radial_squared * db / (b * b * b)) / k)
	var original_gradient := (dx * gradient.x + dy * gradient.y + dz * gradient.z) * inverse_radii
	if diagnostics_enabled:
		last_implicit_level = k - 1.0
		last_implicit_gradient = original_gradient
		last_mapping_determinant = dx.dot(dy.cross(dz)) * da / (b * b)
	# First-order signed distance is exact at the surface. Unlike an arbitrary
	# displacement amplitude it remains calibrated to world-space meshing.
	return (k - 1.0) / maxf(original_gradient.length(), 0.000001)
