extends "res://tools/caves/render_crystal_world.gd"
const OCCURRENCE:String="res://tools/biome_extensions/artifacts/check_cave_crystal_profile_occurrence.json"
var selection:Dictionary={}
func profile_kind()->String:return "geode"
func inspection_name()->String:return "crystal_first_normal_"+profile_kind()
func inspection_host()->String:return selection.host
func inspection_seed()->int:return int(selection.seed)
func inspection_site()->Vector2i:return Vector2i(selection.site[0],selection.site[1])
func selected_room_id()->String:return selection.room.id
func selection_label()->String:return "FIRST normal "+profile_kind()+" from original ordered126case cohort;no changed chance/host/site/density"
func inspection_views(data:Dictionary,_largest:Dictionary)->Array:
	var owned:Dictionary={}
	for placement:Dictionary in data.placements:
		if placement.kind=="crystal" and str(placement.id).begins_with(str(data.room.id)+"/") and (owned.is_empty() or placement.height>owned.height):owned=placement
	check(not owned.is_empty(),"Scenic lining target belongs to the selected new profile,not a giant in the neighboring parent chamber")
	var point:Vector3=data.room.point;var outward:Vector3=(point-data.parent.point).normalized()
	return [{"name":"profile_owned_lining","position":point+Vector3.UP*1.8,"target":owned.bounds.get_center() if not owned.is_empty() else point+outward*10+Vector3.UP*4},{"name":"outer_vault","position":point+Vector3.UP*1.8,"target":point+outward*data.room.chamber_radius*.8+Vector3.UP*data.room.chamber_height*.45},{"name":"actual_neck","position":data.parent.point+Vector3.UP*1.8,"target":point+Vector3.UP*4}]
func additional_guards()->Dictionary:return {OCCURRENCE:FileAccess.get_sha256(OCCURRENCE),"res://tools/caves/render_crystal_normal_profile.gd":FileAccess.get_sha256("res://tools/caves/render_crystal_normal_profile.gd")}
func run()->void:
	var report=JSON.parse_string(FileAccess.get_file_as_string(OCCURRENCE));check(report is Dictionary and report.get("passed",false),"Positive original normal occurrence report available before scenic selection")
	if not report is Dictionary or not report.get("passed",false):quit(1);return
	for path:String in report.source_sha256:check(FileAccess.get_sha256(path)==report.source_sha256[path],"Normal profile selection remains bound to exact current production source "+path)
	selection=report.first_positive_in_original_order.get(profile_kind(),{});check(not selection.is_empty(),"FIRST actual positive profile exists without rerolling")
	if selection.is_empty() or not failures.is_empty():print("NORMAL_PROFILE_PREFLIGHT failures=",failures);quit(1);return
	await super.run()
