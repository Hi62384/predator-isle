extends SceneTree
func _initialize()->void:
	var copies:Dictionary={}
	for variant:String in ["0_0","8_0","0_1","8_1"]:copies["res://tools/biome_extensions/artifacts/probe_junction_preload_"+variant+".json"]=false
	for path:String in ["res://scenes/main.tscn","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/route_probe.gd","res://tools/biome_extensions/check_streamed_roundtrip.gd","res://tools/biome_extensions/check_junction_walk.gd","res://tools/biome_extensions/probe_junction_preload.gd","res://tools/biome_extensions/preserve_preload_diagnostic.gd"]:copies[path]=true
	for log_name:String in ["check_junction_walk","probe_preload_off","probe_preload_yield","preload_matrix_8_0","preload_matrix_0_1"]:
		for suffix:String in ["out","err","engine"]:
			var path:String="res://.godot/extensions_"+log_name+"."+suffix+".log"
			if FileAccess.file_exists(path):copies[path]=false
	var destination:String="res://tools/biome_extensions/artifacts/revisions/preload_poll_diagnostic_"+Time.get_date_string_from_system().replace("-","")+"_"+FileAccess.get_sha256("res://tools/biome_extensions/check_streamed_roundtrip.gd").left(12)
	var records:Array=[]
	for original:String in copies:
		assert(FileAccess.file_exists(original));var target:String=destination+"/"+("sources/" if copies[original] else "evidence/")+original.trim_prefix("res://")+(".txt" if copies[original] else "")
		var absolute:String=ProjectSettings.globalize_path(target);assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())==OK)
		if FileAccess.file_exists(target):assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original),"Do not replace differing diagnostic history")
		else:assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(original),absolute)==OK)
		assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original));records.append({"original":original,"snapshot":target,"sha256":FileAccess.get_sha256(target)})
	var manifest:String=destination+"/manifest.json"
	if not FileAccess.file_exists(manifest):FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"source_snapshot_utc":Time.get_datetime_string_from_system(true),"files":records,"all_user_tasks_complete":false,"scope":"Forensic failed walk/preload diagnostics and source captured before polling-harness change. Raw probes had no run-time source guards; these are preservation-time snapshots, not a guarded performance or walking certificate. Includes unsuccessful no-yield diagnostics rather than silently omitting them."},"  "))
	print("PRELOAD_DIAGNOSTIC_PRESERVED ",destination," ",records.size()," verified copies");quit()
