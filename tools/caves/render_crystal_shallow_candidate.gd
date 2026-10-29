extends "res://tools/caves/render_crystal_world.gd"
const Shallow=preload("res://tools/caves/crystal_shallow_candidate.gd")
const Prefix:String="res://tools/biome_extensions/artifacts/check_cave_crystal_shallow_batch_"
var selection:Dictionary={}
var proposal:Dictionary={}
func inspection_name()->String:return "crystal_shallow_candidate"
func inspection_host()->String:return selection.host
func inspection_seed()->int:return int(selection.seed)
func inspection_site()->Vector2i:return Vector2i(selection.site[0],selection.site[1])
func selected_room_id()->String:return selection.room.id
func selection_label()->String:return "FIRST normal shallow Crystal descriptor at original2070case ordinal336;batch0negative and batch1prefix checked before native selection"
func inspection_control_scope()->String:return "PRIVATE shallow extension only. Original18percent/5,20,50,80,100depth preferences/.65density and all affinity/extent channels unchanged;existing Crystal reach covers actual38m chamber."
func additional_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in [Prefix+"0.json",Prefix+"1.json","res://tools/caves/crystal_shallow_candidate.gd","res://tools/caves/shallow_chamber_candidate.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
func inspection_prepare_workload(work)->void:
	var previous:Callable=work.network.region_finalizer
	var height:Callable=work.builder._get_height
	work.network.region_finalizer=func(region:Dictionary)->Dictionary:
		var original:Dictionary=previous.call(region);var grown:Dictionary=Shallow.prepare(original,height)
		if original.id==inspection_site():proposal=grown
		return grown
func local_access()->PackedVector3Array:
	var access:PackedVector3Array=proposal.edges[0].points;var junction:Vector3=proposal.pocket_passages[-1].points[-3];var nearest:int=0
	for index in range(access.size()):
		if access[index].distance_squared_to(junction)<access[nearest].distance_squared_to(junction):nearest=index
	return access.slice(maxi(0,nearest-4),mini(access.size(),nearest+5))
func inspection_bounds(room:Dictionary,_parent:Dictionary,_pool:Dictionary)->AABB:
	var low:Vector3=room.point-Vector3(24,6,24);var high:Vector3=room.point+Vector3(24,24,24);var branch:PackedVector3Array=proposal.pocket_passages[-1].points
	for point:Vector3 in PackedVector3Array([branch[-3],branch[-2],branch[-1]])+local_access():low=low.min(point-Vector3(10,6,10));high=high.max(point+Vector3(10,16,10))
	return AABB(low,high-low)
func inspection_routes(_data:Dictionary,_field)->Array:
	var result:Array=[];var points:Array=[];var branch:PackedVector3Array=proposal.pocket_passages[-1].points
	for index in range(branch.size()-3,branch.size()):points.append(branch[index]+Vector3.UP*.95)
	for index in range(points.size()-2,-1,-1):points.append(points[index])
	result.append({"label":"Actual normal shallow Crystal branch from original tunnel junction and exact return","points":points});points=[]
	for point:Vector3 in local_access():points.append(point+Vector3.UP*.95)
	for index in range(points.size()-2,-1,-1):points.append(points[index])
	result.append({"label":"Original normal access through shallow Crystal junction and exact return","points":points});return result
func inspection_views(data:Dictionary,_largest:Dictionary)->Array:
	var owned:Dictionary={}
	for form:Dictionary in data.placements:
		if form.kind=="crystal" and str(form.id).begins_with(str(data.room.id)+"/") and (owned.is_empty() or form.height>owned.height):owned=form
	check(not owned.is_empty(),"Selected actual shallow room has its OWN positive mineral prisms,not neighboring parent geometry")
	var branch:PackedVector3Array=proposal.pocket_passages[-1].points
	return [{"name":"actual_level_one_crystals","position":data.room.point+Vector3.UP*1.8,"target":owned.bounds.get_center() if not owned.is_empty() else data.room.point+Vector3(8,3,0)},{"name":"original_access_junction","position":branch[-3]+Vector3.UP*1.8,"target":data.room.point+Vector3.UP*3}]
func inspection_material_checks(data:Dictionary,_nodes:Array,_camera:Camera3D,_light:OmniLight3D)->Dictionary:
	check(data.room.get("shallow_chamber",false) and data.room.point.distance_to(str_to_var("Vector3"+str(selection.room.point)))<.01,"Same original preselected physically shallow descriptor retained")
	return {"depth_m":selection.depth_m,"original_ordinal":selection.ordinal,"theme":selection.theme,"scope":"Actual normal coverage/selected room owned minerals;private extension geometry,no forced biome admission."}
func run()->void:
	var zero=JSON.parse_string(FileAccess.get_file_as_string(Prefix+"0.json"));var one=JSON.parse_string(FileAccess.get_file_as_string(Prefix+"1.json"));check(zero is Dictionary and one is Dictionary and zero.get("passed",false) and one.get("passed",false),"Complete fixed first two batches available")
	if not zero is Dictionary or not one is Dictionary:quit(1);return
	check(int(zero.positives)==0 and not one.first_positive.is_empty() and zero.source_sha256==one.source_sha256,"Earlier234cases negative;first normal positive selected in exact source-bound next prefix")
	for path:String in one.source_sha256:check(FileAccess.get_sha256(path)==one.source_sha256[path],"Original normal shallow survey source unchanged "+path)
	selection=one.first_positive
	if not failures.is_empty():print("SHALLOW_CRYSTAL_PREFLIGHT ",failures);quit(1);return
	await render_selected()
func render_selected()->void:
	await super.run()
