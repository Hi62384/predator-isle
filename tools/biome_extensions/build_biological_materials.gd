extends SceneTree
## Offline material packing only. Source albedos remain untouched.
## RGB is sRGB; no claim that generated albedo is a measured height/normal scan.
func _initialize()->void:
	if OS.get_cmdline_user_args().has("mycelium-v2"):
		var image:=Image.load_from_file("res://assets/textures/biological/mycelium_albedo_v2.png");assert(image!=null)
		print("BIOLOGICAL_SOURCE mycelium_v2 ",image.get_size())
		image.resize(2048,2048,Image.INTERPOLATE_LANCZOS);image.convert(Image.FORMAT_RGB8);image.generate_mipmaps()
		assert(image.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGB)==OK)
		assert(ResourceSaver.save(image,"res://materials/biological_color_mycelium_v2.res")==OK)
		print("BIOLOGICAL_PACK mycelium_v2 ",image.get_data_size());quit();return
	for name:String in ["mycelium","nerve","carapace","membrane"]:
		var source:String="res://assets/textures/biological/"+name+"_albedo_v1.png";var image:=Image.load_from_file(source)
		assert(image!=null);print("BIOLOGICAL_SOURCE ",name," ",image.get_size())
		# A shared power-of-two production size gives predictable mip/compression cost.
		image.resize(2048,2048,Image.INTERPOLATE_LANCZOS);image.convert(Image.FORMAT_RGB8);image.generate_mipmaps()
		assert(image.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RGB)==OK)
		assert(ResourceSaver.save(image,"res://materials/biological_color_"+name+".res")==OK)
		print("BIOLOGICAL_PACK ",name," ",image.get_data_size()," bytes; format ",image.get_format())
	quit()
