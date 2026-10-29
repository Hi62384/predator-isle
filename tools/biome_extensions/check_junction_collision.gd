extends "res://tools/biome_extensions/check_all.gd"
const Junction=preload("res://scripts/alien_junction_geometry.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
func visible_height(faces:PackedVector3Array,p:Vector2)->float:
	var result:float=-INF
	for i in range(0,faces.size(),3):
		var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
		var v:=Vector2(b.x-a.x,b.z-a.z);var w:=Vector2(c.x-a.x,c.z-a.z);var q:=p-Vector2(a.x,a.z)
		var denominator:float=v.cross(w)
		if absf(denominator)<.0000001:continue
		var beta:float=q.cross(w)/denominator;var gamma:float=v.cross(q)/denominator
		if beta>=-.00001 and gamma>=-.00001 and beta+gamma<=1.00001:result=maxf(result,a.y+beta*(b.y-a.y)+gamma*(c.y-a.y))
	return result
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/check_junction_collision.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(7,seed_id);var field=b._extras[7];var point:Vector2=field.hive_node(Vector2i(-12,-12));var edges:PackedVector2Array=field.network_edges(Vector2i(-12,-12))
		var directions:Array[Vector2]=[(edges[1]-point).normalized(),(edges[5]-point).normalized()]
		var g=Structures.new();g.origin=Vector3(point.x,0,point.y);g._support_steps=Structures.support_grids();Junction.new().emit(g,b,point,directions,75,120,.47)
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=g.vertices;arrays[Mesh.ARRAY_NORMAL]=g.normals;arrays[Mesh.ARRAY_COLOR]=g.colors;arrays[Mesh.ARRAY_TEX_UV]=g.uvs
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node:=MeshInstance3D.new();node.mesh=mesh;node.position=g.origin;root.add_child(node)
		mesh.set_meta("collision_data",Collision.prepare([],0,false,[arrays],{}));Collision.stage(node,256,16,false,true)
		var body:StaticBody3D=node.get_node("NearTerrainCollision");check(body.collision_layer==0,"Staged junction physics inactive")
		check(body.get_node("Structures").shape!=null and body.get_node("Heightfield").shape==null,"Exact worker mesh, no unrelated terrain heightfield")
		Collision.activate(node,true);for frame in range(3):await physics_frame
		var space:PhysicsDirectSpaceState3D=node.get_world_3d().direct_space_state;var hits:int=0;var misses:int=0;var maximum_error:float=0;var maximum_query_rounding:float=0
		for z in range(-4,5):
			for x in range(-4,5):
				var p:=Vector2(x*19.13+1.37,z*19.73+2.11)
				var world_point:=Vector3(point.x+p.x,0,point.y+p.y)
				# The stored Vector3 query is float32 at these world coordinates.
				# Compare at its actual x/z, not the unrepresentable intended p:
				# a millimetre x shift on a steep fin can change y by centimetres.
				var actual_local:=Vector2(world_point.x-node.position.x,world_point.z-node.position.z)
				maximum_query_rounding=maxf(maximum_query_rounding,p.distance_to(actual_local))
				var expected:float=visible_height(g.vertices,actual_local)
				var query:=PhysicsRayQueryParameters3D.create(world_point+Vector3(0,2000,0),world_point-Vector3(0,2000,0))
				var hit:Dictionary=space.intersect_ray(query)
				check(hit.is_empty()==not is_finite(expected),"Visible triangle footprint equals native collision")
				if not hit.is_empty() and is_finite(expected):
					var error:float=absf(hit.position.y-expected);maximum_error=maxf(maximum_error,error);hits+=1
					check(error<.03,"Junction collision matches independent triangle plane")
				else:misses+=1
		check(hits>=8 and misses>=8,"Actual shell and open surrounding ground exercised")
		Collision.release(node);check(body.collision_layer==0 and body.get_node("Structures").shape==null,"Released junction collision cleared")
		cases.append({"seed":seed_id,"position":point,"hits":hits,"misses":misses,"maximum_mesh_physics_error_m":maximum_error,"maximum_float32_query_xz_rounding_m":maximum_query_rounding});node.queue_free();await process_frame
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_junction_collision.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Three native Jolt staged/activated/released junction meshes; 81 vertical rays per seed versus independent all-triangle top envelopes. No whole-world traversal or production streaming claim."},"  "))
	print("JUNCTION_COLLISION ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
