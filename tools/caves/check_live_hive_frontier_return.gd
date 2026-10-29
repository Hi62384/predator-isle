extends "res://tools/caves/check_live_hive_return.gd"
func report_name()->String:return "check_cave_live_hive_frontier_return"
func capture_prefix()->String:return "cave_hive_frontier_live"
func motion_scope()->String:return super.motion_scope()+" Default-on temporary frontier rock/render/collision closures are included;the canonical fixed route and original gates remain unchanged."
func finish(details:Dictionary,scene,walker)->void:
	if is_instance_valid(scene) and is_instance_valid(walker) and details.has("walk"):
		var stream=scene.get_node("Terrain")._cave_streamer;var key:=Vector3i(floori(walker.position.x/64),floori(walker.position.y/64),floori(walker.position.z/64));var nearby:Array=[]
		for offset:Vector3i in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
			var candidate:Vector3i=key+offset;var node=stream._cells.get(candidate);var closures:Array=[]
			if is_instance_valid(node) and node.has_node("CaveFrontiers"):
				for face:MeshInstance3D in node.get_node("CaveFrontiers").get_children():closures.append({"face":face.get_meta("face"),"visible":face.is_visible_in_tree(),"collision":face.get_node("FrontierCollision").collision_layer,"path":str(face.get_path())})
			nearby.append({"key":str(candidate),"present":stream._cells.has(candidate),"wanted":stream._wanted.has(candidate),"surface_owned":stream._surface_owned.has(candidate),"frontiers":closures})
		var target:Vector3=walker.route[mini(walker.waypoint,walker.route.size()-1)];var direction:Vector3=walker.position.direction_to(target);var query:=PhysicsRayQueryParameters3D.create(walker.position,walker.position+direction*4);query.exclude=[walker.get_rid()];var hit:Dictionary=walker.get_world_3d().direct_space_state.intersect_ray(query);details["boundary_diagnostic"]={"nearby":nearby,"blocking_object":str(hit.collider.get_path()) if not hit.is_empty() else "none","blocking_hit":str(hit.get("position",Vector3.INF)),"actor":str(walker.position),"target":str(target)}
	super.finish(details,scene,walker)
