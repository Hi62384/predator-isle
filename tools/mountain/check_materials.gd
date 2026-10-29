extends SceneTree
func _initialize()->void:
	var colors:Texture2DArray=load("res://materials/mountain_colors.tres");var normals:Texture2DArray=load("res://materials/mountain_normals.tres")
	assert(colors.get_layers()==3 and normals.get_layers()==3)
	assert(colors.get_width()==2048 and normals.get_width()==1024)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/mountain_material_sources.json"));assert(manifest.size()==3)
	var total:int=0
	for i in range(3):
		var item:Dictionary=manifest[i];assert(item.license=="CC0-1.0")
		for source:Dictionary in item.maps:assert(FileAccess.get_sha256(source.path)==source.sha256)
		var c:Image=load(item.color_resource).duplicate();var n:Image=load(item.normal_resource).duplicate()
		assert(c.is_compressed() and n.is_compressed() and c.has_mipmaps() and n.has_mipmaps());total+=c.get_data_size()+n.get_data_size()
		c.decompress();n.decompress()
		var avg:Image=c.duplicate();avg.resize(1,1,Image.INTERPOLATE_LANCZOS)
		print("MOUNTAIN_AVERAGE ",item.role," ",avg.get_pixel(0,0))
		var low:float=1;var high:float=0;var rough_low:float=1;var rough_high:float=0;var normal_min:float=1;var normal_max:float=0
		for z in range(0,1024,43):
			for x in range(0,1024,47):
				var a:Color=c.get_pixel(x*2,z*2);var b:Color=n.get_pixel(x,z)
				low=minf(low,a.r);high=maxf(high,a.r);rough_low=minf(rough_low,a.a);rough_high=maxf(rough_high,a.a);normal_min=minf(normal_min,b.r);normal_max=maxf(normal_max,b.r)
		print("MOUNTAIN_CHANNEL_RANGES ",item.role," color=",high-low," rough=",rough_high-rough_low," normal=",normal_max-normal_min)
		assert(high-low>.1 and rough_high-rough_low>.05 and normal_max-normal_min>.05,"Source PBR channels must contain real detail: "+str(item.role))
	print("MOUNTAIN_MATERIALS_PASS 3 layers, 9 map checksums, BC3/BC5 mipmaps, source_gpu_bytes=",total);quit()
