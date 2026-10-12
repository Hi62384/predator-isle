extends SceneTree

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var config = load("res://cliff_normals.tres")
	assert(config != null and config.layers.size() == 9)
	var path := "user://cliff_config_save_regression.tres"
	for iteration in range(3):
		assert(ResourceSaver.save(config, path) == OK)
		var file := FileAccess.open(path, FileAccess.READ)
		assert(file.get_length() < 32768, "Settings must not embed texture pixels")
		file.close()
		config = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		assert(config.layers.size() == 9)
		for layer in config.layers:
			assert(not layer.normal_texture.resource_path.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS three save/reload cycles: external textures retained, config <32 KB; elapsed ms: ", Time.get_ticks_msec()-started)
	quit()
