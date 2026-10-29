extends SceneTree
## Preserve a failed source-stability run WITHOUT rebinding unavailable bytes.
## Missing originals are explicit;this can never certify a passing experiment.
func _initialize()->void:
	var name:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("report="):name=arg.trim_prefix("report=")
	assert(name.is_valid_identifier());var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report is Dictionary and not report.passed and not report.failures.is_empty())
	var destination:String="res://tools/biome_extensions/artifacts/revisions/unbound_failed_"+name+"_"+FileAccess.get_sha256(path).left(12);var copies:Dictionary={path:FileAccess.get_sha256(path),get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)};var unavailable:Array=[]
	for source:String in report.source_sha256:
		if FileAccess.get_sha256(source)==report.source_sha256[source]:copies[source]=report.source_sha256[source]
		else:unavailable.append({"original":source,"original_sha256":report.source_sha256[source],"current_sha256":FileAccess.get_sha256(source),"status":"Original bytes unavailable;NO replacement or hash rebinding"})
	for capture:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(capture)==report.capture_sha256[capture]);copies[capture]=report.capture_sha256[capture]
	for suffix:String in ["out.log","err.log","engine.log"]:
		var log_path:String="res://.godot/extensions_"+name+"."+suffix
		if FileAccess.file_exists(log_path):copies[log_path]=FileAccess.get_sha256(log_path)
	var records:Array=[]
	for original:String in copies:
		var target:String=destination+"/files/"+original.trim_prefix("res://")+".txt";assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))==OK)
		if not FileAccess.file_exists(target):assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(original),ProjectSettings.globalize_path(target))==OK)
		assert(FileAccess.get_sha256(target)==copies[original]);records.append({"original":original,"snapshot":target,"sha256":copies[original]})
	var manifest:String=destination+"/manifest.json"
	if not FileAccess.file_exists(manifest):FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"report":path,"passed":false,"files":records,"unavailable_original_sources":unavailable,"scope":"FAILED source-stability diagnostic retained byte-for-byte,including original failures and captures. Available source bytes verified against ORIGINAL report;unavailable originals explicitly listed and NEVER substituted. Not complete source recovery,current-source proof,acceptance or completion."},"  "))
	print("UNBOUND_FAILED_DIAGNOSTIC_PRESERVED ",destination," files=",records.size()," unavailable=",unavailable);quit()
