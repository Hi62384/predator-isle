extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	for source:String in ["res://tools/biome_extensions/native_walk_admission.gd","res://tools/biome_extensions/admission_height_fixture.gd","res://tools/biome_extensions/route_probe.gd","res://tools/biome_extensions/check_native_walk_admission.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var world:=Node3D.new();root.add_child(world)
	var floor:=StaticBody3D.new();var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(500,2,500);floor_shape.shape=box;floor.add_child(floor_shape);floor.position.y=-1;world.add_child(floor)
	var actor:=CharacterBody3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var actor_shape:=CollisionShape3D.new();actor_shape.shape=capsule;actor.add_child(actor_shape);world.add_child(actor);actor.position=Vector3(-300,10,0)
	for frame in range(3):await physics_frame
	var space:PhysicsDirectSpaceState3D=actor.get_world_3d().direct_space_state;var host=preload("res://tools/biome_extensions/admission_height_fixture.gd").new();var planner=preload("res://tools/biome_extensions/native_walk_admission.gd").new();var original:Vector3=actor.position
	var flat:Dictionary=planner.plan(space,host,actor,capsule,Vector2.ZERO,Vector2.RIGHT)
	check(flat.accepted and flat.route.size()==24 and flat.angle_degrees==0,"Flat native floor admits the unchanged straight return")
	check(actor.position==original,"Planner never moves the actor during admission")
	var wall:=StaticBody3D.new();var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(2,100,2);wall_shape.shape=wall_box;wall.add_child(wall_shape);wall.position.y=50;world.add_child(wall)
	for frame in range(3):await physics_frame
	var blocked:Dictionary=planner.plan(space,host,actor,capsule,Vector2.ZERO,Vector2.RIGHT)
	check(not blocked.accepted,"A solid obstacle at the required midpoint cannot be skipped or reported successful")
	wall.queue_free();await physics_frame;await physics_frame
	floor.rotation.z=deg_to_rad(48);host.slope=tan(deg_to_rad(48));host.intercept=1/cos(deg_to_rad(48))-1
	for frame in range(3):await physics_frame
	var steep:Dictionary=planner.plan(space,host,actor,capsule,Vector2.ZERO,Vector2.RIGHT)
	check(not steep.accepted,"Native 48-degree floor is rejected without increasing the declared 45-degree capsule limit")
	floor.collision_layer=0;host.slope=0;host.intercept=0
	for frame in range(3):await physics_frame
	var empty:Dictionary=planner.plan(space,host,actor,capsule,Vector2.ZERO,Vector2.RIGHT)
	check(not empty.accepted,"Missing native floor cannot become an admitted route")
	check(actor.position==original,"All failed admissions preserve the original actor transform")
	actor.set_script(preload("res://tools/biome_extensions/route_probe.gd"));actor.position=Vector3(0,10,0);actor.floor_snap_length=.6
	var falling_route:Array[Vector3]=[Vector3(10,10,0)];actor.route=falling_route;actor.set_physics_process(true)
	for frame in range(120):
		await physics_frame
		if actor.failed:break
	actor.set_physics_process(false)
	check(actor.failed and actor.waypoint==0 and actor.max_unsupported_drop>2,"Unsupported initial drop is now measured even before waypoint zero")
	var measured_initial_drop:float=actor.max_unsupported_drop
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable admission controls source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_native_walk_admission.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"measured_unsupported_initial_drop_m":measured_initial_drop,"source_sha256":hashes,"scope":"Native synthetic positive/negative controls for test-only route admission: flat floor, blocked midpoint, 48-degree floor, absent floor, transform non-mutation and measured unsupported fall before waypoint zero. Does not validate a production-world route or general navigation."},"  "))
	print("NATIVE_WALK_ADMISSION_CONTROLS ",checks," failures=",failures);world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
