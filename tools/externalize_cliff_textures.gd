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
	var colors: Array[Image] = []
	var normals: Array[Image] = []
	for id in ["Grass001", "Ground054", "Snow001", "Rock030", "Ground037", "Ground048", "Gravel020", "Rock035", "Rock028"]:
		colors.append(load("res://materials/palette_color_" + id + ".res"))
		normals.append(load("res://materials/palette_normal_" + id + ".res"))
	var color_array := Texture2DArray.new()
	var normal_array := Texture2DArray.new()
	assert(color_array.create_from_images(colors) == OK)
	assert(normal_array.create_from_images(normals) == OK)
	assert(ResourceSaver.save(color_array, "res://materials/palette_color_roughness.res", ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceSaver.save(normal_array, "res://materials/palette_normals.res", ResourceSaver.FLAG_COMPRESS) == OK)
	quit()
