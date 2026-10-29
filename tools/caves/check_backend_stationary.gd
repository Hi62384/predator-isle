extends "res://tools/biome_extensions/check_all.gd"
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Terrain=preload("res://scripts/chunk_terrain.gd")
class Host extends Node3D:
	var cave_settings
	var _settings_snapshot
	var world_seed:int=73921
	var water_level:float=0
	var upload_budget_ms:float=1.5
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/caves/streamer.gd","res://scripts/caves/workload.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/portal_mesher.gd","res://scripts/caves/mesher.gd","res://scripts/caves/field.gd","res://scripts/caves/network.gd","res://scripts/caves/route_solver.gd","res://scripts/caves/cave_settings.gd","res://shaders/default_cave_rock.gdshader","res://tools/caves/check_backend_stationary.gd"]:guards[path]=FileAccess.get_sha256(path)
	var untouched=Terrain.new();check(untouched.cave_settings.enabled and untouched._cave_streamer==null and untouched.worker_count==4,"Saved terrain enables caves;uninitialized instance has no streamer and retains original four-worker allowance");untouched.free()
	var b=make_builder(3,73921);var host_node:=Host.new();host_node._settings_snapshot=b.settings;host_node.cave_settings=Config.new();host_node.cave_settings.enabled=true;host_node.cave_settings.regional_activity=1;host_node.cave_settings.visible_radius_metres=96;host_node.cave_settings.preload_radius_metres=128;host_node.cave_settings.resident_cell_limit=32;root.add_child(host_node);var streamer=Streamer.new();host_node.add_child(streamer);streamer.initialize(host_node);var point:=Vector3(14771.29,25.37863,-4037.743);var started:int=Time.get_ticks_usec();var maximum_jobs:int=0;var maximum_queue:int=0;var last_count:int=-1
	while Time.get_ticks_usec()-started<180000000:
		# One free shared slot models three occupied terrain slots. The viewer
		# NEVER moves: queue refill must not require camera motion to complete.
		streamer.tick(point,point,1,true);maximum_jobs=maxi(maximum_jobs,streamer.job_count());maximum_queue=maxi(maximum_queue,streamer._pending.size());check(streamer.job_count()<=1,"Cave jobs never exceed the one free slot in the total four-worker allowance");check(streamer._pending.size()<=12 and streamer._ready.size()<=8,"Declared pending/result queues stay bounded")
		if streamer._cells.size()!=last_count:last_count=streamer._cells.size();print("STATIONARY_CAVE_BACKEND ",last_count,"/",streamer._wanted.size()," jobs=",streamer.job_count())
		if streamer.position_ready() and streamer._wanted.size()>0:break
		if not streamer.last_error.is_empty():break
		await process_frame;OS.delay_usec(1000)
	check(streamer.last_error.is_empty() and streamer.position_ready(),"Stationary viewer eventually receives complete sparse native cave set without queue starvation")
	check(streamer._wanted.size()==32 and streamer._cells.size()==32,"Resident hard limit actually exercised,not an empty/no-cave positive")
	var physical:int=0
	for key:Vector3i in streamer._cells:
		var node:MeshInstance3D=streamer._cells[key]
		if node!=null:physical+=1;check(node.visible and node.get_node("CaveCollision").collision_layer==1,"Actual backend cell renders and carries active native collision together")
	check(physical>8,"Positive actual cave geometry,not only empty cell markers")
	var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0;streamer.shutdown();check(streamer.job_count()==0,"Shutdown waits only owned jobs and clears backend task state");host_node.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable backend source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_backend_stationary.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"stationary_position":str(point),"resident_cells":last_count,"physical_cells":physical,"maximum_owned_jobs":maximum_jobs,"maximum_pending_queue":maximum_queue,"single_order_wall_seconds":elapsed,"production_runtime_enabled_by_default":false,"scope":"Actual production cave backend at fixed original Spore underground point,real worker discovery/field extraction/native cells,one available shared slot,32resident bound,12pending/8ready limits and original1ms preload poll/180s gate. No camera motion. This tests backend queue liveness,NOT actual concurrent ChunkTerrain workers,portal rendering/commit or a streamed native capsule route."},"  "));print("CAVE_BACKEND_STATIONARY ",checks," seconds=",elapsed," physical=",physical," failures=",failures);quit(0 if failures.is_empty() else 1)
