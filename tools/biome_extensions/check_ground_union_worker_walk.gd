extends "res://tools/biome_extensions/check_streamed_roundtrip.gd"
const Fixture=preload("res://tools/biome_extensions/ground_union_worker_fixture.gd")
const INPUT="res://tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json"
func v3(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func native_floor(space:PhysicsDirectSpaceState3D,p:Vector2)->Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,1000,p.y),Vector3(p.x,-2000,p.y)))
func run()->void:
	var diagnostic=JSON.parse_string(FileAccess.get_file_as_string(INPUT));assert(diagnostic.passed and diagnostic.cpu_gpu_source_matches==9);var focus:Vector3=v3(diagnostic.focus);var p:=Vector2(focus.x,focus.z)
	var guards:Dictionary={INPUT:FileAccess.get_sha256(INPUT)}
	for path:String in diagnostic.source_sha256:assert(FileAccess.get_sha256(path)==diagnostic.source_sha256[path]);guards[path]=diagnostic.source_sha256[path]
	for path:String in [Fixture.CONTROLLER,"res://tools/biome_extensions/ground_union_worker_fixture.gd","res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_ground_union_worker_walk.gd","res://tools/biome_extensions/check_streamed_roundtrip.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var reference_heights:Array=[];var records:Array=[]
	for enabled:bool in [false,true]:
		var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(17,true);var frame:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").sample(locator._extras[7],p);var axis:Vector2=frame.tangent;var side:=Vector2(-axis.y,axis.x)
		var scene=load("res://scenes/main.tscn").instantiate();scene.get_node("FreeCamera").set_script(null);var terrain=scene.get_node("Terrain");Fixture.configure(terrain,enabled);terrain.world_seed=17;terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
		for property:Dictionary in terrain.get_property_list():
			if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
		var marker:=Marker3D.new();marker.position=focus;scene.add_child(marker);terrain.target=marker;root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
		for idle in range(3):await physics_frame
		var space:PhysicsDirectSpaceState3D=terrain.get_world_3d().direct_space_state;var points:Array[Vector3]=[];var heights:Array=[];var structure_probes:int=0;var changed_floor_points:int=0;var maximum_floor_change:float=0
		for station in range(17):
			var q:Vector2=p+side*(-80+station*10);var hit:Dictionary=native_floor(space,q);check(not hit.is_empty(),"Every fixed cross-section point has actual native floor")
			if hit.is_empty():continue
			points.append(hit.position+Vector3(0,.95,0));heights.append(hit.position.y)
			var body:CollisionObject3D=hit.collider;var owner_id:int=body.shape_find_owner(hit.shape);var shape:Node=body.shape_owner_get_owner(owner_id)
			if shape.name=="Structures":structure_probes+=1
			if enabled:
				var delta:float=absf(hit.position.y-reference_heights[station]);maximum_floor_change=maxf(maximum_floor_change,delta)
				if delta>.02:changed_floor_points+=1
		check(points.size()==17 and structure_probes>=2,"Actual shoulder crossings,not only underlying unaffected ground")
		if not enabled:reference_heights=heights
		else:check(changed_floor_points>=2,"Actual candidate collision differs at original fixed cross-section,not a display-only intervention")
		if points.size()!=17:scene.queue_free();await process_frame;continue
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false);walker.position=points[0]
		var route:Array[Vector3]=[]
		for index in range(1,points.size()):route.append(points[index])
		for index in range(points.size()-2,-1,-1):route.append(points[index])
		check(is_equal_approx(walker.floor_max_angle,deg_to_rad(45)),"Unchanged45degree physical floor limit");walker.route=route;walker.set_physics_process(true);var started:int=Time.get_ticks_usec();var cut:int=terrain.committed_revision
		for frame_index in range(50000):
			await physics_frame
			if walker.failed or walker.finished or Time.get_ticks_usec()-started>180000000:break
		walker.set_physics_process(false);check(walker.finished and walker.waypoint==route.size(),"Actual320m shoulder capsule return completes");check(walker.position.distance_to(points[0])<1.5,"Return without jump/teleport/noclip");check(walker.max_unsupported_drop<.75,"Unchanged unsupported-drop gate,including initial approach");check(terrain.committed_revision==cut,"Declared fixed-cut test does not masquerade as streamed traversal")
		records.append({"candidate_enabled":enabled,"finished":walker.finished,"failed":walker.failed,"waypoints":route.size(),"reached_waypoint":walker.waypoint,"movement_frames":walker.frames,"horizontal_distance_m":walker.horizontal_distance_m,"max_unsupported_drop_m":walker.max_unsupported_drop,"max_airborne_frames":walker.max_airborne,"native_structure_floor_probes":structure_probes,"changed_native_floor_points":changed_floor_points,"maximum_candidate_floor_change_m":maximum_floor_change,"leaves":terrain._active_chunks.size(),"physics_cut":cut,"start":str(points[0]),"end":str(walker.position)});walker.queue_free();scene.queue_free();await process_frame;await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private worker/walk source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_ground_union_worker_walk.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"source_sha256":guards,"cases":records,"scope":"PRIVATE actual full worker-dispatch/collision trial,original versus ground-union candidate at EXACT seed17 ground-boundary cross-section. Actual inherited ChunkTerrain overrides only its original dispatch generator constructor;builder/class-sensitive global bounds,worker count,batching,collision preparation and committed cut remain original.17 fixed native floor probes must cross actual structure shapes;candidate floor must really differ at two points. Two320m capsule returns,1.8mheight/.4mradius/5mps/45degree/.6msnap,gravity9.8,initial drop counted,unchanged.75mgate. FixedMarker target andLOD4:NOT streamed/unpaused/fullLOD6/all-seed/custom-scale/cave acceptance. No production edits."},"  "));print("GROUND_UNION_WORKER_WALK ",records);quit(0 if failures.is_empty() else 1)
