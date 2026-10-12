extends SceneTree
const IDS=["Rock064","Rock058","Rock051","Rock060","Rock030","Rock061","Rock050","Rocks007","Rocks011"]
func _initialize() -> void:
	var sheet:=Image.create(768,768,false,Image.FORMAT_RGB8)
	for i in range(IDS.size()):
		var normal:=Image.load_from_file("res://assets/terrain/cliff_normals/ambientcg/"+IDS[i].to_lower()+"_normal.jpg")
		assert(normal!=null and normal.get_size()==Vector2i(2048,2048))
		var thumb:=normal.duplicate()
		thumb.resize(256,256)
		sheet.blit_rect(thumb,Rect2i(0,0,256,256),Vector2i((i%3)*256,(i/3)*256))
		normal.convert(Image.FORMAT_RG8)
		normal.generate_mipmaps()
		assert(normal.compress_from_channels(Image.COMPRESS_S3TC,Image.USED_CHANNELS_RG)==OK)
		assert(normal.get_format()==Image.FORMAT_RGTC_RG)
		assert(ResourceSaver.save(normal,"res://materials/cliff_normal_"+IDS[i]+".res")==OK)
		print("Packed 2K BC5 ",IDS[i])
	sheet.save_png("res://tools/cliff_normal_sources.png")
	quit()
