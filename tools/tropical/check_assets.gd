extends SceneTree
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_material_sources.json"));assert(manifest.records.size()==8)
	var checked:int=0
	for item:Dictionary in manifest.records:
		for source:Dictionary in item.maps:assert(FileAccess.get_sha256(source.path)==source.sha256,"Changed source "+source.path);checked+=1
	var arrays:Dictionary={}
	for name:String in ["savanna","jungle","swamp","mountain"]:
		for kind:String in ["colors","normals"]:
			var array:Texture2DArray=load("res://materials/"+name+"_"+kind+".tres");arrays[name+"_"+kind]=array
			assert(array!=null and array.get_layers()>0)
	for item:Dictionary in manifest.records:
		assert(item.shared_layer<arrays[item.shared_array].get_layers())
		for kind:String in ["color","normal"]:
			var path:String=item.get(kind+"_resource","res://materials/jungle_"+kind+"_"+item.id+".res")
			var im:Image=load(path);assert(im!=null and im.is_compressed() and im.has_mipmaps(),"Packed PBR "+path)
	var shader:Shader=load("res://shaders/terrain_biomes.gdshader");var uniforms:Dictionary={}
	for u:Dictionary in shader.get_shader_uniform_list():uniforms[u.name]=true
	var config:Resource=load("res://config/biomes/tropical_settings.tres")
	for key:String in config.uniforms():assert(uniforms.has(key),"Missing Tropical uniform "+key)
	print("TROPICAL_ASSETS_PASS ",checked," source hashes; shared compressed mipmapped PBR arrays and uniforms");quit()
