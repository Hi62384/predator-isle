extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
const Field=preload("res://tools/caves/cave_field_candidate.gd")
const Mesher=preload("res://tools/caves/cave_mesher_candidate.gd")
func run()->void:
	var guards:Dictionary={};var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/caves/check_actual_graph_native.gd","res://tools/caves/cave_route_solver_candidate.gd","res://tools/caves/cave_network_candidate.gd","res://tools/caves/cave_field_candidate.gd","res://tools/caves/cave_mesher_candidate.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	# Original Spore geographic cell from the eight-host admission study. Fixed
	# before meshing/traversal,not replaced after a failure. Default geology only.
	var b=make_builder(3,73921);var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,73921);network.activity=1;var data:Dictionary=network.region(Vector2i(9,-3));check(data.valid and data.nodes.size()==17 and data.edges.size()==20,"Original actual canonical geographic cell retains its admitted multi-level graph")
	if not data.valid:quit(1);return
	var field=Field.new();check(field.compile([data],b._get_height),"Whole original region implicit field,not selected disjoint tunnel meshes")
	var route:Array[Vector3]=[];var start:Vector3=data.nodes[1].point+Vector3(0,.95,0);var planned_length:float=0;var previous:Vector3=start
	for edge_id in range(1,10):
		var points:PackedVector3Array=data.edges[edge_id].points
		for i in range(1,points.size()):
			var point:Vector3=points[i]+Vector3(0,.95,0);route.append(point);planned_length+=Vector2(point.x-previous.x,point.z-previous.z).length();previous=point
	for edge_id in range(9,0,-1):
		var points:PackedVector3Array=data.edges[edge_id].points
		for i in range(points.size()-2,-1,-1):
			var point:Vector3=points[i]+Vector3(0,.95,0);route.append(point);planned_length+=Vector2(point.x-previous.x,point.z-previous.z).length();previous=point
	var keys:Dictionary={}
	for point:Vector3 in route:
		var low:Vector3i=field.cell(point-Vector3.ONE*24);var high:Vector3i=field.cell(point+Vector3.ONE*24)
		for z in range(low.z,high.z+1):
			for y in range(low.y,high.y+1):
				for x in range(low.x,high.x+1):
					var key:=Vector3i(x,y,z)
					if field.has_chunk(key):keys[key]=true
	check(keys.size()>8 and keys.size()<256,"Bounded sparse real-graph route preload,not an infinite dense volume")
	var bodies:Array=[];var total_vertices:int=0;var begin:int=Time.get_ticks_usec();var built:int=0;var largest_chunk_seconds:float=0
	for key:Vector3i in keys:
		var chunk_start:int=Time.get_ticks_usec();var arrays:Array=Mesher.new().build(field,key,2);largest_chunk_seconds=maxf(largest_chunk_seconds,(Time.get_ticks_usec()-chunk_start)/1000000.0);built+=1
		if not arrays.is_empty():
			var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];total_vertices+=faces.size();var body:=StaticBody3D.new();body.position=Vector3(key)*64;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);child.shape=shape;body.add_child(child);root.add_child(body);bodies.append(body)
		if built%8==0:print("ACTUAL_GRAPH_MESH ",built,"/",keys.size()," vertices=",total_vertices);await process_frame
	var build_seconds:float=(Time.get_ticks_usec()-begin)/1000000.0
	for frame in range(3):await physics_frame
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=start
	var initial:=PhysicsShapeQueryParameters3D.new();initial.shape=capsule;initial.transform=walker.global_transform;initial.exclude=[walker.get_rid()];initial.margin=.001;var overlaps:Array=walker.get_world_3d().direct_space_state.intersect_shape(initial,8);check(overlaps.is_empty(),"Original declared graph spawn is not embedded in extracted rock")
	walker.route=route;walker.set_physics_process(true);var started:int=Time.get_ticks_usec()
	for frame in range(1000000):
		await physics_frame
		if walker.failed or walker.finished or Time.get_ticks_usec()-started>180000000:break
	walker.set_physics_process(false);check(walker.finished and not walker.failed and walker.waypoint==route.size(),"Actual original two-level cyclic graph traverses down/up/all selected branches/back without teleport/jump")
	check(walker.position.distance_to(start)<1.5,"Physical return to exact original underground graph start")
	check(walker.max_unsupported_drop<.75,"Unchanged750mm unsupported-drop gate on actual graph union")
	check(is_equal_approx(walker.floor_max_angle,deg_to_rad(45)),"Unchanged45degree movement limit")
	var walk:Dictionary={"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"waypoint":walker.waypoint,"waypoints":route.size(),"final_position":str(walker.position),"target":str(route[mini(walker.waypoint,route.size()-1)]),"initial_position":str(start),"maximum_unsupported_drop_m":walker.max_unsupported_drop,"distance_m":walker.horizontal_distance_m,"planned_horizontal_length_m":planned_length,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"initial_overlap_count":overlaps.size()}
	walker.queue_free()
	for body:StaticBody3D in bodies:body.queue_free()
	await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual-graph native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_actual_graph_native.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"original_surface_family":"spore_forest","underground_biome":"Default only","seed":73921,"region":"(9,-3)","original_region_nodes":data.nodes.size(),"original_region_edges":data.edges.size(),"route_preload_cells":keys.size(),"nonempty_native_cells":bodies.size(),"vertices":total_vertices,"single_order_mesh_setup_seconds":build_seconds,"largest_single_chunk_mesh_seconds":largest_chunk_seconds,"walk":walk,"production_registration":false,"scope":"PRIVATE original actual canonical Spore surface geographic cell,Default-only17node/20edge3D implicit union. Selected first two complete underground cycles plus descent/ascent and full return,all source graph geometry participates in field. All sparse route cells preloaded;actual2m64m3meshes/native colliders,unchanged1.8m/.4m/5mps/45degree/.75mdrop test capsule. Original entrance/other owner rejections preserved;not a different positive seed/root. No surface portal traversal,actual streaming,full graph/every owner/material/art acceptance or installed caves. Fixed60Hz acceleration;single-order prebuild costs not isolated runtime performance."},"  "));print("ACTUAL_GRAPH_NATIVE ",checks," walk=",walk," failures=",failures);quit(0 if failures.is_empty() else 1)
