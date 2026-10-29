extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var report_path:String="res://data/alien_surface_followup_20261019.json"
	var report=JSON.parse_string(FileAccess.get_file_as_string(report_path));assert(report.evidence_validated and not report.all_user_tasks_complete)
	var destination:String="res://tools/biome_extensions/artifacts/revisions/alien_"+Time.get_date_string_from_system().replace("-","")+"_"+FileAccess.get_sha256(report_path).left(12)
	var copies:Dictionary={report_path:false}
	for name:String in report.evidence:
		var evidence:Dictionary=report.evidence[name];var path:String=evidence.path;copies[path]=false
		assert(FileAccess.get_sha256(path)==evidence.sha256,"Declared evidence changed before preservation")
		var source=JSON.parse_string(FileAccess.get_file_as_string(path))
		if source.has("capture_sha256"):
			for png:String in source.capture_sha256:
				assert(FileAccess.get_sha256(png)==source.capture_sha256[png],"Native control pixels changed before preservation");copies[png]=false
		for original:String in source.source_sha256:
			var canonical:String=original if original.begins_with("res://") else "res://"+original.replace("\\","/")
			assert(FileAccess.get_sha256(canonical)==source.source_sha256[original],"Declared source changed before preservation")
			copies[canonical]=true
		if name in ["render_junctions","render_carapace","render_production_nerve_fibres","check_debug_light_invariance","render_margin_lod_shores"]:
			for view:Dictionary in source.captures:
				var png:String="res://tools/biome_extensions/artifacts/"+view.biome+"_"+view.view+".png"
				assert(FileAccess.get_sha256(png)==view.sha256);copies[png]=false
		if name=="check_normal_controls":
			for key:String in TerrainSettings.EXTENSION_KEYS:
				for suffix:String in ["on","off","zero"]:copies["res://tools/biome_extensions/artifacts/normal_control_"+key+"_"+suffix+".png"]=false
		if name=="check_authored_color_space_gl_compatibility":copies[path.replace(".json",".png")]=false
	var records:Array=[]
	for original:String in copies:
		assert(FileAccess.file_exists(original),"Missing checkpoint source "+original)
		var target:String=destination+"/"+("sources/" if copies[original] else "evidence/")+original.trim_prefix("res://")+(".txt" if copies[original] else "")
		var absolute:String=ProjectSettings.globalize_path(target);assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())==OK)
		if FileAccess.file_exists(target):assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original),"Never overwrite a different historical checkpoint")
		else:assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(original),absolute)==OK)
		assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original),"Checkpoint copy hash")
		records.append({"original":original,"snapshot":target,"sha256":FileAccess.get_sha256(target),"source_snapshot":copies[original]})
	var manifest:String=destination+"/manifest.json"
	if not FileAccess.file_exists(manifest):FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"created_utc":Time.get_datetime_string_from_system(true),"validated_followup_sha256":FileAccess.get_sha256(report_path),"files":records,"all_user_tasks_complete":false,"scope":"Recoverable source/evidence snapshot of this scoped Alien surface continuation, not an exported game or ZIP delivery."},"  "))
	print("ALIEN_CHECKPOINT ",destination," ",records.size()," verified copies");quit()
