extends "res://tools/biome_extensions/render_all.gd"
const Candidate=preload("res://tools/biome_extensions/grown_plate_terrain_candidate.gd")
func install_field(builder)->void:
	builder.settings.alien_infected.conduit_cache_mib=0;builder._configure_noise()
	var field=Candidate.new();field.plate_relief=72;field.configure(builder.settings.alien_infected,builder.world_seed,builder,7);builder._extras[7]=field
func rebuild_private_cut()->void:
	var started:int=Time.get_ticks_msec()
	while not terrain._jobs.is_empty() or not terrain._ready_chunks.is_empty():
		await process_frame;assert(Time.get_ticks_msec()-started<180000)
	assert(terrain._staged.is_empty());install_field(terrain._sampler)
	for builder in terrain._idle_builders:install_field(builder)
	for node:MeshInstance3D in terrain._active_chunks.values():terrain._release_node(node)
	terrain._active_chunks.clear();terrain._mesh_cache.clear();terrain._wanted.clear();terrain._refresh_visible_chunks();assert(await settle())
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/biome_extension_structures.gd","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/grown_plate_terrain_candidate.gd","res://tools/biome_extensions/render_grown_plate_terrain_candidate.gd","res://tools/biome_extensions/artifacts/check_grown_plate_terrain_candidate.json"]:hashes[path]=FileAccess.get_sha256(path)
	var validation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_grown_plate_terrain_candidate.json"));assert(validation.passed)
	for source:String in validation.source_sha256:assert(FileAccess.get_sha256(source)==validation.source_sha256[source])
	var seen:Dictionary={};var cases:Array=[]
	for site:Dictionary in validation.sites:
		if seen.has(site.habit):continue
		seen[site.habit]=true;var p:=Vector2(site.x,site.z)
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.conduit_cache_mib=0
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(absf(terrain.get_height_at(Vector3(p.x,0,p.y))-site.base_height)<.02)
		var probe=preload("res://scripts/terrain_mesh_builder.gd").new();probe.world_seed=int(site.seed);probe.water_level=terrain.water_level;probe.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);install_field(probe)
		var focus:=Vector3(p.x,site.candidate_height+3,p.y);var shots:Dictionary={}
		for kind:String in ["medium","ground"]:
			var offset:=Vector2(-350,450) if kind=="medium" else Vector2(160,-200);var q:Vector2=p+offset
			var y:float=maxf(probe._get_height(q.x,q.y),terrain.get_height_at(Vector3(q.x,0,q.y)))+(160 if kind=="medium" else 8)
			shots[kind]=Vector3(q.x,y,q.y)-focus
		var suffix:String=str(int(site.seed))+"_"+str(int(site.habit))
		for kind:String in shots:await capture("grown_crust_original_"+suffix,kind,focus,shots[kind])
		started=Time.get_ticks_usec();await rebuild_private_cut();fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(absf(terrain.get_height_at(Vector3(p.x,0,p.y))-site.candidate_height)<.02)
		for kind:String in shots:await capture("grown_crust_candidate_"+suffix,kind,focus,shots[kind])
		cases.append(site);scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Private study source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_grown_plate_terrain_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_change_kept":false,"private_worker_sampler_override":true,"cases":cases,"captures":records,"source_sha256":hashes,"scope":"Private broad grown-crust landform study, up to two actual dry hard/dormant regional sites, paired same-camera/same-light original and candidate medium/ground views, actual production worker/atlas/mesh/staging path. Drained hidden scene is reloaded, not a live production swap. Not GPU/startup benchmark, collision/route or artistic acceptance."},"  "))
	print("GROWN_PLATE_TERRAIN_RENDER_DONE ",records.size());quit()
