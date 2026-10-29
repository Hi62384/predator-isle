extends "res://tools/biome_extensions/check_all.gd"
const FrozenFixture=preload("res://tools/caves/frozen_fixture.gd")
const Field=preload("res://scripts/caves/portal_field.gd")
const Features=preload("res://scripts/caves/frozen_features.gd")
const Dispatch=preload("res://scripts/caves/biome_features.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Renderer=preload("res://scripts/caves/feature_renderer.gd")
var walks:Array=[]
func report_name()->String:return "check_cave_frozen_features"
func shore_route()->Array[Vector3]:return [Vector3(32,20.95,39),Vector3(32,20.95,44),Vector3(32,20.61,50),Vector3(32,20.95,44),Vector3(32,20.95,39)]
func walk(route:Array[Vector3],label:String)->void:
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=route[0];walker.route=route
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=walker.global_transform;query.exclude=[walker.get_rid()];check(walker.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),label+" ordinary capsule has no initial overlap")
	var started:int=Time.get_ticks_usec()
	for frame in range(12000):
		walker._physics_process(1.0/60);await physics_frame
		if walker.finished or walker.failed or Time.get_ticks_usec()-started>120000000:break
	check(walker.finished and not walker.failed and walker.waypoint==route.size() and walker.position.distance_to(route[0])<1.5 and walker.max_unsupported_drop<.75,label+" complete ordinary no-jump/no-correction two-way return")
	walks.append({"label":label,"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"distance_m":walker.horizontal_distance_m,"maximum_unsupported_drop_m":walker.max_unsupported_drop,"waypoint":walker.waypoint,"waypoints":route.size(),"final":str(walker.position),"engine_fixed_fps_marker":OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS")});walker.queue_free();await process_frame
