extends "res://tools/biome_extensions/check_all.gd"
## Actual production terrain, workers, materials and collision. The original
## seed/cell and capsule gates are retained; no private replacement scene.
const Config=preload("res://scripts/caves/cave_settings.gd")
const Network=preload("res://scripts/caves/network.gd")
var guards:Dictionary={}
var captures:Dictionary={}
var maximum_jobs:int=0
var maximum_portal_jobs:int=0
var peak_cells:int=0
func report_name()->String:return "check_cave_live_portal"
func fixture_family()->int:return 3
func fixture_cell()->Vector2i:return Vector2i(9,-3)
func fixture_name()->String:return "spore_forest"
func fixture_seed()->int:return 73921
func fixture_builder():return make_builder(fixture_family(),fixture_seed())
func fixture_configuration()->Resource:
	var config=Config.new();config.enabled=true;config.regional_activity=1;return config
func prepare_live_terrain(_terrain,_builder)->void:pass
func expected_core_nodes()->int:return 17
func capture_prefix()->String:return "cave_live"
func fixture_region(b)->Dictionary:
	var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,fixture_seed());network.activity=1;return network.region(fixture_cell())
func render_motion()->bool:return true
func follow_motion_camera()->bool:return false
func motion_fps_limit()->int:return 0
func allow_preload_pauses()->bool:return true
func capture_mid_motion()->bool:return true
func motion_started(_terrain,_walker,_camera)->void:pass
func motion_measurements()->Dictionary:return {}
func accelerated_worker_yield_usec()->int:
	# Godot#110724: tight fixed-fps diagnostics can starve Jolt's job release
	# queue. Yield scheduler time without changing physics delta or the route.
	return 1000 if OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS").is_valid_int() else 0
func motion_budget_usec()->int:return 420000000
func required_depth()->float:return 0
func planned_route(region:Dictionary,start:Vector3)->Array[Vector3]:
	var route:Array[Vector3]=[];var access:PackedVector3Array=region.edges[0].points
	for point:Vector3 in access:route.append(point+Vector3(0,.95,0))
	for i in range(access.size()-2,-1,-1):route.append(access[i]+Vector3(0,.95,0))
	route.append(start);return route
func motion_scope()->String:return "Original Spore seed73921/cell(9,-3),same approach/130waypoint823mreturn. Fixed60Hz accelerated simulation with declared preload pauses,not uninterrupted timing or all-biome completion."
func observe(terrain)->void:
	maximum_jobs=maxi(maximum_jobs,terrain._jobs.size()+terrain._cave_streamer.job_count());peak_cells=maxi(peak_cells,terrain._cave_streamer._cells.size())
	var count:int=0
	for job:Dictionary in terrain._cave_streamer._jobs.values():
		if job.kind=="portal":count+=1
	maximum_portal_jobs=maxi(maximum_portal_jobs,count)
func settle(terrain,entrance:bool)->bool:
	var began:int=Time.get_ticks_usec();var last_print:int=0
	while Time.get_ticks_usec()-began<180000000:
		observe(terrain)
		var stream=terrain._cave_streamer
		if terrain.committed_revision==terrain.partition_revision and stream.position_ready() and (not entrance or stream.surface_status=="active"):return true
		if not stream.last_error.is_empty():return false
		var elapsed:int=(Time.get_ticks_usec()-began)/1000000
		if elapsed-last_print>=10:print("LIVE_PORTAL_PRELOAD ",elapsed," ",stream.debug_text()," cut=",terrain.committed_revision,"/",terrain.partition_revision);last_print=elapsed
		await process_frame;OS.delay_usec(1000)
	return false
func capture(camera:Camera3D,position:Vector3,focus:Vector3,label:String)->void:
	if DisplayServer.get_name()=="headless":return
	print("LIVE_CAPTURE_BEGIN ",label)
	camera.position=position;camera.look_at(focus)
	for frame in range(3):await process_frame
	# A background/minimized native window may not emit frame_post_draw.
	# Explicitly draw this capture instead of waiting without a deadline.
	RenderingServer.force_draw(false)
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/"+capture_prefix()+"_"+label+".png";check(image.save_png(path)==OK,"Actual live portal capture "+label);captures[path]=FileAccess.get_sha256(path)
	print("LIVE_CAPTURE_END ",label)
