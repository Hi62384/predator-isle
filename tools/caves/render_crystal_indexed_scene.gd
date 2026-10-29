extends "res://tools/caves/render_crystal_world.gd"
const IndexPath:String="res://tools/biome_extensions/artifacts/index_cave_crystal_scene_candidates.json"
var selection:Dictionary={}
var target_key:String="family_0"
func scene_index_path()->String:return IndexPath
func inspection_name()->String:return "crystal_indexed_"+target_key
func inspection_host()->String:return selection.host
func inspection_seed()->int:return int(selection.seed)
func inspection_site()->Vector2i:return Vector2i(selection.site[0],selection.site[1])
func selected_room_id()->String:return selection.room_id
func selection_label()->String:return "FIRST actual normal descriptor for "+target_key+" from fixed918case index,chosen before native rendering;no forced theme/chance/density"
func inspection_cohort_label()->String:return "918case"
func additional_guards()->Dictionary:return {scene_index_path():FileAccess.get_sha256(scene_index_path()),get_script().resource_path:FileAccess.get_sha256(get_script().resource_path),"res://tools/caves/render_crystal_indexed_scene.gd":FileAccess.get_sha256("res://tools/caves/render_crystal_indexed_scene.gd")}
func inspection_views(data:Dictionary,_largest:Dictionary)->Array:
	var owned:Dictionary={}
	for placement:Dictionary in data.placements:
		if placement.kind=="crystal" and str(placement.id).begins_with(str(data.room.id)+"/") and (owned.is_empty() or placement.height>owned.height):owned=placement
	check(not owned.is_empty(),"FIRST preselected actual pocket has its own positive native crystals,not only neighboring mineral metadata")
	if not owned.is_empty():check(owned.family==int(selection.family),"Actual generated mineral matches the preselected regional theme")
	var center:Vector3=data.room.point;var direction:Vector3=(center-data.parent.point).normalized()
	return [{"name":"owned_mineral","position":center+Vector3.UP*1.8,"target":owned.bounds.get_center() if not owned.is_empty() else center+direction*10+Vector3.UP*4},{"name":"whole_chamber","position":center+Vector3.UP*1.8,"target":center+direction*data.room.chamber_radius*.8+Vector3.UP*data.room.chamber_height*.4},{"name":"connected_neck","position":data.parent.point+Vector3.UP*1.8,"target":center+Vector3.UP*4}]
func run()->void:
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("target="):target_key=argument.trim_prefix("target=")
	check(target_key.is_valid_identifier(),"Explicit safe indexed target key")
	var report=JSON.parse_string(FileAccess.get_file_as_string(scene_index_path()));check(report is Dictionary and report.get("passed",false),"Complete fixed descriptor index available")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	for path:String in report.source_sha256:check(FileAccess.get_sha256(path)==report.source_sha256[path],"Scene selection remains bound to exact descriptor-generation source "+path)
	selection=report.first_candidates.get(target_key,{});check(not selection.is_empty(),"Requested first actual descriptor exists;missing case is not replaced by another site")
	if selection.is_empty() or not failures.is_empty():print("INDEXED_CRYSTAL_PREFLIGHT ",failures);quit(1);return
	await super.run()
