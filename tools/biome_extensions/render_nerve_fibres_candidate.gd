extends "res://tools/biome_extensions/render_all.gd"
const Candidate=preload("res://tools/biome_extensions/nerve_fibres_candidate.gd")
func drain()->void:
	var start:int=Time.get_ticks_msec()
	while not terrain._jobs.is_empty() or not terrain._ready_chunks.is_empty():
		await process_frame;assert(Time.get_ticks_msec()-start<180000,"Private fixture drain timeout")
func install_field(builder,height:float)->void:
	builder.settings.alien_infected.conduit_cache_mib=0;builder._configure_noise()
	var field=Candidate.new();field.fibre_height=height;field.configure(builder.settings.alien_infected,builder.world_seed,builder,7);builder._extras[7]=field
func rebuild_private_cut(height:float)->void:
	await drain();assert(terrain._staged.is_empty())
	install_field(terrain._sampler,height)
	for builder in terrain._idle_builders:install_field(builder,height)
	# This is a controlled hidden-scene reload, not a proposed live cut swap.
	# Release only this fixture's generated nodes; no saved scene/settings edits.
	for node:MeshInstance3D in terrain._active_chunks.values():terrain._release_node(node)
	terrain._active_chunks.clear();terrain._mesh_cache.clear();terrain._wanted.clear()
	terrain._refresh_visible_chunks();assert(await settle());await drain()
	for builder in terrain._idle_builders:assert(builder._extras[7].get_script()==Candidate,"Actual reused production workers run the private prototype")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/nerve_fibres_candidate.gd","res://tools/biome_extensions/render_nerve_fibres_candidate.gd","res://tools/biome_extensions/artifacts/check_nerve_fibres_candidate.json"]:hashes[path]=FileAccess.get_sha256(path)
	var validation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_nerve_fibres_candidate.json"));assert(validation.passed);var site:Dictionary=validation.preview_site
	var p:=Vector2(site.x,site.z);var axis:=Vector2(site.axis[0],site.axis[1]);var side:=Vector2(-axis.y,axis.x)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.conduit_cache_mib=0
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());await drain();fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	await rebuild_private_cut(0)
	var base_height:float=terrain.get_height_at(Vector3(p.x,0,p.y));assert(absf(base_height-site.base_height)<.02)
	var probe=preload("res://scripts/terrain_mesh_builder.gd").new();probe.world_seed=int(site.seed);probe.water_level=terrain.water_level;probe.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);install_field(probe,24)
	var focus:=Vector3(p.x,maxf(base_height,site.candidate_height)+3,p.y);var shots:Dictionary={}
	for kind:String in ["medium","ground","profile"]:
		var horizontal:Vector2=-axis*(450 if kind=="medium" else 110)+side*(550 if kind=="medium" else (150 if kind=="ground" else 320))
		var q:Vector2=p+horizontal;var old_height:float=terrain.get_height_at(Vector3(q.x,0,q.y));var new_height:float=probe._get_height(q.x,q.y)
		var y:float=maxf(old_height,new_height)+(180 if kind=="medium" else (5 if kind=="ground" else 18))
		shots[kind]=Vector3(q.x,y,q.y)-focus
	for kind:String in shots:await capture("nerve_fibres_original",kind,focus,shots[kind])
	start=Time.get_ticks_usec();await rebuild_private_cut(24);fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	var actual_height:float=terrain.get_height_at(Vector3(p.x,0,p.y));assert(absf(actual_height-site.candidate_height)<.02 and actual_height-base_height>.5)
	for kind:String in shots:await capture("nerve_fibres_candidate",kind,focus,shots[kind])
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Prototype review source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_nerve_fibres_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_change_kept":false,"private_worker_sampler_override":true,"site":site,"actual_added_height_at_site_m":actual_height-base_height,"captures":records,"source_sha256":hashes,"scope":"Six same-camera/same-lighting original-versus-private tapered fibre views, actual production worker/atlas/mesh/staging path and 50km hierarchy. Only this hidden fixture's drained samplers/generated cut are replaced; not a production registration or safe live-reload implementation. Numeric controls/resources remain private; geometry/appearance study, not startup/GPU benchmark, traversal or artistic sign-off."},"  "))
	print("NERVE_FIBRES_RENDER_DONE ",records.size());scene.queue_free();await process_frame;quit()
