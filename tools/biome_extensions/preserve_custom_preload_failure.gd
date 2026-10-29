extends SceneTree
func _initialize()->void:
	var failure_log:String="res://.godot/extensions_check_junction_custom_walk.err.log"
	assert(FileAccess.get_file_as_string(failure_log).contains("Real streamed route preload timeout"),"Preserve only the actual failed preload, not a success substitute")
	var copies:Dictionary={}
	for suffix:String in ["err","out","engine"]:copies["res://.godot/extensions_check_junction_custom_walk."+suffix+".log"]=false
	copies["res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"]=false
	for path:String in ["res://scenes/main.tscn","res://project.godot","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://tools/biome_extensions/check_junction_custom_walk.gd","res://tools/biome_extensions/check_streamed_roundtrip.gd","res://tools/biome_extensions/route_probe.gd","res://tools/biome_extensions/run_test.ps1","res://tools/biome_extensions/preserve_custom_preload_failure.gd"]:copies[path]=true
	var destination:String="res://tools/biome_extensions/artifacts/revisions/custom_preload_timeout_"+Time.get_date_string_from_system().replace("-","")+"_"+FileAccess.get_sha256(failure_log).left(12)
	var records:Array=[]
	for original:String in copies:
		assert(FileAccess.file_exists(original));var target:String=destination+"/"+("sources/" if copies[original] else "evidence/")+original.trim_prefix("res://")+(".txt" if copies[original] else "")
		var absolute:String=ProjectSettings.globalize_path(target);assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())==OK)
		if FileAccess.file_exists(target):assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original),"Never replace distinct failed fixture history")
		else:assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(original),absolute)==OK)
		assert(FileAccess.get_sha256(target)==FileAccess.get_sha256(original));records.append({"original":original,"snapshot":target,"sha256":FileAccess.get_sha256(target)})
	var manifest:String=destination+"/manifest.json"
	if not FileAccess.file_exists(manifest):FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"preserved_utc":Time.get_datetime_string_from_system(true),"files":records,"passed":false,"all_user_tasks_complete":false,"scope":"Forensic preservation-time source/log snapshot of an actual minimum-scale native preload failure under the unchanged 180s budget. Raw logs retain any completed cases, Jolt warnings and exact failure; no final passing report is inferred. Sources hashed at preservation time, not a run-time source-guarded performance certificate. Engine fixture was stopped by its own test wrapper; no timeout or memory limit was raised."},"  "))
	print("CUSTOM_PRELOAD_FAILURE_PRESERVED ",destination," ",records.size()," verified copies");quit()
