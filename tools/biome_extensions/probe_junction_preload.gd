extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var cache_mib:int=8;var throttle:int=0
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("cache="):cache_mib=int(arg.trim_prefix("cache="))
		if arg.begins_with("throttle="):throttle=int(arg.trim_prefix("throttle="))
	assert(cache_mib in [0,8] and throttle in [0,1])
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed)
	var item:Dictionary=admission.cases[0];var p:=Vector2(item.position[0],item.position[1]);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain")
	scene.get_node("FreeCamera").set_script(null)
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6
	var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.conduit_cache_mib=cache_mib
	terrain.world_seed=int(item.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=walker
	var started:int=Time.get_ticks_msec();root.add_child(scene);scene.get_node("Interface").hide()
	var records:Array=[];var last:int=0;var frames:int=0
	while terrain.committed_revision!=terrain.partition_revision and Time.get_ticks_msec()-started<30000:
		await process_frame;frames+=1
		if throttle>0:OS.delay_msec(throttle)
		var elapsed:int=Time.get_ticks_msec()-started
		if elapsed-last>=2000:
			last=elapsed;var tasks:Array=[]
			for key:Vector3i in terrain._jobs:
				# Do not inspect a live worker's mutable builder/result dictionary.
				var job:Dictionary=terrain._jobs[key];tasks.append({"key":key,"completed":WorkerThreadPool.is_task_completed(job.task)})
			var row:Dictionary={"elapsed_ms":elapsed,"frames":frames,"target":walker.position,"cut":terrain.committed_revision,"wanted_revision":terrain.partition_revision,"wanted":terrain._wanted.size(),"pending":terrain._pending_chunks.size(),"ready":terrain._ready_chunks.size(),"staged":terrain._staged.size(),"active":terrain._active_chunks.size(),"tasks":tasks}
			records.append(row);print("PRELOAD_PROGRESS ",row)
	var complete:bool=terrain.committed_revision==terrain.partition_revision
	var report:Dictionary={"completed":complete,"cache_mib":cache_mib,"throttle_ms_per_process_frame":throttle,"elapsed_ms":Time.get_ticks_msec()-started,"frames":frames,"records":records,"scope":"Diagnostic first-cut preload only, same disabled test capsule/actual terrain scene. No walking or performance acceptance. Optional 1ms polling yield is a controlled starvation diagnostic, not a production change."}
	FileAccess.open("res://tools/biome_extensions/artifacts/probe_junction_preload_"+str(cache_mib)+"_"+str(throttle)+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PRELOAD_PROBE_RESULT ",report)
	if not complete:push_error("Preload diagnostic incomplete after 30 seconds; preserve progress evidence");quit(1);return
	scene.queue_free();walker.queue_free();await process_frame;quit()
