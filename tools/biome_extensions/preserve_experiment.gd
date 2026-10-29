extends SceneTree
func _initialize()->void:
	var name:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("report="):name=arg.trim_prefix("report=")
	assert(not name.is_empty() and name.is_valid_identifier(),"Explicit local report basename required")
	var report_path:String="res://tools/biome_extensions/artifacts/"+name+".json"
	var report=JSON.parse_string(FileAccess.get_file_as_string(report_path));assert(report is Dictionary and report.has("source_sha256"))
	if report.has("passed"):assert(report.passed)
	if report.has("failures"):assert(report.failures.is_empty())
	var destination:String="res://tools/biome_extensions/artifacts/revisions/experiment_"+name+"_"+FileAccess.get_sha256(report_path).left(12)
	var copies:Dictionary={report_path:false,"res://tools/biome_extensions/preserve_experiment.gd":true}
	for source:String in report.source_sha256:
		assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Experiment source changed before preservation "+source);copies[source]=true
	for capture:Dictionary in report.get("captures",[]):
		var path:String=capture.path if capture.has("path") else "res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png"
		assert(path.begins_with("res://tools/") and not path.contains(".."),"Capture must identify an explicit local tool artifact")
		assert(FileAccess.get_sha256(path)==capture.sha256,"Experiment pixels changed before preservation");copies[path]=false
	for path:String in report.get("capture_sha256",{}):
		assert(FileAccess.get_sha256(path)==report.capture_sha256[path]);copies[path]=false
	var records:Array=[]
	for original:String in copies:
		var target:String=destination+"/"+("sources/" if copies[original] else "evidence/")+original.trim_prefix("res://")+(".txt" if copies[original] else "")
		var absolute:String=ProjectSettings.globalize_path(target);assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())==OK)
		if FileAccess.file_exists(target):assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original),"Never replace differing historical evidence")
		else:assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(original),absolute)==OK)
		assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original));records.append({"original":original,"snapshot":target,"sha256":FileAccess.get_sha256(target),"source_snapshot":copies[original]})
	var manifest:String=destination+"/manifest.json"
	if not FileAccess.file_exists(manifest):FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"created_utc":Time.get_datetime_string_from_system(true),"report":report_path,"files":records,"scope":"Recoverable experiment evidence only; source/pixel integrity is not production adoption or full task completion."},"  "))
	print("EXPERIMENT_PRESERVED ",destination," ",records.size()," verified copies");quit()
