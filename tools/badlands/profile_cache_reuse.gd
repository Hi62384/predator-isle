extends SceneTree
## Work-count diagnostic, not a performance benchmark or acceptance certificate.
func _initialize()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/badlands_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://tools/badlands/trace_cache_sampler.gd","res://tools/badlands/profile_cache_reuse.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	var records:Array=[]
	for feature:String in ["painted_hills","dense_gullies","hoodoo_country"]:
		var site:Dictionary=manifest.features[feature]
		for dimensions:Vector2i in [Vector2i(256,64),Vector2i(4096,64),Vector2i(16384,64)]:
			var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.chunk_size=dimensions.x
			for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
			b.settings.badlands_coverage=100;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b._configure_noise()
			b._badlands=preload("res://tools/badlands/trace_cache_sampler.gd").new();b._badlands.configure(b.settings.badlands,b.world_seed,b)
			var cell:=Vector2i(floori(site.x/dimensions.x),floori(site.z/dimensions.x));var start:int=Time.get_ticks_usec()
			var arrays:Array=b.build(cell,dimensions.y)
			assert(not arrays.is_empty())
			records.append({"feature":feature,"span_m":dimensions.x,"resolution":dimensions.y,"coordinate":str(cell),"diagnostic_elapsed_ms":(Time.get_ticks_usec()-start)/1000.0,"counts":b._badlands.counters.duplicate(),"retained_trees":b._badlands._trees.size(),"retained_nodes":b._badlands._nodes.size(),"retained_patches":b._badlands._patches.size()})
			print("BADLANDS_CACHE_WORK ",records.back())
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Diagnostic source changed")
	FileAccess.open("res://tools/badlands/artifacts/profile_cache_reuse.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"source_sha256":hashes,"scope":"Instrumented work counts at actual inland sites. Diagnostic dispatch adds overhead; elapsed times must not be compared with uninstrumented benchmarks."},"  "));quit()
