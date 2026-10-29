extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_production_nerve_fibres.gd","res://tools/biome_extensions/artifacts/check_production_nerve_fibres.json"]:hashes[path]=FileAccess.get_sha256(path)
	var validation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_production_nerve_fibres.json"));assert(validation.passed)
	for source:String in validation.source_sha256:assert(FileAccess.get_sha256(source)==validation.source_sha256[source])
	var p:=Vector2(10427.419921875,-1825.93872070313);var axis:=Vector2(.960382878780365,.278684109449387);var side:=Vector2(-axis.y,axis.x)
	var probe=preload("res://tools/biome_extensions/check_production_nerve_fibres.gd").new();var raised=probe.field_builder(73921,1,24);var disabled=probe.field_builder(73921,1,0)
	var base_height:float=disabled._get_height(p.x,p.y);var new_height:float=raised._get_height(p.x,p.y);var focus:=Vector3(p.x,maxf(base_height,new_height)+3,p.y);var shots:Dictionary={}
	for kind:String in ["medium","ground","profile"]:
		var horizontal:Vector2=-axis*(450 if kind=="medium" else 110)+side*(550 if kind=="medium" else (150 if kind=="ground" else 320));var q:Vector2=p+horizontal
		var y:float=maxf(disabled._get_height(q.x,q.y),raised._get_height(q.x,q.y))+(180 if kind=="medium" else (5 if kind=="ground" else 18))
		shots[kind]=Vector3(q.x,y,q.y)-focus
	for strength:float in [0,24]:
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=73921;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.nerve_fibre_height=strength
		var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
		assert(terrain._sampler._extras[7].get_script()==load("res://scripts/alien_infected_sampler.gd"),"Actual production field, no private sampler override")
		assert(absf(terrain.get_height_at(Vector3(p.x,0,p.y))-(base_height if strength==0 else new_height))<.02)
		for kind:String in shots:
			await capture("production_nerve_fibres_zero" if strength==0 else "production_nerve_fibres_enabled",kind,focus,shots[kind]);records[-1]["nerve_fibre_height_m"]=strength
		scene.queue_free();await process_frame;await process_frame
	probe.free()
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Native review source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_production_nerve_fibres.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"production_path":true,"private_sampler_override":false,"captures":records,"source_sha256":hashes,"site":{"seed":73921,"x":p.x,"z":p.y,"base_height":base_height,"enabled_height":new_height,"added_height_m":new_height-base_height},"scope":"Six actual production-streamed default-versus-zero views at one dry nerve-lowland site, unchanged camera/light/50km hierarchy, GPU measurement enabled. Does not certify all artistic targets, uninterrupted streaming or whole-world navigation."},"  "))
	print("PRODUCTION_NERVE_FIBRES_RENDER_DONE ",records.size());quit()
