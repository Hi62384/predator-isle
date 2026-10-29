extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const WaterRenderer=preload("res://scripts/caves/water_renderer.gd")
func run()->void:
	var guards:Dictionary={};var directory=DirAccess.open("res://scripts/caves")
	for name:String in directory.get_files():
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/check_geology_integration.gd","res://tools/biome_extensions/route_probe.gd","res://shaders/swamp_water.gdshader","res://config/caves/cave_settings.tres"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var configuration=Config.new();configuration.regional_activity=1;var work=Workload.new();check(work.configure(b.settings,configuration,73921,0),"Worker snapshots live independent geological settings")
	configuration.chamber_variety=false;configuration.seepage_density=0
	check(work.configuration.chamber_variety and work.configuration.seepage_density==.15,"Later source-resource edits cannot mutate owned worker settings")
	var result:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(9,-3));var own:Dictionary={};var pockets:int=0;var pools:int=0;var water_cases:Array=[];var seen:Dictionary={};var rejected:Array=[]
		for region:Dictionary in bundle.get("regions",[]):
			pockets+=region.get("pockets",[]).size();pools+=region.get("pools",[]).size()
			if region.id==Vector2i(9,-3):own=region
			for basin:Dictionary in region.get("pools",[]):
				var key:Vector3i=work.field.cell(Vector3(basin.center.x,basin.water_y,basin.center.z))
				if seen.has(key):continue
				seen[key]=true;var water:Dictionary=work.water_cell(key);rejected.append_array(water.rejected);water_cases.append({"key":key,"water":water,"repeat":Basins.water_cell(bundle.regions,work.field,key)})
		var neck:Dictionary=own.get("pocket_passages",[])[0] if not own.get("pocket_passages",[]).is_empty() else {};var pool:Dictionary=own.get("pools",[])[0] if not own.get("pools",[]).is_empty() else {};var keys:Dictionary={}
		if not neck.is_empty():
			var low:Vector3i=work.field.cell(neck.points[0].min(neck.points[1])-Vector3(7,3,7));var high:Vector3i=work.field.cell(neck.points[0].max(neck.points[1])+Vector3(7,10,7))
			for z in range(low.z,high.z+1):
				for y in range(low.y,high.y+1):
					for x in range(low.x,high.x+1):keys[Vector3i(x,y,z)]=true
		if not pool.is_empty():
			for y in range(floori((pool.bed_y-2)/64),floori(pool.water_y/64)+1):keys[Vector3i(floori(pool.center.x/64),y,floori(pool.center.z/64))]=true
		var cells:Array=[]
		for key:Vector3i in keys:cells.append(work.build_cell(key))
		result.append({"bundle":bundle,"own":own,"pockets":pockets,"pools":pools,"water_cases":water_cases,"rejected":rejected,"neck":neck,"pool":pool,"cells":cells})
	)
	var began:int=Time.get_ticks_usec()
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(result.size()==1,"Actual worker geological workload completes")
	if result.is_empty():quit(1);return
	var data:Dictionary=result[0];check(not data.bundle.has("error") and data.own.get("valid",false),"Original geographic region remains admitted,not rerolled")
	check(data.pockets>0 and data.pools>0 and not data.neck.is_empty(),"Default settings create actual joined chambers and retained pools")
	check(data.rejected.is_empty(),"Every admitted regional pool has fully measured air and real bed,not an invalid invisible positive")
	var pool_ids:Dictionary={};var water_vertices:int=0
	for entry:Dictionary in data.water_cases:
		check(var_to_bytes(entry.water)==var_to_bytes(entry.repeat),"Complete water arrays regenerate exactly at the same owned cell")
		for id:String in entry.water.ids:check(not pool_ids.has(id),"No pool duplicated between half-open owner cells");pool_ids[id]=true
		var arrays:Array=entry.water.arrays
		if arrays.is_empty():continue
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];water_vertices+=vertices.size()
		for index in range(vertices.size()):
			var point:Vector3=vertices[index]+Vector3(entry.key)*64;check(work.field.sample(point)<-.015 and point.y-arrays[Mesh.ARRAY_TEX_UV][index].x>.015,"Actual rendered water vertex has carved air and positive measured depth")
	check(pool_ids.size()==data.pools and water_vertices>0,"Every actual canonical pool is owned and meshed exactly once")
	for region:Dictionary in data.bundle.regions:
		for pool:Dictionary in region.get("pools",[]):check(Basins.route_clear(pool.center,pool.radius,pool.bed_y,pool.water_y,region),"Main routes AND new capsule-wide chamber necks stay dry")
	var cold=Workload.new();var original_config=Config.new();original_config.regional_activity=1;check(cold.configure(b.settings,original_config,73921,0),"Independent canonical regeneration worker")
	# Opposite region query order must not change later canonical descriptors.
	cold.network.region(Vector2i(10,-3));cold.network.region(Vector2i(8,-3));check(var_to_bytes(data.own)==var_to_bytes(cold.network.region(Vector2i(9,-3))),"Complete enlarged regional graph independent of neighbor load order")
	var nodes:Array=[];var water_nodes:int=0
	for cell:Dictionary in data.cells:
		if cell.arrays.is_empty():continue
		var node:=MeshInstance3D.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cell.arrays);node.mesh=mesh;node.position=Vector3(cell.key)*64;var body:=StaticBody3D.new();body.name="CaveCollision";var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child);node.add_child(body);root.add_child(node);nodes.append(node)
		var water_node:MeshInstance3D=WaterRenderer.attach(node,cell.water)
		if water_node!=null:water_nodes+=1;check(water_node.get_child_count()==0 and water_node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Water is rendered independently without fake walking collision")
	for frame in range(3):await physics_frame
	var walk:Dictionary={};var maximum_error:float=0
	if not data.neck.is_empty() and not nodes.is_empty():
		var points:PackedVector3Array=data.neck.points;var state:PhysicsDirectSpaceState3D=nodes[0].get_world_3d().direct_space_state
		for station in range(33):
			var point:Vector3=points[0].lerp(points[1],float(station)/32);var hit:Dictionary=state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3(0,3,0),point-Vector3(0,2,0)));check(not hit.is_empty(),"Native supported floor across the entire enlarged-room neck")
			if not hit.is_empty():maximum_error=maxf(maximum_error,absf(hit.position.y-point.y))
		check(maximum_error<.03,"Actual capsule-wide flat-neck floor within unchanged30mm native bound")
		var start:Vector3=points[0]+Vector3(0,.95,0);var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=start;walker.route.append_array([points[1],points[0]])
		var initial:=PhysicsShapeQueryParameters3D.new();initial.shape=capsule;initial.transform=walker.global_transform;initial.exclude=[walker.get_rid()];check(state.intersect_shape(initial,8).is_empty(),"Actual canonical room start has no initial capsule overlap")
		var started:int=Time.get_ticks_usec()
		for frame in range(6000):
			walker._physics_process(1.0/60);await physics_frame
			if walker.finished or walker.failed or Time.get_ticks_usec()-started>60000000:break
		check(walker.finished and not walker.failed and walker.position.distance_to(start)<1.5 and walker.max_unsupported_drop<.75,"Unchanged ordinary capsule enters actual new chamber and returns without unsupported drop")
		walk={"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"distance_m":walker.horizontal_distance_m,"maximum_unsupported_drop_m":walker.max_unsupported_drop,"maximum_native_floor_error_m":maximum_error};walker.queue_free()
	if not data.pool.is_empty() and not nodes.is_empty():
		var pool:Dictionary=data.pool;var state:PhysicsDirectSpaceState3D=nodes[0].get_world_3d().direct_space_state;var hit:Dictionary=state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pool.center.x,pool.water_y,pool.center.z),Vector3(pool.center.x,pool.bed_y-2,pool.center.z)));check(not hit.is_empty() and hit.position.y<pool.water_y-.05,"Actual pool has native rock bed below water,not an opaque ground-plane overlay")
	for node:Node3D in nodes:node.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable live geology source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_geology_integration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"pockets":data.pockets,"pools":data.pools,"water_vertices":water_vertices,"rejected_pool_ids":data.rejected,"native_cells":data.cells.size(),"water_nodes":water_nodes,"walk":walk,"single_order_seconds":(Time.get_ticks_usec()-began)/1000000.0,"runtime_enabled_by_default":false,"scope":"Actual original Spore seed73921/cell(9,-3),complete canonical3x3regional field and neighboring edges with DEFAULT geological controls. Real worker room/bed/water arrays,unique pool ownership,measured depth,unchanged dry neck floor/native capsule return,independent neighbor-order regeneration and actual water-node installation. Not a streamed whole-network return,water GPU art acceptance or all-user-task completion."},"  "));print("CAVE_GEOLOGY_INTEGRATION ",checks," pockets=",data.pockets," pools=",data.pools," walk=",walk," failures=",failures);quit(0 if failures.is_empty() else 1)
