extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shader: Shader = load("res://shaders/terrain_biomes.gdshader")
	assert(shader != null)
	var settings: GroundMaterialSettings = load("res://ground_materials.tres")
	var values := settings.uniforms()
	assert(is_equal_approx(values.path_wander_strength, 0.82))
	assert(is_equal_approx(values.path_edge_noise_metres, 7.0))
	assert(is_equal_approx(values.path_dry_earth_mix, 0.28))
	assert(is_equal_approx(values.path_mud_mix, 0.24))
	print("TERRAIN_SHADER_RESOURCE_OK")
	quit()
