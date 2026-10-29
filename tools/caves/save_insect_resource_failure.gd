extends SceneTree
## External watcher killed the owned fixture before its normal final report.
## Preserve that incomplete result and exact source BEFORE optimization.
func _initialize()->void:
	var guards:Dictionary={};var images:Dictionary={};var peak:float=2049.9;var process_id:int=45608;var run_name:String="check_cave_live_insect_return";var prefix:String="cave_insect_live_"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("peak="):peak=float(arg.trim_prefix("peak="))
		if arg.begins_with("pid="):process_id=int(arg.trim_prefix("pid="))
		if arg.begins_with("run="):run_name=arg.trim_prefix("run=")
		if arg.begins_with("prefix="):prefix=arg.trim_prefix("prefix=")
	assert(run_name in ["check_cave_live_insect_return","check_cave_live_insect_presented_return"])
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scenes/main.tscn","res://project.godot","res://config/caves/cave_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_partition.gd","res://scripts/terrain_collision.gd","res://tools/caves/check_live_insect_return.gd","res://tools/caves/check_live_portal.gd","res://tools/caves/save_insect_resource_failure.gd","res://tools/caves/check_"+run_name.trim_prefix("check_cave_")+".gd","res://.godot/extensions_"+run_name+".engine.log","res://.godot/extensions_"+run_name+".err.log"]:
		if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	for name:String in DirAccess.get_files_at("res://tools/biome_extensions/artifacts"):
		if name.begins_with(prefix) and name.ends_with(".png"):var path:String="res://tools/biome_extensions/artifacts/"+name;images[path]=FileAccess.get_sha256(path)
	var text:String=FileAccess.get_file_as_string("res://.godot/extensions_"+run_name+".engine.log");var pattern:=RegEx.new();assert(pattern.compile("LIVE_CAVE_WALK waypoint=(\\d+)/(\\d+) metres=([0-9.]+) cuts=(\\d+) cells=(\\d+) drop=([0-9.]+)")==OK);var matches:Array[RegExMatch]=pattern.search_all(text);assert(not matches.is_empty());var last:RegExMatch=matches[-1];var report:Dictionary={"passed":false,"checks":guards.size()+1,"failures":["External500ms watcher stopped ONLY owned engine%d at%.1fMiB,above original2048MiB cap;return incomplete"%[process_id,peak]],"source_sha256":guards,"capture_sha256":images,"seed":73921,"fixed_region":"(7,-2)","original_run":run_name,"last_logged_waypoint":int(last.get_string(1)),"waypoints":int(last.get_string(2)),"last_logged_distance_m":float(last.get_string(3)),"last_logged_drop_m":float(last.get_string(6)),"last_logged_committed_cuts":int(last.get_string(4)),"externally_transcribed_observed_private_mib":peak,"original_limit_mib":2048,"scope":"Failed/incomplete original actual Insect live-main-scene surface/chamber/return. Resource watchdog terminated its own fixture before normal final JSON. Actual progress/images/logs retained,NOT a passed complete return or old-gate waiver. Time,scene,route,capsule and resource limits were not enlarged."};FileAccess.open("res://tools/biome_extensions/artifacts/failed_cave_live_insect_resource.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("FAILED_INSECT_RESOURCE_SAVED incomplete",last.get_string(1),"/",last.get_string(2)," at",peak,"/2048MiB");quit()
