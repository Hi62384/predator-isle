extends SceneTree
const Collision=preload("res://scripts/terrain_collision.gd")
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	var records:Array=[];var sources:Dictionary={}
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tools/badlands/artifacts/check_fan_geometry.json"));assert(fixture.passed)
	for path:String in fixture.source_sha256:assert(FileAccess.get_sha256(path)==fixture.source_sha256[path]);sources[path]=fixture.source_sha256[path]
	for item:Dictionary in fixture.cases:
		var seed_id:int=item.seed;var site:Dictionary=item.floor_cases[0]
		var b=preload("res://tools/badlands/check_fan_geometry.gd").builder(seed_id)
		var tree:Dictionary=b._badlands._tree(int(site.index),int(site.lane),1)
		var frame:PackedFloat64Array=preload("res://scripts/badlands_fan_geometry.gd").frame(tree)
		var origin:=Vector2(frame[0],frame[1]);var axis:=Vector2(frame[2],frame[3]);var normal:=Vector2(-axis.y,axis.x);var reach:float=minf(425,maxf(32,frame[4]*.85))
		var control:Array[Vector2]=[origin-axis*40,origin+axis*reach*.15,origin+axis*reach*.15+normal*120,origin+axis*reach*.5+normal*80,origin+axis*reach*.85]
		var route:Array[Vector3]=[];var minimum:Vector2=control[0];var maximum:Vector2=control[0];var dry:bool=true
		for segment in range(control.size()-1):
			var length:float=control[segment].distance_to(control[segment+1]);var steps:int=ceili(length/4)
			for j in range(steps):
				var p:Vector2=control[segment].lerp(control[segment+1],float(j)/steps);var h:float=b._get_height(p.x,p.y)
				route.append(Vector3(p.x,h+.95,p.y));minimum=minimum.min(p);maximum=maximum.max(p);dry=dry and h>b.get_water_surface_height(p.x,p.y)+.1
		var last:Vector2=control[-1];route.append(Vector3(last.x,b._get_height(last.x,last.y)+.95,last.y));minimum=minimum.min(last);maximum=maximum.max(last)
		for j in range(route.size()-2,-1,-1):route.append(route[j])
		var stage:=Node3D.new();root.add_child(stage);var cells:int=0;var exact_triangles:int=0
		for z in range(floori((minimum.y-16)/256),floori((maximum.y+16)/256)+1):
			for x in range(floori((minimum.x-16)/256),floori((maximum.x+16)/256)+1):
				var arrays:Array=b.build(Vector2i(x,z),128);var data:Dictionary=Collision.prepare(arrays,128,true,[],{})
				var mesh:=ArrayMesh.new();mesh.set_meta("collision_data",data)
				var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(x*256,0,z*256);stage.add_child(node);Collision.stage(node,256,128,true);Collision.activate(node,true)
				cells+=1
				if not data.ground_faces.is_empty():exact_triangles+=1
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6
		var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;shape.shape=capsule;walker.add_child(shape);stage.add_child(walker);walker.position=route[0];walker.route=route
		await physics_frame;await physics_frame;walker.set_physics_process(true)
		var started:int=Time.get_ticks_msec()
		for unused in range(100000):
			await physics_frame
			if walker.failed or walker.finished or Time.get_ticks_msec()-started>180000:break
		walker.set_physics_process(false)
		var completed:bool=dry and walker.finished and not walker.failed and walker.waypoint==route.size() and walker.position.distance_to(route[0])<1.5 and walker.max_unsupported_drop<.75
		if not completed:failures.append({"seed":seed_id,"finished":walker.finished,"failed":walker.failed,"waypoint":walker.waypoint,"max_drop":walker.max_unsupported_drop,"dry":dry})
		records.append({"seed":seed_id,"index":site.index,"lane":site.lane,"completed":completed,"dry":dry,"route_points":route.size(),"movement_frames":walker.frames,"walked_metres":walker.horizontal_distance_m,"max_unsupported_drop":walker.max_unsupported_drop,"near_cells":cells,"exact_triangle_cells":exact_triangles,"position":str(walker.position),"start":str(route[0])})
		print("FAN_APRON_COLLISION ",records[-1]);stage.queue_free();await process_frame;await process_frame
	for path:String in ["res://tools/badlands/check_fan_apron_collision.gd","res://tools/biome_extensions/route_probe.gd","res://scripts/terrain_collision.gd","res://tools/badlands/artifacts/check_fan_geometry.json"]:sources[path]=FileAccess.get_sha256(path)
	for path:String in sources:assert(FileAccess.get_sha256(path)==sources[path])
	FileAccess.open("res://tools/badlands/artifacts/check_fan_apron_collision.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records,"source_sha256":sources,"scope":"Three fixed on-land fan-province root frames. No-jump1.8m/.4m capsule crosses each apron and feeder throat then returns; original5m/s,gravity9.8,snap.6,floor45deg and180s budget. Actual production128-resolution mesh/collision preparation, not hand-built flat geometry. Static model only, not streamed or uninterrupted performance; separate existing streamed wash is a different route."},"  "))
	quit(0 if failures.is_empty() else 1)