func run()->void:
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for file:String in DirAccess.get_files_at(folder):
			if file.ends_with(".gd") or file.ends_with(".gdshader") or file.ends_with(".gdshaderinc"):var path:String=folder+"/"+file;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_partition.gd","res://scripts/terrain_ready_cut.gd","res://scripts/terrain_collision.gd","res://scripts/terrain_mesh_builder.gd","res://tools/caves/check_live_portal.gd","res://tools/caves/check_live_insect_return.gd","res://tools/biome_extensions/route_probe.gd","res://scenes/main.tscn","res://project.godot","res://config/caves/cave_settings.tres",get_script().resource_path]:guards[path]=FileAccess.get_sha256(path)
	for path:String in preload("res://tools/maintenance/resource_paths.gd").configuration_files():guards[path]=FileAccess.get_sha256(path)
	var b=fixture_builder();var region:Dictionary=fixture_region(b);check(region.valid and region.nodes.size()==expected_core_nodes(),"Original actual "+fixture_name()+" region retained,not rerolled")
	if not region.valid:finish({},null,null);return
	var access:PackedVector3Array=region.edges[0].points;var p:Vector3=access[0];var direction:=Vector2(access[1].x-p.x,access[1].z-p.z).normalized();var start:Vector3=p-Vector3(direction.x,0,direction.y)*40;start.y=b._get_height(start.x,start.z)+.95
	var route:Array[Vector3]=planned_route(region,start)
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var collision:=CollisionShape3D.new();collision.shape=capsule;walker.add_child(collision);root.add_child(walker);walker.set_physics_process(false)
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain.target=walker;terrain.extension_preview=fixture_name();terrain.extension_preview_position=Vector2(start.x,start.z);terrain.profile_streaming=true
	for name:String in ["jungle","forest","savanna","swamp","mountain","coast","beach","tropical","badlands"]:terrain.set("start_in_"+name,false)
	terrain.cave_settings=fixture_configuration();prepare_live_terrain(terrain,b);root.add_child(scene);scene.get_node("Interface").hide();walker.position=start;terrain._refresh_visible_chunks();camera.position=start+Vector3(0,10,18);camera.look_at(p)
	if motion_fps_limit()>0:Engine.max_fps=motion_fps_limit()
	var began:int=Time.get_ticks_usec();var ready:bool=await settle(terrain,true);var preload_seconds:float=(Time.get_ticks_usec()-began)/1000000.0;check(ready,"Actual live complete surface portal and cave cells ready inside original180s gate")
	var details:Dictionary={"preload_seconds":preload_seconds,"surface_status":terrain._cave_streamer.surface_status,"streamer_error":terrain._cave_streamer.last_error,"start":str(start),"seed":fixture_seed(),"region":str(fixture_cell()),"surface_family":fixture_name()}
	if not ready:finish(details,scene,walker);return
	for frame in range(3):await physics_frame
	var hole:=Vector3.INF
	for point:Vector3 in access:
		var depth:float=b._get_height(point.x,point.z)-point.y
		if depth>1 and depth<6:hole=point;break
	var ground:float=b._get_height(hole.x,hole.z);var query:=PhysicsRayQueryParameters3D.create(Vector3(hole.x,ground+4,hole.z),Vector3(hole.x,ground-20,hole.z));var hit:Dictionary=walker.get_world_3d().direct_space_state.intersect_ray(query);check(not hit.is_empty() and hit.position.y<ground-.5,"Actual committed terrain collider has an open cave mouth,not a terrain cap")
	details["opening_probe"]=str(hole);details["opening_hit"]=str(hit.get("position",Vector3.INF));details["initial_surface_columns"]=terrain._cave_streamer._surface_columns.size()
	var overlap:=PhysicsShapeQueryParameters3D.new();overlap.shape=capsule;overlap.transform=walker.global_transform;overlap.exclude=[walker.get_rid()];overlap.margin=.001;var overlaps:Array=walker.get_world_3d().direct_space_state.intersect_shape(overlap,8);check(overlaps.is_empty(),"Original surface spawn is not embedded in live terrain");details["initial_overlap_count"]=overlaps.size()
	await capture(camera,start+Vector3(12,9,15),p+Vector3(0,1,0),"approach")
	await capture(camera,hole+Vector3(6,5,9),hole+Vector3(-1,1,-2),"mouth")
	if not render_motion():RenderingServer.render_loop_enabled=false
	walker.route=route;walker.set_physics_process(true);var revisions:Dictionary={};var pauses:int=0;var rebuilds:int=0;var previous_transaction=terrain._cave_streamer._surface_transaction;var walk_began:int=Time.get_ticks_usec();var pause_began:int=0;var chamber_captured:bool=false;var measured_waypoint:int=-1;var maximum_depth:float=0;var deepest_position:=Vector3.INF;var graphics_samples:Array=[]
	motion_started(terrain,walker,camera)
	for frame in range(1000000):
		await physics_frame;observe(terrain);var stream=terrain._cave_streamer
		if follow_motion_camera():
			camera.position=walker.position+Vector3(0,.65,0);var focus:Vector3=route[mini(walker.waypoint,route.size()-1)]+Vector3(0,.65,0)
			if camera.position.distance_squared_to(focus)>.01:camera.look_at(focus)
		if frame%1200==0:
			var sample:Dictionary={"metres":walker.horizontal_distance_m,"static_bytes":OS.get_static_memory_usage(),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered":render_motion()};graphics_samples.append(sample);print("LIVE_CAVE_RESOURCE_DIAGNOSTIC ",sample)
		# Explicit preload pauses preserve physical support and never modify the
		# capsule,route,gravity,speed or floor angle to conceal missing geometry.
		walker.paused=allow_preload_pauses() and (terrain.committed_revision!=terrain.partition_revision or not stream.traversal_ready(walker.position))
		if walker.paused:
			pauses+=1
			if pause_began==0:pause_began=Time.get_ticks_usec()
			if Time.get_ticks_usec()-pause_began>180000000:break
			OS.delay_usec(1000)
		else:pause_began=0
		if stream._surface_transaction!=previous_transaction:rebuilds+=1;previous_transaction=stream._surface_transaction
		revisions[terrain.committed_revision]=true
		if measured_waypoint!=walker.waypoint:
			measured_waypoint=walker.waypoint;var depth:float=b._get_height(walker.position.x,walker.position.z)-(walker.position.y-.9)
			if depth>maximum_depth:maximum_depth=depth;deepest_position=walker.position
		if capture_mid_motion() and not chamber_captured and walker.waypoint>=route.size()/2:
			chamber_captured=true;walker.set_physics_process(false);RenderingServer.render_loop_enabled=true
			await capture(camera,walker.position+Vector3(3,2,4),walker.position+Vector3(-8,3,-12),report_name().trim_prefix("check_cave_live_")+"_chamber")
			var diagnostic_light:=OmniLight3D.new();diagnostic_light.position=camera.position;diagnostic_light.omni_range=24;diagnostic_light.light_energy=1.2;diagnostic_light.shadow_enabled=true;root.add_child(diagnostic_light)
			await capture(camera,camera.position,walker.position+Vector3(-8,3,-12),report_name().trim_prefix("check_cave_live_")+"_chamber_debug_light")
			diagnostic_light.queue_free();await process_frame
			if not render_motion():RenderingServer.render_loop_enabled=false
			walker.set_physics_process(true)
		if frame%12000==0:print("LIVE_CAVE_WALK waypoint=",walker.waypoint,"/",route.size()," metres=",walker.horizontal_distance_m," cuts=",revisions.size()," cells=",stream._cells.size()," drop=",walker.max_unsupported_drop)
		if walker.finished or walker.failed or Time.get_ticks_usec()-walk_began>motion_budget_usec():break
		var yield_usec:int=accelerated_worker_yield_usec()
		if yield_usec>0:OS.delay_usec(yield_usec)
	walker.set_physics_process(false);RenderingServer.render_loop_enabled=true;check(walker.finished and not walker.failed and walker.waypoint==route.size(),"Actual streamed surface→live mouth→declared underground destination→same surface return");check(walker.position.distance_to(start)<1.5 and walker.max_unsupported_drop<.75,"Original physical return/drop gates retained");check(revisions.size()>1,"Actual committed terrain tile changes,not a frozen replacement preview");check(maximum_jobs<=4,"Four TOTAL terrain+cave workers throughout live route")
	check(maximum_depth>=required_depth() and maximum_depth<=terrain.cave_settings.maximum_depth_metres+.25,"Actual native positions reach declared deep destination and remain inside local canonical depth envelope")
	check(maximum_portal_jobs>1,"Positive simultaneous surface-column extraction,not a serial or empty scheduler control")
	details["walk"]={"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"waypoint":walker.waypoint,"waypoints":route.size(),"final_position":str(walker.position),"target":str(route[mini(walker.waypoint,route.size()-1)]),"maximum_unsupported_drop_m":walker.max_unsupported_drop,"maximum_canonical_depth_m":maximum_depth,"deepest_position":str(deepest_position),"distance_m":walker.horizontal_distance_m,"preload_pause_frames":pauses,"committed_cuts":revisions.size(),"entrance_transactions_changed":rebuilds,"wall_seconds":(Time.get_ticks_usec()-walk_began)/1000000.0,"capsule_height_m":1.8,"capsule_radius_m":.4,"speed_mps":5,"floor_angle_degrees":45}
	details["motion_graphics_samples"]=graphics_samples;details["motion_rendered"]=render_motion();details["motion_camera_follows_actor"]=follow_motion_camera();details["motion_fps_limit"]=motion_fps_limit()
	details["motion_measurements"]=motion_measurements();details["automatic_preload_pauses_allowed"]=allow_preload_pauses();details["accelerated_worker_yield_usec"]=accelerated_worker_yield_usec()
	details["final_stream_state"]={"surface_status":terrain._cave_streamer.surface_status,"surface_columns":terrain._cave_streamer._surface_columns.size(),"surface_cells":terrain._cave_streamer._surface_owned.size(),"pending_jobs":terrain._cave_streamer.job_count(),"surface_committed":terrain._cave_streamer._surface_transaction!=null and terrain._cave_streamer._surface_transaction.committed}
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name()+"_motion_checkpoint.json",FileAccess.WRITE).store_string(JSON.stringify({"phase":"motion_finished_before_final_capture","details":details,"failures_so_far":failures,"scope":"Diagnostic checkpoint only;not a completed test or release acceptance"},"  "))
	print("LIVE_MOTION_END ",details.walk)
	await capture(camera,start+Vector3(12,9,15),p+Vector3(0,1,0),"return")
	finish(details,scene,walker)
func finish(details:Dictionary,scene,walker)->void:
	var declared_fps:String=OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS");details["engine_fixed_fps_acceleration"]=null if declared_fps.is_empty() else declared_fps!="none";details["engine_fixed_fps_value"]=int(declared_fps) if declared_fps.is_valid_int() else null;details["engine_mode_source"]="Runner child-only marker from declared engine arguments;unknown outside runner. Godot strips recognized flags from OS.get_cmdline_args()."
	if is_instance_valid(walker):walker.queue_free()
	if is_instance_valid(scene):scene.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable live entrance source "+path)
	details.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"maximum_total_jobs":maximum_jobs,"maximum_simultaneous_portal_jobs":maximum_portal_jobs,"peak_resident_cells":peak_cells,"production_enabled_by_default":bool(load("res://config/caves/cave_settings.tres").enabled),"scope":"Actual main scene/fullLOD6/four total workers using production cave surface transactions,terrain materials and native collision. "+motion_scope()})
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(details,"  "));print(report_name().to_upper()," ",checks," details=",details.get("walk",{})," failures=",failures);quit(0 if failures.is_empty() else 1)
