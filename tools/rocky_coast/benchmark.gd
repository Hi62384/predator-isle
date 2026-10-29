extends SceneTree
var mode:String="coast"
var cpu_only:bool=false
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):mode=arg.trim_prefix("mode=")
		if arg=="cpu-only":cpu_only=true
	var b=preload("res://scripts/terrain_mesh_builder.gd").new()
	if mode=="baseline":b=preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/rocky_coast/baseline/builder.gd").new()
	b.profile_build=true
	b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=mode=="coast";b.settings.rocky_coast.coverage=1;b.settings.grass_coverage=100;b.settings.jungle_coverage=0;b.settings.forest_coverage=0;b.settings.mountain_coverage=0;b.settings.savanna_coverage=0;b.settings.swamp_coverage=0;b.settings.temperature_enabled=false;b._configure_noise()
	var item:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocky_coast_previews.json")).features.towering_cliffs
	var focus:=Vector3(item.x,0,item.z);var outward:=Vector3(item.outward_x,0,item.outward_z)
	var cpu:Array=[];var water_cpu:Array=[]
	for res in [16,64,128]:
		var samples:Array=[]
		for i in range(3):
			b._configure_noise();var start:int=Time.get_ticks_usec();var arrays:Array=b.build(Vector2i(floori(focus.x/256)+i,floori(focus.z/256)),res);samples.append(float(Time.get_ticks_usec()-start)/1000)
			if mode=="coast":
				var water_start:int=Time.get_ticks_usec();b.build_swamp_water(arrays,res);water_cpu.append({"resolution":res,"array_build_ms":float(Time.get_ticks_usec()-water_start)/1000})
		cpu.append({"resolution":res,"cold_chunk_p50_ms":percentile(samples,.5),"cold_chunk_max_ms":percentile(samples,1),"last_chunk_breakdown":b.last_build_profile.duplicate(true)})
	var start:int=Time.get_ticks_usec()
	for i in range(1000):b._get_height(focus.x+i*.07,focus.z+i*.03)
	var queries:float=float(Time.get_ticks_usec()-start)/1000
	var water_queries:float=0
	if mode=="coast":
		start=Time.get_ticks_usec()
		for i in range(1000):b.get_water_surface_height(focus.x+i*.07,focus.z+i*.03)
		water_queries=float(Time.get_ticks_usec()-start)/1000
	if cpu_only:
		print("COAST_CPU_PROBE ",JSON.stringify({"chunks":cpu,"queries_ms":queries,"water_queries_ms":water_queries,"fields_us":b._coast.timings if mode=="coast" else {}}));quit();return
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;camera.near=.8
	terrain=scene.get_node("Terrain");terrain.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.target=camera;terrain.profile_streaming=true;terrain.start_in_jungle=false;terrain.start_in_forest=false;terrain.start_in_coast=false;terrain.start_in_mountain=false;terrain.start_in_swamp=false;terrain.start_in_savanna=false
	camera.position=focus+outward*500+Vector3(0,300,0);root.add_child(scene);scene.get_node("Interface").hide()
	if mode=="baseline":
		for material:ShaderMaterial in terrain._lod_materials.values():material.shader=load("res://tools/rocky_coast/baseline/terrain.gdshader")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var fill:float=await settle();camera.position.y=maxf(terrain.water_level,terrain.get_height_at(camera.position))+80;camera.look_at(camera.position-outward*400+Vector3(0,-80,0))
	for i in range(90):await process_frame
	await measure("static",0)
	await measure("walking",7)
	await measure("fast_travel",1500)
	var p:=focus+Vector3(5000,0,5000);p.y=maxf(terrain.water_level,terrain.get_height_at(p))+80;terrain.request_teleport(p);var teleport:float=await settle()
	await measure("regional_static",0)
	var report:Dictionary={"mode":mode,"sampler_timings_us":b._coast.timings if mode=="coast" else {},"initial_fill_s":fill,"teleport_s":teleport,"cpu_chunks":cpu,"water_array_builds":water_cpu,"water_1000_queries_ms":water_queries,"height_1000_queries_ms":queries,"max_plan_ms":terrain.max_plan_ms,"max_commit_ms":terrain.max_partition_swap_ms,"records":records,"streaming":terrain.streaming_records,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"maximum_lod":terrain.maximum_lod,"camera_far":camera.far,"collision":"not installed","vegetation":"not installed","material_runtime_build_ms":0,"gpu_note":"Null means unavailable timing; never zero cost. Same controller/settings and XZ; camera terrain-following at 80m. Baseline uses pre-Rocky Coast builder CPU and pre-Rocky Coast GPU shader."}
	FileAccess.open("res://tools/rocky_coast/artifacts/benchmark_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("ROCKY_COAST_BENCHMARK_DONE ",mode," fill_s=",fill," cpu=",cpu);scene.queue_free();await process_frame;quit()
