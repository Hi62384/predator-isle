extends "res://tools/biome_extensions/check_streamed_roundtrip.gd"
func streamed_junction(terrain,p:Vector2,directions:Array[Vector2],width:float,height:float,phase:float)->Dictionary:
	# Compare the exact worker-owned CPU payload, not a GPU readback or an
	# admission manifest that could be true while the visible owner is absent.
	for node:MeshInstance3D in terrain._active_chunks.values():
		if node.mesh==null or not node.mesh.has_meta("collision_data"):continue
		var span:float=terrain.chunk_size*float(1<<node.get_meta("tile").z)
		if p.x<node.position.x or p.y<node.position.z or p.x>=node.position.x+span or p.y>=node.position.z+span:continue
		var g=Structures.new();g.origin=node.position;g._support_steps=Structures.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
		var helper=preload("res://scripts/alien_junction_geometry.gd").new();helper.longitudinal_ribs=terrain.settings.alien_infected.hive_longitudinal_ribs
		helper.emit(g,terrain._sampler,p,directions,width,height,phase)
		preload("res://scripts/alien_membrane_geometry.gd").new().emit(g,terrain._sampler,p,directions[0],width,height,phase)
		var faces:PackedVector3Array=node.mesh.get_meta("collision_data").structure_faces
		for offset in range(0,maxi(0,faces.size()-g.vertices.size()+1),3):
			if faces[offset]!=g.vertices[0]:continue
			if faces.slice(offset,offset+g.vertices.size())==g.vertices:
				var endpoint:Vector2=p+directions[0]*width*3.6
				return {"matched_vertices":g.vertices.size(),"owner":node.position,"deep_endpoint_y":g.footing_height(terrain._sampler,endpoint),"canonical_endpoint_y":terrain._sampler._get_height(endpoint.x,endpoint.y)}
	return {}
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	hashes["res://tools/biome_extensions/native_walk_admission.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/native_walk_admission.gd")
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	hashes["res://tools/biome_extensions/check_streamed_roundtrip.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_streamed_roundtrip.gd")
	for source:String in ["res://scripts/alien_carapace_geometry.gd","res://scripts/biome_extension_settings.gd"]:hashes[source]=FileAccess.get_sha256(source)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/alien_junction_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_collision.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/route_probe.gd","res://tools/biome_extensions/check_junction_navigation_walk.gd","res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json"));check(admission.passed,"Actual default-admission sites")
	check(admission.cases.size()==6,"Complete three-seed minimum/maximum-scale admission manifest")
	var cases:Array=[]
	var selected_seed:int=0
	var selected_scale:float=0
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):selected_seed=int(argument.trim_prefix("seed="))
		if argument.begins_with("scale="):selected_scale=float(argument.trim_prefix("scale="))
	check(selected_scale in [0.0,.2,2.0],"Only declared min/max scale diagnostics accepted")
	for item:Dictionary in admission.cases:
		if selected_seed!=0 and int(item.seed)!=selected_seed:continue
		if selected_scale!=0 and float(item.feature_scale)!=selected_scale:continue
		var p:=Vector2(item.position[0],item.position[1]);var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain")
		scene.get_node("FreeCamera").set_script(null)
		var walker:=CharacterBody3D.new();walker.set_script(preload("res://tools/biome_extensions/route_probe.gd"));walker.set_physics_process(false);walker.floor_snap_length=.6
		var capsule:=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.8;var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
		check(is_equal_approx(walker.floor_max_angle,deg_to_rad(45)),"Unchanged default 45-degree capsule slope limit")
		terrain.world_seed=int(item.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=walker;terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.feature_scale=float(item.feature_scale);root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
		var field=terrain._sampler._extras[7];var cell:=Vector2i(floori(p.x/(4096*item.feature_scale)),floori(p.y/(4096*item.feature_scale)));var edges:PackedVector2Array=field.network_edges(cell)
		var axis:Vector2=(edges[1]-p).normalized();var side:=Vector2(-axis.y,axis.x);var width:float=item.width
		var d:Dictionary=field.descriptor(cell,4096*item.feature_scale);var shoulder:float=.65
		var a:Vector2=p+axis*width*.6*sin(shoulder*PI*.65)+side*width*.07*sin(shoulder*PI+d.angle)*shoulder
		var center:Vector2=(a+(p+axis*width*3.0)*2+(p+axis*width*3.6))*.25
		var start2:Vector2=center-side*60;var start:=Vector3(start2.x,0,start2.y);start.y=terrain.get_height_at(start)+.95
		walker.position=start;terrain._refresh_visible_chunks();await settle(terrain)
		for frame in range(3):await physics_frame
		var directions:Array[Vector2]=[axis,(edges[5]-p).normalized()]
		var geometry:Dictionary=streamed_junction(terrain,p,directions,width,float(item.junction_height),d.angle)
		check(geometry.get("matched_vertices",0)==14304,"Complete actual streamed junction/membrane CPU collision payload")
		var under:=Vector3(center.x,0,center.y);under.y=terrain.get_height_at(under)
		var space:PhysicsDirectSpaceState3D=walker.get_world_3d().direct_space_state
		var start_ray:=PhysicsRayQueryParameters3D.create(start+Vector3(0,24,0),start-Vector3(0,100,0));start_ray.exclude=[walker.get_rid()]
		var start_hit:Dictionary=space.intersect_ray(start_ray)
		var initial_query:=PhysicsShapeQueryParameters3D.new();initial_query.shape=capsule;initial_query.transform=walker.global_transform;initial_query.exclude=[walker.get_rid()];initial_query.margin=.001
		var initial_overlap:Array=space.intersect_shape(initial_query,8)
		var initial_probe:Dictionary={"position":start,"native_floor_position":start_hit.get("position",Vector3.INF),"native_floor_normal":start_hit.get("normal",Vector3.ZERO),"collider":str(start_hit.get("collider",null)),"initial_capsule_overlap_count":initial_overlap.size(),"overlap_colliders":[]}
		for overlap:Dictionary in initial_overlap:initial_probe.overlap_colliders.append({"collider":str(overlap.collider),"shape":overlap.shape})
		print("NAVIGATION_JUNCTION_INITIAL_SUPPORT ",initial_probe)
		var query:=PhysicsRayQueryParameters3D.create(under+Vector3(0,2,0),under+Vector3(0,1000,0));query.exclude=[walker.get_rid()]
		var ceiling:Dictionary=space.intersect_ray(query);var clearance:float=ceiling.position.y-under.y if not ceiling.is_empty() else -1
		check(clearance>3,"Actual overhead strut collider with usable ground clearance")
		var physical_floor:Dictionary={};var physical_clearance:float=-1
		if not ceiling.is_empty():
			var floor_query:=PhysicsRayQueryParameters3D.create(under+Vector3(0,clearance-.25,0),under-Vector3(0,10,0));floor_query.exclude=[walker.get_rid()]
			physical_floor=space.intersect_ray(floor_query)
			if not physical_floor.is_empty():physical_clearance=ceiling.position.y-physical_floor.position.y
		check(physical_clearance>capsule.height+.25,"Actual native floor-to-ceiling gap fits the declared capsule")
		var route:Array[Vector3]=[]
		var maximum_conduit_support:float=0;var floor_probes:Array=[]
		for step in range(1,13):
			var q:Vector2=center+side*(-60+step*10);var point:=Vector3(q.x,0,q.y);var canonical:float=terrain.get_height_at(point)
			# The pre-existing surface conduit is also solid walking ground.
			# Aim at its actual top, not a waypoint several metres INSIDE it.
			# The ray starts below the overhead strut and never moves the walker.
			var overhead_query:=PhysicsRayQueryParameters3D.create(Vector3(q.x,canonical+2,q.y),Vector3(q.x,canonical+1000,q.y));overhead_query.exclude=[walker.get_rid()]
			var overhead_hit:Dictionary=space.intersect_ray(overhead_query)
			var probe_top:float=minf(canonical+24,overhead_hit.position.y-.25) if not overhead_hit.is_empty() else canonical+24
			var floor_query:=PhysicsRayQueryParameters3D.create(Vector3(q.x,probe_top,q.y),Vector3(q.x,canonical-10,q.y));floor_query.exclude=[walker.get_rid()]
			var floor_hit:Dictionary=space.intersect_ray(floor_query);check(not floor_hit.is_empty(),"Physical walking support below overhead strut")
			point.y=(floor_hit.position.y if not floor_hit.is_empty() else canonical)+.95
			floor_probes.append({"xz":q,"canonical_y":canonical,"ray_start_y":probe_top,"overhead_y":overhead_hit.get("position",Vector3.INF).y,"support_y":point.y-.95})
			maximum_conduit_support=maxf(maximum_conduit_support,point.y-.95-canonical);route.append(point)
		for step in range(11,-1,-1):
			route.append(route[step-1] if step>0 else start)
		var admission_plan:Dictionary=preload("res://tools/biome_extensions/native_walk_admission.gd").new().plan(space,terrain,walker,capsule,center,side)
		check(admission_plan.accepted,"Admit a complete native-supported, capsule-clear approach with unchanged floor-angle limit")
		if admission_plan.accepted:
			start=admission_plan.start;route.assign(admission_plan.route);walker.position=start;terrain._refresh_visible_chunks();await settle(terrain)
			for frame in range(3):await physics_frame
			geometry=streamed_junction(terrain,p,directions,width,float(item.junction_height),d.angle)
			check(geometry.get("matched_vertices",0)==14304,"Complete actual landmark remains after admitted approach cut")
			floor_probes=admission_plan.probes
			maximum_conduit_support=0
			for sample:Dictionary in floor_probes:maximum_conduit_support=maxf(maximum_conduit_support,sample.floor_y-sample.canonical_y)
			initial_query.transform=walker.global_transform
			check(space.intersect_shape(initial_query,1).is_empty(),"Actual admitted walking spawn remains capsule-clear after its committed cut")
		walker.route=route;walker.set_physics_process(true)
		var cuts:Dictionary={};var pause_frames:int=0;var started:int=Time.get_ticks_usec()
		for frame in range(1000000):
			await physics_frame
			walker.paused=terrain.committed_revision!=terrain.partition_revision
			if walker.paused:
				pause_frames+=1
				if DisplayServer.get_name()=="headless":OS.delay_msec(HEADLESS_PRELOAD_POLL_MS)
			cuts[terrain.committed_revision]=true
			if walker.failed or walker.finished or Time.get_ticks_usec()-started>180000000:break
		walker.set_physics_process(false)
		var contacts:Array=[]
		for collision_index in range(walker.get_slide_collision_count()):
			var contact:KinematicCollision3D=walker.get_slide_collision(collision_index);var position:Vector3=contact.get_position()
			var canonical_normal:=Vector3(terrain.get_height_at(position-Vector3(.25,0,0))-terrain.get_height_at(position+Vector3(.25,0,0)),.5,terrain.get_height_at(position-Vector3(0,0,.25))-terrain.get_height_at(position+Vector3(0,0,.25))).normalized()
			contacts.append({"position":position,"normal":contact.get_normal(),"canonical_normal":canonical_normal,"height_above_canonical":position.y-terrain.get_height_at(position),"collider":str(contact.get_collider()),"shape":str(contact.get_collider_shape())})
		check(walker.finished and walker.waypoint==route.size(),"Complete two-way walk below actual streamed root strut")
		check(walker.position.distance_to(start)<1.5,"Return to actual surface start")
		check(walker.frames>2000,"Actual 240m capsule motion at 5m/s")
		check(walker.max_unsupported_drop<.75,"No mandatory large drop below root strut")
		if admission_plan.get("curved_native_route",false):check(walker.horizontal_distance_m>=240,"Actual tracked curved return motion is at least the original 240m")
		check(terrain.maximum_lod==6,"Full production hierarchy retained")
		var measured_horizontal_distance:float=walker.horizontal_distance_m
		var record:Dictionary={"seed":item.seed,"feature_scale":item.feature_scale,"position":p,"finished":walker.finished,"failed":walker.failed,"waypoint":walker.waypoint,"waypoints":route.size(),"movement_frames":walker.frames,"paused_preload_frames":pause_frames,"committed_cuts":cuts.size(),"overhead_physics_clearance_m":clearance,"max_unsupported_drop_m":walker.max_unsupported_drop,"maximum_existing_conduit_support_above_canonical_m":maximum_conduit_support,"final_position":walker.position,"target":route[mini(walker.waypoint,route.size()-1)],"route_length_m":admission_plan.get("nominal_horizontal_return_metres",240),"capsule_height_m":1.8,"capsule_radius_m":.4,"speed_mps":5,"walk_wall_s":(Time.get_ticks_usec()-started)/1000000.0}
		cases.append(record);print("NAVIGATION_JUNCTION_WALK ",record);walker.queue_free();scene.queue_free();await process_frame;await process_frame
		record["streamed_geometry"]=geometry;record["floor_probes"]=floor_probes
		record["initial_support_probe"]=initial_probe
		record["actual_horizontal_motion_m"]=measured_horizontal_distance
		record["approach_admission"]=admission_plan
		record["headless_preload_poll_yield_ms"]=HEADLESS_PRELOAD_POLL_MS if DisplayServer.get_name()=="headless" else 0
		record["final_contacts"]=contacts
		record["floor_max_angle_degrees"]=45.0
		record["production_membrane_present"]=item.get("membrane_present",false)
		record["overhead_native_contact"]=ceiling.get("position",Vector3.INF)
		record["actual_native_floor_to_ceiling_gap_m"]=physical_clearance
		record["actual_native_floor_contact"]=physical_floor.get("position",Vector3.INF)
	check(cases.size()==((3 if selected_seed==0 else 1)*(2 if selected_scale==0 else 1)),"Every explicitly requested custom-scale route case exercised")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable route source "+path)
	var suffix:String=("_diagnostic"+("_seed_"+str(selected_seed) if selected_seed!=0 else "")+("_scale_"+str(selected_scale).replace(".","p") if selected_scale!=0 else "")) if selected_seed!=0 or selected_scale!=0 else ""
	FileAccess.open("res://tools/biome_extensions/artifacts/check_junction_navigation_walk"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Six separate navigation-admitted, default-rarity root sites at minimum/maximum feature scale, actual production streaming/collision and declared capsule/speed/gravity, nominal 240m horizontal returns or longer physically measured curved returns. Original purely geometric steep sites and failed approaches remain separate evidence; this does not claim every root or arbitrary terrain is walkable. Initial unsupported drops are counted; no cave, intermediate/arbitrary-settings, uninterrupted performance or whole-world navigation certificate."},"  "))
	print("NAVIGATION_JUNCTION_WALK_DONE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
