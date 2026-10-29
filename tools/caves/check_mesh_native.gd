extends "res://tools/caves/check_field.gd"
const Mesher=preload("res://tools/caves/cave_mesher_candidate.gd")
func edge_key(first:Vector3,second:Vector3)->String:
	var a:Vector3=first;var b:Vector3=second
	for axis in range(3):
		if a[axis]==0:a[axis]=0.0
		if b[axis]==0:b[axis]=0.0
	if a.x>b.x or (a.x==b.x and (a.y>b.y or (a.y==b.y and a.z>b.z))):var swap:Vector3=a;a=b;b=swap
	return PackedVector3Array([a,b]).to_byte_array().hex_encode()
func interface_edges(arrays:Array,origin:Vector3,axis:int,at:float)->Dictionary:
	var counts:Dictionary={};var result:Dictionary={}
	if arrays.is_empty():return result
	var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in range(0,positions.size(),3):
		for j in range(3):
			var a:Vector3=positions[i+j]+origin;var b:Vector3=positions[i+(j+1)%3]+origin
			if absf(a[axis]-at)>.00001 or absf(b[axis]-at)>.00001:continue
			# An edge at the intersection of two chunk planes can be paired
			# through either other neighbor. Global incidence checks it exactly.
			var multiple_planes:bool=false
			for other in range(3):
				if other==axis:continue
				for boundary:float in [origin[other],origin[other]+64]:
					if absf(a[other]-boundary)<.00001 and absf(b[other]-boundary)<.00001:multiple_planes=true
			if multiple_planes:continue
			var id:String=edge_key(a,b);counts[id]=int(counts.get(id,0))+1
	for id:String in counts:
		if counts[id]==1:result[id]=true
	return result
