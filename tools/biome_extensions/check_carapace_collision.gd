extends "res://tools/biome_extensions/check_junction_collision.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_carapace_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/check_carapace_collision.gd","res://tools/biome_extensions/check_junction_collision.gd","res://tools/biome_extensions/artifacts/check_carapace_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_carapace_admission.json"));check(admission.passed and admission.cases.size()==6,"Six real admitted sites")
	var cases:Array=[]
	for item:Dictionary in admission.cases:
		var b=make_builder(7,item.seed);b.chunk_size=256;var point:=Vector2(item.position[0],item.position[1]);var cell:=Vector2i(floori(point.x/256),floori(point.y/256))
		var arrays:Array=build_structures(b,cell)[2];var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var tags:int=0
		for color:Color in colors:
			if absf(color.r-(.74 if item.habit==5 else .25))<.001:tags+=1
		check(tags==18000,"Full production plate addition in source arrays")
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(cell.x*256,0,cell.y*256);root.add_child(node)
		mesh.set_meta("collision_data",Collision.prepare([],0,false,[arrays],{}));Collision.stage(node,256,16,false,true)
		var body:StaticBody3D=node.get_node("NearTerrainCollision");check(body.collision_layer==0,"Staged plate physics inactive")
		check(body.get_node("Structures").shape!=null and body.get_node("Heightfield").shape==null,"Exact complete production structure arrays")
		Collision.activate(node,true);for frame in range(3):await physics_frame
		var space:PhysicsDirectSpaceState3D=node.get_world_3d().direct_space_state;var hits:int=0;var misses:int=0;var plate_hits:int=0;var maximum_error:float=0
		var plate_faces:=PackedVector3Array()
		for i in range(0,faces.size(),3):
			if absf(colors[i].r-(.74 if item.habit==5 else .25))<.001:plate_faces.append_array(faces.slice(i,i+3))
		for z in range(-5,6):
			for x in range(-5,6):
				var p:=Vector2(x*item.width*.4+1.37,z*item.width*.4+2.11);var world_point:=Vector3(point.x+p.x,0,point.y+p.y)
				var actual_local:=Vector2(world_point.x-node.position.x,world_point.z-node.position.z)
				var expected:float=visible_height(faces,actual_local);var plate:float=visible_height(plate_faces,actual_local)
				var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(world_point+Vector3(0,2000,0),world_point-Vector3(0,2000,0)))
				check(hit.is_empty()==not is_finite(expected),"Full structure footprint equals native collision")
				if not hit.is_empty() and is_finite(expected):
					var error:float=absf(hit.position.y-expected);maximum_error=maxf(maximum_error,error);hits+=1
					check(error<.03,"Independent triangle top envelope agrees within 3cm")
					if is_finite(plate) and absf(plate-expected)<.001:plate_hits+=1
				else:misses+=1
		check(plate_hits>=3 and misses>=20,"Plate surface and open surroundings both exercised")
		Collision.release(node);check(body.collision_layer==0 and body.get_node("Structures").shape==null,"Released plate collision cleared")
		cases.append({"seed":item.seed,"habit":item.habit,"position":point,"hits":hits,"plate_hits":plate_hits,"misses":misses,"maximum_mesh_physics_error_m":maximum_error});node.queue_free();await process_frame
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_carapace_collision.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Six default-admitted production structure arrays through native Jolt staging/activation/release; 121 vertical rays per case versus independent triangle top envelopes at actual float32 query positions. No whole-world streaming or traversal certificate."},"  "))
	print("CARAPACE_COLLISION ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
