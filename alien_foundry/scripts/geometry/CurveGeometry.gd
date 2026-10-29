class_name OrganicCurveGeometry
extends RefCounted
## One Catmull-Rom swept-radius representation for limbs, tendrils, necks,
## serpentine spines and branching roots. The volume, not separate tubes,
## extracts their final surface, so their attachment collars are fused tissue.

static func vector(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		return value
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array:
		if value.size() >= 3:
			return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

static func sample(node: Dictionary, subdivisions: int = 3, smooth_radius: bool = false) -> Dictionary:
	var source: Array = node.get("points", [])
	var positions := PackedVector3Array()
	var radii := PackedFloat32Array()
	if source.size() < 2:
		return {"points": positions, "radii": radii}
	var source_radii: Array = node.get("radii", [])
	var base_radius := maxf(float(node.get("radius", 0.16)), 0.005)
	var shape: Dictionary = node.get("shape", {})
	var taper := float(shape.get("taper", 0.0))
	var swelling := float(shape.get("swelling", 0.06))
	var twist := float(shape.get("twist", 0.0))
	for i in range(source.size() - 1):
		var a := vector(source[maxi(i - 1, 0)])
		var b := vector(source[i])
		var c := vector(source[i + 1])
		var d := vector(source[mini(i + 2, source.size() - 1)])
		var radius_b := float(source_radii[i]) if i < source_radii.size() else base_radius
		var radius_c := float(source_radii[i + 1]) if i + 1 < source_radii.size() else base_radius
		for j in range(maxi(subdivisions, 1)):
			var t := float(j) / float(maxi(subdivisions, 1))
			var t2 := t * t
			var t3 := t2 * t
			var p := (2.0 * b + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (-a + 3.0 * b - 3.0 * c + d) * t3) * 0.5
			var along := (float(i) + t) / float(source.size() - 1)
			var radius := lerpf(radius_b, radius_c, t) * (1.0 - taper * along)
			radius *= 1.0 + swelling * sin(along * TAU * 2.7)
			if absf(twist) > 0.0001:
				var tangent := (c - b).normalized()
				var axis := tangent.cross(Vector3.UP)
				if axis.length_squared() < 0.01:
					axis = tangent.cross(Vector3.RIGHT)
				axis = axis.normalized()
				p += axis.rotated(tangent, along * TAU * 2.0) * sin(along * PI) * radius * twist
			positions.append(p)
			radii.append(maxf(radius, 0.004))
	positions.append(vector(source[-1]))
	radii.append(maxf((float(source_radii[-1]) if not source_radii.is_empty() else base_radius) * (1.0 - taper), 0.004))
	if smooth_radius:
		radii = smooth_radii(node, positions.size(), 0.06)
	return {"points": positions, "radii": radii}

static func attachment_frame(point: Vector3, normal: Vector3, up: Vector3 = Vector3.UP) -> Transform3D:
	var outward := normal.normalized()
	if outward.length_squared() < 0.1:
		outward = Vector3.FORWARD
	var x := up.cross(outward).normalized()
	if x.length_squared() < 0.1:
		x = Vector3.RIGHT.cross(outward).normalized()
	var y := outward.cross(x).normalized()
	return Transform3D(Basis(x, y, outward), point)


static func smooth_radii(node: Dictionary, sample_count: int, default_swelling: float = 0.0) -> PackedFloat32Array:
	# Shared by continuous primary envelopes and direct anatomical details.
	# Monotone Hermite interpolation removes conical radius-derivative corners
	# while preserving authored knots and extrema before explicit modifiers.
	var count: int = node.get("points", []).size()
	var source: Array = node.get("radii", [])
	var values := PackedFloat32Array()
	var slopes := PackedFloat32Array()
	var output := PackedFloat32Array()
	var base := maxf(float(node.get("radius", 0.16)), 0.004)
	for i in range(count):
		values.append(maxf(float(source[i]) if i < source.size() else base, 0.004))
	slopes.resize(count)
	for i in range(count):
		if i == 0:
			slopes[i] = values[1] - values[0]
		elif i == count - 1:
			slopes[i] = values[-1] - values[-2]
		else:
			var before := values[i] - values[i - 1]
			var after := values[i + 1] - values[i]
			slopes[i] = 2.0 * before * after / (before + after) if before * after > 0.0 else 0.0
	var shape: Dictionary = node.get("shape", {})
	var taper := float(shape.get("taper", 0.0))
	var swelling := float(shape.get("swelling", default_swelling))
	for i in range(sample_count):
		var along := float(i) / float(maxi(sample_count - 1, 1))
		var f := along * float(count - 1)
		var segment := mini(floori(f), count - 2)
		var t := f - float(segment)
		var t2 := t * t
		var t3 := t2 * t
		var a := values[segment]
		var b := values[segment + 1]
		var radius := (2.0 * t3 - 3.0 * t2 + 1.0) * a + (t3 - 2.0 * t2 + t) * slopes[segment] + (-2.0 * t3 + 3.0 * t2) * b + (t3 - t2) * slopes[segment + 1]
		radius = clampf(radius, minf(a, b), maxf(a, b))
		# No implicit swelling/taper for authored bellies or digits. Explicit
		# swelling fades to zero at both ends so cap radii stay continuous.
		radius *= (1.0 - taper * along) * (1.0 + swelling * sin(along * TAU * 2.7) * sin(along * PI))
		output.append(maxf(radius, 0.004))
	return output


static func profile_value(values: Array, t: float) -> float:
	# Bounded C1 factor interpolation shared by primary envelopes and details.
	if values.is_empty(): return 1.0
	if values.size() == 1: return clampf(float(values[0]), 0.10, 4.0)
	var f := clampf(t, 0.0, 1.0) * float(values.size() - 1)
	var i := mini(floori(f), values.size() - 2)
	return clampf(lerpf(float(values[i]), float(values[i + 1]), smoothstep(0.0, 1.0, f - i)), 0.10, 4.0)
