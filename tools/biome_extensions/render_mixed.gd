extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var config:TerrainSettings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);config.beaches_enabled=false;config.rocky_coast_enabled=false
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:config.set(key+"_coverage",20);config.set(key+"_region_size",14000)
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=config;b._configure_noise();var p:=Vector2.INF
	for i in range(10000):
		var candidate:=Vector2(i*7919%160000-80000,i*11939%160000-80000);var old:Vector4=b._biome_weights(candidate.x,candidate.y);var extra:float=0
		for weight:float in b._extra_weights:extra+=weight
		if extra>.2 and extra<.8 and old.x+old.y+old.z+old.w+b._jungle_weight+b._mountain_weight+b._tropical_weight+b._badlands_weight>.2 and b._island_mask(candidate.x,candidate.y)>.1:p=candidate;break
	assert(p.is_finite(),"Find actual old/new material transition")
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;camera.position=Vector3(p.x,b._get_height(p.x,p.y)+400,p.y)
	terrain=scene.get_node("Terrain");terrain.settings=config;terrain.target=camera
	for key:String in ["start_in_beach","start_in_coast","start_in_mountain","start_in_swamp","start_in_savanna","start_in_forest","start_in_jungle","start_in_tropical","start_in_badlands"]:terrain.set(key,false)
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
	await capture("mixed","medium",focus,Vector3(-700,400,-1000));await capture("mixed","normals",focus,Vector3(-120,80,-170),8)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_mixed.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"all_sixteen_owners_enabled":true,"old_new_transition_focus":str(p),"captures":records,"initial_stream_fill_s":fill_seconds,"draw_distance":50000,"maximum_lod":terrain.maximum_lod},"\t"))
	scene.queue_free();await process_frame;print("EXTENSION_MIXED_DONE ",p);quit()
