extends SceneTree
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/biological_material_sources.json"));var array:Texture2DArray=load(manifest.array)
	var hashes:Dictionary={}
	for path:String in ["res://data/biological_material_sources.json",manifest.array,"res://scripts/chunk_terrain.gd","res://tools/biome_extensions/check_assets.gd"]:hashes[path]=FileAccess.get_sha256(path)
	assert(FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd").count(manifest.array)==2,"Both real terrain and shell array bindings must match provenance")
	assert(array.get_layers()==4 and array.get_width()==2048 and array.get_height()==2048)
	var total:int=0
	var readbacks:Array=[]
	for i in range(4):
		var record:Dictionary=manifest.assets[i];assert(FileAccess.get_sha256(record.source)==record.sha256)
		for path:String in [record.source,record.packed]:hashes[path]=FileAccess.get_sha256(path)
		var image:Image=load(record.packed);assert(image.has_mipmaps() and image.is_compressed() and image.get_format()==Image.FORMAT_DXT1);total+=image.get_data_size()
		assert(FileAccess.get_file_as_string(manifest.array).contains(record.packed),"Production array references provenance image "+record.name)
		if DisplayServer.get_name()!="headless":
			var actual:Image=array.get_layer_data(i);assert(actual!=null)
			print("BIOLOGICAL_READBACK ",record.name," ",actual.get_format()," ",actual.get_size()," bytes=",actual.get_data_size()," source=",image.get_data_size())
			var expected:Image=image.duplicate()
			if expected.is_compressed():assert(expected.decompress()==OK)
			if actual.is_compressed():assert(actual.decompress()==OK)
			var error:float=0
			for y in range(16,2048,64):
				for x in range(16,2048,64):
					var a:Color=actual.get_pixel(x,y);var b:Color=expected.get_pixel(x,y)
					error=maxf(error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
			print("BIOLOGICAL_READBACK_MAX_ERROR ",error)
			assert(error<.02,"Production biological GPU layer differs from provenance source "+record.name)
			readbacks.append({"name":record.name,"max_channel_error":error,"sample_count":1024})
	assert(total==manifest.array_gpu_bytes)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/check_assets.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"source_sha256":hashes,"source_hashes_valid":true,"production_array_references_valid":true,"gpu_readback_performed":DisplayServer.get_name()!="headless","readbacks":readbacks,"array":manifest.array,"compressed_array_bytes":total,"native_source_dimensions":[1254,1254],"production_dimensions":[2048,2048],"failures":[],"scope":"Four source/packed assets, both runtime binding paths, shared BC1/mipmap byte bound and optional actual GPU layer readback. Source color data are generated albedo, not measured height/normal/roughness scans or whole-biome artistic acceptance."},"\t"))
	print("EXTENSION_ASSETS_PASS four source hashes, four BC1/mipmapped 2048-square production images, ",total," shared GPU bytes; original generated resolution 1254 square");quit()
