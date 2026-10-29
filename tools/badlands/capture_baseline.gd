extends SceneTree
func _initialize()->void:
	assert(not FileAccess.file_exists("res://data/pre_badlands_mesh_hashes.json"),"Pre-change fixture already exists; do not overwrite it with post-change output")
	var records:Array=[]
	for preset:String in ["saved_world","tropical","mixed_tropical","mountain","coast"]:
		var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		if preset!="saved_world":
			for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:b.settings.set(biome+"_coverage",0)
			b.settings.beaches_enabled=preset=="coast";b.settings.rocky_coast_enabled=preset=="coast"
			b.settings.tropical_coverage=100 if preset!="mountain" else 0
			if preset=="mountain":b.settings.mountain_coverage=100
			if preset=="mixed_tropical":b.settings.forest_coverage=50;b.settings.forest_region_size=14000
		b._configure_noise()
		for cell:Vector2i in [Vector2i(21,17),Vector2i(-43,-384)]:
			var mesh:Array=b.build(cell,16);var hashes:Array=[]
			for channel in range(Mesh.ARRAY_MAX):
				var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(mesh[channel]));hashes.append(hash.finish().hex_encode())
			records.append({"preset":preset,"cell":[cell.x,cell.y],"hashes":hashes})
	FileAccess.open("res://data/pre_badlands_mesh_hashes.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha256":FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd"),"records":records},"\t"));print("PRE_BADLANDS_BASELINE_CAPTURED");quit()
