extends SceneTree
func _initialize()->void:
	var records:Array=[]
	for span:float in [256,16384]:
		for resolution:int in [16,64,128]:
			var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.profile_build=true;b.chunk_size=span
			for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:b.settings.set(biome+"_coverage",0)
			b.settings.badlands_coverage=100;b._configure_noise();var start:int=Time.get_ticks_usec();b.build(Vector2i(1,1),resolution)
			var record:Dictionary={"span":span,"resolution":resolution,"ms":float(Time.get_ticks_usec()-start)/1000,"breakdown":b.last_build_profile,"raw_us":b._badlands.timings};records.append(record);print("BADLANDS_CPU ",record)
	FileAccess.open("res://tools/badlands/artifacts/profile_cpu.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"));quit()
