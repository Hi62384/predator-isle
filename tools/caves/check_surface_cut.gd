extends "res://tools/biome_extensions/check_all.gd"
const Cut=preload("res://scripts/caves/surface_cut.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func area(faces:PackedVector3Array)->float:
	var total:float=0
	for i in range(0,faces.size(),3):total+=absf((faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).y)*.5
	return total
func run()->void:
	var guards:Dictionary={}
	for path:String in ["res://scripts/caves/surface_cut.gd","res://scripts/caves/cave_settings.gd","res://config/caves/cave_settings.tres","res://tools/caves/check_surface_cut.gd"]:guards[path]=FileAccess.get_sha256(path)
	var config=load("res://config/caves/cave_settings.tres");check(config is Config and config.enabled and config.validation_errors().is_empty(),"Saved game enables the validated shared cave runtime")
	var invalid=Config.new();invalid.maximum_depth_metres=10000;check(not invalid.validation_errors().is_empty(),"Unbounded local underground depth rejected")
	var columns:Dictionary={Vector2i(-1,-1):true,Vector2i.ZERO:true};var description:Dictionary=Cut.mask(columns,Vector2.ZERO,32);check(description.side==32 and description.r8_bytes.size()==1024 and description.columns==columns,"Exact bounded negative/positive replacement-column mask")
	for z in range(32):
		for x in range(32):check((description.r8_bytes[z*32+x]>0)==columns.has(description.origin_cell+Vector2i(x,z)),"R8mask and exact CPU column identity agree at every texel")
	check(Cut.mask(columns,Vector2.INF).is_empty() and Cut.mask(columns,Vector2.ZERO,2048).is_empty(),"Invalid/unbounded visual mask fails closed")
	var faces:=PackedVector3Array()
	for z in range(4):
		for x in range(4):
			var points:=PackedVector3Array()
			for offset:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var q:Vector2=(Vector2(x,z)+offset)*40;points.append(Vector3(q.x,8+(q.x-80)*.01+(q.y-80)*.02,q.y))
			faces.append_array(PackedVector3Array([points[0],points[1],points[2],points[1],points[3],points[2]]))
	var origin:=Vector3(-80,0,-80);var clipped:Dictionary=Cut.ground(faces,origin,columns);check(clipped.valid and clipped.split_source_triangles>0,"Custom40m grid actually clips unaligned64m columns,not whole-triangle erasure")
	check(absf(area(clipped.faces)-(25600-8192))<.02,"Exact outside-ground area retained;two complete64m holes removed")
	for point:Vector3 in clipped.faces:check(absf(point.y-(8+(point.x-80)*.01+(point.z-80)*.02))<.00001,"Every new intersection stays on the ORIGINAL visible terrain triangle plane")
	var off:Dictionary=Cut.ground(faces,origin,{});check(off.valid and off.faces.to_byte_array()==faces.to_byte_array(),"Zero-cut mode preserves full original native faces byte-for-byte")
	var body:=StaticBody3D.new();body.position=origin;var child:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(clipped.faces);child.shape=shape;body.add_child(child);root.add_child(body)
	for frame in range(3):await physics_frame
	var maximum_error:float=0;var holes:int=0;var solid:int=0
	for z in range(10):
		for x in range(10):
			var q:=Vector2(-79.37+x*16.71,-78.91+z*16.53);var expected:bool=not columns.has(Vector2i(floori(q.x/64),floori(q.y/64)));var state:PhysicsDirectSpaceState3D=body.get_world_3d().direct_space_state;var hit:Dictionary=state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x,30,q.y),Vector3(q.x,-10,q.y)));check(not hit.is_empty() if expected else hit.is_empty(),"Native ground ray and exact replacement mask agree at every off-grid signed point")
			if expected:
				solid+=1
				if not hit.is_empty():maximum_error=maxf(maximum_error,absf(hit.position.y-(8+q.x*.01+q.y*.02)))
			else:holes+=1
	check(holes>20 and solid>20 and maximum_error<.03,"Positive native hole/solid controls and unchanged30mm floor bound")
	body.queue_free();await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable surface cut source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_surface_cut.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"original_triangles":faces.size()/3,"clipped_triangles":clipped.faces.size()/3,"native_hole_rays":holes,"native_solid_rays":solid,"maximum_native_floor_error_m":maximum_error,"production_runtime_enabled":false,"scope":"Surface/collision cut primitive only:exact shared64m column identity,R8mask bounds,signed unaligned40m triangle clipping,original planar heights and100native rays. Config remains disabled;not actual ChunkTerrain commit/streaming/live cave acceptance."},"  "));print("SURFACE_CUT ",checks," native_error=",maximum_error," failures=",failures);quit(0 if failures.is_empty() else 1)
