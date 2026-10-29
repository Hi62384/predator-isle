extends SceneTree
func _initialize()->void:
	var root_path:String="res://tools/biome_extensions/artifacts/revisions/rejected_distance_bounds_20261019_ac5c8d55acc6"
	var copies:Dictionary={}
	for name:String in ["profile_bounds_work","profile_network_distances","profile_conduit_foundations"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));copies[path]=false
		for original:String in report.source_sha256:
			assert(FileAccess.get_sha256(original)==report.source_sha256[original],"Experiment source changed before preservation")
			copies[original]=true
	var records:Array=[]
	for original:String in copies:
		var target:String=root_path+"/"+("sources/" if copies[original] else "evidence/")+original.trim_prefix("res://")+(".txt" if copies[original] else "")
		var absolute:String=ProjectSettings.globalize_path(target);assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())==OK)
		if FileAccess.file_exists(target):assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original))
		else:assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(original),absolute)==OK)
		assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original));records.append({"original":original,"copy":target,"sha256":FileAccess.get_sha256(target)})
	FileAccess.open(root_path+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"rejected":true,"production_change_kept":false,"reason":"Exact-output conservative bounding skipped most projections but increased median paired network time (ratio 1.0637566); complete foundation median also did not improve. Restore the simpler validated cached-path sampler.","files":records},"  "))
	print("REJECTED_DISTANCE_EXPERIMENT_PRESERVED ",records.size()," verified copies");quit()
