extends SceneTree

# External binary Texture2D resources stay external when the Inspector saves
# cliff_normals.tres; embedded ImageTextures serialize millions of text numbers.
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run with a rendering device, not --headless: array serialization requires GPU readback.")
		quit(1)
		return
	for id in ["Rock064", "Rock058", "Rock051", "Rock060", "Rock030", "Rock061", "Rock050", "Rocks007", "Rocks011"]:
		var source := load("res://materials/cliff_normal_" + id + ".res") as Image
		assert(source != null)
		var texture := ImageTexture.create_from_image(source)
		assert(ResourceSaver.save(texture, "res://materials/cliff_texture_" + id + ".res", ResourceSaver.FLAG_COMPRESS) == OK)
	print("External cliff textures saved")
	# The small .tres arrays reference existing compressed Image layers.
	# Serializing arrays after GL readback duplicates and decompresses their data.
	var color_array: Texture2DArray = load("res://materials/palette_color_roughness.tres")
	var normal_array: Texture2DArray = load("res://materials/palette_normals.tres")
	assert(color_array.get_layers() == 9)
	assert(normal_array.get_layers() == 9)
	print("Palette uses external compressed layers; no combined binary copies saved")
	quit()
