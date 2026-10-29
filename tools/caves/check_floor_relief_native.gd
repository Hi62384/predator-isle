extends "res://tools/caves/check_floor_relief_candidate.gd"
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_floor_relief_candidate.gd","res://tools/caves/floor_relief_field_candidate.gd","res://tools/caves/floor_relief_candidate.gd","res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var region:Dictionary=crystal_fixture();region.nodes[0].chamber_height=36.0;region.nodes.append({"id":"B","point":Vector3(64,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.nodes.append({"id":"C","point":Vector3(96,20,32),"level":0,"chamber_radius":26.0,"chamber_height":36.0});region.cave_biome_regions.candidates[0].distances["C"]=10000.0
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var field=Candidate.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Identical controlled candidate volume compiles")
	var world:=Node3D.new();root.add_child(world);var shared:Array=[{},{}];var vertices:int=0
	for index in range(-1,2):
		var key:=Vector3i(index,0,0);var arrays:Array=Mesher.new().build(field,key,2);check(not arrays.is_empty(),"Positive real meshed relief cell")
		var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate();vertices+=faces.size()
		for i in range(faces.size()):
			faces[i]+=Vector3(key)*64
			if index>=0 and faces[i].x==64:shared[index][str(faces[i])]=true
		var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1;body.collision_mask=0;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);child.shape=shape;body.add_child(child);world.add_child(body)
	check(not shared[0].is_empty() and shared[0]==shared[1],"Identical entire shared64m face vertex set from independent cell builds")
	await physics_frame;await physics_frame
	var route:Array[Vector3]=[];var native_heights:Array=[]
	for x in range(56,73,2):
		var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,24,46),Vector3(x,16,46),1));check(not hit.is_empty(),"Actual native cross-cell ridge floor present")
		if hit.is_empty():continue
		native_heights.append(hit.position.y);check(hit.normal.y>=cos(PI/4) and absf(hit.position.y-floor_at(field,x,46))<.12,"Native2m lattice ridge agrees with scalar and ordinary walk slope")
		route.append(hit.position+Vector3.UP*.95)
	for i in range(route.size()-2,-1,-1):route.append(route[i])
	await walk(route,"Actual rocky raised room floor across64m cell seam and exact no-jump return")
	await walk([Vector3(-12,20.95,32),Vector3(96,20.95,32),Vector3(-12,20.95,32)],"Original protected full-width passage unchanged by room floor ridges")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private native relief source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_floor_relief_native.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"native_floor_heights_m":native_heights,"shared_face_vertices":shared[0].size(),"vertices":vertices,"walks":walks,"scope":"Private same-field controlled raised rock-floor ridges,actual production2m lattice/native collision,cross-cell seam and ordinary1.8m/.4m no-jump5mps two-way walks. No production adoption,normal-world frequency or FPS claim."},"  "));print("FLOOR_RELIEF_NATIVE ",checks," walks=",walks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
