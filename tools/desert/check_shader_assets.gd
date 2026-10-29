extends SceneTree
## Project source/resource validation. Headless shader parse is not GPU acceptance.
var failures: Array[String] = []
var assertions: int = 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	var shader = load("res://shaders/terrain_biomes.gdshader") as Shader
	check(shader != null, "Current terrain shader load")
	if shader == null: quit(1); return
	var uniforms: Array = shader.get_shader_uniform_list()
	var uniform_names: Array[String] = []
	for entry in uniforms: uniform_names.append(str(entry.name))
	for required in ["desert_color", "desert_normal", "desert_palette_ready", "desert_clay_metres", "desert_ripple_strength"]:
		check(required in uniform_names, "Shader uniform present: " + required)
	for path in ["res://scripts/chunk_terrain.gd", "res://scripts/free_camera.gd", "res://scripts/terrain_mesh_builder.gd", "res://scripts/desert_sampler.gd", "res://scripts/desert_drainage.gd"]:
		var script = load(path) as Script
		check(script != null and script.can_instantiate(), "Script parses: " + path)
	var arrays: Array = []
	for path in ["res://materials/desert_color_roughness_clay.tres", "res://materials/desert_normals_clay.tres"]:
		var texture = load(path) as Texture2DArray
		check(texture != null, "Prepared clay array load: " + path)
		if texture != null:
			check(texture.get_layers() == 6, "Six prepared structural layers")
			arrays.append(texture)
	if arrays.size() == 2:
		# Inspect the saved Images directly: a dummy/headless renderer may not
		# support GPU texture readback, which would not be an asset failure.
		var color = load("res://materials/desert_color_polyhaven_clay.res") as Image
		var normal = load("res://materials/desert_normal_polyhaven_clay.res") as Image
		check(color != null and color.get_size() == Vector2i(2048, 2048), "Clay color physical source dimensions")
		check(normal != null and normal.get_size() == Vector2i(1024, 1024), "Clay normal prepared dimensions")
		if color != null and normal != null:
			check(color.has_mipmaps() and normal.has_mipmaps(), "Prepared clay mipmaps")
			check(color.get_format() == Image.FORMAT_DXT5 and normal.get_format() == Image.FORMAT_RGTC_RG, "Prepared clay compression formats")
	for path in ["res://materials/desert_color_roughness_geology.tres","res://materials/desert_normals_geology.tres"]:
		var geology=load(path) as Texture2DArray
		check(geology!=null and geology.get_layers()==7,"Seven prepared geology layers: "+path)
	for path in ["res://materials/desert_color_original_salt.res","res://materials/desert_normal_original_salt.res"]:
		var salt=load(path) as Image
		check(salt!=null and salt.has_mipmaps(),"Authored salt source: "+path)
	var config = load("res://config/biomes/desert_settings.tres") as DesertSettings
	check(config != null, "Existing Desert preset load")
	if config != null:
		check(config.dune_occurrence == 1.0 and config.canyon_occurrence == 1.0 and config.dry_lake_occurrence == 1.0, "Occurrence defaults preserved")
		var saved := "res://tools/desert/artifacts/settings_compatibility_snapshot.tres"
		check(ResourceSaver.save(config, saved) == OK, "Compatibility snapshot save")
		var text := FileAccess.get_file_as_string(saved)
		check(not text.contains("dune_relief_strength") and not text.contains("canyon_incision_strength") and not text.contains("dry_lake_floor_strength"), "Editor aliases are not serialized")
	var report := {"engine":Engine.get_version_info().string, "os":OS.get_name(),
		"display":DisplayServer.get_name(), "assertions":assertions, "shader_uniforms":uniform_names,
		"failures":failures, "scope":"Current project source and prepared resources; no actual GPU lighting, seam or visual acceptance."}
	FileAccess.open("res://tools/desert/current_shader_assets.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
