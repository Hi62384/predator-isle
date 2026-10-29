extends "res://tools/biome_extensions/check_streamed_roundtrip.gd"
const Fixture=preload("res://tools/biome_extensions/ground_union_worker_fixture.gd")
const VIEWS="res://tools/biome_extensions/artifacts/render_tissue_variation_registered.json"
func v3(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func triangle_floor(vertices:PackedVector3Array,p:Vector2)->Dictionary:
	var best:Dictionary={};var highest:float=-INF
	for index in range(0,vertices.size(),3):
		var a:Vector3=vertices[index];var b:Vector3=vertices[index+1];var c:Vector3=vertices[index+2]
		if (c-a).cross(b-a).y<=0:continue
		var v:=Vector2(b.x-a.x,b.z-a.z);var w:=Vector2(c.x-a.x,c.z-a.z);var q:=p-Vector2(a.x,a.z);var determinant:float=v.cross(w)
		if absf(determinant)<.0000001:continue
		var beta:float=q.cross(w)/determinant;var gamma:float=v.cross(q)/determinant
		if beta<-.000001 or gamma<-.000001 or beta+gamma>1.000001:continue
		var height:float=a.y+beta*(b.y-a.y)+gamma*(c.y-a.y)
		if height>highest:highest=height;best={"height":height,"triangle":index/3,"vertices":[str(a),str(b),str(c)]}
	return best
func run()->void:
	var views=JSON.parse_string(FileAccess.get_file_as_string(VIEWS));assert(views.passed);var focus:=Vector3.INF
	for view:Dictionary in views.views:
		if view.seed==92881 and view.view=="ground":focus=v3(view.focus);break
	assert(focus.is_finite());var p:=Vector2(focus.x,focus.z);var original:Array=[];var records:Array=[];var changed:int=0;var maximum:float=0;var mesh_changed:int=0;var maximum_mesh_delta:float=0;var maximum_native_mesh_error:float=0
	var guards:Dictionary={VIEWS:FileAccess.get_sha256(VIEWS)}
	for path:String in views.source_sha256:assert(FileAccess.get_sha256(path)==views.source_sha256[path]);guards[path]=views.source_sha256[path]
	for path:String in ["res://tools/biome_extensions/ground_union_worker_fixture.gd","res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://tools/biome_extensions/check_streamed_roundtrip.gd","res://tools/biome_extensions/diagnose_ground_union_unchanged_route.gd"]:guards[path]=FileAccess.get_sha256(path)
	for enabled:bool in [false,true]:
		var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(92881,true);var frame:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").sample(locator._extras[7],p);var side:=Vector2(-frame.tangent.y,frame.tangent.x)
		var scene=load("res://scenes/main.tscn").instantiate();scene.get_node("FreeCamera").set_script(null);var terrain=scene.get_node("Terrain");Fixture.configure(terrain,enabled);terrain.world_seed=92881;terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
		for property:Dictionary in terrain.get_property_list():
			if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
		var marker:=Marker3D.new();marker.position=focus;scene.add_child(marker);terrain.target=marker;root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
		for idle in range(3):await physics_frame
		var space:PhysicsDirectSpaceState3D=terrain.get_world_3d().direct_space_state;var samples:Array=[];var structure_probes:int=0
		for station in range(161):
			var q:Vector2=p+side*(-80+station);var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x,1000,q.y),Vector3(q.x,-2000,q.y)));check(not hit.is_empty(),"Every original fixed metre point has actual native floor")
			if hit.is_empty():continue
			var body:CollisionObject3D=hit.collider;var shape:Node=body.shape_owner_get_owner(body.shape_find_owner(hit.shape));var node:MeshInstance3D=body.get_parent();var kind:String=String(shape.name);var reference:Dictionary={}
			if kind=="Structures":
				structure_probes+=1;var faces:PackedVector3Array=node.mesh.get_meta("collision_data").structure_faces
				var actual_query:=Vector3(q.x,0,q.y);var local:Vector3=actual_query-node.global_position;reference=triangle_floor(faces,Vector2(local.x,local.z));check(not reference.is_empty(),"Actual native structure hit has independent front-triangle reference")
				if not reference.is_empty():
					var error:float=absf(reference.height+node.global_position.y-hit.position.y);maximum_native_mesh_error=maxf(maximum_native_mesh_error,error);check(error<.03,"Original unchanged3cm actual triangle/native reference gate")
					if enabled and not original[station].triangle_reference.is_empty():
						var mesh_delta:float=absf(reference.height-original[station].triangle_reference.height);maximum_mesh_delta=maxf(maximum_mesh_delta,mesh_delta)
						if mesh_delta>.000001:mesh_changed+=1
			var delta:float=absf(hit.position.y-original[station].height) if enabled else 0
			if enabled:
				maximum=maxf(maximum,delta)
				if delta>.000001:changed+=1
			samples.append({"station":station,"xz":str(q),"height":hit.position.y,"normal":str(hit.normal),"kind":kind,"owner_key":str(node.get_meta("tile",Vector3i.ZERO)),"candidate_delta_m":delta,"triangle_reference":reference})
		if not enabled:original=samples.duplicate(true)
		records.append({"candidate_enabled":enabled,"native_structure_floor_probes":structure_probes,"samples":samples});scene.queue_free();await process_frame;await process_frame
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable unchanged-route diagnostic source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_ground_union_unchanged_route.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"seed":92881,"focus":str(focus),"cases":records,"changed_metre_grid_floor_points":changed,"maximum_native_floor_change_m":maximum,"changed_independent_triangle_floor_points":mesh_changed,"maximum_independent_triangle_floor_change_m":maximum_mesh_delta,"maximum_native_mesh_error_m":maximum_native_mesh_error,"scope":"PRIVATE DIAGNOSTIC after the original17-point92881 efficacy gate failed. SAME original160m cross-section,no reroll:actual original/candidate worker colliders sampled every metre. Reports all322 native floor hits,source shapes/owners/normals,exact height differences and independent actual clockwise triangle-plane references for EVERY native structure sample under unchanged3cm native error bound. This separates real sampled mesh change from native-mesh error without guessing its cause. It does NOT retroactively pass the failed17-point gate or certify unchanged continuous geometry between samples. Original actual capsule returns already complete in the preserved failed efficacy report. No production edits."},"  "));print("GROUND_UNION_DENSE_ROUTE changed=",changed," max=",maximum," mesh_changed=",mesh_changed," mesh_max=",maximum_mesh_delta);quit(0 if failures.is_empty() else 1)
