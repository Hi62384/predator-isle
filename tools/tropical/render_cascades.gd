extends "res://tools/biome_extensions/render_all.gd"
func vector2_from_report(value:String)->Vector2:
	var expression:=RegEx.new();assert(expression.compile("[-+]?[0-9]+(?:\\.[0-9]+)?")==OK)
	var numbers:Array[RegExMatch]=expression.search_all(value);assert(numbers.size()==2)
	return Vector2(float(numbers[0].get_string()),float(numbers[1].get_string()))
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scripts/tropical_sampler.gd","res://scripts/tropical_settings.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://shaders/terrain_features.gdshader","res://shaders/tropical_material.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://tools/tropical/artifacts/check_cascades.json","res://tools/tropical/render_cascades.gd","res://tools/biome_extensions/render_all.gd","res://config/world/terrain_settings.tres","res://scenes/main.tscn","res://project.godot"]:hashes[path]=FileAccess.get_sha256(path)
	var tested=JSON.parse_string(FileAccess.get_file_as_string("res://tools/tropical/artifacts/check_cascades.json"));assert(tested.passed and tested.failures.is_empty())
	var used:Dictionary={};var staged_counts:Array=[]
	for item:Dictionary in tested.records:
		var seed_id:int=int(item.seed)
		if used.has(seed_id):continue
		used[seed_id]=true;var p:Vector2=vector2_from_report(item.position)
		var config:TerrainSettings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:config.set(key+"_coverage",0)
		config.tropical_coverage=100;config.beaches_enabled=false;config.rocky_coast_enabled=false
		var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=config;b.world_seed=seed_id;b._configure_noise()
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;camera.near=.1
		camera.position=Vector3(p.x,b.get_water_surface_height(p.x,p.y)+80,p.y)
		terrain=scene.get_node("Terrain");terrain.settings=config;terrain.world_seed=seed_id;terrain.target=camera
		for key:String in ["start_in_beach","start_in_coast","start_in_mountain","start_in_swamp","start_in_savanna","start_in_forest","start_in_jungle","start_in_tropical","start_in_badlands"]:terrain.set(key,false)
		var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
		var focus:=Vector3(p.x,terrain._sampler.get_water_surface_height(p.x,p.y),p.y)
		await capture("tropical_cascade_"+str(seed_id),"medium",focus,Vector3(-90,30,-130))
		await capture("tropical_cascade_"+str(seed_id),"aerial",focus,Vector3(-220,180,-240))
		await capture("tropical_cascade_"+str(seed_id),"ground",focus,Vector3(-8,3,-14))
		var batches:int=0;var triangles:int=0
		for node:MeshInstance3D in terrain._active_chunks.values():
			var features:MeshInstance3D=node.get_node_or_null("TerrainFeatures")
			if features==null or features.mesh==null:continue
			for surface in range(features.mesh.get_surface_count()):
				var material:ShaderMaterial=features.mesh.surface_get_material(surface)
				if int(material.get_shader_parameter("kind"))==3:batches+=1;triangles+=features.mesh.surface_get_array_len(surface)/3
		assert(batches>0 and triangles>=64,"Actual production worker/staging cascade surfaces required")
		staged_counts.append({"seed":seed_id,"foam_batches":batches,"foam_triangles":triangles,"position":p})
		scene.queue_free();await process_frame;await process_frame
	assert(used.size()==3 and records.size()==9)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during native cascade review")
	FileAccess.open("res://tools/tropical/artifacts/render_cascades.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"captures":records,"staged_foam":staged_counts,"source_sha256":hashes,"maximum_lod":6,"draw_distance":50000,"scope":"Nine native views of actual three-seed Tropical cascades through production workers, full hierarchy and existing foam materials. Not a complete Tropical visual/route/performance certificate."},"  "))
	print("TROPICAL_CASCADE_RENDER ",records.size()," views / ",used.size()," seeds");quit()
