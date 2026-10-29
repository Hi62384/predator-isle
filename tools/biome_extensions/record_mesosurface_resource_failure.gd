extends SceneTree
func _initialize()->void:
	var second:bool=OS.get_cmdline_user_args().has("trial=2")
	var third:bool=OS.get_cmdline_user_args().has("trial=3")
	var fourth:bool=OS.get_cmdline_user_args().has("trial=4")
	var fifth:bool=OS.get_cmdline_user_args().has("trial=5")
	var sixth:bool=OS.get_cmdline_user_args().has("trial=6")
	var observed:float=2050.5 if sixth else (2209.6 if fifth else (2201.4 if fourth else (2195.5 if third else (2162.1 if second else 2180.7))));var engine_pid:int=31460 if sixth else (28920 if fifth else (15480 if fourth else (22788 if third else (4684 if second else 19136))))
	var hashes:Dictionary={}
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed)
	for path:String in regression.source_sha256:
		var canonical:String="res://"+path.replace("\\","/");assert(FileAccess.get_sha256(canonical)==regression.source_sha256[path]);hashes[canonical]=regression.source_sha256[path]
	for path:String in ["res://tools/biome_extensions/alien_mesosurface_candidate.gdshaderinc","res://tools/biome_extensions/render_alien_mesosurface_candidate.gd","res://tools/biome_extensions/record_mesosurface_resource_failure.gd","res://tools/biome_extensions/run_test.ps1","res://.godot/extensions_render_alien_mesosurface_candidate.out.log","res://.godot/extensions_render_alien_mesosurface_candidate.err.log","res://.godot/extensions_render_alien_mesosurface_candidate.engine.log"]:hashes[path]=FileAccess.get_sha256(path)
	assert(not FileAccess.file_exists("res://tools/biome_extensions/artifacts/render_alien_mesosurface_candidate.json"),"Do not replace a completed result with this forensic record")
	var report_path:String="res://tools/biome_extensions/artifacts/render_alien_mesosurface_candidate_resource_failure"+("_v6" if sixth else ("_v5" if fifth else ("_v4" if fourth else ("_v3" if third else ("_v2" if second else "")))))+".json"
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["Runner stopped its own engine PID"+str(engine_pid)+" after observing "+str(observed)+"MiB private memory against the predeclared 2048MiB limit; no native capture/result was produced."],"source_sha256":hashes,"preserved_utc":Time.get_datetime_string_from_system(true),"memory_limit_mib":2048,"observed_private_mib":observed,"sample_period_ms":500,"engine_pid":engine_pid,"production_registration":false,"scope":"Forensic preservation-time snapshot of the failed private material trial. Memory observation comes from the runner's returned exception, not a claimed engine log metric or true peak. Source hashes verified at preservation time against the unchanged shared regression; no successful render/performance/art certificate. The private engine alone was stopped, and no production code, memory limit or timeout was changed."},"  "))
	quit()
