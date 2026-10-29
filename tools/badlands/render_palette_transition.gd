extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/badlands_sampler.gd","res://shaders/badlands_material.gdshaderinc","res://shaders/terrain_biomes.gdshader"]:hashes[path]=FileAccess.get_sha256(path)
	var config:TerrainSettings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);config.beaches_enabled=false;config.rocky_coast_enabled=false
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:config.set(key+"_coverage",0)
	config.badlands_coverage=50;config.quarry_coverage=50
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=config;builder._configure_noise();var p:=Vector2.INF
	for i in range(1000):
		var candidate:=Vector2(i*7919%160000-80000,i*11939%160000-80000);builder._biome_weights(candidate.x,candidate.y)
		if builder._badlands_weight>.15 and builder._badlands_weight<.85 and builder._extra_weights[0]>.15 and builder._island_mask(candidate.x,candidate.y)>.1:p=candidate;break
	assert(p.is_finite(),"Actual Badlands/Quarry transition found")
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;camera.position=Vector3(p.x,builder._get_height(p.x,p.y)+300,p.y)
	terrain=scene.get_node("Terrain");terrain.settings=config;terrain.target=camera
	for key:String in ["start_in_beach","start_in_coast","start_in_mountain","start_in_swamp","start_in_savanna","start_in_forest","start_in_jungle","start_in_tropical","start_in_badlands"]:terrain.set(key,false)
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
	await capture("badlands_quarry","medium",focus,Vector3(-500,220,-700))
	await capture("badlands_quarry","normals",focus,Vector3(-100,50,-140),8)
	var atlas_nodes:int=0
	for node:MeshInstance3D in terrain._active_chunks.values():
		var material:ShaderMaterial=node.mesh.surface_get_material(0)
		if material.get_shader_parameter("badlands_palette_enabled") and material.get_shader_parameter("badlands_palette_slot")==8:atlas_nodes+=1
	assert(atlas_nodes>0,"Actual nine-slot materials staged by production terrain")
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during native transition review")
	var report:Dictionary={"actual_render":true,"captures":records,"nine_slot_material_nodes":atlas_nodes,"source_sha256":hashes,"focus":p,"maximum_lod":terrain.maximum_lod,"draw_distance":camera.far}
	FileAccess.open("res://tools/badlands/artifacts/render_palette_transition.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("BADLANDS_PALETTE_TRANSITION ",atlas_nodes," staged nine-slot materials")
	scene.queue_free();await process_frame;quit()
