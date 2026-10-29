extends "res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd"
const ADMISSION="res://tools/biome_extensions/artifacts/revisions/experiment_grounded_conduit_adoption_01a831638aa7/sources/tools/biome_extensions/artifacts/check_junction_admission.json.txt"
func native_pair(faces:PackedVector3Array,selected:PackedVector3Array,point:Vector3)->Dictionary:
	var bodies:Array=[];var creation:Array=[]
	for mode:int in range(2):
		var begin:int=Time.get_ticks_usec();var body:=StaticBody3D.new();body.collision_layer=1<<mode;body.collision_mask=0;var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces if mode==0 else selected);var child:=CollisionShape3D.new();child.shape=shape;body.add_child(child);root.add_child(body);bodies.append(body)
		for frame in range(3):await physics_frame
		creation.append((Time.get_ticks_usec()-begin)/1000.0)
	var cell:Vector3=Vector3(Blocks.cell(point))*256;var low:Vector3=cell-Vector3.ONE*596;var high:Vector3=cell+Vector3.ONE*852;var count:int=0;var hits:int=0;var error:float=0;var normal_error:float=0
	var space:PhysicsDirectSpaceState3D=bodies[0].get_world_3d().direct_space_state;var stride:int=maxi(1,selected.size()/3/160)
	for triangle in range(0,selected.size()/3,stride):
		var a:Vector3=selected[triangle*3];var b:Vector3=selected[triangle*3+1];var c:Vector3=selected[triangle*3+2];var center:Vector3=(a+b+c)/3;var normal:Vector3=(c-a).cross(b-a).normalized()
		if normal.length_squared()<.5 or center.x<low.x or center.x>high.x or center.y<low.y or center.y>high.y or center.z<low.z or center.z>high.z:continue
		var first:=PhysicsRayQueryParameters3D.create(center+normal*2,center-normal*2,1);var second:=PhysicsRayQueryParameters3D.create(center+normal*2,center-normal*2,2);var old:Dictionary=space.intersect_ray(first);var current:Dictionary=space.intersect_ray(second);count+=1
		check(old.is_empty()==current.is_empty(),"Native Jolt full/subset hit presence identical within protected volume")
		if old.is_empty() or current.is_empty():continue
		hits+=1;var gap:float=old.position.distance_to(current.position);error=maxf(error,gap);normal_error=maxf(normal_error,old.normal.distance_to(current.normal));check(gap<=.03,"Native original/subset contacts agree within unchanged30mm bound")
	check(count>0 and hits>0,"Actual nearby structure triangles exercised by native collision")
	for body:StaticBody3D in bodies:body.queue_free()
	for frame in range(3):await physics_frame
	return {"ray_pairs":count,"positive_pairs":hits,"maximum_contact_position_error_m":error,"maximum_native_normal_delta":normal_error,"single_order_full_then_subset_setup_including_three_physics_frames_ms":creation,"isolated_timing":false}
func run()->void:
	var guards:Dictionary={ADMISSION:FileAccess.get_sha256(ADMISSION)};var admission=JSON.parse_string(FileAccess.get_file_as_string(ADMISSION));assert(admission.passed and admission.cases.size()==3)
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/check_all.gd","res://tools/biome_extensions/structure_collision_blocks_candidate.gd","res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd","res://tools/biome_extensions/check_structure_collision_blocks_real.gd"]:guards[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var fixtures:Array=admission.cases.duplicate(true);var dense:Dictionary=admission.cases[0].duplicate(true);dense["dense_parent"]=true;fixtures.append(dense)
	for item:Dictionary in fixtures:
		var b=make_builder(7,int(item.seed));var p:=Vector2(item.position[0],item.position[1]);var span:float=16384 if item.get("dense_parent",false) else 4096;b.chunk_size=span;var coordinate:=Vector2i(floori(p.x/span),floori(p.y/span));var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();mesher.builder=b
		var structures:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var faces:PackedVector3Array=structures[2][Mesh.ARRAY_VERTEX];var original:PackedByteArray=faces.to_byte_array();var begin:int=Time.get_ticks_usec();var bounds:PackedVector3Array=Blocks.build(faces);var build_ms:float=(Time.get_ticks_usec()-begin)/1000.0
		var root_origin:=Vector3(coordinate.x*span,0,coordinate.y*span);var queries:Array=[];var selection_ms:Array=[];var primary:Dictionary={};var local_primary:=Vector3.ZERO
		for offset:Vector2 in [Vector2.ZERO,Vector2(256,0),Vector2(-256,.01),Vector2(512,128)]:
			var q:Vector2=p+offset;var point:Vector3=Vector3(q.x,b._get_height(q.x,q.y)+1,q.y)-root_origin;begin=Time.get_ticks_usec();var selected:Dictionary=Blocks.select(faces,bounds,point);selection_ms.append((Time.get_ticks_usec()-begin)/1000.0);queries.append(verify_query(faces,bounds,point))
			if primary.is_empty():primary=selected;local_primary=point
		check(faces.to_byte_array()==original,"Real emitted complete source faces unchanged by all queries")
		check(primary.faces.size()<faces.size(),"Real root loses unnecessary distant collider faces,not a synthetic-only effect")
		var native:Dictionary=await native_pair(faces,primary.faces,local_primary)
		var record:Dictionary={"seed":item.seed,"span_m":span,"root":str(coordinate),"dense_parent":item.get("dense_parent",false),"complete_triangles":faces.size()/3,"index_bytes":bounds.size()*12,"index_build_ms":build_ms,"selection_ms":selection_ms,"queries":queries,"native":native};cases.append(record);print("REAL_COLLISION_BLOCKS ",item.seed," span=",span," triangles=",faces.size()/3," selected=",primary.faces.size()/3," index_ms=",build_ms)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable real private collision source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_structure_collision_blocks_real.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"production_registration":false,"scope":"PRIVATE index over complete ACTUAL current production LOD structures:three original default-rarity native junction roots/three seeds at4096m plus first same-root16384m parent. Four protected-cell query positions each;independent per-triangle all-nearby coverage and exact ordered-subsequence checks. Actual full/subset Jolt concave shapes at original local positions,paired nearby rays with unchanged30mm bound.24bytes/64triangles index cost/build/query time and single-order shape setup reported,not a repeated isolated benchmark. No production code,geometry,capsule,physics settings or scheduling change. Streaming/lifecycle/real motion and demonstrated end-to-end benefit still required before adoption."},"  "))
	print("REAL_COLLISION_BLOCK_DONE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
