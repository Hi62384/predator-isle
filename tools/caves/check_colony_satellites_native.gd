extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/check_colony_satellites_native.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(6,73921);var config=Config.new();config.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual colony worker configuration");var result:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var region:Dictionary=work.network.region(Vector2i(7,-2));var bundle:Dictionary={"cell":region.id,"regions":[region],"connections":[]};var valid:bool=work.use_bundle(bundle);var branches:Array=[];var keys:Dictionary={}
		for edge:Dictionary in region.edges:
			if edge.get("excavation_role","")!="secondary_passage":continue
			branches.append(edge)
			for point:Vector3 in edge.points:
				var low:Vector3i=work.field.cell(point-Vector3(8,3,8));var high:Vector3i=work.field.cell(point+Vector3(8,16,8))
				for z in range(low.z,high.z+1):
					for y in range(low.y,high.y+1):
						for x in range(low.x,high.x+1):keys[Vector3i(x,y,z)]=true
		var cells:Array=[]
		for key:Vector3i in keys:cells.append(work.build_cell(key))
		result.append({"valid":valid,"branches":branches,"cells":cells})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(result.size()==1 and result[0].valid and result[0].branches.size()==2,"Original region retains both true shared-field satellite branches")
	if result.is_empty():quit(1);return
	var data:Dictionary=result[0];var bodies:Array=[];var triangles:int=0
	for cell:Dictionary in data.cells:
		if cell.arrays.is_empty():continue
		triangles+=cell.arrays[Mesh.ARRAY_VERTEX].size()/3;var body:=StaticBody3D.new();body.position=Vector3(cell.key)*64;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);root.add_child(body);bodies.append(body)
	for frame in range(3):await physics_frame
	var walks:Array=[]
	for branch:Dictionary in data.branches:
		var points:PackedVector3Array=branch.points;var start:Vector3=points[0]+Vector3(0,.95,0);var route:Array[Vector3]=[]
		for point:Vector3 in points:route.append(point+Vector3(0,.95,0))
		for i in range(points.size()-2,-1,-1):route.append(points[i]+Vector3(0,.95,0))
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=start;walker.route=route
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=walker.global_transform;query.exclude=[walker.get_rid()];check(walker.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),"Original parent excavation-room start has no initial capsule overlap")
		var started:int=Time.get_ticks_usec()
		for frame in range(10000):
			walker._physics_process(1.0/60);await physics_frame
			if walker.finished or walker.failed or Time.get_ticks_usec()-started>120000000:break
		check(walker.finished and not walker.failed and walker.waypoint==route.size() and walker.position.distance_to(start)<1.5 and walker.max_unsupported_drop<.75,"Ordinary capsule enters actual narrower satellite,returns through parent junction and preserves original physical limits")
		walks.append({"from":branch.from,"to":branch.to,"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"distance_m":walker.horizontal_distance_m,"maximum_unsupported_drop_m":walker.max_unsupported_drop,"waypoints":route.size(),"waypoint":walker.waypoint});walker.queue_free();await process_frame
	for body:Node in bodies:body.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable native excavation source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_colony_satellites_native.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"seed":73921,"original_region":"(7,-2)","native_cells":bodies.size(),"native_triangles":triangles,"walks":walks,"scope":"Actual original Insect shared graph/field generated on real worker,including all rooms and protected other routes. Both narrower satellite corridors and parent-room junctions extracted into native collision,independent ordinary1.8m/.4m/5mps/45degree/.75mdrop/two-way returns. Closed route cells preloaded;separate main-scene live entrance test covers streaming/materials/complete surface structures. Not continuous surface-to-deepest/all-world or full Insect art completion."},"  "));print("CAVE_COLONY_SATELLITES_NATIVE ",checks," walks=",walks," failures=",failures);quit(0 if failures.is_empty() else 1)
