class_name VascularField
extends RefCounted
## Bounded, deterministic packed-only worker bake. These are explicit connected
## tapered vessel trees, not thresholded noise or cellular boundary contours.
## R: main vessels. G: diffuse subdermal halos. B: fine daughter capillaries.
const MAX_RESOLUTION: int = 512
var resolution: int = 512
var pixels: PackedByteArray = PackedByteArray()
var rng := RandomNumberGenerator.new()
var segment_count: int = 0
var controls: RefCounted

func build(dna: Dictionary, job: RefCounted = null, requested_resolution: int = 512) -> Dictionary:
	resolution = clampi(requested_resolution, 64, MAX_RESOLUTION)
	controls = job
	rng.seed = int(dna.get("seed", 0)) ^ 0x1a3b5c79
	return _generate()

func _generate() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	pixels.resize(resolution * resolution * 4)
	pixels.fill(0)
	for pixel: int in range(resolution * resolution):
		pixels[pixel * 4 + 3] = 255
	var scale: float = float(resolution) / 512.0
	for tree: int in range(11):
		if controls != null and controls.is_cancelled():
			return {"cancelled": true}
		var start := Vector2(rng.randf_range(0.0, resolution), rng.randf_range(0.0, resolution))
		var direction: float = PI * 0.5 + rng.randf_range(-0.85, 0.85)
		if tree % 3 == 0: direction += PI
		_grow(start, direction, rng.randf_range(135.0, 205.0) * scale, rng.randf_range(1.15, 1.85) * scale, 0.88, 0)
	var core_pixels: int = 0
	var halo_pixels: int = 0
	for pixel: int in range(resolution * resolution):
		if pixels[pixel * 4] > 32 or pixels[pixel * 4 + 2] > 32: core_pixels += 1
		if pixels[pixel * 4 + 1] > 20: halo_pixels += 1
	return {"width": resolution, "height": resolution, "pixels": pixels, "segment_count": segment_count, "core_coverage": float(core_pixels) / float(resolution * resolution), "halo_coverage": float(halo_pixels) / float(resolution * resolution), "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}

func _grow(start: Vector2, direction: float, length_value: float, width: float, opacity: float, level: int) -> void:
	var steps: int = 19 if level == 0 else (13 if level == 1 else 8)
	var step_length: float = length_value / float(steps)
	var point: Vector2 = start
	var heading: float = direction
	var bend: float = rng.randf_range(-0.018, 0.018)
	var branch_sites: Array = []
	for step: int in range(steps):
		heading += bend + rng.randf_range(-0.085, 0.085)
		var next: Vector2 = point + Vector2(cos(heading), sin(heading)) * step_length
		var taper_a: float = lerpf(1.0, 0.22, float(step) / float(steps))
		var taper_b: float = lerpf(1.0, 0.22, float(step + 1) / float(steps))
		_paint_segment(point, next, width * taper_a, width * taper_b, opacity, level >= 2)
		if level < 2 and (step == steps / 3 or (level == 0 and step == steps * 2 / 3)):
			branch_sites.append({"point": next, "heading": heading, "width": width * taper_b})
		point = next
	for index: int in range(branch_sites.size()):
		var branch: Dictionary = branch_sites[index]
		var sign_value: float = -1.0 if index % 2 == 0 else 1.0
		_grow(branch.point, float(branch.heading) + sign_value * rng.randf_range(0.38, 0.91), length_value * rng.randf_range(0.38, 0.59), float(branch.width) * 0.66, opacity * 0.78, level + 1)

func _paint_segment(a: Vector2, b: Vector2, radius_a: float, radius_b: float, opacity: float, capillary: bool) -> void:
	segment_count += 1
	var halo_radius: float = maxf(radius_a, radius_b) * 3.8 + 1.15
	var minimum: Vector2 = a.min(b) - Vector2.ONE * halo_radius
	var maximum: Vector2 = a.max(b) + Vector2.ONE * halo_radius
	var direction: Vector2 = b - a
	var inverse_length: float = 1.0 / maxf(direction.length_squared(), 0.00001)
	for y: int in range(floori(minimum.y), ceili(maximum.y) + 1):
		for x: int in range(floori(minimum.x), ceili(maximum.x) + 1):
			var sample_position := Vector2(float(x) + 0.5, float(y) + 0.5)
			var t: float = clampf((sample_position - a).dot(direction) * inverse_length, 0.0, 1.0)
			var distance: float = sample_position.distance_to(a + direction * t)
			var radius: float = lerpf(radius_a, radius_b, t)
			var halo: float = maxf(0.0, 1.0 - distance / (radius * 3.8 + 1.15))
			if halo <= 0.0: continue
			# Subpixel anti-aliasing retains tapered fine branches without binary
			# jagged lines. The halo has finite support and wraps continuously.
			var core: float = clampf((radius + 0.65 - distance) / 1.1, 0.0, 1.0) * opacity
			var offset: int = (posmod(x, resolution) + posmod(y, resolution) * resolution) * 4
			var channel: int = 2 if capillary else 0
			pixels[offset + channel] = maxi(int(pixels[offset + channel]), roundi(core * 255.0))
			pixels[offset + 1] = maxi(int(pixels[offset + 1]), roundi(halo * halo * opacity * 255.0))
