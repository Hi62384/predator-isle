class_name OrganicNoiseGenerator
extends RefCounted
## Native FastNoiseLite samplers. Each build owns these resources; no global RNG.
## Large silhouette drift, stretched tendon folds and cellular tissue are separate
## frequency bands, rather than one uniform displacement stamped over the body.
var simplex := FastNoiseLite.new()
var gradient := FastNoiseLite.new()
var cellular := FastNoiseLite.new()
var fbm := FastNoiseLite.new()
var ridged := FastNoiseLite.new()
var warped := FastNoiseLite.new()
var detail: float = 0.5
var world_scale: float = 1.0

func configure(seed_value: int, scale_value: float, surface_detail: float) -> void:
	detail = clampf(surface_detail, 0.0, 1.0)
	world_scale = maxf(scale_value, 0.05)
	var noises: Array[FastNoiseLite] = [simplex, gradient, cellular, fbm, ridged, warped]
	for i in range(noises.size()):
		noises[i].seed = int((seed_value + 104729 * (i + 1)) & 0x7fffffff)
		noises[i].frequency = 1.0 / world_scale
		noises[i].fractal_type = FastNoiseLite.FRACTAL_NONE
	simplex.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	simplex.frequency = 0.82 / world_scale
	gradient.noise_type = FastNoiseLite.TYPE_PERLIN
	gradient.frequency = 2.4 / world_scale
	cellular.noise_type = FastNoiseLite.TYPE_CELLULAR
	cellular.frequency = 4.2 / world_scale
	cellular.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	fbm.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fbm.fractal_type = FastNoiseLite.FRACTAL_FBM
	fbm.fractal_octaves = 3
	fbm.frequency = 1.9 / world_scale
	ridged.noise_type = FastNoiseLite.TYPE_PERLIN
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridged.fractal_octaves = 2
	ridged.frequency = 2.7 / world_scale
	warped.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warped.fractal_type = FastNoiseLite.FRACTAL_FBM
	warped.fractal_octaves = 2
	warped.frequency = 2.1 / world_scale
	warped.domain_warp_enabled = true
	warped.domain_warp_amplitude = 0.30 * world_scale
	warped.domain_warp_frequency = 1.3 / world_scale

func displacement(point: Vector3, profile: float = 0.0) -> float:
	var large := simplex.get_noise_3dv(point)
	var lower := clampi(floori(profile), 0, 7)
	var fraction := clampf(profile - float(lower), 0.0, 1.0)
	var medium := _medium(point, lower)
	if fraction > 0.001:
		medium = lerpf(medium, _medium(point, mini(lower + 1, 7)), fraction)
	return large * 0.64 + medium * (0.28 + detail * 0.65)

func _medium(point: Vector3, profile: int) -> float:
	match profile:
		1: # roots: stretched flowing fibres
			return warped.get_noise_3dv(point * Vector3(2.2, 0.55, 1.9)) * 0.62 + ridged.get_noise_3dv(point) * 0.18
		2: # muscle: directional perlin folds, not isotropic lumps
			return gradient.get_noise_3dv(point * Vector3(1.6, 0.46, 2.6)) * 0.70 + fbm.get_noise_3dv(point) * 0.16
		3: # chitin: nonuniform cellular plates and ridges
			return cellular.get_noise_3dv(point) * 0.30 + ridged.get_noise_3dv(point) * 0.48
		4: # cartilage / crystalline ridges
			return ridged.get_noise_3dv(point) * 0.70 + gradient.get_noise_3dv(point) * 0.16
		5: # membrane is intentionally quieter
			return gradient.get_noise_3dv(point * Vector3(2.8, 0.4, 1.4)) * 0.24
		_:
			return warped.get_noise_3dv(point) * 0.52 + fbm.get_noise_3dv(point) * 0.28

func anatomical_displacement(point: Vector3, local_point: Vector3, context: Vector4, fold_frequency: float) -> float:
	# Geometry carries broad silhouette drift and resolvable directional folds.
	# Fine pores/wrinkles remain shader work. Semantic weights and coordinates
	# are continuously mixed by the same SDF union, rather than mixing category
	# integers and accidentally selecting an unrelated noise family at a seam.
	var large := simplex.get_noise_3dv(point)
	var directional := local_point * Vector3.ONE.lerp(Vector3(2.1, 0.52, 1.8), clampf(context.x, 0.0, 1.0))
	var flowing := warped.get_noise_3dv(directional)
	var clustered := fbm.get_noise_3dv(local_point)
	var medium := lerpf(clustered, flowing, 0.30 + clampf(context.w, 0.0, 1.0) * 0.65) * 0.72
	if context.y > 0.001:
		var fold := sin(local_point.y * fold_frequency * PI / world_scale + flowing * 1.4)
		medium = lerpf(medium, medium * 0.65 + fold * 0.26, clampf(context.y, 0.0, 1.0))
	if context.z > 0.001:
		var hard := ridged.get_noise_3dv(local_point) * 0.40 + cellular.get_noise_3dv(local_point) * 0.16
		medium = lerpf(medium, hard, clampf(context.z, 0.0, 1.0))
	return large * 0.58 + medium * (0.60 + detail * 0.55)

func tissue_variation(point: Vector3) -> float:
	return clampf(0.5 + fbm.get_noise_3dv(point) * 0.33 + cellular.get_noise_3dv(point) * 0.12, 0.0, 1.0)

func sample_all(point: Vector3) -> Dictionary:
	return {"open_simplex": simplex.get_noise_3dv(point), "gradient": gradient.get_noise_3dv(point), "cellular": cellular.get_noise_3dv(point), "fbm": fbm.get_noise_3dv(point), "ridged": ridged.get_noise_3dv(point), "domain_warped": warped.get_noise_3dv(point)}
