extends "res://tools/caves/check_crystal_features.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const FAILURE_POSITION:=Vector3(9689.473,-61.20719,-2777.026)
const FAILURE_TARGET:=Vector3(9691.392,-59.66418,-2779.899)
func probe(points:PackedVector3Array)->Dictionary:
	var route:Array[Vector3]=[]
	for p:Vector3 in points:route.append(p+Vector3(0,.95,0))
	for i in range(points.size()-2,-1,-1):route.append(points[i]+Vector3(0,.95,0))
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=route[0];walker.route=route
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=walker.global_transform;query.exclude=[walker.get_rid()];var overlaps:int=walker.get_world_3d().direct_space_state.intersect_shape(query,8).size()
	for frame in range(12000):
		walker._physics_process(1.0/60);await physics_frame
		if walker.failed or walker.finished:break
	var result:Dictionary={"finished":walker.finished,"failed":walker.failed,"waypoint":walker.waypoint,"waypoints":route.size(),"frames":walker.frames,"initial_overlap_count":overlaps,"maximum_unsupported_drop_m":walker.max_unsupported_drop,"distance_m":walker.horizontal_distance_m,"final":str(walker.position),"start":str(route[0]),"return_error_m":walker.position.distance_to(route[0])};walker.queue_free();await process_frame;return result
func run()->void:
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_features.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://tools/biome_extensions/artifacts/check_cave_live_crystal_return.json"]:guards[path]=FileAccess.get_sha256(path)
	var records:Array=[]
	for mode:String in ["normal","feature_meshes_off","chamber_growth_off","crystal_off","original_cap_floor"]:
		var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		if mode=="feature_meshes_off":definition.feature_configuration.density=0
		if mode=="chamber_growth_off":definition.feature_configuration.chamber_growth=false
		if mode=="crystal_off":definition.spawn_chance_percent=0
		config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var b=make_builder(5,73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original fixed Crystal worker diagnostic configuration "+mode);var output:Array=[]
		if mode=="original_cap_floor":work.field.continuous_route_floors=false
		var task:int=WorkerThreadPool.add_task(func()->void:
			var bundle:Dictionary=work.discover(Vector2i(6,-2));var matching:Array=[];var nearest:Array=[];var probe_points:=PackedVector3Array()
			for region:Dictionary in bundle.regions:
				for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
					for i in range(edge.points.size()):
						if edge.points[i].distance_to(FAILURE_TARGET-Vector3(0,.95,0))<.01:
							var points:Array=[]
							for j in range(maxi(0,i-4),mini(edge.points.size(),i+5)):points.append({"station":j,"point":str(edge.points[j])})
							probe_points=edge.points.slice(maxi(0,i-4),mini(edge.points.size(),i+5))
							matching.append({"region":str(region.id),"from":edge.from,"to":edge.to,"station":i,"maximum_grade":edge.get("maximum_grade",-1),"points":points})
			var cells:Array=[];var center:Vector3i=work.field.cell(FAILURE_TARGET)
			for z in range(center.z-1,center.z+2):
				for x in range(center.x-1,center.x+2):cells.append(work.build_cell(Vector3i(x,center.y,z)))
			var p:Vector3=FAILURE_POSITION-Vector3(0,.9,0)
			for index:int in work.field.bins.get(work.field.bin_cell(p),PackedInt32Array()):
				var value:float=work.field.evaluate(p,PackedInt32Array([index]))
				if value<2:nearest.append({"index":index,"kind":work.field.kinds[index],"begin":str(work.field.begins[index]),"end":str(work.field.ends[index]),"dimensions":str(work.field.dimensions[index]),"style":work.field.styles[index],"scalar_at_failed_floor":value})
			output.append({"bundle":bundle,"cells":cells,"matching_graph_points":matching,"field_features_at_failed_floor":nearest,"probe_points":probe_points})
		)
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1 and not output[0].cells.is_empty(),"Positive same-site local failure geometry "+mode);var world:=Node3D.new();root.add_child(world)
		for cell:Dictionary in output[0].cells:
			var node:=Node3D.new();node.position=Vector3(cell.key)*64;var body:=StaticBody3D.new();body.name="CaveCollision";node.add_child(body)
			if not cell.arrays.is_empty():var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child)
			check(Renderer.attach(node,cell.get("features",[]),config.biome_regions,true,false),"Same actual native feature collider path "+mode);world.add_child(node)
		await physics_frame;await physics_frame;var state:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state;var samples:Array=[];var direction:Vector3=(FAILURE_TARGET-FAILURE_POSITION)*Vector3(1,0,1);direction=direction.normalized()
		for step in range(-20,29):
			var p:Vector3=FAILURE_POSITION+direction*step*.25;var ray:=PhysicsRayQueryParameters3D.create(Vector3(p.x,FAILURE_TARGET.y+.5,p.z),Vector3(p.x,FAILURE_TARGET.y-12,p.z),1);var hit:Dictionary=state.intersect_ray(ray);var owner:String="none"
			if not hit.is_empty():var collider:CollisionObject3D=hit.collider;owner=str(collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape)).name)
			samples.append({"station_m":step*.25,"x":p.x,"z":p.z,"native_floor_y":hit.position.y if not hit.is_empty() else null,"shape":owner,"scalar_at_expected_floor":work.field.sample(Vector3(p.x,FAILURE_TARGET.y-.95,p.z))})
		var walk_result:Dictionary=await probe(output[0].probe_points)
		check(walk_result.initial_overlap_count==0,"Same unchanged local ordinary capsule spawn is not embedded "+mode)
		if mode=="original_cap_floor":check(not walk_result.finished and walk_result.failed,"Exact old floor-cap control reproduces original real physical trap without changing route/capsule")
		else:check(walk_result.finished and not walk_result.failed and walk_result.return_error_m<1.5 and walk_result.maximum_unsupported_drop_m<.75,"Same original local solved path now completes ordinary no-jump two-way native return "+mode)
		records.append({"mode":mode,"matching_graph_points":output[0].matching_graph_points,"field_features_at_failed_floor":output[0].field_features_at_failed_floor,"native_profile":samples,"walk":walk_result});world.queue_free();await process_frame;await physics_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable original live-failure diagnostic source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_cave_crystal_live_route.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"failed_position":str(FAILURE_POSITION),"failed_target":str(FAILURE_TARGET),"records":records,"engine_fixed_fps_marker":OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS"),"scope":"Original failed1872.873m live walk at same73921/(6,-2),fixed failed capsule position/target,normal/feature-mesh-off/chamber-growth-off/Crystal-off and exact original floor-cap controls,all local graph matches/field features/native ray profiles. Same original nine solved route points and ordinary1.8m/.4m/5mps/45degree/.6snap/no-jump return. New continuous adjacent-grade caps must pass every mode while old cap mode reproduces trap. This is LOCAL physical repair evidence,not a full live return or completion claim."},"  "));print("CRYSTAL_LIVE_DIAGNOSIS ",checks," variants=",records.size()," walks=",records.map(func(item:Dictionary)->Dictionary:return item.walk)," failures=",failures);quit(0 if failures.is_empty() else 1)
