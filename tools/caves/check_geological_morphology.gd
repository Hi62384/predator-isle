extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/field.gd")
const Mesher=preload("res://scripts/caves/mesher.gd")
const PrivateField=preload("res://tools/caves/cave_field_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/network.gd","res://scripts/caves/cave_settings.gd","res://scripts/caves/workload.gd","res://tools/caves/cave_field_candidate.gd","res://tools/caves/check_geological_morphology.gd","res://tools/biome_extensions/route_probe.gd"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 150
	var region:Dictionary={"valid":true,"nodes":[{"point":Vector3(32,20,32),"level":0,"chamber_radius":24.0,"chamber_height":18.0}],"edges":[{"points":PackedVector3Array([Vector3(-16,20,32),Vector3(80,20,32)]),"half_width":4.0,"headroom":8.0,"entrance":false}]};var original=PrivateField.new();check(original.compile([region],height),"Frozen complete original shape control");var baseline:Array=Mesher.new().build(original,Vector3i.ZERO,2);var records:Array=[];var hashes:Dictionary={}
	for style in range(6):
		var data:Dictionary=region.duplicate(true);data["cross_section_style"]=style;var field=Field.new();check(field.compile([data],height),"Actual geological field compilation "+str(style));var arrays:Array=Mesher.new().build(field,Vector3i.ZERO,2);check(not arrays.is_empty(),"Positive actual geological geometry "+str(style))
		if style==0:check(var_to_bytes(arrays)==var_to_bytes(baseline),"Style0 retains complete original mesher output,not only sampled heights")
		else:check(var_to_bytes(arrays)!=var_to_bytes(baseline),"Geological profiles change real extracted geometry,not just material tint")
		for x in range(8,57,4):
			for y:float in [.2,1,1.8,3,5.5]:
				for z:float in [-2.2,0,2.2]:check(field.sample(Vector3(x,20+y,32+z))<0,"Original protected broad-floor capsule corridor remains genuine air")
		var body:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(arrays[Mesh.ARRAY_VERTEX]);collision.shape=shape;body.add_child(collision);root.add_child(body)
		for frame in range(3):await physics_frame
		var error:float=0
		for x in range(8,57,2):
			var hit:Dictionary=body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,23,32),Vector3(x,18,32)));check(not hit.is_empty(),"Genuine native protected floor for every cross-section style")
			if not hit.is_empty():error=maxf(error,absf(hit.position.y-20))
		check(error<.03,"Unchanged30mm native floor bound across real profile variation")
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6;var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var child:=CollisionShape3D.new();child.shape=capsule;walker.add_child(child);root.add_child(walker);walker.set_physics_process(false);walker.position=Vector3(8,20.95,32);walker.route.append_array([Vector3(56,20.95,32),Vector3(8,20.95,32)])
		for frame in range(3000):
			walker._physics_process(1.0/60);await physics_frame
			if walker.failed or walker.finished:break
		check(walker.finished and not walker.failed and walker.max_unsupported_drop<.75 and walker.position.distance_to(Vector3(8,20.95,32))<1.5,"Unchanged ordinary capsule makes a complete two-way return through each actual geological profile")
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(arrays));var digest:String=hash.finish().hex_encode();check(not hashes.has(digest),"Every configured cross-section has distinct complete mesh arrays");hashes[digest]=true;records.append({"style":style,"mesh_sha256":digest,"triangles":arrays[Mesh.ARRAY_VERTEX].size()/3,"maximum_native_floor_error_m":error,"walk_metres":walker.horizontal_distance_m,"maximum_unsupported_drop_m":walker.max_unsupported_drop});walker.queue_free();body.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable geological cross-section source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_geological_morphology.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"scope":"Six real production implicit-field cross-section controls,complete extracted arrays distinct;original style0 complete arrays exact against frozen private field. Unchanged protected air/native floors and six ordinary-capsule96mreturns. Synthetic closed-room/corridor controls,not six actual-world regional walks,full topology or artistic acceptance."},"  "));print("CAVE_GEOLOGICAL_MORPHOLOGY ",checks," cases=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
