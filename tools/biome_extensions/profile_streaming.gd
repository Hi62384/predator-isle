extends "res://tools/biome_extensions/render_all.gd"
var settle_seconds:Array=[]
func settle()->bool:
	var started:int=Time.get_ticks_usec();var success:bool=await super.settle()
	settle_seconds.append((Time.get_ticks_usec()-started)/1000000.0);return success
func drain_workers()->void:
	var started:int=Time.get_ticks_msec()
	while not terrain._jobs.is_empty():
		await process_frame;assert(Time.get_ticks_msec()-started<180000,"Drain only this fixture's pending workers")
func worker_memos()->Array:
	# Only read after all worker jobs have stopped mutating their dictionaries.
	assert(terrain._jobs.is_empty())
	var result:Array=[]
	for builder in terrain._idle_builders:
		var memo:Dictionary=builder.get_meta(preload("res://scripts/biome_extension_structures.gd").CONDUIT_MEMO_KEY,{})
		result.append({"numeric_bytes":memo.get("bytes",0),"entries":memo.get("entries",{}).size(),"hits":memo.get("hits",0),"misses":memo.get("misses",0),"validations":memo.get("validations",0)})
	return result
func worker_queries()->Array:
	assert(terrain._jobs.is_empty());var result:Array=[]
	for builder in terrain._idle_builders:
		var field=builder._extras[7]
		assert(field._query_tiles.size()<=512 and field._tile_probes.size()<=512)
		if not builder.settings.alien_infected.network_query_cache_enabled:assert(field._query_tiles.is_empty() and field._tile_probes.is_empty())
		result.append({"tiles":field._query_tiles.size(),"admission_tiles":field._tile_probes.size(),"tile_builds":field.tile_builds,"tile_hits":field.tile_hits,"uncached_queries":field.uncached_queries,"serialized_metadata_bytes":var_to_bytes([field._query_tiles,field._tile_probes]).size()})
	return result
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless")
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var key:String="alien_infected";var label:String="baseline";var cache_mib:int=-1;var scenario:String="nearby";var query_cache:int=-1
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):key=arg.trim_prefix("only=")
		if arg.begins_with("label="):label=arg.trim_prefix("label=")
		if arg.begins_with("cache="):cache_mib=clampi(int(arg.trim_prefix("cache=")),0,16)
		if arg.begins_with("query="):query_cache=clampi(int(arg.trim_prefix("query=")),0,1)
		if arg.begins_with("scenario="):scenario=arg.trim_prefix("scenario=")
	assert(TerrainSettings.EXTENSION_KEYS.has(key) and label.is_valid_identifier())
	assert(scenario in ["nearby","root"])
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://config/biomes/alien_infected_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/terrain_feature_meshes.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/artifacts/previews.json","res://tools/biome_extensions/profile_streaming.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var previews=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"))
	var item:Dictionary=previews.families[key].primary;var p:=Vector2(item.x,item.z)
	var offsets:Array[Vector2]=[Vector2.ZERO,Vector2(768,256),Vector2(1536,512),Vector2.ZERO];var seed_id:int=73921
	if scenario=="root":
		assert(key=="alien_infected")
		var admission_path:String="res://tools/biome_extensions/artifacts/check_carapace_admission.json";hashes[admission_path]=FileAccess.get_sha256(admission_path)
		var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));assert(admission.passed)
		var site:Dictionary=admission.cases[0];p=Vector2(site.position[0],site.position[1]);seed_id=site.seed
		offsets=[Vector2(-4096,-1024),Vector2(-768,-256),Vector2(768,256),Vector2(4096,1024),Vector2.ZERO]
	for path:String in ["res://scripts/terrain_settings.gd","res://scripts/biome_extension_sampler.gd","res://tools/biome_extensions/render_all.gd"]:hashes[path]=FileAccess.get_sha256(path)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.extension_preview=key;terrain.extension_preview_position=p;terrain.target=camera;terrain.profile_streaming=true
	terrain.world_seed=seed_id
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	if cache_mib>=0:terrain.settings.alien_infected.conduit_cache_mib=cache_mib
	if query_cache>=0:terrain.settings.alien_infected.network_query_cache_enabled=query_cache==1
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide()
	if not await settle():quit(1);return
	fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	await drain_workers();var initial_memos:Array=worker_memos();var runs:Array=[]
	var initial_queries:Array=worker_queries() if key=="alien_infected" else []
	for offset:Vector2 in offsets:
		var q:Vector2=p+offset;var focus:=Vector3(q.x,terrain.get_height_at(Vector3(q.x,0,q.y)),q.y)
		await capture(key,"profile_"+label+"_"+str(runs.size()),focus,Vector3(-100,4,-130))
		await drain_workers();runs.append({"camera":camera.position,"committed":terrain.committed_revision,"revision":terrain.partition_revision,"cut_wait_s":settle_seconds[-1],"worker_conduit_caches":worker_memos()})
		if key=="alien_infected":runs[-1]["worker_network_query_caches"]=worker_queries()
	var actual_mib:int=terrain._settings_snapshot.alien_infected.conduit_cache_mib
	var actual_queries:bool=terrain._settings_snapshot.alien_infected.network_query_cache_enabled
	if query_cache>=0:assert(actual_queries==(query_cache==1),"Query cache setting reached actual scene snapshot")
	if cache_mib>=0:assert(actual_mib==cache_mib,"Private setting reached the production scene snapshot")
	var workers:Array=[]
	for builder in terrain._idle_builders:
		assert(builder.settings.alien_infected.conduit_cache_mib==actual_mib,"Actual independent worker received setting")
		assert(builder.settings.alien_infected.network_query_cache_enabled==actual_queries,"Actual independent worker received query setting")
		var memo:Dictionary=builder.get_meta(preload("res://scripts/biome_extension_structures.gd").CONDUIT_MEMO_KEY,{})
		if actual_mib==0:assert(memo.is_empty(),"Disabled cache has no retained numerical data")
		else:assert(memo.get("bytes",0)<=actual_mib*1024*1024 and memo.get("entries",{}).size()<=32,"Actual worker cache stays bounded")
		workers.append({"numeric_bytes":memo.get("bytes",0),"entries":memo.get("entries",{}).size(),"hits":memo.get("hits",0),"misses":memo.get("misses",0),"validations":memo.get("validations",0)})
	assert(not workers.is_empty() and workers.size()<=terrain.worker_count)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Streaming profile source changed "+path)
	var report:Dictionary={"actual_render":true,"passed":true,"label":label,"biome":key,"scenario":scenario,"seed":seed_id,"focus":p,"conduit_cache_mib":actual_mib,"initial_worker_conduit_caches":initial_memos,"worker_conduit_caches":workers,"initial_fill_s":fill_seconds,"max_plan_ms":terrain.max_plan_ms,"max_partition_swap_ms":terrain.max_partition_swap_ms,"streaming":terrain.streaming_records,"captures":records,"runs":runs,"adapter":RenderingServer.get_video_adapter_name(),"view_distance":camera.far,"cache_count":terrain._mesh_cache.size(),"pool_count":terrain._chunk_pool.size(),"source_sha256":hashes,"profile_scope":"Actual production workers, upload, supplementary resources, collision staging and complete-cut commit; declared nearby or root-focused teleport scenario. Worker metadata is read only after jobs drain. Initial fill excludes process launch/scene instantiation. Warm per-view GPU/frame samples are not uninterrupted walking or an isolated shader benchmark."}
	report["network_query_cache_enabled"]=actual_queries;report["initial_worker_network_query_caches"]=initial_queries;report["worker_network_query_caches"]=worker_queries() if key=="alien_infected" else []
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_streaming_"+key+"_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STREAMING_PROFILE_DONE ",label);scene.queue_free();await process_frame;quit()
