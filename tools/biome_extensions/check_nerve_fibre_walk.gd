extends "res://tools/biome_extensions/check_streamed_roundtrip.gd"
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://tools/biome_extensions/check_streamed_roundtrip.gd","res://tools/biome_extensions/route_probe.gd","res://tools/biome_extensions/check_nerve_fibre_walk.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var p:=Vector2(10427.419921875,-1825.93872070313);var axis:=Vector2(.960382878780365,.278684109449387)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.get_node("FreeCamera").set_script(null)
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6
	var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
	terrain.world_seed=73921;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=walker
	root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
	var start2:Vector2=p-axis*120;var start:=Vector3(start2.x,0,start2.y);start.y=terrain.get_height_at(start)+.95;walker.position=start;terrain._refresh_visible_chunks();await settle(terrain)
	for i in range(3):await physics_frame
	var route:Array[Vector3]=[];var changed:int=0;var maximum_raw_added:float=0
	for step in range(1,25):
		var q:Vector2=start2+axis*(step*10);var point:=Vector3(q.x,0,q.y);point.y=terrain.get_height_at(point)+.95;route.append(point)
		var added:float=terrain._sampler._extras[7].nerve_fibre_relief(q);maximum_raw_added=maxf(maximum_raw_added,added)
		if added>.5:changed+=1
	for step in range(23,-1,-1):route.append(route[step-1] if step>0 else start)
	check(changed>=12,"Actual relief-bearing route, not unaffected terrain")
	check(is_equal_approx(walker.floor_max_angle,deg_to_rad(45)),"Unchanged 45-degree capsule slope limit")
	walker.route=route;walker.set_physics_process(true);var cuts:Dictionary={};var paused_frames:int=0;var started:int=Time.get_ticks_usec()
	for frame in range(1000000):
		await physics_frame;walker.paused=terrain.committed_revision!=terrain.partition_revision
		if walker.paused:
			paused_frames+=1
			if DisplayServer.get_name()=="headless":OS.delay_msec(HEADLESS_PRELOAD_POLL_MS)
		cuts[terrain.committed_revision]=true
		if walker.failed or walker.finished or Time.get_ticks_usec()-started>180000000:break
	walker.set_physics_process(false)
	check(walker.finished and walker.waypoint==route.size(),"Actual default-strength fibre return walk completes")
	check(walker.position.distance_to(start)<1.5,"Returns to surface start without teleport/jump")
	check(walker.frames>5000,"Actual 480m motion at 5m/s")
	check(walker.max_unsupported_drop<.75,"No large unsupported drop during committed cut changes")
	check(terrain.maximum_lod==6,"Full production hierarchy retained")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable walk source "+path)
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"checks":checks,"source_sha256":hashes,"finished":walker.finished,"failed":walker.failed,"final_position":walker.position,"target":route[mini(walker.waypoint,route.size()-1)],"waypoint":walker.waypoint,"waypoints":route.size(),"movement_frames":walker.frames,"max_unsupported_drop_m":walker.max_unsupported_drop,"max_airborne_frames":walker.max_airborne,"paused_preload_frames":paused_frames,"committed_cuts":cuts.size(),"changed_route_points":changed,"maximum_raw_added_relief_m":maximum_raw_added,"route_length_m":480,"capsule_height_m":1.8,"capsule_radius_m":.4,"speed_mps":5,"floor_max_angle_degrees":45,"headless_preload_poll_yield_ms":HEADLESS_PRELOAD_POLL_MS,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"scope":"One 480m two-way actual production-streamed default-strength Nerve-lowland surface route, declared native capsule and unchanged gravity/slope/speed, paused for replacement-cut preloads. No cave, global navigation, uninterrupted streaming or performance certificate."}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_nerve_fibre_walk.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NERVE_FIBRE_WALK ",report)
	walker.queue_free();scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
