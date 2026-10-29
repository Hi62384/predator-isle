extends SceneTree
func _initialize()->void:
	var conflict:int=0
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("conflict="):conflict=int(arg.trim_prefix("conflict="))
	assert(conflict in [0,1])
	var input:String="res://tools/biome_extensions/artifacts/check_insect_streamed_burrow_"+str(conflict)+".json"
	var report=JSON.parse_string(FileAccess.get_file_as_string(input));assert(report.passed)
	for path:String in report.source_sha256:assert(FileAccess.get_sha256(path)==report.source_sha256[path],"Current streamed-walk source required")
	report.source_sha256[input]=FileAccess.get_sha256(input)
	report.source_sha256["res://tools/biome_extensions/bind_insect_streamed_logs.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/bind_insect_streamed_logs.gd")
	var warning_count:int=0
	for suffix:String in ["engine.log","out.log","err.log"]:
		var source:String="res://.godot/extensions_check_insect_streamed_burrow."+suffix
		var copy:String="res://tools/biome_extensions/artifacts/insect_streamed_"+str(conflict)+"."+suffix
		assert(FileAccess.file_exists(source))
		if FileAccess.file_exists(copy):assert(FileAccess.get_sha256(copy)==FileAccess.get_sha256(source),"Never overwrite differing raw walk logs")
		else:assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(copy))==OK)
		assert(FileAccess.get_sha256(copy)==FileAccess.get_sha256(source));report.source_sha256[copy]=FileAccess.get_sha256(copy)
		if suffix=="engine.log":warning_count=FileAccess.get_file_as_string(copy).count("Jolt Physics job system exceeded the maximum number of jobs.")
	report["jolt_job_capacity_warning_count"]=warning_count
	report["warning_note"]="Raw engine/output/error logs are bound. Any Jolt job-capacity warning was observed in this accelerated headless fixture; route completion does not isolate its cause or certify frame-time stability. No physics job settings, four terrain workers, capsule, route or preload limits were altered."
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_streamed_burrow_"+str(conflict)+"_bound.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INSECT_STREAMED_LOGS_BOUND conflict=",conflict," Jolt warnings=",warning_count);quit()