func border(arrays:Array,origin:Vector3,axis:int,at:float)->Dictionary:
	var points:Dictionary={}
	if arrays.is_empty():return points
	for vertex:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var p:Vector3=vertex+origin
		if absf(p[axis]-at)<.00001:points[p]=true
	return points
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://tools/caves/cave_field_candidate.gd","res://tools/caves/cave_mesher_candidate.gd","res://tools/caves/check_field.gd","res://tools/caves/check_mesh_native.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var surface:Callable=func(_x:float,_z:float)->float:return 100
	var region:Dictionary={"valid":true,"nodes":[{"point":Vector3(0,-8,0),"level":0,"chamber_radius":14.0,"chamber_height":14.0}],"edges":[]}
	for pair:Array in [[Vector3(-40,-8,0),Vector3(40,-8,0)],[Vector3(0,-8,-40),Vector3(0,-8,40)],[Vector3(30,-8,0),Vector3(58,-13.6,0)]]:region.edges.append({"points":PackedVector3Array(pair),"half_width":4.0,"headroom":8.0,"entrance":false})
	var field=Field.new();check(field.compile([region],surface),"Actual test field compiles")
	var meshes:Dictionary={};var bodies:Array=[];var vertices:int=0;var begin:int=Time.get_ticks_usec();var positive_seams:int=0;var seam_records:Array=[]
	for z in range(-1,1):
		for y in range(-1,1):
			for x in range(-1,1):
				var key:=Vector3i(x,y,z);var mesher=Mesher.new();var arrays:Array=mesher.build(field,key,2);meshes[key]=arrays
				if arrays.is_empty():continue
				var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];vertices+=positions.size();check(positions.size()%3==0 and positions.size()==normals.size(),"Complete actual triangle/normal arrays")
				for i in range(0,positions.size(),3):
					var face:Vector3=(positions[i+2]-positions[i]).cross(positions[i+1]-positions[i]).normalized();check(face.length_squared()>.9,"No degenerate emitted native triangles")
					for j in range(3):check(normals[i+j].is_finite() and absf(normals[i+j].length()-1)<.00001 and normals[i+j].dot(face)>=.149,"Finite unit inward normals in actual triangle hemisphere")
				var body:=StaticBody3D.new();body.position=Vector3(key)*64;var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(positions);collision.shape=shape;body.add_child(collision);root.add_child(body);bodies.append(body)
	var build_seconds:float=(Time.get_ticks_usec()-begin)/1000000.0
	for key:Vector3i in meshes:
		for axis in range(3):
			var offset:=Vector3i.ZERO;offset[axis]=1;var neighbor:Vector3i=key+offset
			if not meshes.has(neighbor):continue
			var at:float=float(neighbor[axis])*64;var first:Dictionary=border(meshes[key],Vector3(key)*64,axis,at);var second:Dictionary=border(meshes[neighbor],Vector3(neighbor)*64,axis,at)
			var first_edges:Dictionary=interface_edges(meshes[key],Vector3(key)*64,axis,at);var second_edges:Dictionary=interface_edges(meshes[neighbor],Vector3(neighbor)*64,axis,at)
			check(first_edges==second_edges,"Exact proper shared-face open-edge contours match;global incidence covers tangent/multiple-plane contacts")
			var missing:Array=[]
			for p:Vector3 in first:
				if second.has(p):continue
				var distance:float=INF;var nearest:=Vector3.INF
				for q:Vector3 in second:
					if p.distance_squared_to(q)<distance:distance=p.distance_squared_to(q);nearest=q
				if missing.size()<8:missing.append({"point":str(p),"nearest":str(nearest),"distance_m":sqrt(distance)})
			seam_records.append({"key":str(key),"neighbor":str(neighbor),"axis":axis,"raw_vertex_sets_equal":first==second,"proper_edges_equal":first_edges==second_edges,"proper_edge_count":first_edges.size(),"first_count":first.size(),"second_count":second.size(),"raw_tangent_missing_examples":missing})
			if not first.is_empty():positive_seams+=1
	check(positive_seams>=6,"Real positive X/Y/Z shared cave-surface seams exercised")
	var global_edges:Dictionary={};var first_triangle_keys:Array[String]=[]
	for key:Vector3i in meshes:
		if meshes[key].is_empty():continue
		var positions:PackedVector3Array=meshes[key][Mesh.ARRAY_VERTEX]
		for i in range(0,positions.size(),3):
			for j in range(3):
				var id:String=edge_key(positions[i+j]+Vector3(key)*64,positions[i+(j+1)%3]+Vector3(key)*64);global_edges[id]=int(global_edges.get(id,0))+1
				if first_triangle_keys.size()<3:first_triangle_keys.append(id)
	var incidences:Dictionary={}
	for id:String in global_edges:
		var count:int=global_edges[id];incidences[str(count)]=int(incidences.get(str(count),0))+1;check(count==2,"Entire contained cave surface has exactly two incident triangles at EVERY exact global edge")
	check(global_edges.size()>10000,"Positive closed volume,not empty seam/edge sets")
	var broken:Dictionary=global_edges.duplicate()
	for id:String in first_triangle_keys:broken[id]-=1
	var exposed:int=0
	for id:String in broken:
		if broken[id]!=2:exposed+=1
	check(exposed==3,"Deliberately omitted actual triangle creates three detected open edges")
	for frame in range(3):await physics_frame
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var collision:=CollisionShape3D.new();collision.shape=capsule;walker.add_child(collision);root.add_child(walker);walker.set_physics_process(false);walker.position=Vector3(-30,-7.05,0)
	var route:Array[Vector3]=[Vector3(30,-7.05,0),Vector3(40,-9.05,0),Vector3(54,-11.85,0),Vector3(40,-9.05,0),Vector3(30,-7.05,0),Vector3(0,-7.05,0),Vector3(0,-7.05,30),Vector3(0,-7.05,-30),Vector3(0,-7.05,0),Vector3(-30,-7.05,0)]
	var space:PhysicsDirectSpaceState3D=walker.get_world_3d().direct_space_state;var ray_error:float=0
	for point:Vector3 in route:
		var query:=PhysicsRayQueryParameters3D.create(point+Vector3(0,1,0),point-Vector3(0,3,0));query.exclude=[walker.get_rid()];var hit:Dictionary=space.intersect_ray(query);check(not hit.is_empty(),"Actual extracted native floor exists at every original route station")
		if not hit.is_empty():var error:float=absf(hit.position.y-(point.y-.95));ray_error=maxf(ray_error,error);check(error<.03,"Actual native floor agrees within unchanged30mm declared bound")
	check(is_equal_approx(walker.floor_max_angle,deg_to_rad(45)),"Unchanged native45degree capsule slope limit")
	walker.route=route;walker.set_physics_process(true)
	for frame in range(15000):
		await physics_frame
		if walker.finished or walker.failed:break
	walker.set_physics_process(false);check(walker.finished and not walker.failed and walker.waypoint==route.size(),"Actual native capsule completes connected chamber/orthogonal corridors/downramp/upramp/return without teleport/jump")
	check(walker.position.distance_to(Vector3(-30,-7.05,0))<1.5,"Actual physical return to original start")
	check(walker.max_unsupported_drop<.75,"Unchanged750mm unsupported-drop gate")
	check(walker.frames>3000,"Actual movement distance,not an empty/pre-finished route")
	var walk:Dictionary={"finished":walker.finished,"failed":walker.failed,"frames":walker.frames,"waypoint":walker.waypoint,"waypoints":route.size(),"final_position":str(walker.position),"max_unsupported_drop_m":walker.max_unsupported_drop,"distance_m":walker.horizontal_distance_m,"max_native_floor_error_m":ray_error,"capsule_height_m":1.8,"capsule_radius_m":.4,"speed_mps":5,"floor_max_angle_degrees":45}
	walker.queue_free()
	for body:StaticBody3D in bodies:body.queue_free()
	await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private mesher/native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_mesh_native.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"chunks":meshes.size(),"vertices":vertices,"positive_shared_seams":positive_seams,"seams":seam_records,"global_edge_incidence":incidences,"detected_omitted_triangle_open_edges":exposed,"vertex_weld_quantum_m":1.0/4096,"single_order_mesh_and_shape_seconds":build_seconds,"walk":walk,"production_registration":false,"scope":"PRIVATE actual2m tetrahedral implicit extraction across eight signed64m3chunks at one joined chamber/cross-corridor/20percent ramp fixture. Exact proper shared-face open-edge contours AND whole contained surface exact edge incidence2 everywhere,including tangent/multiple-plane contacts. Deliberately omitted triangle exposes3edges. Initial raw vertex-set predicate incorrectly demanded upper-chunk vertices where the ceiling only touchesY0;all raw observations/failures retained,not relabelled passes. Independent diagnosis ALSO found real tiny omitted triangles/local float collapse;canonical edge ordering and shared binary0.244mm weld repaired those before proper topology gates. No area-based positive triangle deletion. Unit inward normal hemisphere,actual full Jolt colliders and unchanged native1.8m/.4m/5mps/45degree capsule complete down/up/branch/return under unchanged.75mdrop/.03mray gates. Fixed60Hz acceleration,private preloaded chunks;not actual graph/portals/streaming/material/art or installed caves. Single-order mesh/setup not isolated benchmark."},"  "));print("CAVE_MESH_NATIVE ",checks," vertices=",vertices," seams=",positive_seams," edges=",incidences," walk=",walk," failures=",failures);quit(0 if failures.is_empty() else 1)
