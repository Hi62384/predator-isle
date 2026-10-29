extends SceneTree
## Actual production terrain/collision, not a hand-built flat test floor.
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func settle(terrain)->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-start<180000,"Badlands route preload timeout")
func run()->void:
	var source_hashes:Dictionary={}
	for path:String in ["res://scripts/badlands_sampler.gd","res://scripts/badlands_fan_geometry.gd","res://scripts/badlands_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/route_probe.gd","res://tools/badlands/check_streamed_wash.gd"]:source_hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	var site:Dictionary=manifest.features.major_dry_wash;var p:=Vector2(site.x,site.z)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain")
	scene.get_node("FreeCamera").set_script(null)
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.floor_snap_length=.6
	var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8
	var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
	terrain.badlands_preview=true;terrain.badlands_preview_feature="major_dry_wash";terrain.target=walker;terrain.profile_streaming=true
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
	var field=terrain._sampler._badlands;var lane:int=roundi(p.y/field._spacing());var nearest:float=INF
	for candidate in range(lane-2,lane+3):
		var distance:float=absf(field._carrier(p.x,candidate)-p.y)
		if distance<nearest:nearest=distance;lane=candidate
	var route:Array[Vector3]=[];var dry:bool=true
	for i in range(101):
		var x:float=p.x-400+i*8;var z:float=field._carrier(x,lane)
		var point:=Vector3(x,0,z);point.y=terrain.get_height_at(point)+.95
		dry=dry and point.y-.95>terrain._sampler.get_water_surface_height(x,z)+.1
		route.append(point)
	var outward_count:int=route.size()
	for i in range(outward_count-2,-1,-1):route.append(route[i])
	var route_metres:float=0
	for i in range(1,route.size()):route_metres+=route[i-1].distance_to(route[i])
	var surface_start:Vector3=route[0];walker.position=surface_start;terrain._refresh_visible_chunks();await settle(terrain)
	var fill_seconds:float=(Time.get_ticks_usec()-start)/1000000.0
	print("BADLANDS_WASH_READY fill_s=",fill_seconds," route_m=",route_metres," nominal_walk_s=",route_metres/5," declared_fixed_step=",OS.get_cmdline_user_args().has("fixed-step-run"))
	walker.route=route;walker.set_physics_process(true)
	var pauses:int=0;var revisions:Dictionary={};var walk_start:int=Time.get_ticks_usec()
	for frame in range(1000000):
		await physics_frame
		walker.paused=terrain.committed_revision!=terrain.partition_revision
		if walker.paused:pauses+=1
		revisions[terrain.committed_revision]=true
		if walker.failed or walker.finished:break
		if Time.get_ticks_usec()-walk_start>180000000:break
	walker.set_physics_process(false)
	check(dry,"Actual selected wash route is dry")
	check(walker.finished and walker.waypoint==route.size(),"Full outward and return wash walk completes")
	check(walker.frames>1000,"Actual capsule movement occurred")
	check(walker.position.distance_to(surface_start)<1.5,"Capsule returns to its surface start")
	check(revisions.size()>1,"Production streaming committed multiple cuts")
	check(walker.max_unsupported_drop<.75,"No large unsupported drop across committed cuts")
	check(terrain.maximum_lod==6,"Full LOD6 terrain hierarchy retained")
	var result:Dictionary={"checks":checks,"failures":failures,"completed":walker.finished,"waypoint":walker.waypoint,"waypoints":route.size(),"movement_frames":walker.frames,"preload_pause_frames":pauses,"committed_cuts":revisions.size(),"initial_fill_seconds":fill_seconds,"walk_wall_seconds":(Time.get_ticks_usec()-walk_start)/1000000.0,"fixed_step_declared":OS.get_cmdline_user_args().has("fixed-step-run"),"route_metres":route_metres,"max_unsupported_drop_metres":walker.max_unsupported_drop,"start":surface_start,"seed":terrain.world_seed,"scope":"One real Badlands wash over an 800m X extent, outward and back, 1.8m capsule with gravity and 5m/s movement; production workers/caches/collision; preload pauses, not uninterrupted performance or all-world certification","sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd")}
	for path:String in source_hashes:assert(FileAccess.get_sha256(path)==source_hashes[path],"Source changed during physical route test")
	result.source_sha256=source_hashes
	FileAccess.open("res://tools/badlands/artifacts/check_streamed_wash.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_STREAMED_WASH ",result)
	walker.queue_free();scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
