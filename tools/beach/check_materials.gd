extends SceneTree
func _initialize()->void:
	var sources=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_material_sources.json"));assert(sources is Array and sources.size()==4)
	var bytes:int=0;var ids:Array=[]
	for source:Dictionary in sources:
		assert(source.license=="CC0-1.0" and source.creation_method=="PBRPhotogrammetry")
		assert(not ids.has(source.id));ids.append(source.id)
		for map:Dictionary in source.maps:assert(FileAccess.get_sha256(map.path)==map.sha256,"Beach PBR source hash")
		var color:Image=load(source.color_resource);var normal:Image=load(source.normal_resource)
		assert(color.get_width()==2048 and color.get_height()==2048 and color.has_mipmaps() and color.is_compressed())
		assert(normal.get_width()==1024 and normal.get_height()==1024 and normal.has_mipmaps() and normal.is_compressed())
		bytes+=color.get_data_size()+normal.get_data_size()
	assert(bytes<32*1024*1024)
	var config:Resource=load("res://config/biomes/beach_settings.tres")
	var shader:String=FileAccess.get_file_as_string("res://shaders/beach_material.gdshaderinc")
	for name:String in config.uniforms():assert(shader.contains("uniform float "+name),"Beach uniform wiring: "+name)
	assert(shader.contains("textureGrad") and shader.contains("transpose(rotation)") and not shader.contains("NORMAL_MAP ="))
	print("BEACH_MATERIALS 4 photographed sources, compressed GPU bytes=",bytes," hashes/mips/uniforms/normal basis passed");quit()
