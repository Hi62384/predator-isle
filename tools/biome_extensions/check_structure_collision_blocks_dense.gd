extends "res://tools/biome_extensions/check_structure_collision_blocks_real.gd"
func original_face(selected_face:int,ranges:PackedInt32Array)->int:
	var cursor:int=0
	for i in range(0,ranges.size(),2):
		var count:int=(ranges[i+1]-ranges[i])/3
		if selected_face<cursor+count:return ranges[i]/3+selected_face-cursor
		cursor+=count
	return -1
func face_normal(faces:PackedVector3Array,index:int)->Vector3:
	if index<0 or index*3+2>=faces.size():return Vector3.ZERO
	return (faces[index*3+2]-faces[index*3]).cross(faces[index*3+1]-faces[index*3]).normalized()
func detailed_native(faces:PackedVector3Array,selected:Dictionary,point:Vector3)->Dictionary:
	var bodies:Array=[];var setup:Array=[]
	for mode in range(2):
		var begin:int=Time.get_ticks_usec();var body:=StaticBody3D.new();body.collision_layer=1<<mode;body.collision_mask=0;var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces if mode==0 else selected.faces);var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);root.add_child(body);bodies.append(body)
		for frame in range(3):await physics_frame
		setup.append((Time.get_ticks_usec()-begin)/1000.0)
	var space:PhysicsDirectSpaceState3D=bodies[0].get_world_3d().direct_space_state;var cell:Vector3=Vector3(Blocks.cell(point))*256;var low:Vector3=cell-Vector3.ONE*596;var high:Vector3=cell+Vector3.ONE*852
	var probes:int=0;var hits:int=0;var max_gap:float=0;var max_normal_difference:float=0;var normal_records:Array=[];var same_source_faces:int=0;var old_reference_error:float=0;var new_reference_error:float=0;var returned_keys:Array=[]
	var stride:int=maxi(1,selected.faces.size()/3/192)
	for triangle in range(0,selected.faces.size()/3,stride):
		var a:Vector3=selected.faces[triangle*3];var b:Vector3=selected.faces[triangle*3+1];var c:Vector3=selected.faces[triangle*3+2];var center:Vector3=(a+b+c)/3;var normal:Vector3=(c-a).cross(b-a).normalized()
		if normal.length_squared()<.5 or center.x<low.x or center.x>high.x or center.y<low.y or center.y>high.y or center.z<low.z or center.z>high.z:continue
		var old:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*2,center-normal*2,1));var current:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*2,center-normal*2,2));probes+=1;check(old.is_empty()==current.is_empty(),"Dense full/subset native hit presence identical")
		if old.is_empty() or current.is_empty():continue
		hits+=1;var gap:float=old.position.distance_to(current.position);max_gap=maxf(max_gap,gap);check(gap<=.03,"Dense native full/subset contact within original30mm bound")
		if returned_keys.is_empty():returned_keys=old.keys()
		var full_face:int=old.get("face_index",-1);var subset_face:int=original_face(current.get("face_index",-1),selected.ranges) if current.get("face_index",-1)>=0 else -1
		var difference:float=old.normal.distance_to(current.normal);max_normal_difference=maxf(max_normal_difference,difference)
		var old_error:float=old.normal.distance_to(face_normal(faces,full_face));var new_error:float=current.normal.distance_to(face_normal(faces,subset_face))
		if full_face>=0 and full_face==subset_face:same_source_faces+=1;old_reference_error=maxf(old_reference_error,old_error);new_reference_error=maxf(new_reference_error,new_error)
		if difference>.02:normal_records.append({"source_triangle_target":original_face(triangle,selected.ranges),"full_face":full_face,"subset_original_face":subset_face,"same_original_face":full_face>=0 and full_face==subset_face,"native_normal_delta":difference,"old_error_to_own_original_face_normal":old_error,"new_error_to_own_original_face_normal":new_error,"old_position":str(old.position),"new_position":str(current.position),"contact_delta_m":gap})
	check(hits>0,"Actual dense nearby contacts exercised")
	for body:StaticBody3D in bodies:body.queue_free()
	for frame in range(3):await physics_frame
	return {"ray_pairs":probes,"positive_pairs":hits,"maximum_contact_error_m":max_gap,"maximum_native_normal_difference":max_normal_difference,"same_original_face_pairs":same_source_faces,"maximum_old_normal_error_on_same_faces":old_reference_error,"maximum_new_normal_error_on_same_faces":new_reference_error,"normal_difference_diagnostics":normal_records,"native_returned_keys":returned_keys,"single_order_setup_with_three_fixed_physics_frames_ms":setup,"isolated_timing":false}
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://tools/biome_extensions/check_all.gd","res://tools/biome_extensions/structure_collision_blocks_candidate.gd","res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd","res://tools/biome_extensions/check_structure_collision_blocks_real.gd","res://tools/biome_extensions/check_structure_collision_blocks_dense.gd","res://tools/biome_extensions/profile_far_conduit_lod.gd"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(7,92881);b.settings.alien_infected.feature_scale=.2;b._configure_noise();b.chunk_size=16384;var coordinate:=Vector2i(-5,-7);var root_origin:=Vector3(-81920,0,-114688);var center:=Vector2(-73728,-106496);var field=b._extras[7];var selected_site:Dictionary={};var nearest:float=INF
	for z in range(-140,-120):
		for x in range(-100,-80):
			var cell:=Vector2i(x,z);var p:Vector2=field.hive_node(cell);var descriptor:Dictionary=field.descriptor(cell,819.2)
			if descriptor.chance>field.settings.structure_density or b._island_mask(p.x,p.y)<.1:continue
			var h:float=b._get_height(p.x,p.y)
			if h<=maxf(b.water_level,b.get_water_surface_height(p.x,p.y))+4:continue
			var distance:float=p.distance_to(center)
			if distance<nearest:nearest=distance;selected_site={"cell":str(cell),"position":p,"height":h,"distance_to_parent_center_m":distance}
	check(not selected_site.is_empty(),"Nearest actual dry admitted root fixed before collider benchmark")
	var mesher=preload("res://scripts/terrain_feature_meshes.gd").new();mesher.builder=b;var begin:int=Time.get_ticks_usec();var structures:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate,Structures.support_grids(),mesher.portal_sites);var structure_seconds:float=(Time.get_ticks_usec()-begin)/1000000.0
	var faces:PackedVector3Array=structures[2][Mesh.ARRAY_VERTEX];var original:PackedByteArray=faces.to_byte_array();begin=Time.get_ticks_usec();var bounds:PackedVector3Array=Blocks.build(faces);var index_ms:float=(Time.get_ticks_usec()-begin)/1000.0
	var p:Vector2=selected_site.position;var point:Vector3=Vector3(p.x,selected_site.height+1,p.y)-root_origin;begin=Time.get_ticks_usec();var selected:Dictionary=Blocks.select(faces,bounds,point);var query_ms:float=(Time.get_ticks_usec()-begin)/1000.0;var oracle:Dictionary=verify_query(faces,bounds,point);check(selected.faces.size()>0 and selected.faces.size()<faces.size(),"Dense original workload has genuine retained nearby and omitted distant faces")
	var native:Dictionary=await detailed_native(faces,selected,point);check(original==faces.to_byte_array(),"Dense source bytes unchanged")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual dense collision source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_structure_collision_blocks_dense.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"seed":92881,"scale":.2,"tile":str(coordinate),"root_origin":str(root_origin),"admitted_query_site":selected_site,"structure_seconds":structure_seconds,"index_ms":index_ms,"selection_ms":query_ms,"complete_triangles":faces.size()/3,"index_bytes":bounds.size()*12,"oracle":oracle,"native":native,"production_registration":false,"scope":"PRIVATE ADDITIONAL original dense16km seed92881 scale.2 tile(-5,-7),not a replacement for the three default-scale cases or a new world/seed. Nearest actual dry admitted network root fixed before performance;actual current production LOD geometry and protected-cell subset. Independent every-triangle coverage,ordered faces,source integrity and full/subset native Jolt rays under unchanged30mm position bound. Native face IDs/original geometric normals diagnose any normal changes,not assumed equivalent. Single-order shape setup and index costs are observations,not a repeatable/end-to-end improvement. Physics accelerated60Hz;no production integration,streaming/capsule or whole-world claim."},"  "))
	print("DENSE_COLLISION_BLOCKS ",faces.size()/3," triangles -> ",selected.faces.size()/3," selected / index_ms=",index_ms," native=",native," failures=",failures);quit(0 if failures.is_empty() else 1)
