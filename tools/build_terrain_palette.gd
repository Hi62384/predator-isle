extends SceneTree

const IDS = ["Grass001","Ground054","Snow001","Rock030","Ground037","Ground048","Gravel020","Rock035","Rock028"]

func _initialize() -> void:
	var colors: Array[Image]=[]
	var normals: Array[Image]=[]
	for id in IDS:
		if not OS.get_cmdline_user_args().is_empty() and not OS.get_cmdline_user_args().has(id): continue
		var prefix := "res://assets/textures/ambientcg/%s/%s_2K-JPG_" % [id,id]
		var color := Image.load_from_file(prefix+"Color.jpg")
		var rough := Image.load_from_file(prefix+"Roughness.jpg")
		var normal := Image.load_from_file(prefix+"NormalGL.jpg")
		color.convert(Image.FORMAT_RGBA8)
		# Development-only packing. Alpha is linear roughness, RGB stays sRGB.
		for y in range(2048):
			for x in range(2048):
				var pixel := color.get_pixel(x,y)
				pixel.a = rough.get_pixel(x,y).r
				color.set_pixel(x,y,pixel)
		color.generate_mipmaps()
		assert(color.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		normal.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
		normal.convert(Image.FORMAT_RG8)
		normal.generate_mipmaps()
		assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		assert(normal.get_format()==Image.FORMAT_RGTC_RG)
		colors.append(color)
		normals.append(normal)
		assert(ResourceSaver.save(color,"res://materials/palette_color_"+id+".res")==OK)
		assert(ResourceSaver.save(normal,"res://materials/palette_normal_"+id+".res")==OK)
		print("Packed ",id)
	var color_array := Texture2DArray.new()
	var normal_array := Texture2DArray.new()
	assert(color_array.create_from_images(colors)==OK)
	assert(normal_array.create_from_images(normals)==OK)
	# Array .tres files reference the compressed Image resources directly.
	# Saving Texture2DArray itself reads back/decompresses GPU data on GL.
	print("Palette saved: BC3 2K color+roughness; BC5/RGTC 1K OpenGL XY normals")
	quit()
