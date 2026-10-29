extends SceneTree
func _initialize()->void:
	var args:Dictionary={}
	for arg:String in OS.get_cmdline_user_args():
		var parts:PackedStringArray=arg.split("=",true,1)
		if parts.size()==2:args[parts[0]]=parts[1]
	var fixture:String=args.get("fixture","");var label:String=args.get("label","")
	assert(fixture.is_valid_identifier() and label.is_valid_identifier())
	var cap:int=int(args.get("cap","2048"));var observed:float=float(args.get("observed","0"));var engine_pid:int=int(args.get("pid","0"));assert(observed>cap and cap>0 and engine_pid>0)
	var hashes:Dictionary={}
	var inventory=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(inventory is Dictionary)
	for path:String in inventory.source_sha256:
		var canonical:String="res://"+path.replace("\\","/");hashes[canonical]=FileAccess.get_sha256(canonical)
	for path:String in ["res://tools/biome_extensions/"+fixture+".gd","res://tools/biome_extensions/render_alien_memory_baseline.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/record_resource_limit_failure.gd","res://tools/biome_extensions/run_test.ps1","res://.godot/extensions_"+fixture+".out.log","res://.godot/extensions_"+fixture+".err.log","res://.godot/extensions_"+fixture+".engine.log"]:
		assert(FileAccess.file_exists(path));hashes[path]=FileAccess.get_sha256(path)
	var output:String="res://tools/biome_extensions/artifacts/"+label+".json";assert(not FileAccess.file_exists(output),"Do not overwrite an existing forensic result")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["Runner stopped its own engine after its 500ms private-memory sample exceeded the predeclared "+str(cap)+"MiB cap; no completed result."],"source_sha256":hashes,"preserved_utc":Time.get_datetime_string_from_system(true),"fixture":fixture,"memory_limit_mib":cap,"observed_private_mib":observed,"sample_period_ms":500,"engine_pid":engine_pid,"production_registration":false,"scope":"Forensic preservation-time snapshot of current source/log bytes. Memory sample and PID are transcribed from the runner exception, not independently present in the engine log, certified peak, successful render or isolated compiler-cause measurement."},"  "))
	quit()
