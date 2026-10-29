extends SceneTree
const REPORTS=["render_cave_default_rooms","check_cave_indexed_surface","check_cave_live_hive_frontier_return","check_cave_lighting","check_cave_surface_transaction","check_cave_hive_entry_material"]
const DEEP_ARCHIVE="res://tools/biome_extensions/artifacts/revisions/experiment_check_cave_live_default_registry_deep_f054ad99c24a/"
var guards:Dictionary={}
func bind(path:String,digest:String)->void:
	assert(FileAccess.get_sha256(path)==digest,"Stale projection checkpoint source "+path)
	if guards.has(path):assert(guards[path]==digest,"Conflicting projection checkpoint evidence "+path)
	guards[path]=digest
func _initialize()->void:call_deferred("run")
func run()->void:
	var summaries:Dictionary={};var pictures:Dictionary={}
	for name:String in REPORTS:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty());bind(path,FileAccess.get_sha256(path))
		for source:String in report.source_sha256:bind(source,report.source_sha256[source])
		for picture:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(picture)==report.capture_sha256[picture]);pictures[picture]=report.capture_sha256[picture]
		summaries[name]={"checks":report.checks,"report":path,"sha256":FileAccess.get_sha256(path),"scope":report.get("scope","")}
		var receipt:String="res://.godot/extensions_"+name+".receipt.json"
		if FileAccess.file_exists(receipt):var observation:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(receipt));assert(observation.passed);bind(receipt,FileAccess.get_sha256(receipt));summaries[name]["runner_observation"]=observation
	var regression_path:String="res://data/surface_regression_20261018.json";var regression:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);bind(regression_path,FileAccess.get_sha256(regression_path))
	for source:String in regression.source_sha256:bind("res://"+source.replace("\\","/"),regression.source_sha256[source])
	# This is an explicitly HISTORICAL full physical run,not a report rebound
	# to changed shaders. Its unchanged numeric kernel is checked independently.
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEEP_ARCHIVE+"manifest.json"));bind(DEEP_ARCHIVE+"manifest.json",FileAccess.get_sha256(DEEP_ARCHIVE+"manifest.json"));var deep:Dictionary={}
	for record:Dictionary in manifest.files:
		var copy_path:String=record.snapshot;assert(FileAccess.get_sha256(copy_path)==record.sha256)
		if str(record.original).ends_with("/check_cave_live_default_registry_deep.json"):deep=JSON.parse_string(FileAccess.get_file_as_string(copy_path));bind(copy_path,record.sha256)
	assert(not deep.is_empty() and deep.passed and deep.walk.finished and deep.walk.maximum_canonical_depth_m>300 and deep.walk.maximum_unsupported_drop_m<.75)
	for source:String in ["res://scripts/caves/field.gd","res://scripts/caves/mesher.gd","res://scripts/caves/workload.gd","res://scripts/caves/network.gd"]:assert(FileAccess.get_sha256(source)==deep.source_sha256[source],"Physical dependency kernel changed;full return must be refreshed")
	var audit_path:String="res://tools/biome_extensions/artifacts/cave_engine_mode_metadata_audit.json";var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(audit_path));assert(audit.passed);bind(audit_path,FileAccess.get_sha256(audit_path))
	assert(not load("res://config/caves/cave_settings.tres").enabled and FileAccess.get_sha256("res://scenes/main.tscn")=="5eb02b7c56d22b44757ba94ff29b0bbd20bfc81cdf1297b82bb4485e77d94699")
	bind(get_script().resource_path,FileAccess.get_sha256(get_script().resource_path));var result:Dictionary={"passed":true,"checks":guards.size()+REPORTS.size()+6,"failures":[],"source_sha256":guards,"capture_sha256":pictures,"reports":summaries,"shared_regressions":31,"historical_deep_run":{"archive":DEEP_ARCHIVE,"walk":deep.walk,"scope":"Pre-projection118check24.736km physical run;field/mesher/workload/network hashes still exact. Shaders/test metadata changed;not claimed as a current-shader full deep run. Actual authoritative engine mode was fixed-fps60;original false fixture boolean is audited separately."},"projection_microseams_fixed_in_12_original_views":true,"unchanged_native_geometry":true,"runtime_enabled_by_default":false,"all_user_tasks_complete":false,"frozen_implemented":false,"crystal_caverns_implemented":false,"magma_caverns_implemented":false,"scope":"Current-source cave-only shared camera-grid-relative projection checkpoint. Original12actual Default room/lobe/pool views have zero uncovered geometry pixels;production equals private correction and independent off restores complete old images/defects. Natural and explicitly labelled test-only illumination,real calcite/water.18indexing equivalence images,actual original972mHive entrance return,real double-sided roof/sun-off controls and atomic native surface transaction pass. Original main/global terrain shader unchanged;active cut-parent copies use same projection.31shared regressions refreshed. Full deep physical run is historical with unchanged numeric kernels,explicitly not rebound. No all-world/art/uninterrupted FPS or later biome/all-user completion."};var encoded:String=JSON.stringify(result,"  ");FileAccess.open("res://data/cave_projection_checkpoint.json",FileAccess.WRITE).store_string(encoded);FileAccess.open("res://tools/biome_extensions/artifacts/cave_projection_checkpoint.json",FileAccess.WRITE).store_string(encoded);print("PROJECTION_CHECKPOINT ",result.checks," reports=",REPORTS.size()," pictures=",pictures.size());quit()
