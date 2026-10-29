extends SceneTree
var failures:Array[String]=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func validate(terrain)->void:
	var keys:Array=terrain._active_chunks.keys()
	for i in keys.size():
		verify(terrain._active_chunks[keys[i]].visible,"Active leaf visible")
		for j in range(i+1,keys.size()):
			verify(not terrain._partition.bounds(keys[i]).intersects(terrain._partition.bounds(keys[j])),"No visible parent/child overlap")
			verify(not terrain._partition.adjacent(keys[i],keys[j]) or terrain.is_active_edge_certified(keys[i],keys[j]),"Balanced edge or recorded equivalent final grid on the actual node instances")
	verify(terrain._jobs.size()+terrain._cave_streamer.job_count()<=4,"Four total terrain/cave jobs retained")
func _initialize()->void:call_deferred("run")
func intervention()->Dictionary:return {}
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	var paths:Array[String]=[get_script().resource_path,"res://scripts/chunk_terrain.gd","res://scripts/terrain_ready_cut.gd","res://scripts/terrain_partition.gd","res://scripts/terrain_collision.gd","res://scripts/caves/streamer.gd","res://config/world/terrain_settings.tres","res://scenes/main.tscn"]
	var hashes:Dictionary={}
	for path:String in paths:hashes[path]=FileAccess.get_sha256(path)
	var boot=load("res://scenes/world_startup.tscn").instantiate();root.add_child(boot);current_scene=boot
	while current_scene==boot or current_scene==null:await process_frame
	var scene=current_scene;var terrain=scene.get_node("Terrain");terrain.profile_streaming=true;var camera:Camera3D=scene.get_node("FreeCamera");camera.set_process(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var began:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-began>180000:verify(false,"Initial cut ready inside180s");quit(1);return
	validate(terrain)
	var records:Array=[]
	var moves:Array[Vector3]=[Vector3(768,0,0),Vector3(-1536,0,768),Vector3(20000,0,0)]
	if OS.get_cmdline_user_args().has("single-move"):moves.resize(1)
	for offset:Vector3 in moves:
		camera.position+=offset;camera.position.y=maxf(camera.position.y,terrain.get_height_at(camera.position)+80)
		var swaps_before:int=terrain.incremental_cut_swaps;terrain._refresh_visible_chunks()
		began=Time.get_ticks_msec();var local_seconds:float=-1;var staged_seconds:float=-1;var publication_seconds:float=-1;var signature:String="";var last_diagnostic:String=""
		while terrain.committed_revision!=terrain.partition_revision:
			await process_frame
			var key:=Vector3i(terrain._target_chunk.x,terrain._target_chunk.y,0)
			if staged_seconds<0 and terrain._staged.has(key):staged_seconds=(Time.get_ticks_msec()-began)/1000.0
			if staged_seconds>=0 and local_seconds<0:
				var diagnostic:String=str(terrain._ready_cut_diagnostics)
				if diagnostic!=last_diagnostic:last_diagnostic=diagnostic;print("NEAR_WAIT ",(Time.get_ticks_msec()-began)/1000.0," ",diagnostic)
			if local_seconds<0 and terrain._active_chunks.has(key) and terrain._active_chunks[key].get_meta("resolution")>=terrain.close_resolution:
				local_seconds=(Time.get_ticks_msec()-began)/1000.0
				publication_seconds=float(terrain._active_chunks[key].get_meta("published_usec",0))/1000000.0-float(began)/1000.0
				var body:StaticBody3D=terrain._active_chunks[key].get_node_or_null("NearTerrainCollision")
				verify(body!=null and body.collision_layer!=0,"Published near terrain has an active native collider")
			var now:String=str(terrain._active_chunks.keys())
			if now!=signature:signature=now;validate(terrain)
			if Time.get_ticks_msec()-began>90000:verify(false,"Moving cut ready inside90s");break
		var complete_seconds:float=(Time.get_ticks_msec()-began)/1000.0
		verify(local_seconds>=0 and local_seconds<=complete_seconds,"Local full detail appears before whole moving cut completes")
		records.append({"offset":str(offset),"camera_position":str(camera.position),"staged_seconds":staged_seconds,"publication_seconds":publication_seconds,"local_full_detail_seconds":local_seconds,"complete_cut_seconds":complete_seconds,"local_swaps":terrain.incremental_cut_swaps-swaps_before,"active_leaves":terrain._active_chunks.size(),"surface_status":terrain._cave_streamer.surface_status})
		print("LIVE_NEAR_REFINEMENT ",records[-1]);validate(terrain)
	var early:int=0
	for record:Dictionary in records:
		if record.local_swaps>0 and record.local_full_detail_seconds<record.complete_cut_seconds:early+=1
	verify(early>0,"Actual complete local groups refine before distant replacement work")
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable native refinement source "+path)
	verify(terrain.max_partition_swap_ms<50,"Bounded complete local transactions retain a below50ms observed swap budget")
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records,"maximum_partition_swap_ms":terrain.max_partition_swap_ms,"source_sha256":hashes,"private_intervention":intervention(),"scope":"Actual saved game and native colliders;visible-cut overlap/edge evidence throughout the recorded moves. The default three-move set includes a root change;single-move is diagnostic only. Timing includes validation overhead;not isolated FPS."}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_live_near_refinement.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("LIVE_NEAR_REFINEMENT_COMPLETE ",checks," failures=",failures)
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
