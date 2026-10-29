extends SceneTree
var mode:String="badlands"
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
func _initialize()->void:call_deferred("run")
func percentile(values:Array,p:float)->float:
	values.sort();return values[clampi(int((values.size()-1)*p),0,values.size()-1)] if not values.is_empty() else -1
func settle()->float:
	var start:int=Time.get_ticks_usec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_usec()-start>120000000:push_error("Benchmark fill timeout");quit(1);return -1
	return float(Time.get_ticks_usec()-start)/1000000
func measure(label:String,speed:float)->void:
	var frames:Array=[];var gpu:Array=[];var start:int=Time.get_ticks_usec();var last:int=start
	while Time.get_ticks_usec()-start<3000000:
		await process_frame
		var now:int=Time.get_ticks_usec();var delta:float=float(now-last)/1000000;last=now;frames.append(delta*1000)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		camera.position.x+=speed*delta
		camera.position.y=maxf(terrain.water_level,terrain.get_height_at(camera.position))+80
	var g:float=percentile(gpu,.5)
	records.append({"case":label,"speed":speed,"frame_p50_ms":percentile(frames,.5),"frame_p95_ms":percentile(frames,.95),"frame_max_ms":percentile(frames,1),"gpu_p50_ms":g if g>0 else null,"leaves":terrain._active_chunks.size(),"static_memory_bytes":OS.get_static_memory_usage(),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"settle_s":await settle()})
func run()->void:
	var started_hashes:Dictionary={}
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/badlands_settings.gd","res://config/biomes/badlands_settings.tres","res://scripts/badlands_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://shaders/badlands_material.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://tools/badlands/benchmark.gd"]:started_hashes[path]=FileAccess.get_sha256(path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):mode=arg.trim_prefix("mode=")
	var b=preload("res://scripts/terrain_mesh_builder.gd").new()
	b.profile_build=true
	b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]:b.settings.set(biome+"_coverage",100 if biome==mode else 0)
	b.settings.temperature_enabled=false;b._configure_noise()
	var cpu:Array=[];var water_cpu:Array=[]
	for res in [16,64,128]:
		var samples:Array=[]
		for i in range(3):
			b._configure_noise();var start:int=Time.get_ticks_usec();var arrays:Array=b.build(Vector2i(55+i,73),res);samples.append(float(Time.get_ticks_usec()-start)/1000)
			if mode=="badlands":
				var water_start:int=Time.get_ticks_usec();b.build_swamp_water(arrays,res);water_cpu.append({"resolution":res,"array_build_ms":float(Time.get_ticks_usec()-water_start)/1000})
		cpu.append({"resolution":res,"cold_chunk_p50_ms":percentile(samples,.5),"cold_chunk_max_ms":percentile(samples,1)})
	var start:int=Time.get_ticks_usec()
	for i in range(1000):b._get_height(i*13.7,19000+i*7.3)
	var queries:float=float(Time.get_ticks_usec()-start)/1000
	var water_queries:float=0
	if mode=="badlands":
		start=Time.get_ticks_usec()
		for i in range(1000):b.get_water_surface_height(i*13.7,19000+i*7.3)
		water_queries=float(Time.get_ticks_usec()-start)/1000
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var scene_start:int=Time.get_ticks_usec()
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;camera.near=.8
	terrain=scene.get_node("Terrain");terrain.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.target=camera;terrain.profile_streaming=true;terrain.start_in_jungle=false;terrain.start_in_forest=false;terrain.start_in_badlands=false;terrain.start_in_swamp=false;terrain.start_in_savanna=false
	camera.position=Vector3(14080,400,18688)
	var ready_start:int=Time.get_ticks_usec();root.add_child(scene);var ready_ms:float=(Time.get_ticks_usec()-ready_start)/1000.0;scene.get_node("Interface").hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var fill:float=await settle();var scene_and_first_cut:float=(Time.get_ticks_usec()-scene_start)/1000000.0
	camera.position.y=maxf(terrain.water_level,terrain.get_height_at(camera.position))+80;camera.look_at(camera.position+Vector3(400,-80,400))
	for i in range(90):await process_frame
	await measure("static",0)
	await measure("walking",7)
	await measure("fast_travel",1500)
	var p:=Vector3(-25000,0,35000);p.y=maxf(terrain.water_level,terrain.get_height_at(p))+80;terrain.request_teleport(p);var teleport:float=await settle()
	await measure("regional_static",0)
	var report:Dictionary={"mode":mode,"sampler_timings_us":b._badlands.timings if mode=="badlands" else {},"initial_fill_s":fill,"teleport_s":teleport,"cpu_chunks":cpu,"water_array_builds":water_cpu,"water_1000_queries_ms":water_queries,"height_1000_queries_ms":queries,"max_plan_ms":terrain.max_plan_ms,"max_commit_ms":terrain.max_partition_swap_ms,"records":records,"streaming":terrain.streaming_records,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"maximum_lod":terrain.maximum_lod,"camera_far":camera.far,"collision":"not installed","vegetation":"not installed","material_runtime_build_ms":0,"gpu_note":"Null means unavailable timing; never zero cost. Same controller/settings and XZ; camera terrain-following at 80m. Both modes use current source. Badlands and Grass use identical XZ, controller, draw distance and terrain-following clearance."}
	report.source_sha256={}
	report.scene_ready_ms=ready_ms;report.scene_and_first_cut_seconds=scene_and_first_cut
	report.initial_fill_scope="initial_fill_s is the post-ready worker wait, not end-to-end startup. scene_and_first_cut_seconds includes scene load/instantiate/ready and first committed cut, but excludes process launch. GPU driver/shader caches are not cleared; this run follows review rendering."
	for path:String in started_hashes:
		report.source_sha256[path]=FileAccess.get_sha256(path);assert(report.source_sha256[path]==started_hashes[path],"Source changed during benchmark")
	report.collision="Production near-terrain collision enabled: "+str(terrain.terrain_collision_enabled)
	FileAccess.open("res://tools/badlands/artifacts/benchmark_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("BADLANDS_BENCHMARK_DONE ",mode," fill_s=",fill," cpu=",cpu);scene.queue_free();await process_frame;quit()
