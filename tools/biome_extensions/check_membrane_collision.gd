extends "res://tools/biome_extensions/check_all.gd"
const Junction=preload("res://tools/biome_extensions/membrane_junction_candidate.gd")
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
func ray_parameter(vertices:PackedVector3Array,from:Vector3,to:Vector3,front_faces_only:bool=false)->float:
	var direction:Vector3=to-from;var nearest:float=INF
	for i in range(0,vertices.size(),3):
		var a:Vector3=vertices[i];var ab:Vector3=vertices[i+1]-a;var ac:Vector3=vertices[i+2]-a;var cross_value:Vector3=direction.cross(ac);var determinant:float=ab.dot(cross_value)
		if absf(determinant)<.00000001:continue
		if front_faces_only and determinant>=0:continue # actual clockwise Godot front face
		var offset:Vector3=from-a;var u:float=offset.dot(cross_value)/determinant
		if u<-.000001 or u>1.000001:continue
		var q:Vector3=offset.cross(ab);var v:float=direction.dot(q)/determinant
		if v<-.000001 or u+v>1.000001:continue
		var t:float=ac.dot(q)/determinant
		if t>=0 and t<=1:nearest=minf(nearest,t)
	return nearest
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd","res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/junction_flutes_candidate.gd","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/membrane_junction_candidate.gd","res://tools/biome_extensions/check_membrane_collision.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var empty_probes:Array=[];var backface_controls:Array=[]
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
		var face_normal_hits:int=0;var maximum_face_ray_error:float=0
		for column:int in [4,8,12,16,20,24,28]:
			for row:int in [3,6,9]:
				var i:int=9168+(column*12+row)*12
				var face:Vector3=(g.vertices[i]+g.vertices[i+1]+g.vertices[i+2])/3
				# A folded face need not face the nominal wall-lateral direction.
				# Probe its actual geometric normal, not a near-tangent world ray.
				var ray_normal:Vector3=(g.vertices[i+2]-g.vertices[i]).cross(g.vertices[i+1]-g.vertices[i]).normalized()
				var from:Vector3=node.position+face+ray_normal*75;var to:Vector3=node.position+face-ray_normal*75
				var local_from:Vector3=from-node.position;var local_to:Vector3=to-node.position
				var two_sided_parameter:float=ray_parameter(g.vertices,local_from,local_to)
				var one_sided:bool=not body.get_node("Structures").shape.backface_collision
				var parameter:float=ray_parameter(g.vertices,local_from,local_to,one_sided);check(is_finite(parameter),"Independent face-normal triangle intersection exists")
				if not is_finite(parameter):
					var face_normal:Vector3=(g.vertices[i+2]-g.vertices[i]).cross(g.vertices[i+1]-g.vertices[i]).normalized()
					empty_probes.append({"seed":seed_id,"column":column,"row":row,"local_face":face,"face_normal":face_normal,"ray_dot_face_normal":ray_normal.dot(face_normal),"world_query_midpoint_error_m":((local_from+local_to)*.5).distance_to(face),"intended_unrounded_parameter":ray_parameter(g.vertices,face+ray_normal*75,face-ray_normal*75)})
				var query:=PhysicsRayQueryParameters3D.create(from,to);var hit:Dictionary=space.intersect_ray(query)
				check(not hit.is_empty(),"Native collision on actual folded membrane face")
				if not hit.is_empty() and is_finite(parameter):
					var expected:Vector3=node.position+local_from.lerp(local_to,parameter);var error:float=hit.position.distance_to(expected);maximum_face_ray_error=maxf(maximum_face_ray_error,error)
					check(error<.03,"Face-normal native membrane contact matches independent exact triangles");face_normal_hits+=1
					if is_finite(two_sided_parameter) and absf(two_sided_parameter-parameter)>.001:
						backface_controls.append({"seed":seed_id,"column":column,"row":row,"shape_backface_collision":not one_sided,"two_sided_parameter":two_sided_parameter,"actual_front_face_parameter":parameter,"actual_native_error_m":error,"incorrect_two_sided_error_m":hit.position.distance_to(node.position+local_from.lerp(local_to,two_sided_parameter))})
		check(face_normal_hits==21,"Every declared membrane face ray exercised")
		Collision.release(node);check(body.collision_layer==0 and body.get_node("Structures").shape==null,"Released junction collision cleared")
		cases.append({"seed":seed_id,"position":point,"hits":hits,"misses":misses,"maximum_mesh_physics_error_m":maximum_error,"maximum_float32_query_xz_rounding_m":maximum_query_rounding,"face_normal_hits":face_normal_hits,"maximum_face_ray_error_m":maximum_face_ray_error});node.queue_free();await process_frame
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	check(not backface_controls.is_empty(),"An incorrect two-sided reference is rejected by actual one-sided structure collision")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_membrane_collision.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"empty_probes":empty_probes,"backface_negative_controls":backface_controls,"source_sha256":hashes,"scope":"Private fluted junction/membrane native Jolt staged/activated/released meshes, 81 vertical rays and 21 face-normal membrane-face rays per seed against independent triangle envelopes/intersections with actual structure backface policy. A two-sided reference is retained as an explicit negative control. Not production integration, actual capsule routes or whole-world acceptance."},"  "))
	print("MEMBRANE_COLLISION ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
