extends SceneTree
## Separate real-time test,not a relaxed rerun of the180s accelerated gate.
## The unchanged2.74km/5m/s route needs about548s physical time. No preload
## pauses after departure;four workers and production collision policy remain.
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func settle(terrain)->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>180000:return false
	return true
func run()->void:
	verify(OS.get_cmdline_user_args().has("realtime-run"),"Explicit separate real-time test declaration")
	verify(Engine.physics_ticks_per_second==60,"Unchanged60Hz physics")
	var guards:Dictionary={}
	for path:String in ["res://scripts/badlands_sampler.gd","res://scripts/badlands_fan_geometry.gd","res://scripts/badlands_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/route_probe.gd","res://tools/badlands/check_realtime_streamed_wash.gd","res://data/badlands_previews.json"]:guards[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"));var site:Dictionary=manifest.features.major_dry_wash;var p:=Vector2(site.x,site.z)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.get_node("FreeCamera").set_script(null)
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.floor_snap_length=.6
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
	terrain.badlands_preview=true;terrain.badlands_preview_feature="major_dry_wash";terrain.target=walker;terrain.profile_streaming=true
	var initial:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();verify(await settle(terrain),"Initial cut within unchanged180s preload budget")
	var field=terrain._sampler._badlands;var lane:int=roundi(p.y/field._spacing());var nearest:float=INF
	for candidate in range(lane-2,lane+3):
		var distance:float=absf(field._carrier(p.x,candidate)-p.y)
		if distance<nearest:nearest=distance;lane=candidate
	var route:Array[Vector3]=[];var dry:bool=true
	for i in range(101):
		var x:float=p.x-400+i*8;var z:float=field._carrier(x,lane);var point:=Vector3(x,0,z);point.y=terrain.get_height_at(point)+.95
		dry=dry and point.y-.95>terrain._sampler.get_water_surface_height(x,z)+.1;route.append(point)
	for index in range(route.size()-2,-1,-1):route.append(route[index])
	var route_metres:float=0
	for index in range(1,route.size()):route_metres+=route[index-1].distance_to(route[index])
	var surface_start:Vector3=route[0];walker.position=surface_start;terrain._refresh_visible_chunks();verify(await settle(terrain),"Departure cut within unchanged180s preload budget")
	var initial_seconds:float=(Time.get_ticks_usec()-initial)/1000000.0
	verify(terrain.maximum_lod==6,"Full LOD6 hierarchy")
	if not failures.is_empty():scene.queue_free();walker.queue_free();quit(1);return
	walker.route=route;walker.paused=false;walker.set_physics_process(true)
	var frames:Array=[];var revisions:Dictionary={};var pending_frames:int=0;var started:int=Time.get_ticks_usec();var previous:int=started;var progress:int=0
	for index in range(45000):
		await physics_frame
		var now:int=Time.get_ticks_usec();frames.append(float(now-previous)/1000);previous=now
		verify(not walker.paused,"No automatic movement pause after departure")
		if terrain.committed_revision!=terrain.partition_revision:pending_frames+=1
		revisions[terrain.committed_revision]=true
		if walker.waypoint/20>progress:progress=walker.waypoint/20;print("REALTIME_WASH_PROGRESS waypoint=",walker.waypoint," wall_s=",(now-started)/1000000.0," cuts=",revisions.size())
		if walker.failed or walker.finished or now-started>650000000:break
	walker.set_physics_process(false);var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0;frames.sort()
	verify(dry,"Fixed route is dry");verify(walker.finished and not walker.failed and walker.waypoint==route.size(),"Unpaused outward-and-return completes within650s real-time budget")
	verify(walker.position.distance_to(surface_start)<1.5,"Returns to same departure");verify(walker.max_unsupported_drop<.75,"Original unsupported-drop bound")
	verify(revisions.size()>1,"Actual production cuts committed while walking");verify(elapsed>route_metres/5*.85,"No accelerated fixed-step result masquerading as real time")
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable real-time source "+path)
	var result:Dictionary={"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"seed":terrain.world_seed,"route_metres":route_metres,"waypoints":route.size(),"completed_waypoints":walker.waypoint,"initial_fill_seconds":initial_seconds,"walk_wall_seconds":elapsed,"movement_frames":walker.frames,"pending_cut_physics_frames_without_pausing":pending_frames,"committed_cuts":revisions.size(),"maximum_unsupported_drop_metres":walker.max_unsupported_drop,"physics_interval_ms":{"p50":frames[int(frames.size()*.5)],"p95":frames[int(frames.size()*.95)],"p99":frames[int(frames.size()*.99)],"maximum":frames[-1]},"scope":"Separate unaccelerated60Hz headless2.74km/5m/s production-physics route with fullLOD6/four workers. Only initial/departure preload;never pauses for replacement cuts. Predeclared650s walk budget based on548s nominal travel,not a relaxed original accelerated180s test. Reports physical interval costs;not GPU frame time,all-world art/performance,shipped-player-controller or cave acceptance."}
	FileAccess.open("res://tools/badlands/artifacts/check_realtime_streamed_wash.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("REALTIME_STREAMED_WASH ",result);walker.queue_free();scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
