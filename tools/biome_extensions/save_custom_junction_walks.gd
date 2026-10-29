extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={};var cases:Array=[];var seen:Dictionary={}
	for scale_value:float in [.2,2.0]:
		var path:String="res://tools/biome_extensions/artifacts/check_junction_navigation_walk_diagnostic_scale_"+str(scale_value).replace(".","p")+".json"
		check(FileAccess.file_exists(path),"Required separate scale walk report exists")
		if not FileAccess.file_exists(path):continue
		hashes[path]=FileAccess.get_sha256(path);var result=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(result is Dictionary and result.get("passed",false) and result.get("failures",[1]).is_empty(),"Separate scale report passes without skipped failures")
		if not result is Dictionary:continue
		check(result.cases.size()==3,"Every scale exercises all three seeds")
		for source:String in result.source_sha256:
			check(FileAccess.get_sha256(source)==result.source_sha256[source],"Current source for scale report "+source);hashes[source]=result.source_sha256[source]
		for item:Dictionary in result.cases:
			var identity:String=str(int(item.seed))+"/"+str(item.feature_scale)
			check(not seen.has(identity) and float(item.feature_scale)==scale_value,"Unique declared scale/seed route");seen[identity]=true
			check(item.finished and not item.failed and item.waypoint==item.waypoints and item.waypoints>=24 and item.movement_frames>2000,"Complete actual capsule return, no motion shortcut")
			check(item.streamed_geometry.matched_vertices==14304,"Complete actual worker junction/membrane geometry")
			check(item.actual_native_floor_to_ceiling_gap_m>2.05 and item.max_unsupported_drop_m<.75,"Native headroom and unsupported-drop bounds")
			check(item.capsule_height_m==1.8 and item.capsule_radius_m==.4 and item.speed_mps==5 and item.route_length_m>=240,"Unchanged physical fixture and at least original approach length")
			if item.get("approach_admission",{}).get("curved_native_route",false):check(item.actual_horizontal_motion_m>=240,"Actual curved motion meets the original 240m minimum")
			cases.append(item)
	check(cases.size()==6,"Six actual custom-scale routes, none silently omitted")
	hashes["res://tools/biome_extensions/save_custom_junction_walks.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/save_custom_junction_walks.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_junction_navigation_walk.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Aggregation of two guarded three-seed minimum/maximum-scale navigation-admitted native capsule returns, nominal 240m or longer tracked curved motion, complete worker payloads and physical clearance. Original steep geometric site and failed approaches remain separate expected-rejection evidence, not claimed repaired. Full maximum_lod 6 hierarchy retained. Preload pauses permitted; not uninterrupted performance, arbitrary slopes/settings or whole-world navigation acceptance."},"  "))
	print("CUSTOM_SCALE_WALKS_VERIFIED ",cases.size()," cases; failures=",failures);quit(0 if failures.is_empty() else 1)
