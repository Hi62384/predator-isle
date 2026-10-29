extends SceneTree
## Preserve semantic-success/native-shutdown-failure without editing the
## original semantic report or pretending its runner completed successfully.
func _initialize()->void:
	var report_name:String="";var prefix:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("report="):report_name=arg.trim_prefix("report=")
		if arg.begins_with("prefix="):prefix=arg.trim_prefix("prefix=")
	assert(report_name.is_valid_identifier() and prefix.is_valid_identifier())
	var original:String="res://tools/biome_extensions/artifacts/"+report_name+".json";var semantic=JSON.parse_string(FileAccess.get_file_as_string(original));assert(semantic is Dictionary and semantic.get("passed",false));var error_log:String="res://.godot/extensions_"+prefix+".err.log";assert(FileAccess.get_file_as_string(error_log).contains("ERROR:"))
	var guards:Dictionary=semantic.source_sha256.duplicate();guards[original]=FileAccess.get_sha256(original);guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	for suffix:String in ["out.log","err.log","engine.log"]:
		var path:String="res://.godot/extensions_"+prefix+"."+suffix
		if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	var wrapper:Dictionary={"passed":false,"failures":["Native engine reported shutdown ERROR after semantic checks;not an accepted native run."],"source_sha256":guards,"capture_sha256":semantic.get("capture_sha256",{}),"original_semantic_report":original,"scope":"Original semantic report is retained byte-for-byte. Its movement assertions passed,while native runner shutdown failed with resource leaks. This wrapper records the failed overall result without modifying or rebinding original evidence."}
	var output:String="res://tools/biome_extensions/artifacts/"+report_name+"_shutdown_failure.json";FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(wrapper,"  "));print("SHUTDOWN_FAILURE_RECORDED ",output);quit()
