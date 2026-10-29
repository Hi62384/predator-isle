extends "res://tools/caves/check_live_crystal_return.gd"
## PRIVATE scheduler study only. Retains the entire original committed
## six-LOD outdoor cut;never hides geometry or changes any worker payload.
var private_surface_source_sha256:String=""
func report_name()->String:return "check_cave_live_crystal_occluded_surface"
func prepare_live_terrain(terrain,_builder)->void:
	var source:String="extends \"res://scripts/chunk_terrain.gd\"\nvar private_deferred_surface_plans:int=0\nfunc _refresh_visible_chunks(destination:Vector3=Vector3.INF)->void:\n\tif not destination.is_finite() and not _teleport_pending and is_instance_valid(target) and _cave_streamer!=null and not _cave_streamer._bundle.is_empty() and not _active_chunks.is_empty():\n\t\tvar point:Vector3=target.global_position\n\t\tif get_height_at(point)-point.y>96.0 and _cave_streamer.nearby_columns(point).is_empty():\n\t\t\tprivate_deferred_surface_plans+=1;return\n\tsuper._refresh_visible_chunks(destination)\n"
	var script:=GDScript.new();script.source_code=source;check(script.reload()==OK,"PRIVATE original terrain subclass only defers new hidden outdoor plans below96m and outside existing3D entrance envelope")
	var original:Dictionary={}
	for property:Dictionary in terrain.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:original[str(property.name)]=terrain.get(property.name)
	terrain.set_script(script)
	for key:String in original:terrain.set(key,original[key])
	for key:String in original:check(terrain.get(key)==original[key],"Original main scene terrain property preserved by private subclass "+key)
	private_surface_source_sha256=source.sha256_text();planned["private_surface_source"]=source;planned["private_surface_source_sha256"]=private_surface_source_sha256
func finish(details:Dictionary,scene,walker)->void:
	if is_instance_valid(scene):
		var terrain=scene.get_node("Terrain");details["private_deferred_surface_plans"]=terrain.private_deferred_surface_plans;details["private_surface_source_sha256"]=private_surface_source_sha256;details["retained_surface_maximum_lod"]=terrain.maximum_lod;check(terrain.private_deferred_surface_plans>0 and terrain.maximum_lod==6,"Positive private deep-only plan deferral retains full original6LOD outdoor cut")
		if is_instance_valid(walker):
			var contacts:Array=[];var stream=terrain._cave_streamer;var key:=Vector3i(floori(walker.position.x/64),floori(walker.position.y/64),floori(walker.position.z/64));var neighbors:Array=[]
			for index in range(walker.get_slide_collision_count()):
				var contact:KinematicCollision3D=walker.get_slide_collision(index);var collider=contact.get_collider();var owner:String="none"
				var shape_owner=contact.get_collider_shape()
				if shape_owner is Node:owner=str(shape_owner.get_path())
				elif shape_owner!=null:owner=str(shape_owner)
				contacts.append({"position":contact.get_position(),"normal":contact.get_normal(),"depth":contact.get_depth(),"collider_path":str(collider.get_path()) if collider is Node else str(collider),"shape_owner":owner})
			for offset:Vector3i in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
				var neighbor:Vector3i=key+offset;var node=stream._cells.get(neighbor);neighbors.append({"key":str(neighbor),"bundle_contains":neighbor in stream._bundle.get("cells",[]),"wanted":stream._wanted.has(neighbor),"resident_key":stream._cells.has(neighbor),"native_node":is_instance_valid(node),"surface_owned":stream._surface_owned.has(neighbor),"node_path":str(node.get_path()) if is_instance_valid(node) else "none"})
			details["final_native_contacts"]=contacts;details["final_neighbor_states"]=neighbors
			print("PRIVATE_CONTACT_DEBUG position=",walker.position," contacts=",contacts," neighbors=",neighbors)
	super.finish(details,scene,walker)
func motion_scope()->String:return super.motion_scope()+" PRIVATE not production:only new overlying terrain replans are deferred below96m canonical cover and outside existing3D mouth envelope. Original entire committed6LOD visible mesh/colliders stay present;no smaller LOD,geometry hiding,changed cave mesh/route/player/worker/time/memory limits. Destination/teleport plans never defer;normal planning resumes above96m or near a required real entrance. Full native return required. Not adopted merely by this experiment."
