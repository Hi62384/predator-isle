extends "res://tools/biome_extensions/check_integration.gd"
const HEADLESS_PRELOAD_POLL_MS:int=1
func vector(value:String)->Vector2:
	var parts:PackedStringArray=value.trim_prefix("(").trim_suffix(")").split(",");return Vector2(float(parts[0]),float(parts[1]))
func settle(terrain)->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		# --fixed-fps accelerates this diagnostic's simulation. Unbounded
		# headless polling can consume hundreds of thousands of main/physics
		# frames while background workers need CPU. Yield only during declared
		# preload pauses; never change movement speed, gravity or collision.
		if DisplayServer.get_name()=="headless":OS.delay_msec(HEADLESS_PRELOAD_POLL_MS)
		assert(Time.get_ticks_msec()-start<180000,"Real streamed route preload timeout")
func run()->void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_roundtrip.json"))
	var site:Dictionary=fixture.cases[0].site;var p:Vector2=vector(site.position)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain")
	var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null)
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6
	var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8
	var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
	terrain.extension_preview="wise_mountains";terrain.extension_preview_position=p;terrain.target=walker;terrain.profile_streaming=true
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.wise_mountains.cave_frequency=.5
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
	var entry:float=96*(1+.04*sin(site.phase));var top:float=terrain.get_height_at(Vector3(p.x+entry,0,p.y))+.15
	var turns:int=maxi(1,ceili((site.top-site.floor)/(TAU*70*.12)))
	var route:Array[Vector3]=[Vector3(p.x+entry+2,top+.9,p.y),Vector3(p.x+70,top+.9,p.y)]
	for i in range(1,turns*96+1):
		var t:float=float(i)/(turns*96);var angle:float=t*turns*TAU
		route.append(Vector3(p.x+cos(angle)*70,lerpf(top,site.floor,t)+.9,p.y+sin(angle)*70))
	route.append(Vector3(p.x+112,site.floor+.9,p.y));route.append(Vector3(p.x+230,site.floor+.9,p.y))
	var count:int=route.size()
	for i in range(count-2,-1,-1):route.append(route[i])
	var surface_start:=Vector3(p.x+entry+20,terrain.get_height_at(Vector3(p.x+entry+20,0,p.y))+.95,p.y);route.append(surface_start)
	# Initial spawn is placed once before movement; no teleport/noclip/jump is
	# used on the actual route. Normal production streaming owns every collider.
	walker.position=surface_start;terrain._refresh_visible_chunks();await settle(terrain)
	var fill_seconds:float=(Time.get_ticks_usec()-start)/1000000.0
	walker.route=route;walker.set_physics_process(true)
	var paused_frames:int=0;var revisions:Dictionary={};var start_walk:int=Time.get_ticks_usec()
	for frame in range(1000000):
		await physics_frame
		walker.paused=terrain.committed_revision!=terrain.partition_revision
		if walker.paused:
			paused_frames+=1
			if DisplayServer.get_name()=="headless":OS.delay_msec(HEADLESS_PRELOAD_POLL_MS)
		revisions[terrain.committed_revision]=true
		if walker.failed or walker.finished:break
		if Time.get_ticks_usec()-start_walk>180000000:break
	walker.set_physics_process(false)
	check(walker.finished and walker.waypoint==route.size(),"Real streaming surface/cavity/surface walk completes")
	check(walker.frames>1000,"Real movement occurred, not a pre-route empty-path completion")
	check(walker.position.distance_to(surface_start)<1.5,"Real streaming walk returns to surface start")
	check(revisions.size()>1,"Actual committed LOD cut changes during route")
	check(walker.max_unsupported_drop<.75,"No large unsupported drop during cut changes")
	check(terrain.maximum_lod==6,"Full production 50 km hierarchy retained")
	var report:Dictionary={"checks":checks,"failures":failures,"site":site,"completed":walker.finished,"waypoint":walker.waypoint,"waypoints":route.size(),"movement_frames":walker.frames,"preload_pause_frames":paused_frames,"committed_cuts":revisions.size(),"fill_seconds":fill_seconds,"walk_wall_seconds":(Time.get_ticks_usec()-start_walk)/1000000.0,"maximum_lod":terrain.maximum_lod,"max_unsupported_drop_metres":walker.max_unsupported_drop,"max_plan_ms":terrain.max_plan_ms,"max_partition_swap_ms":terrain.max_partition_swap_ms,"scope":"One Wise fixture using actual production chunk jobs, staging, caches and transactional collision cuts; test walker pauses while replacement cut preloads; not an infinite cave or uninterrupted performance certificate"}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_streamed_roundtrip.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("STREAMED_ROUNDTRIP ",report)
	walker.queue_free();scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
