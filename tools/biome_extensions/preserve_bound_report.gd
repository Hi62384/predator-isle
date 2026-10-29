extends SceneTree
## Preserve an UNCHANGED historical report when an explicitly named generated
## dependency has since been replaced. Only an existing hash-verified frozen
## manifest may supply old bytes;never substitute or rebind different source.
func _initialize()->void:
	var name:String="";var dependency:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("report="):name=arg.trim_prefix("report=")
		if arg.begins_with("dependency_manifest="):dependency=arg.trim_prefix("dependency_manifest=")
	assert(name.is_valid_identifier() and dependency.begins_with("res://tools/biome_extensions/artifacts/revisions/") and dependency.ends_with("/manifest.json") and not dependency.contains(".."))
	var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.get("passed",false) and report.get("failures",[]).is_empty());var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dependency));var available:Dictionary={}
	for record:Dictionary in frozen.files:
		assert(FileAccess.get_sha256(record.snapshot)==record.sha256,"Existing frozen dependency integrity "+str(record.original));available[str(record.original)]=record
	var sources:Dictionary=report.source_sha256.duplicate();sources[path]=FileAccess.get_sha256(path);sources[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);sources[dependency]=FileAccess.get_sha256(dependency)
	for capture:String in report.get("capture_sha256",{}):sources[capture]=report.capture_sha256[capture]
	var destination:String="res://tools/biome_extensions/artifacts/revisions/bound_experiment_"+name+"_"+FileAccess.get_sha256(path).left(12);var records:Array=[]
	for original:String in sources:
		var expected:String=sources[original];var resolved:String=original
		if FileAccess.get_sha256(original)!=expected:
			assert(available.has(original) and available[original].sha256==expected,"No original verified bytes available for historical dependency "+original);resolved=available[original].snapshot
		assert(FileAccess.get_sha256(resolved)==expected)
		var target:String=destination+"/files/"+original.trim_prefix("res://")+".txt";assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))==OK)
		if not FileAccess.file_exists(target):assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(resolved),ProjectSettings.globalize_path(target))==OK)
		assert(FileAccess.get_sha256(target)==expected);records.append({"original":original,"sha256":expected,"snapshot":target,"resolved_from":resolved})
	var manifest:String=destination+"/manifest.json"
	if not FileAccess.file_exists(manifest):FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"report":path,"files":records,"dependency_manifest":dependency,"scope":"Unchanged historical report and exact originally guarded bytes,recovered only from an explicitly provided pre-existing hash-verified frozen dependency when its generated current path changed. No report/hash rewrite,no claim of current-source regression or all-task completion."},"  "))
	print("BOUND_HISTORICAL_REPORT_PRESERVED ",destination," ",records.size()," verified copies");quit()
