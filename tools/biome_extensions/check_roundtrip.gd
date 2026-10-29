extends "res://tools/biome_extensions/check_integration.gd"
const Features=preload("res://scripts/terrain_feature_meshes.gd")
const Collision=preload("res://scripts/terrain_collision.gd")
func run()->void:
	var cases:Array=[]
	var seed_id:int=73921
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):seed_id=int(arg.trim_prefix("seed="))
	for family_id:int in [1,2,6,7]:
		var b=make_builder(family_id,seed_id);b.settings.get(TerrainSettings.EXTENSION_KEYS[family_id]).cave_frequency=.5;b.chunk_size=8192;b._configure_noise()
		var found:Dictionary={}
		for i in range(256):
			var feature:Dictionary=Features.new().build(b,Vector2i(i-24,i%7-3))
			if not feature.cavities.is_empty():found=feature;break
		check(not found.is_empty(),"Dry round-trip fixture found")
		if found.is_empty():continue
		var site:Dictionary=found.cavities[0];var p:Vector2=site.position
		b.chunk_size=256
		var owner:=Vector2i(floori(p.x/256),floori(p.y/256));var nodes:Array[MeshInstance3D]=[]
		# Include the entire surface approach and neighbouring portal leaves, not just its owner.
		for dz in range(-1,2):
			for dx in range(-1,3):
				var coordinate:Vector2i=owner+Vector2i(dx,dz);var a:Array=b.build(coordinate,64)
				var feature:Dictionary=Features.new().build(b,coordinate)
				var node:=MeshInstance3D.new();node.mesh=mesh_for(a);node.position=Vector3(coordinate.x*256,0,coordinate.y*256);root.add_child(node)
				node.mesh.set_meta("collision_data",Collision.prepare(a,64,true,[],feature))
				Collision.stage(node,256,64,true,true);Collision.activate(node,true);nodes.append(node)
		for i in range(3):await physics_frame
		var entry:float=96*(1+.1*sin(site.phase)-.06*sin(site.phase))
		var top_h:float=b._get_height(p.x+entry,p.y)+.15
		var turns:int=maxi(1,ceili((site.top-site.floor)/(TAU*70*.12)))
		var route:Array[Vector3]=[]
		var start:=Vector3(p.x+entry+20,b._get_height(p.x+entry+20,p.y)+.95,p.y)
		route.append(Vector3(p.x+entry+2,top_h+.9,p.y))
		route.append(Vector3(p.x+70,top_h+.9,p.y))
		for i in range(1,turns*96+1):
			var t:float=float(i)/(turns*96);var angle:float=t*turns*TAU
			route.append(Vector3(p.x+cos(angle)*70,lerpf(top_h,site.floor,t)+.9,p.y+sin(angle)*70))
		route.append(Vector3(p.x+112,site.floor+.9,p.y));route.append(Vector3(p.x+230,site.floor+.9,p.y))
		var outward_count:int=route.size()
		for i in range(outward_count-2,-1,-1):route.append(route[i])
		route.append(start)
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.floor_snap_length=.6
		var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8
		var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.position=start;walker.route=route
		for frame in range(100000):
			await physics_frame
			if walker.failed or walker.finished:break
		walker.set_physics_process(false)
		var record:Dictionary={"family":family_id,"site":site,"finished":walker.finished,"failed":walker.failed,"waypoint":walker.waypoint,"waypoints":route.size(),"frames":walker.frames,"position":walker.position,"target":route[mini(walker.waypoint,route.size()-1)],"max_airborne_frames":walker.max_airborne,"capsule_radius":.4,"capsule_height":1.8,"speed_mps":5}
		cases.append(record);print("ROUNDTRIP ",record)
		record["max_airborne_waypoint"]=walker.max_airborne_waypoint;record["max_unsupported_drop_metres"]=walker.max_unsupported_drop
		check(walker.finished,"Full walking surface/cavity/surface route family %d stopped at %d/%d"%[family_id,walker.waypoint,route.size()])
		check(walker.position.distance_to(start)<1.5,"Returned to actual surface start")
		check(walker.max_unsupported_drop<.75,"No mandatory drop over 0.75 m along the walking route")
		walker.queue_free()
		for node:MeshInstance3D in nodes:Collision.release(node);node.queue_free()
		await process_frame
	var suffix:String="" if seed_id==73921 else "_"+str(seed_id)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_roundtrip"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"seed":seed_id,"cases":cases,"fixture_cave_frequency":.5,"scope":"Finite cavity physics, no streaming or infinite cave certification"},"\t"))
	print("ROUNDTRIP_CHECKS ",checks," ",failures);quit(0 if failures.is_empty() else 1)
