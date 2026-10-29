extends "res://tools/biome_extensions/check_all.gd"
func mesh_for(arrays:Array)->ArrayMesh:
	var mesh:=ArrayMesh.new();var flags:int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT if arrays[Mesh.ARRAY_CUSTOM0].size()==arrays[Mesh.ARRAY_VERTEX].size()*4 else Mesh.ARRAY_CUSTOM_RGB_FLOAT)<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for i in range(1,4):
		if arrays[Mesh.ARRAY_CUSTOM0+i]!=null:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT << [Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][i-1]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);return mesh
func world_vertices(arrays:Array,offset:Vector3)->Array[String]:
	var result:Array[String]=[]
	for surface in arrays:
		if surface==null:continue
		for v:Vector3 in surface[Mesh.ARRAY_VERTEX]:
			var p:Vector3=v+offset;result.append("%d,%d,%d"%[roundi(p.x*100),roundi(p.y*100),roundi(p.z*100)])
	return result
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://scripts/alien_carapace_geometry.gd","res://scripts/biome_extension_settings.gd"]:hashes[source]=FileAccess.get_sha256(source)
	hashes["res://scripts/alien_junction_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_junction_geometry.gd")
	for path:String in ["res://tools/biome_extensions/check_integration.gd","res://tools/biome_extensions/check_all.gd","res://scripts/biome_extension_structures.gd","res://scripts/terrain_collision.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/alien_infected_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for family_id in range(8):
		var b=make_builder(family_id);var arrays:Array=b.build(Vector2i(20,20),32);var bytes:PackedByteArray=b.built_extension_data
		if not bytes.is_empty():
			check(bytes.size()==33*33*32,"Atlas bounded dimensions")
			var actual_mask:int=0
			for family in range(8):
				for z in range(33):
					for x in range(33):
						if bytes[(z*33*8+family*33+x)*4]>0:actual_mask|=1<<family
			check(actual_mask==b.built_extension_mask,"Worker-produced sparse material mask")
			for i in range(0,bytes.size(),4):check(bytes[i+1]<=bytes[i] and bytes[i+2]<=bytes[i] and bytes[i+3]<=bytes[i],"Premultiplied numeric controls")
		var node:=MeshInstance3D.new();node.mesh=mesh_for(arrays);node.position=Vector3(5120,0,5120);root.add_child(node)
		var prepared:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,32,true,[],{})
		check(prepared.heights.size()==33*33,"Worker collision height dimensions")
		for i in range(33*33):check(prepared.heights[i]==arrays[Mesh.ARRAY_VERTEX][i].y,"Worker collision matches source height")
		node.mesh.set_meta("collision_data",prepared)
		preload("res://scripts/terrain_collision.gd").stage(node,256,32,true)
		var body:StaticBody3D=node.get_node("NearTerrainCollision");check(body.collision_layer==0,"Hidden staged collision inactive")
		preload("res://scripts/terrain_collision.gd").activate(node,true)
		for frame in range(3):await physics_frame
		var space:PhysicsDirectSpaceState3D=node.get_world_3d().direct_space_state
		for i in [0,12,32]:
			var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][i*33+i]+node.position;var query:=PhysicsRayQueryParameters3D.create(vertex+Vector3(0,2000,0),vertex-Vector3(0,2000,0));var hit:Dictionary=space.intersect_ray(query)
			check(not hit.is_empty(),"Heightfield ray hit "+str(family_id))
			if not hit.is_empty():check(absf(hit.position.y-vertex.y)<.05,"Heightfield matches visible vertex "+str(family_id))
		preload("res://scripts/terrain_collision.gd").release(node);check(body.collision_layer==0 and body.get_node("Heightfield").shape==null,"Released collision cleared");node.queue_free();await process_frame
	for family_id in [5,6,7]:
		var b=make_builder(family_id);b.chunk_size=8192;var parent:Array=build_structures(b,Vector2i.ZERO);var expected:Array[String]=world_vertices(parent,Vector3.ZERO);var actual:Array[String]=[]
		b.chunk_size=4096
		for z in range(2):
			for x in range(2):actual.append_array(world_vertices(build_structures(b,Vector2i(x,z)),Vector3(x*4096,0,z*4096)))
		expected.sort();actual.sort();check(not expected.is_empty(),"Actual major structure geometry "+str(family_id));check(expected==actual,"Exactly one stable parent/child owner "+str(family_id))
		for surface in parent:
			if surface==null:continue
			var vs:PackedVector3Array=surface[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=surface[Mesh.ARRAY_NORMAL]
			for i in range(0,vs.size(),3):
				var outward:Vector3=(vs[i+2]-vs[i]).cross(vs[i+1]-vs[i]).normalized()
				for j in range(3):
					check(ns[i+j].is_finite() and absf(ns[i+j].length()-1)<.001,"Finite unit structure normal")
					# Crystals retain hard facets; weathered mounds and attached
					# conduits have smooth normals, always outside the actual face.
					check(outward.dot(ns[i+j])>(.99 if family_id==5 else (.149 if family_id==7 else 0.0)),"Clockwise outward normals")
	var b=make_builder(0);b.settings.quarry_coverage=0;b.settings.grass_coverage=100;b.settings.alien_infected.overlay_strength=0;b._configure_noise();var p:=Vector2(9000,12000);var h:float=b._get_height(p.x,p.y)
	b.settings.alien_infected.overlay_strength=.8;b._configure_noise();var node:Vector2=b._extras[7].hive_node(Vector2i(2,2));var modified:float=b._get_height(node.x,node.y)
	check(b._last_extras[7].x>0,"Partial infection overlay without full-biome coverage");check(is_finite(modified),"Finite overlay geometry")
	b.settings.alien_infected.overlay_strength=0;b._configure_noise();check(h==b._get_height(p.x,p.y),"Overlay zero restores underlying geography exactly")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable integration source "+path)
	var output:Dictionary={"checks":checks,"failures":failures,"source_sha256":hashes,"collision":"Native PhysicsDirectSpaceState3D downward rays at canonical mesh vertices","ownership":"Exact world-space major geometry multiset, parent versus four children"}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_integration.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"));print("EXTENSION_INTEGRATION ",checks," checks ",failures);quit(0 if failures.is_empty() else 1)
