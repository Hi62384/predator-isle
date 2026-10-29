extends SceneTree
## Offline authored maps. No external content, runtime bake or runtime download.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Salt baking requires a rendered viewport");quit(2);return
	var destination: String="res://assets/textures/desert/original_salt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(2048,2048)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.disable_3d=true
	root.add_child(viewport)
	var rect:=ColorRect.new();rect.size=Vector2(2048,2048)
	var material:=ShaderMaterial.new();material.shader=load("res://tools/desert/bake_salt.gdshader")
	rect.material=material;viewport.add_child(rect)
	var maps: Array[Image]=[]
	var names: Array[String]=["Color","NormalGL","Roughness","Height"]
	for channel in range(4):
		material.set_shader_parameter("channel",channel)
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var result: Image=viewport.get_texture().get_image()
		if result==null or result.is_empty():push_error("Salt bake readback failed");quit(1);return
		assert(result.save_png(destination+"/SaltCrust_2K_"+names[channel]+".png")==OK)
		maps.append(result)
	var color: Image=maps[0];color.convert(Image.FORMAT_RGBA8)
	for y in range(2048):
		for x in range(2048):
			var pixel: Color=color.get_pixel(x,y);pixel.a=maps[2].get_pixel(x,y).r;color.set_pixel(x,y,pixel)
	# Linear-light color filtering, with linear roughness alpha.
	color=preload("res://tools/desert/pack_source.gd").srgb_mips(color)
	assert(color.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
	assert(ResourceSaver.save(color,"res://materials/desert_color_original_salt.res")==OK)
	var normal: Image=maps[1];normal.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	for y in range(1024):
		for x in range(1024):
			var c: Color=normal.get_pixel(x,y);var n:=Vector3(c.r*2.0-1.0,c.g*2.0-1.0,c.b*2.0-1.0).normalized()
			normal.set_pixel(x,y,Color(n.x*0.5+0.5,n.y*0.5+0.5,n.z*0.5+0.5))
	assert(normal.generate_mipmaps(true)==OK);normal.convert(Image.FORMAT_RG8)
	assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
	assert(ResourceSaver.save(normal,"res://materials/desert_normal_original_salt.res")==OK)
	viewport.queue_free()
	for frame in range(4):await process_frame
	print("Original salt crust baked: 2K BC3 color/roughness, 1K BC5 OpenGL normals, periodic 2 m tile.")
	quit()
