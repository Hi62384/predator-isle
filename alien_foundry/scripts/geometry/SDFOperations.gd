class_name SDFOperations
extends RefCounted
## Exact sign-preserving field operators shared by volume construction and tests.

static func smooth_union(a: float, b: float, radius: float) -> float:
	if radius <= 0.000001:
		return minf(a, b)
	var h := clampf(0.5 + 0.5 * (b - a) / radius, 0.0, 1.0)
	return lerpf(b, a, h) - radius * h * (1.0 - h)

static func smooth_subtraction(body: float, cavity: float, radius: float) -> float:
	return -smooth_union(-body, cavity, radius)

static func ellipsoid(point: Vector3, radii: Vector3) -> float:
	var safe := radii.max(Vector3.ONE * 0.0001)
	var k0 := (point / safe).length()
	var k1 := (point / (safe * safe)).length()
	if k1 < 0.000001:
		return -minf(safe.x, minf(safe.y, safe.z))
	return k0 * (k0 - 1.0) / k1

static func tapered_capsule(point: Vector3, start: Vector3, finish: Vector3, radius_a: float, radius_b: float) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared < 0.0000001:
		return point.distance_to(start) - maxf(radius_a, radius_b)
	# Minimise distance to a linearly varying-radius swept sphere. Including dr
	# prevents the thin end of a strongly tapered appendage from becoming blunt.
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var radial := point.distance_to(start + segment * t)
	t = clampf(t + (radius_b - radius_a) * radial / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t) - lerpf(radius_a, radius_b, t)
