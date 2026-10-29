extends SceneTree
# Offline-only packing. No runtime conversion, downloads or per-chunk resources.
const IDS = ["Ground092A","Ground054","Gravel020","Rock061","Ground031","Ground033"]
func _initialize() -> void:
	# Never overwrite unexpected generated resources. On a rerun, preserve and
	# review the previous generated set before authorizing replacement.
	var outputs: Array[String]=["res://materials/desert_color_roughness.tres","res://materials/desert_normals.tres"]
	for id in IDS:
		outputs.append("res://materials/desert_color_"+id+".res")
		outputs.append("res://materials/desert_normal_"+id+".res")
	for output in outputs:
		if FileAccess.file_exists(output):
			push_error("Refusing to overwrite an existing generated resource: "+output)
			quit(1)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/desert/artifacts"))
	var color_paths: Array[String]=[]
	var normal_paths: Array[String]=[]
	var records: Array=[]
	for id in IDS:
		var prefix: String="res://assets/textures/desert/%s/%s_2K-JPG_" % [id,id]
		var color: Image=Image.load_from_file(prefix+"Color.jpg")
		var rough: Image=Image.load_from_file(prefix+"Roughness.jpg")
		var normal: Image=Image.load_from_file(prefix+"NormalGL.jpg")
		if color==null or rough==null or normal==null:push_error("Missing source maps: "+id);quit(1);return
		assert(color.get_size()==Vector2i(2048,2048))
		assert(rough.get_size()==color.get_size() and normal.get_size()==color.get_size())
		var preview: Image=color.duplicate()
		preview.resize(512,512,Image.INTERPOLATE_LANCZOS)
		preview.save_png("res://tools/desert/artifacts/"+id+"_source.png")
		var normal_preview: Image=normal.duplicate()
		normal_preview.resize(512,512,Image.INTERPOLATE_LANCZOS)
		normal_preview.save_png("res://tools/desert/artifacts/"+id+"_normal_source.png")
		var rough_preview: Image=rough.duplicate()
		rough_preview.resize(512,512,Image.INTERPOLATE_LANCZOS)
		rough_preview.save_png("res://tools/desert/artifacts/"+id+"_roughness_source.png")
		color.convert(Image.FORMAT_RGBA8)
		for y in range(2048):
			for x in range(2048):
				var pixel: Color=color.get_pixel(x,y)
				pixel.a=rough.get_pixel(x,y).r
				color.set_pixel(x,y,pixel)
		color.generate_mipmaps()
		assert(color.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		normal.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
		normal.convert(Image.FORMAT_RG8)
		normal.generate_mipmaps()
		assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		assert(color.get_format()==Image.FORMAT_DXT5 and normal.get_format()==Image.FORMAT_RGTC_RG)
		var cp: String="res://materials/desert_color_"+id+".res"
		var np: String="res://materials/desert_normal_"+id+".res"
		assert(ResourceSaver.save(color,cp)==OK)
		assert(ResourceSaver.save(normal,np)==OK)
		color_paths.append(cp);normal_paths.append(np)
		records.append({"id":id,"color_bytes":color.get_data_size(),"normal_bytes":normal.get_data_size(),"mipmaps":true,"normal_convention":"OpenGL XY BC5; positive Y; no DX flip"})
	write_array("res://materials/desert_color_roughness.tres",color_paths)
	write_array("res://materials/desert_normals.tres",normal_paths)
	FileAccess.open("res://tools/desert/artifacts/palette_memory.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("Packed 6 shared Desert layers: BC3 2K albedo/linear roughness + BC5 1K normals.")
	quit()
func write_array(path: String,images: Array[String]) -> void:
	var text: String="[gd_resource type=\"Texture2DArray\" load_steps=%d format=3]\n\n" % (images.size()+1)
	var refs: Array[String]=[]
	for i in range(images.size()):
		text+="[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n" % [images[i],i+1]
		refs.append("ExtResource(\"%d\")" % (i+1))
	text+="\n[resource]\n_images = Array[Image](["+", ".join(refs)+"])\n"
	FileAccess.open(path,FileAccess.WRITE).store_string(text)
