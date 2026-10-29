extends SceneTree
func _initialize()->void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_previews.json"));var records:Array=[]
	for name:String in ["lush_plain","rocky_highland","freshwater_lake"]:
		var item:Dictionary=manifest.features[name]
		for resolution:int in [16,64,128]:
			var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.profile_build=true
			for biome:String in ["grass","forest","savanna","swamp","jungle","mountain"]:b.settings.set(biome+"_coverage",0)
			b.settings.tropical_coverage=100;b._configure_noise()
			var start:int=Time.get_ticks_usec();var mesh:Array=b.build(Vector2i(floori(item.x/256),floori(item.z/256)),resolution)
			var total:float=float(Time.get_ticks_usec()-start)/1000;var breakdown:Dictionary=b.last_build_profile.duplicate(true)
			start=Time.get_ticks_usec();var water:Array=b.build_swamp_water(mesh,resolution);var water_ms:float=float(Time.get_ticks_usec()-start)/1000
			records.append({"feature":name,"resolution":resolution,"cold_build_ms":total,"breakdown":breakdown,"water_mesh_ms":water_ms,"has_water":not water.is_empty(),"numerical_field_us":b._tropical.timings.duplicate(true)})
	var report:Dictionary={"records":records,"source_sha256":FileAccess.get_sha256("res://scripts/tropical_sampler.gd"),"note":"Isolated headless CPU probe; not GPU or native frame time. One cold build per location/resolution; no statistical tail claim."}
	FileAccess.open("res://tools/tropical/artifacts/profile_cpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("TROPICAL_CPU_PROFILE ",JSON.stringify(report));quit()
