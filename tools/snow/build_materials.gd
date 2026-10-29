extends SceneTree
## Offline packing only; shared BC3 colour/roughness, BC5 GL normals, BC4 height.
## Raw sources are .gdignore'd; runtime uses only the prepared resources.
const IDS=["Snow005","Snow006","Snow014","Ice004"]
func _initialize()->void:
	var colors:Array[String]=[];var normals:Array[String]=[];var heights:Array[String]=[]
	for id in IDS:
		var prefix:String="res://assets/textures/snow/%s/%s_2K-JPG_"%[id,id]
		var color:=Image.load_from_file(prefix+"Color.jpg")
		var rough:=Image.load_from_file(prefix+"Roughness.jpg")
		var normal:=Image.load_from_file(prefix+"NormalGL.jpg")
		var height:=Image.load_from_file(prefix+"Displacement.jpg")
		assert(color!=null and rough!=null and normal!=null and height!=null)
		assert(color.get_size()==Vector2i(2048,2048))
		color.convert(Image.FORMAT_RGBA8)
		for y in range(2048):
			for x in range(2048):
				var pixel:=color.get_pixel(x,y);pixel.a=rough.get_pixel(x,y).r;color.set_pixel(x,y,pixel)
		color.generate_mipmaps()
		assert(color.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGBA)==OK)
		normal.resize(1024,1024,Image.INTERPOLATE_LANCZOS);normal.convert(Image.FORMAT_RG8);normal.generate_mipmaps()
		assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		height.resize(1024,1024,Image.INTERPOLATE_LANCZOS);height.convert(Image.FORMAT_R8);height.generate_mipmaps()
		assert(height.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_R)==OK)
		for item in [[color,"color",colors],[normal,"normal",normals],[height,"height",heights]]:
			var path:String="res://materials/snow_%s_%s.res"%[item[1],id]
			assert(ResourceSaver.save(item[0],path)==OK);item[2].append(path)
	write_array("res://materials/snow_color_roughness.tres",colors)
	write_array("res://materials/snow_normals.tres",normals)
	write_array("res://materials/snow_heights.tres",heights)
	print("SNOW_PBR_PACKED: four shared CC0 materials, 2K BC3 colour/roughness, 1K BC5 normals and BC4 height; mipmapped.")
	quit()
func write_array(path:String,images:Array[String])->void:
	var content:String="[gd_resource type=\"Texture2DArray\" load_steps=%d format=3]\n\n"%(images.size()+1)
	var refs:Array[String]=[]
	for i in range(images.size()):
		content+="[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n"%[images[i],i+1];refs.append("ExtResource(\"%d\")"%(i+1))
	content+="\n[resource]\n_images = Array[Image](["+", ".join(refs)+"])\n"
	FileAccess.open(path,FileAccess.WRITE).store_string(content)
