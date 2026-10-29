extends "res://tools/biome_extensions/check_all.gd"
const Network=preload("res://tools/caves/cave_network_candidate.gd")
const Field=preload("res://tools/caves/cave_portal_field_candidate.gd")
const Mesher=preload("res://tools/caves/cave_portal_mesher_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/check_portal_native.gd","res://tools/caves/cave_portal_field_candidate.gd","res://tools/caves/cave_portal_mesher_candidate.gd","res://tools/caves/cave_route_solver_candidate.gd","res://tools/caves/cave_network_candidate.gd","res://tools/caves/cave_field_candidate.gd","res://tools/caves/cave_mesher_candidate.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 120
	var water:Callable=func(_x:float,_z:float)->float:return 0
	var network=Network.new();network.configure(height,water,73921);network.activity=1;var data:Dictionary=network.region(Vector2i.ZERO);check(data.valid,"Original deterministic synthetic Default graph entrance admitted")
	var access:PackedVector3Array=data.edges[0].points;var p:Vector3=access[0];var direction:=Vector2(access[1].x-p.x,access[1].z-p.z).normalized();var start:Vector3=p-Vector3(direction.x,0,direction.y)*40;start.y=120.95
	var field=Field.new();check(field.compile([data],height),"Full original graph participates in the same implicit surface/cave union")
	field.surface_rect=Rect2((Vector2(p.x,p.z)/64).floor()*64-Vector2.ONE*192,Vector2.ONE*448);field.surface_min_y=120;field.surface_max_y=120
	var route:Array[Vector3]=[]
	for point:Vector3 in access:route.append(point+Vector3(0,.95,0))
	for i in range(access.size()-2,-1,-1):route.append(access[i]+Vector3(0,.95,0))
	route.append(start)
	var keys:Dictionary={}
	for point:Vector3 in route:
		var low:Vector3i=field.cell(point-Vector3.ONE*24);var high:Vector3i=field.cell(point+Vector3.ONE*24)
		for z in range(low.z,high.z+1):
			for y in range(low.y,high.y+1):
				for x in range(low.x,high.x+1):
					var key:=Vector3i(x,y,z)
					if field.has_chunk(key):keys[key]=true
	for z in range(floori(field.surface_rect.position.y/64),ceili(field.surface_rect.end.y/64)):
		for x in range(floori(field.surface_rect.position.x/64),ceili(field.surface_rect.end.x/64)):keys[Vector3i(x,1,z)]=true
	check(keys.size()<128,"Bounded finite synthetic portal/surface preview cells")
	var bodies:Array=[];var vertices:int=0;var begin:int=Time.get_ticks_usec();var completed:int=0
	for key:Vector3i in keys:
		var arrays:Array=Mesher.new().build(field,key,2);completed+=1
		if not arrays.is_empty():
			var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];vertices+=faces.size();var body:=StaticBody3D.new();body.position=Vector3(key)*64;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);child.shape=shape;body.add_child(child);root.add_child(body);bodies.append(body)
		if completed%8==0:print("PORTAL_PREVIEW_MESH ",completed,"/",keys.size());await process_frame
	var setup:float=(Time.get_ticks_usec()-begin)/1000000.0
	for frame in range(3):await physics_frame
	var hole:Vector3=Vector3.INF
	for point:Vector3 in access:
		var depth:float=120-point.y
		if depth>1 and depth<6:hole=point;break
	check(hole.is_finite(),"Original planned access includes actual ground-intersecting opening,not only buried tunnels")
	var state:PhysicsDirectSpaceState3D=bodies[0].get_world_3d().direct_space_state;var ray:Dictionary=state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(hole.x,124,hole.z),Vector3(hole.x,100,hole.z)))
	check(not ray.is_empty() and ray.position.y<119,"Native surface hole is genuinely open,not a fully collidable terrain cap")
	if not ray.is_empty():check(absf(ray.position.y-hole.y)<.03,"Visible/extracted/native opening floor within unchanged30mm bound")
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=start;walker.route=route;walker.set_physics_process(true);var started:int=Time.get_ticks_usec()
	for frame in range(1000000):
		await physics_frame
		if walker.finished or walker.failed or Time.get_ticks_usec()-started>180000000:break
	walker.set_physics_process(false);check(walker.finished and not walker.failed and walker.waypoint==route.size(),"Actual native surface→open portal→first underground chamber→same surface return,without jumps/teleport")
	check(walker.position.distance_to(start)<1.5 and walker.max_unsupported_drop<.75,"Unchanged return-position/drop gates")
	var walk:Dictionary={"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"waypoint":walker.waypoint,"waypoints":route.size(),"final_position":str(walker.position),"target":str(route[mini(walker.waypoint,route.size()-1)]),"start":str(start),"maximum_unsupported_drop_m":walker.max_unsupported_drop,"distance_m":walker.horizontal_distance_m,"capsule_height_m":1.8,"capsule_radius_m":.4,"speed_mps":5,"floor_max_angle_degrees":45}
	walker.queue_free()
	for body:StaticBody3D in bodies:body.queue_free()
	await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private portal-union source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_portal_native.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"synthetic_surface_height_m":120,"seed":73921,"region":"(0,0)","route_preload_cells":keys.size(),"vertices":vertices,"single_order_prebuild_seconds":setup,"original_opening_probe":str(hole),"native_opening_floor":str(ray.get("position",Vector3.INF)),"walk":walk,"production_registration":false,"scope":"PRIVATE same implicit surface/cave air union removes actual top terrain and exposed tunnel roof,not black decals or collider-only holes. Original deterministic flat120m canonical field/seed73921Default graph entrance;all graph participates,finite448m surface replacement preview plus preloaded sparse route cells. Actual2m64m3native meshes and unchanged1.8m/.4m/5mps/45degree/.75mdrop/.03mray test capsule completes intended surface/firstchamber/surface route. Fixed60Hz acceleration,synthetic field only,no original-world surface patch/attribute transport/material/real streaming or installed cave claim."},"  "));print("CAVE_PORTAL_NATIVE ",checks," walk=",walk," failures=",failures);quit(0 if failures.is_empty() else 1)
