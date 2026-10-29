extends "res://tools/caves/check_live_portal.gd"
func floor_hit(actor:Node3D)->Dictionary:
	return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3(0,.25,0),actor.position-Vector3(0,2.0,0)))
func teleport(terrain,actor:Node3D,destination:Vector3)->Dictionary:
	var original:Vector3=actor.position;var before:Dictionary=floor_hit(actor);var began:int=Time.get_ticks_usec();var probes:int=0;var stable:bool=not before.is_empty();terrain.request_teleport(destination)
	while terrain._teleport_pending and Time.get_ticks_usec()-began<180000000:
		observe(terrain)
		if actor.position!=original:stable=false;break
		var hit:Dictionary=floor_hit(actor)
		if hit.is_empty() or before.is_empty() or hit.position.distance_to(before.position)>.03:stable=false;break
		probes+=1;await process_frame;OS.delay_usec(1000)
	check(stable,"Pending teleport retains original live entrance floor and exact actor position until complete destination cut")
	check(not terrain._teleport_pending and actor.position.distance_to(destination)<.001,"Destination-specific cave readiness before atomic target move")
	return {"stable_before_commit":stable,"support_probes":probes,"seconds":(Time.get_ticks_usec()-began)/1000000.0,"destination":str(destination),"arrived":not terrain._teleport_pending,"surface_status":terrain._cave_streamer.surface_status}
func run()->void:
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for file:String in DirAccess.get_files_at(folder):
			if file.ends_with(".gd") or file.ends_with(".gdshader") or file.ends_with(".gdshaderinc"):var path:String=folder+"/"+file;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_partition.gd","res://scripts/terrain_collision.gd","res://tools/caves/check_live_lifecycle.gd","res://tools/caves/check_live_portal.gd","res://scenes/main.tscn","res://project.godot","res://config/caves/cave_settings.tres"]:guards[path]=FileAccess.get_sha256(path)
	var b=make_builder(3,73921);var network=Network.new();network.configure(b._get_height,b.get_water_surface_height,73921);network.activity=1;var region:Dictionary=network.region(Vector2i(9,-3));var hole:=Vector3.INF
	for point:Vector3 in region.edges[0].points:
		var depth:float=b._get_height(point.x,point.z)-point.y
		if depth>1 and depth<6:hole=point;break
	var actor:=Node3D.new();root.add_child(actor);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null);terrain.target=actor;terrain.extension_preview="spore_forest";terrain.extension_preview_position=Vector2(hole.x,hole.z)
	for name:String in ["jungle","forest","savanna","swamp","mountain","coast","beach","tropical","badlands"]:terrain.set("start_in_"+name,false)
	terrain.cave_settings=Config.new();terrain.cave_settings.enabled=true;terrain.cave_settings.regional_activity=1;root.add_child(scene);scene.get_node("Interface").hide();actor.position=hole+Vector3(0,.95,0);terrain._refresh_visible_chunks();camera.position=hole+Vector3(12,9,15);camera.look_at(hole)
	var ready:bool=await settle(terrain,true);check(ready,"Actual live portal prepared before lifecycle checks");var details:Dictionary={"initial_ready":ready,"initial_status":terrain._cave_streamer.surface_status}
	if ready:
		for frame in range(3):await physics_frame
		check(not floor_hit(actor).is_empty(),"Original exposed mouth contains actual native support below actor")
		var far_point:Vector3=actor.position+Vector3(5000,0,-3000);far_point.y=b._get_height(far_point.x,far_point.z)+.95
		details["outbound"]=await teleport(terrain,actor,far_point)
		if not terrain._teleport_pending:
			check(terrain._cave_streamer._surface_transaction==null,"Far cut releases original surface transaction instead of retaining infinite old patches")
			for frame in range(3):await physics_frame
			details["return"]=await teleport(terrain,actor,hole+Vector3(0,.95,0))
			if not terrain._teleport_pending:
				for frame in range(3):await physics_frame
				var hit:Dictionary=floor_hit(actor);check(not hit.is_empty() and absf(hit.position.y-hole.y)<.03,"Return teleport enters rebuilt OPEN mouth floor,not original closed ground cap")
				check(terrain._cave_streamer._surface_transaction!=null and terrain._cave_streamer._surface_transaction.committed,"Destination surface transaction committed atomically with terrain/target")
				await capture(camera,hole+Vector3(12,9,15),hole,"lifecycle_return")
	check(maximum_jobs<=4,"Lifecycle retains four TOTAL terrain/cave worker slots")
	if is_instance_valid(actor):actor.queue_free()
	if is_instance_valid(scene):scene.queue_free()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable live lifecycle source "+path)
	details.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":captures,"maximum_total_jobs":maximum_jobs,"peak_resident_cells":peak_cells,"production_enabled_by_default":false,"scope":"Original actual Spore mouth(fullLOD6/four TOTAL workers),pending5km/-3km teleport while actor remains inside exposed entrance,original support probes until atomic commit,release,then destination-specific readiness+rebuild before actual return teleport. Explicit teleport safety,not a walking-route claim."})
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_live_lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify(details,"  "));print("CAVE_LIVE_LIFECYCLE ",checks," details=",details," failures=",failures);quit(0 if failures.is_empty() else 1)
