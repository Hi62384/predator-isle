extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/portal_field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
func edge_key(a:Vector3,b:Vector3)->String:
	var first:String=str(a*4096);var second:String=str(b*4096);return first+"/"+second if first<second else second+"/"+first
func native_cell(key:Vector3i,arrays:Array,caps:Dictionary)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.position=Vector3(key)*64
	if not arrays.is_empty():
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh;var body:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision);node.add_child(body)
	Frontiers.attach(node,caps,StandardMaterial3D.new(),true);root.add_child(node);return node
func run()->void:
	var guards:Dictionary={}
	for name:String in ["stream_frontiers","mesher","portal_field","workload","surface_renderer","streamer","cave_settings"]:
		var path:String="res://scripts/caves/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/caves/check_stream_frontiers.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var field=Field.new();field.height=func(_x:float,_z:float)->float:return 200.0;field.include_surface_air=false;field.opening_rock_cover=6
	check(field.append_feature(Vector3(-20,5.35,32),Vector3(148,5.35,32),Vector2(5,10),0),"Positive canonical protected route crosses two native stream boundaries")
	var output:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		for key:Vector3i in [Vector3i.ZERO,Vector3i.RIGHT]:
			var mesher=Mesher.new();mesher.capture_boundary_values=true;var arrays:Array=mesher.build(field,key);var fresh:Dictionary=Frontiers.build(field,key);var reused:Dictionary=Frontiers.build(field,key,mesher.boundary_values);output.append({"key":key,"arrays":arrays,"caps":reused,"fresh_exact":var_to_bytes(fresh)==var_to_bytes(reused),"geometry_exact":var_to_bytes(arrays)==var_to_bytes(Mesher.new().build(field,key))})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame
	WorkerThreadPool.wait_for_task_completion(task);var native:Dictionary={};var cap_triangles:int=0;var edges_checked:int=0
	for data:Dictionary in output:
		check(data.fresh_exact and data.geometry_exact,"Reused canonical boundary samples preserve complete cap and cave mesh bytes exactly")
		var all_vertices:PackedVector3Array=data.arrays[Mesh.ARRAY_VERTEX].duplicate();var canonical:PackedByteArray=var_to_bytes(data.arrays)
		for face:int in data.caps:
			var vertices:PackedVector3Array=data.caps[face][Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=data.caps[face][Mesh.ARRAY_NORMAL];cap_triangles+=vertices.size()/3;var inward:Vector3=-Vector3(Frontiers.DIRECTIONS[face])
			for i in range(0,vertices.size(),3):check((vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).dot(inward)>0 and normals[i]==inward,"Temporary closure has exact inward winding and matching normals")
			all_vertices.append_array(vertices)
		var edges:Dictionary={}
		for i in range(0,all_vertices.size(),3):
			for corner in range(3):var key:String=edge_key(all_vertices[i+corner],all_vertices[i+(corner+1)%3]);edges[key]=int(edges.get(key,0))+1
		var bad:int=0
		for count:int in edges.values():
			edges_checked+=1
			if count!=2:bad+=1
		check(bad==0,"Complete per-cell closed manifold: every original wall/cap edge paired exactly,no cracks/overlap/nonmanifold triangles")
		check(canonical==var_to_bytes(data.arrays),"Temporary boundary never rewrites canonical extracted geometry")
		native[data.key]=native_cell(data.key,data.arrays,data.caps)
	var first:MeshInstance3D=native[Vector3i.ZERO];var second:MeshInstance3D=native[Vector3i.RIGHT];second.visible=false
	for child:Node in second.get_children():
		if child is StaticBody3D:child.collision_layer=0
	var cells:Dictionary={Vector3i.ZERO:first};Frontiers.synchronize(cells)
	for frame in range(3):await physics_frame
	var space=first.get_world_3d().direct_space_state;var ray:=PhysicsRayQueryParameters3D.create(Vector3(32,7,32),Vector3(90,7,32));var hit:Dictionary=space.intersect_ray(ray);check(not hit.is_empty() and absf(hit.position.x-64)<.001,"Unloaded neighbour is a real rock/collision boundary,not a sky hole or unsupported void")
	second.visible=true
	for child:Node in second.get_children():
		if child is StaticBody3D:child.collision_layer=1
	cells[Vector3i.RIGHT]=second;Frontiers.synchronize(cells)
	for frame in range(3):await physics_frame
	check(space.intersect_ray(ray).is_empty(),"Both reciprocal native closures removed after complete neighbouring geometry is ready")
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);var start:=Vector3(16,6.30,32);walker.position=start;var route:Array[Vector3]=[start,Vector3(112,6.30,32),start];walker.route=route
	for frame in range(4000):
		walker._physics_process(1.0/60);await physics_frame
		if walker.finished or walker.failed:break
	check(walker.finished and not walker.failed and walker.waypoint==3 and walker.position.distance_to(start)<1.5 and walker.max_unsupported_drop<.75,"Ordinary unchanged capsule makes two-way return across newly opened cell seam")
	cells.erase(Vector3i.RIGHT);Frontiers.synchronize(cells)
	for frame in range(3):await physics_frame
	hit=space.intersect_ray(ray);check(not hit.is_empty() and absf(hit.position.x-64)<.001,"Closure collision restored before neighbouring cell can be evicted")
	Frontiers.synchronize(cells,false)
	for frame in range(3):await physics_frame
	check(space.intersect_ray(ray).is_empty(),"Global collision opt-out also disables temporary boundary physics")
	field.include_surface_air=true;field.height=func(_x:float,_z:float)->float:return -100.0
	check(Frontiers.build(field,Vector3i.ZERO).is_empty(),"Portal outdoor half-space never produces frontier curtains/walls")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable boundary proof source "+path)
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cap_triangles":cap_triangles,"paired_edges":edges_checked,"walk":{"finished":walker.finished,"distance_m":walker.horizontal_distance_m,"drop_m":walker.max_unsupported_drop,"frames":walker.frames},"scope":"Canonical2m/tetrahedral face-diagonal/weld clipping;two positive numeric worker cells,complete per-cell wall+closure closed-manifold audit,matching native render/collision payloads,unloaded/loaded/evicted/collision-off ray controls and ordinary capsule return. Outdoor surface-air negative. Temporary load boundaries only;no permanent graph changes,no LOD/whole-world/reference-art claim."};FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_stream_frontiers.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CAVE_STREAM_FRONTIERS ",checks," caps=",cap_triangles," edges=",edges_checked," walk=",report.walk," failures=",failures);walker.queue_free();first.queue_free();second.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
