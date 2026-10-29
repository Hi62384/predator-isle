extends "res://tools/caves/check_crystal_world_cohort.gd"
const Scope=preload("res://tools/caves/inspection_scope.gd")
func run()->void:
	var index_path:String="res://tools/biome_extensions/artifacts/index_cave_crystal_scene_candidates.json";var target:String="family_0"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("index="):index_path=arg.trim_prefix("index=")
		if arg.begins_with("target="):target=arg.trim_prefix("target=")
	check(target.is_valid_identifier() and index_path.begins_with("res://tools/biome_extensions/artifacts/") and index_path.ends_with(".json"),"Explicit local immutable-origin descriptor and safe target key")
	var original=JSON.parse_string(FileAccess.get_file_as_string(index_path));check(original is Dictionary and original.get("passed",false),"Original completed descriptor catalogue retained")
	if not original is Dictionary or not original.get("passed",false):quit(1);return
	var selection:Dictionary=original.get("first_candidates",{}).get(target,{});check(not selection.is_empty(),"Original requested fixed descriptor exists;no replacement site")
	if selection.is_empty():quit(1);return
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards);guards[index_path]=FileAccess.get_sha256(index_path);guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			var path:String=folder+"/"+name
			if (name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc")) and Scope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var b=owner(selection.host,int(selection.seed));var work=Workload.new();check(work.configure(b.settings,config,int(selection.seed),0),"Current normal production configuration");var region:Dictionary=work.network.region(Vector2i(selection.site[0],selection.site[1]));var room:Dictionary={};var parent:Dictionary={}
	for body:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
		if str(body.id)==str(selection.room_id):room=body
		if str(body.id)==str(selection.parent_id):parent=body
	check(not room.is_empty() and not parent.is_empty(),"Exact original room and parent remain present")
	if room.is_empty() or parent.is_empty():quit(1);return
	var expected:Vector3=str_to_var("Vector3"+str(selection.point));check(room.point.distance_to(expected)<.01,"Original physical coordinates retained;JSON decimal tolerance only");var assignment:Dictionary=Regions.along_edge(region.cave_biome_regions,str(room.id),str(room.id),0,0);check(float(assignment.weights.get("crystal",0))>=.8 and str(assignment.candidate_ids.get("crystal",""))==str(selection.theme),"Original normal full-weight mineral theme retained")
	if target=="rare_luminous":check(Regions.random(str(selection.theme),int(selection.seed),"crystal/fictional_region")<float(definition.feature_configuration.luminous_region_chance),"Original fixed region still qualifies under unchanged normal rare channel")
	var actual:Dictionary=selection.duplicate(true);actual.point=room.point;actual.radius_m=room.chamber_radius;actual.headroom_m=room.chamber_height;actual.depth_m=work.builder._get_height(room.point.x,room.point.z)-room.point.y;actual["selection_rule"]="Exact preserved original location revalidated under current production source;no replacement or probability override. Original complete catalogue remains historical under its own original hashes."
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Current fixed-location source unchanged "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_fixed_scene_"+target+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"origin_catalogue":index_path,"origin_sha256":FileAccess.get_sha256(index_path),"original_catalogue_source_sha256":original.source_sha256,"first_candidates":{target:actual},"scope":"Current FIXED LOCATION validation only. Exact original selected host/seed/site/room/theme/coordinates retained,normal definition unchanged. Original catalogue and all negatives remain immutable historical evidence;their source hashes are NOT rebound and this does NOT rerun its whole cohort or certify a new FIRST result. Native geometry/visual/physics checks follow separately."},"  "));print("CRYSTAL_FIXED_SELECTION ",target," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
