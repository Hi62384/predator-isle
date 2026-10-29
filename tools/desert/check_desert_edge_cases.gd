extends SceneTree
## Bounded CPU regressions. Shader parsing is not native lighting/PBR acceptance.
const Desert = preload("res://scripts/desert_sampler.gd")
const Settings = preload("res://scripts/desert_settings.gd")
var failures: Array[String] = []
var assertions: int = 0

class StarProbe extends "res://scripts/desert_sampler.gd":
	var angle: float = 0.0
	func _near_dune_sites(_q: Vector2, _pitch: float, _width: float, _family: int) -> Array[Vector4]:
		return _dune_sites(Vector2i.ZERO)
	func _dune_sites(_cell: Vector2i) -> Array[Vector4]:
		return [Vector4(0.0, 0.0, 1.0, angle)]

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		if failures.size() < 10: push_error(label)

func _initialize() -> void:
	var probe := StarProbe.new()
	probe.configure(Settings.new(), 73921)
	var largest_step: float = 0.0
	for i in range(101):
		probe.angle = float(i) / 100.0
		for j in range(-25, 26):
			for side in [-1.0, 1.0]:
				# Sweep across the old culling edge with a 1.6 cm step.
				var a: float = probe._isolated_dunes(Vector2(j * 8.5, side * 849.99 * 0.8), 850.0, 3)
				var b: float = probe._isolated_dunes(Vector2(j * 8.5, side * 850.01 * 0.8), 850.0, 3)
				largest_step = maxf(largest_step, absf(a - b))
				check(absf(a - b) < 0.002, "Star arm clipped before its radial fade")
		for side in [-1.0, 1.0]:
			check(probe._isolated_dunes(Vector2(0.0, side * 850.0 * 0.851), 850.0, 3) == 0.0, "Star footprint remains finite")
	var phase_error: float = 0.0
	var old_phase_errors: Array = []
	for seed_value in [0, 73921, -73921, 10007, -10007, 16777217, -16777217, 2147483647, -2147483648]:
		var sampler = Desert.new()
		sampler.configure(Settings.new(), seed_value)
		# Shader uniforms store float32; reduction must happen as integer first.
		var uniform_phase: float = PackedFloat32Array([float(seed_value % 10007) * 0.013])[0]
		var error: float = absf(uniform_phase - sampler._wind_phase)
		phase_error = maxf(phase_error, error)
		check(error < 0.00001, "CPU/GPU reduced wind phase differs")
		var old_seed: float = PackedFloat32Array([float(seed_value)])[0]
		old_phase_errors.append({"seed":seed_value, "old_error":absf(fposmod(old_seed, 10007.0) * 0.013 - sampler._wind_phase), "bound_uniform_error":error})
	var shader = load("res://shaders/terrain_biomes.gdshader") as Shader
	check(shader != null, "Terrain shader loads")
	var uniform_names: Array[String] = []
	if shader != null:
		for entry in shader.get_shader_uniform_list(): uniform_names.append(str(entry.name))
	check("desert_wind_phase" in uniform_names, "Reduced wind phase uniform parses")
	var shader_source := FileAccess.get_file_as_string("res://shaders/desert_material.gdshaderinc")
	var controller_source := FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd")
	check(shader_source.contains("float phase=desert_wind_phase;"), "Wind frame consumes bound phase")
	check(controller_source.contains('set_shader_parameter("desert_wind_phase", float(world_seed % 10007) * 0.013)'), "Controller binds integer-reduced phase")
	var report := {"engine":Engine.get_version_info().string, "os":OS.get_name(), "assertions":assertions,
		"star_edge_max_step_m":largest_step, "float32_phase_max_error":phase_error, "seed_cases":old_phase_errors,
		"shader_uniforms":uniform_names.size(), "failures":failures,
		"scope":"CPU star-footprint continuity, integer/float32 seed transport, shader parsing and binding source contract. No native GPU lighting, PBR, full-world or performance acceptance."}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
