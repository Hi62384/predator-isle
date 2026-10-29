extends "res://tools/biome_extensions/check_all.gd"
const Envelope=preload("res://scripts/caves/traversal_envelope.gd")
const Field=preload("res://scripts/caves/portal_field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const Streamer=preload("res://scripts/caves/streamer.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func old_ready(point:Vector3,resident:Dictionary,wanted:Dictionary)->bool:
	var key:=Vector3i(floori(point.x/64),floori(point.y/64),floori(point.z/64))
	if not resident.has(key):return false
	var local:Vector3=point-Vector3(key)*64
	for axis in range(3):
		for sign_value:int in [-1,1]:
			if (local[axis] if sign_value<0 else 64-local[axis])>2:continue
			var offset:=Vector3i.ZERO;offset[axis]=sign_value;var neighbor:Vector3i=key+offset
			if wanted.has(neighbor) and not resident.has(neighbor):return false
	return true
func cell_node(field,key:Vector3i,world:Node3D)->MeshInstance3D:
	var arrays:Array=Mesher.new().build(field,key,2);var node:=MeshInstance3D.new();node.position=Vector3(key)*64;var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;body.collision_mask=0;node.add_child(body)
	if not arrays.is_empty():
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh;var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	Frontiers.attach(node,Frontiers.build(field,key),StandardMaterial3D.new(),false);world.add_child(node);return node
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://scripts/caves/traversal_envelope.gd","res://scripts/caves/streamer.gd","res://scripts/caves/stream_frontiers.gd","res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var old_false_positives:int=0;var combinations:int=0
	for origin:Vector3i in [Vector3i.ZERO,Vector3i(150,-3,-35),Vector3i(-150,3,35)]:
		for corner in range(8):
			var point:Vector3=Vector3(origin)*64+Vector3(1 if corner&1 else 63,1 if corner&2 else 63,1 if corner&4 else 63);var wanted:Dictionary={};var loaded:Dictionary={};var signs:=Vector3i(-1 if corner&1 else 1,-1 if corner&2 else 1,-1 if corner&4 else 1)
			for z in range(2):
				for y in range(2):
					for x in range(2):wanted[origin+Vector3i(x*signs.x,y*signs.y,z*signs.z)]=true
			for missing:Vector3i in wanted:
				loaded=wanted.duplicate();loaded.erase(missing);combinations+=1;check(not Envelope.ready(point,loaded,wanted),"Full original2m margin waits for every missing requested face/edge/corner cell,all8signed corners")
				if old_ready(point,loaded,wanted):old_false_positives+=1
			check(Envelope.ready(point,wanted,wanted),"All original wanted cells restored;no impossible wait on absent rock-only cells")
	check(combinations==192 and old_false_positives==96,"Original six-face-only gate has96positive diagonal false-readies in the fixed cohort")
	var field=Field.new();field.include_surface_air=false
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	check(field.compile([{"valid":true,"id":Vector2i.ZERO,"nodes":[{"id":"room","level":1,"point":Vector3(32,-1.4,64),"chamber_radius":24.0,"chamber_height":18.0}],"edges":[]}],height),"Real shared air room straddles both Y and Z64m boundaries")
	var world:=Node3D.new();root.add_child(world);var nodes:Dictionary={};var wanted:Dictionary={Vector3i(0,-1,0):true,Vector3i(0,-1,1):true,Vector3i(0,0,0):true,Vector3i(0,0,1):true}
	for key:Vector3i in [Vector3i(0,-1,0),Vector3i(0,-1,1),Vector3i(0,0,0)]:nodes[key]=cell_node(field,key,world)
	Frontiers.synchronize(nodes);await physics_frame;await physics_frame
	var start:=Vector3(32,-.45,63.5);var stream=Streamer.new();stream.configuration=Config.new();stream._bundle={"entrances":[]};stream._cells=nodes;stream._wanted=wanted
	check(old_ready(start,nodes,wanted) and not stream.traversal_ready(start),"Actual production streamer now rejects the reproduced original false-ready:missing upper-forward diagonal,all six needed face cells present")
	var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var collision:=CollisionShape3D.new();collision.shape=capsule;walker.add_child(collision);root.add_child(walker);walker.set_physics_process(false);walker.position=start;var route:Array[Vector3]=[start,Vector3(32,-.45,67),start];walker.route=route
	for frame in range(40):walker._physics_process(1.0/60);await physics_frame
	var native_contacts:Array=[];var frontier_contact:bool=false
	for i in range(walker.get_slide_collision_count()):
		var contact:KinematicCollision3D=walker.get_slide_collision(i);var collider=contact.get_collider();var path:String=str(collider.get_path()) if collider is Node else str(collider);native_contacts.append({"path":path,"position":contact.get_position(),"normal":contact.get_normal()});frontier_contact=frontier_contact or path.contains("CaveFrontiers")
	check(walker.position.z<63.8 and frontier_contact,"Original old-ready negative really catches the ordinary capsule head on the upper diagonal native frontier,not merely a Dictionary fixture")
	var blocked_position:Vector3=walker.position;nodes[Vector3i(0,0,1)]=cell_node(field,Vector3i(0,0,1),world);Frontiers.synchronize(nodes);await physics_frame;await physics_frame;check(stream.traversal_ready(walker.position),"Exact missing native diagonal uploaded/frontier released;complete envelope restores ready")
	for frame in range(2400):
		walker._physics_process(1.0/60);await physics_frame
		if walker.finished or walker.failed:break
	check(walker.finished and not walker.failed and walker.position.distance_to(start)<1.5 and walker.max_unsupported_drop<.75,"SAME capsule/route resumes across original corner and returns without teleport/jump/correction or relaxed gates")
	var walk:Dictionary={"blocked_position":blocked_position,"old_false_ready_native_contacts":native_contacts,"finished":walker.finished,"failed":walker.failed,"distance_m":walker.horizontal_distance_m,"frames":walker.frames,"maximum_unsupported_drop_m":walker.max_unsupported_drop,"final":walker.position};walker.queue_free();world.queue_free();stream.free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable shared diagonal-readiness source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frontier_corners.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"signed_corner_missing_cases":combinations,"original_positive_false_readies":old_false_positives,"native_walk":walk,"scope":"Whole existing2m capsule loading margin,not larger player/cell radius.192signed corner/missing-cell controls and original96diagonal false-ready negatives. Actual shared SDF/2m mesher/native clipped upper-cell frontier catches1.8m/.4m capsule despite all face neighbors ready;upload exact missing diagonal and resume SAME route/capsule back to original start,unchanged5mps/45degrees/.6snap/.75drop. Explicit fixed-fps acceleration if runner declares it. Not full-world return/FPS/art acceptance."},"  "));print("FRONTIER_CORNERS ",checks," combinations=",combinations," old_false=",old_false_positives," walk=",walk," failures=",failures);quit(0 if failures.is_empty() else 1)
