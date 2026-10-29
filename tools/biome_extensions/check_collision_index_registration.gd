extends "res://tools/biome_extensions/check_all.gd"
const Index=preload("res://scripts/structure_collision_index.gd")
const Frozen=preload("res://tools/biome_extensions/structure_collision_spatial_candidate.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
class Harness extends "res://scripts/chunk_terrain.gd":
	func _ready()->void:pass
	func _process(_delta:float)->void:pass
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/structure_collision_index.gd","res://scripts/terrain_collision.gd","res://scripts/chunk_terrain.gd","res://tools/biome_extensions/check_collision_index_registration.gd","res://tools/biome_extensions/structure_collision_spatial_candidate.gd","res://tools/biome_extensions/structure_collision_blocks_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var faces:=PackedVector3Array()
	for z in range(-6,7):
		for x in range(-6,7):
			for i in range(64):
				var a:=Vector3(x*500+i,0,z*500)
				faces.append_array(PackedVector3Array([a,a+Vector3(0,0,4),a+Vector3(4,0,0)]))
	var metadata:Dictionary=Index.build(faces)
	check(metadata==Frozen.build(faces),"Complete worker metadata exactly equals accepted private index")
	for x:int in range(-12,13):
		var point:=Vector3(x*256+.001,2,-x*128)
		check(Index.select(faces,metadata,point)==Frozen.select(faces,metadata,point),"Exact frozen faces/ranges across25 negative/positive cells")
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=faces
	var old:Dictionary=Collision.prepare([],0,false,[arrays],{});var indexed:Dictionary=Collision.prepare([],0,false,[arrays],{},true)
	check(not old.has("structure_index") and indexed.structure_faces==faces,"Default prepare contract unchanged;complete source faces retained")
	var stripped:Dictionary=indexed.duplicate();stripped.erase("structure_index");check(stripped==old,"Index adds metadata only,not ground/cavity/structure changes")
	var terrain:=Harness.new();terrain.target=Node3D.new();root.add_child(terrain.target);root.add_child(terrain)
	var node:=MeshInstance3D.new();var mesh:=ArrayMesh.new();var structures:=ArrayMesh.new();structures.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.set_meta("collision_data",indexed);mesh.set_meta("extension_structures",structures)
	node.mesh=mesh;node.position=Vector3(37.5,0,-61.25);node.set_meta("tile",Vector3i(0,0,2));node.set_meta("resolution",16);terrain.add_child(node);terrain._active_chunks[Vector3i(0,0,2)]=node
	var cases:Array=[]
	for x:int in range(-4,5):
		terrain.target.global_position=node.position+Vector3(x*256+5,2,5)
		terrain._update_near_collision(node,x==-4,true)
		var body:StaticBody3D=node.get_node("NearTerrainCollision");var shape:CollisionShape3D=body.get_node("Structures");var point:Vector3=terrain.target.global_position-node.position
		check(body.collision_layer==1,"Active body remains enabled after staging/refresh")
		check(shape.shape.get_faces()==Index.select(faces,metadata,point).faces,"Controller refresh installs exact current local-cell subset at translated origin")
		check(shape.shape.get_faces().size()<faces.size(),"Actual staged shape excludes distant original blocks")
		var rid:RID=shape.shape.get_rid();terrain._update_near_collision(node,false,true);check(shape.shape.get_rid()==rid,"Same-cell update preserves native shape,not repeated rebuild")
		cases.append({"x":x,"triangles":shape.shape.get_faces().size()/3})
	terrain._teleport_pending=true;terrain._teleport_destination=node.position+Vector3(2500,2,2500);terrain.target.global_position=node.position+Vector3(-900,2,-900);terrain._update_near_collision(node,false,true)
	check(node.get_node("NearTerrainCollision/Structures").shape.get_faces()==Index.select(faces,metadata,Vector3(-900,2,-900)).faces,"Pending teleport retains coverage at actual active player,not future destination")
	terrain._teleport_pending=false;terrain.spatial_structure_collision=false;terrain._update_near_collision(node,true,true)
	check(node.get_node("NearTerrainCollision/Structures").shape.get_faces()==faces,"Independent off switch restores entire original collider")
	terrain.spatial_structure_collision=true;terrain._active_chunks.clear();terrain._update_near_collision(node,true)
	check(node.get_node("NearTerrainCollision").collision_layer==0,"Hidden staged replacement remains inactive until cut commit")
	terrain._active_chunks[Vector3i.ZERO]=node;terrain.target.queue_free();terrain.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable registered collision source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_collision_index_registration.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"scope":"Actual production index/prepare/stage/controller lifecycle. Frozen accepted metadata and25query cells;translated-origin active crossings,same-cell native RID retention,pending teleport actual-player protection,independent off full faces,hidden staged replacement remains disabled. No capsule/end-to-end performance claim."},"  "))
	print("COLLISION_INDEX_REGISTRATION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
