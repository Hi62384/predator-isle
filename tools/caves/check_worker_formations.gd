extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Forms=preload("res://scripts/caves/formations.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/cave_settings.gd","res://scripts/caves/workload.gd","res://scripts/caves/formations.gd","res://scripts/caves/field.gd","res://scripts/caves/portal_field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/portal_mesher.gd","res://scripts/caves/network.gd","res://scripts/caves/route_solver.gd","res://tools/caves/check_worker_formations.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var configuration=Config.new();configuration.formation_density=0;configuration.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,configuration,73921,0),"Actual worker owns immutable cave/surface settings")
	var results:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var region:Dictionary=work.network.region(Vector2i(9,-3));var bundle:Dictionary={"cell":region.id,"regions":[region],"connections":[]};var valid:bool=work.use_bundle(bundle);var cases:Array=[];var center:Vector3=region.nodes[1].point;var key:=Vector3i(floori(center.x/64),floori(center.y/64),floori(center.z/64))
		for dz in range(-1,2):
			for dx in range(-1,2):
				var cell:Vector3i=key+Vector3i(dx,0,dz);work.configuration.formation_density=0;var base:Array=work.build(cell);work.configuration.formation_density=.75;var decorated:Array=work.build(cell);work.configuration.formation_density=0;var restored:Array=work.build(cell);var forms:Dictionary=Forms.new().build(work.field,cell,73921,region.geology,.75);cases.append({"key":cell,"base":base,"decorated":decorated,"restored":restored,"forms":forms})
		results.append({"valid":valid,"cases":cases,"center":center,"geology":region.geology})
	)
	var began:int=Time.get_ticks_usec()
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(results.size()==1 and results[0].valid,"Actual WorkerThreadPool formation workload completes");var result:Dictionary=results[0];var total:int=0;var added:int=0;var bodies:Array=[]
	for data:Dictionary in result.cases:
		check(var_to_bytes(data.base)==var_to_bytes(data.restored),"Zero density restores complete original worker arrays exactly")
		check(var_to_bytes(data.decorated)==var_to_bytes(Forms.join(data.base,data.forms.arrays)),"Actual worker appends complete expected geological geometry,not a shader-only tag")
		total+=data.forms.placements.size();added+=data.forms.arrays[Mesh.ARRAY_VERTEX].size()/3 if not data.forms.arrays.is_empty() else 0
		if not data.decorated.is_empty():
			var body:=StaticBody3D.new();body.position=Vector3(data.key)*64;var shape_node:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(data.decorated[Mesh.ARRAY_VERTEX]);shape_node.shape=shape;body.add_child(shape_node);root.add_child(body);bodies.append(body)
	check(total>0 and added>0,"Original actual first chamber has positive installed calcite geometry")
	for frame in range(3):await physics_frame
	var state:PhysicsDirectSpaceState3D=bodies[0].get_world_3d().direct_space_state;var center:Vector3=result.center
	for dx:float in [-1.0,0.0,1.0]:
		for dz:float in [-1.0,0.0,1.0]:
			var p:Vector3=center+Vector3(dx,0,dz);var hit:Dictionary=state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(0,3,0),p-Vector3(0,2,0)));check(not hit.is_empty() and absf(hit.position.y-center.y)<.03,"Actual decorated native chamber retains protected floor within30mm")
	for body:StaticBody3D in bodies:body.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable worker formation source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_worker_formations.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"original_region":"(9,-3)","seed":73921,"geology":result.geology,"worker_cells":result.cases.size(),"actual_forms":total,"added_triangles":added,"single_order_seconds":(Time.get_ticks_usec()-began)/1000000.0,"scope":"Original actual Spore first chamber,nine genuine worker cells:complete zero/decorated/zero arrays,independent full appended-geometry comparison,positive source geometry and actual native protected-floor rays. Not broad reference art or GPU/timing certification."},"  "));print("CAVE_WORKER_FORMATIONS ",checks," forms=",total," triangles=",added," failures=",failures);quit(0 if failures.is_empty() else 1)
