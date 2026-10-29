extends SceneTree
func _initialize()->void:
	var guards:Dictionary={}
	var failure:String="Original live Hive GPU run stopped by owned watchdog on shader compilation: CAMERA_POSITION_WORLD unknown in global helper expression"
	if OS.get_cmdline_user_args().has("style_readback"):failure="Original live Hive GPU run stopped by owned watchdog: int(null) after reading an unused shader-default geological_style uniform in surface staging"
	if OS.get_cmdline_user_args().has("entry_shadow"):failure="Original live Hive GPU run stopped by owned watchdog: entry helper view_distance parameter shadows existing terrain varying;interior shader had compiled but full portal wrapper failed"
	if OS.get_cmdline_user_args().has("startup_memory"):failure="Original live Hive GPU run killed only owned engine15984 at externally sampled2078.2MiB above unchanged2048MiB cap,during initial complete portal staging after40s,last logged17/73cave cells;no completed live traversal"
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scenes/main.tscn","res://project.godot","res://tools/caves/check_live_hive_return.gd","res://tools/caves/check_live_insect_return.gd","res://tools/caves/check_live_portal.gd","res://tools/caves/save_hive_shader_failure.gd","res://.godot/extensions_check_cave_live_hive_return.engine.log","res://.godot/extensions_check_cave_live_hive_return.err.log"]:guards[path]=FileAccess.get_sha256(path)
	var report:Dictionary={"passed":false,"checks":guards.size()+1,"failures":[failure],"source_sha256":guards,"scope":"Incomplete original Hive live-main-scene run. Native graph/core/branch controls passed separately,but the recorded GPU/staging integration error prevents live return acceptance. Exact source/error logs retained before repair."};FileAccess.open("res://tools/biome_extensions/artifacts/failed_hive_live_integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("HIVE_LIVE_FAILURE_SAVED");quit()