func fixture()->Dictionary:
	var room:Dictionary={"id":"A","point":Vector3(32,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0}
	# Match real basin admission:side of protected route,roughly.7room radius,
	# radius3–5m. The original overextended corner basin is retained as failed
	# evidence;its low rock roof was not a valid walking-lake fixture.
	var pool:Dictionary={"id":"A:seepage","center":Vector3(32,20,50),"radius":5.0,"water_y":19.6,"bed_y":17.0,"depth":3.0,"bed":{"id":"A:basin-bed","point":Vector3(32,17,50),"level":0,"chamber_radius":4.25,"chamber_height":4.5}}
	var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([Vector3(-16,20,32),Vector3(96,20,32)]),"half_width":4.0,"headroom":8.0,"entrance":false}
	var assignment:Dictionary={"fallback":"default","candidates":[{"id":"A/frozen","biome_id":"frozen","distances":{"A":0.0,"B":112.0},"reach_m":350.0,"transition_m":32.0}]}
	return {"id":Vector2i.ZERO,"valid":true,"nodes":[room],"edges":[edge],"geology":0,"pools":[pool],"cave_biome_regions":assignment}
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_features.gd","res://tools/biome_extensions/route_probe.gd","res://config/caves/biomes/frozen_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=fixture();var field=Field.new();field.include_surface_air=false
	var height:Callable=func(_x:float,_z:float)->float:return 150.0
	check(field.compile([region],height,[],region.cave_biome_regions),"Positive real shared rock chamber/retained basin/Frozen graph scalar")
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/frozen_cave_definition.tres"));var all_kinds:Dictionary={};var cases:Array=[];var form_count:int=0;var water_count:int=0;var attachment_count:int=0
	var cells:Array=[];var vertices_total:int=0
	for key:Vector3i in [Vector3i(-1,0,-1),Vector3i(0,0,-1),Vector3i(-1,0,0),Vector3i.ZERO,Vector3i(1,0,0),Vector3i(0,-1,0)]:
		var water:Dictionary=Basins.water_cell([region],field,key)
		var generator=Features.new();var settings:Dictionary={"density":1.0,"curtain_chance":1.0,"lake_ice":true};var result:Dictionary=generator.build(field,key,73921,[region],settings,water)
		check(result.valid and var_to_bytes(result)==var_to_bytes(generator.build(field,key,73921,[region],settings,water)),"Complete cold/repeated numeric ice geometry and ownership deterministic")
		for placement:Dictionary in result.placements:
			all_kinds[placement.kind]=true;check(placement.owner==key,"Stable half-open feature owner")
			if placement.kind in ["icicle","ice_stalagmite","ice_column"]:
				form_count+=1;var tip:float=placement.root.y+placement.up*placement.height
				check(not generator.shapes.protected(field,placement.root,placement.radius,minf(placement.root.y,tip),maxf(placement.root.y,tip)),"Ice complete footprint/vertical span outside original mandatory clearance")
				check(absf(field.sample(placement.root))<.001 and placement.groundwater>.08,"Ice root measured on actual solid/air boundary with real nearby water")
			if placement.kind=="frozen_waterfall":check(placement.measured_wall_vertices>=153 and placement.source_basin=="A:seepage","Large waterfall follows measured curved rock and real groundwater source")
			if placement.kind=="frozen_water":water_count+=1;check(placement.top_triangles>50 and placement.thickness==.55 and placement.source_basins==["A:seepage"],"Substantial volumetric frozen surface on real retained pool,not random blue plane")
			for ring:PackedVector3Array in placement.get("attachments",[]):
				for point:Vector3 in ring:attachment_count+=1;check(field.sample(point)>.06,"Complete buried ice contact ring/sheet—not a center-only floating attachment")
		for batch:Dictionary in result.batches:
			var positions:PackedVector3Array=batch.arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=batch.arrays[Mesh.ARRAY_NORMAL];vertices_total+=positions.size();batch["biome_id"]="frozen"
			for i in range(0,positions.size(),3):check(normals[i].is_finite() and absf(normals[i].length()-1)<.0001 and (positions[i+2]-positions[i]).cross(positions[i+1]-positions[i]).normalized().dot(normals[i])>.1,"Every physical ice triangle nondegenerate with unit smooth normal facing correct native side")
		var dispatched:Dictionary=Dispatch.build(field,key,73921,[region],config.biome_regions,water);check(dispatched.valid,"Generic worker dispatch accepts registered numeric provider without Node/GPU calls")
		cells.append({"key":key,"arrays":Mesher.new().build(field,key),"features":result.batches});cases.append({"key":str(key),"placements":result.placements.map(func(p:Dictionary)->String:return p.kind),"batches":result.batches.size()})
	check(form_count>0 and water_count==1 and all_kinds.has("frozen_waterfall"),"Positive actual icicles/waterfall/lake geometry—not empty successful fixtures")
	var negative=Field.new();negative.include_surface_air=false;negative.compile([region],height)
	check(Dispatch.build(negative,Vector3i.ZERO,73921,[region],config.biome_regions,{}).batches.is_empty(),"Unassigned Default has exact empty feature output")
	var parent:=Node3D.new();root.add_child(parent)
	for cell:Dictionary in cells:
		var node:=MeshInstance3D.new();node.position=Vector3(cell.key)*64;var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;body.collision_mask=0;node.add_child(body);parent.add_child(node)
		if not cell.arrays.is_empty():var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(cell.arrays[Mesh.ARRAY_VERTEX]);child.shape=shape;body.add_child(child)
		check(Renderer.attach(node,cell.features,config.biome_regions,true,true),"Same native cave cell/body uploads material and actual ice collision together")
	for frame in range(3):await physics_frame
	var space:PhysicsDirectSpaceState3D=parent.get_world_3d().direct_space_state
	var high_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(32,25,50),Vector3(32,15,50),1));print("FROZEN_HIGH_RAY ",high_hit.get("position","empty"))
	var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(32,20.5,50),Vector3(32,15,50),1));print("FROZEN_LAKE_RAY ",hit.get("position","empty")," normal=",hit.get("normal","empty"));check(not hit.is_empty() and absf(hit.position.y-(region.pools[0].water_y+Features.ICE_FREEBOARD))<.015,"Native frozen lake collision is actual visible ice top,not old underwater bed")
	await walk([Vector3(0,20.95,32),Vector3(80,20.95,32),Vector3(0,20.95,32)],"Protected cave route with complete ice formations present")
	await walk(shore_route(),"Natural shore to frozen lake center and back")
	for node:MeshInstance3D in parent.get_children():node.get_node("CaveCollision").collision_layer=0
	for frame in range(2):await physics_frame
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(32,25,50),Vector3(32,15,50),1)).is_empty(),"Atomic original cave collision-off switch also removes every ice collider")
	parent.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Frozen physical geometry source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"forms":form_count,"frozen_water":water_count,"attached_samples":attachment_count,"vertices":vertices_total,"walks":walks,"basin_radius":region.pools[0].radius,"high_probe_hit":str(high_hit.get("position","empty")),"scope":"Controlled real shared rock/basin with Frozen scalar: deterministic numeric geometry,all complete buried contact rings,protected routes,curved groundwater-fed waterfall,thick retained-water ice and actual native material/collision upload/off. Ordinary1.8m/.4m/5mps/45degree/.6msnap/no-jump/no-correction protected-route and shore/lake two-way returns. Fixed-fps acceleration explicitly labelled,not FPS. Not saved registry placement,large natural-world art or complete Frozen acceptance."},"  "));print("FROZEN_FEATURES ",checks," forms=",form_count," kinds=",all_kinds," vertices=",vertices_total," walks=",walks," failures=",failures);quit(0 if failures.is_empty() else 1)
