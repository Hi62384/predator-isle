extends SceneTree
## Scoped opt-in integration evidence,not an all-task/default-biome completion.
const REPORTS=["check_cave_live_deep_return","check_cave_live_short_return","check_cave_portal_batch_equivalence","check_cave_queue_refill","check_cave_surface_readiness","check_cave_surface_batch","check_cave_production_core","check_cave_surface_context","check_cave_surface_cut","check_cave_surface_transaction","check_cave_entry_seal","check_cave_lighting","check_cave_formations","check_cave_worker_formations","check_cave_chamber_profiles","check_cave_seepage_basins"]
var guards:Dictionary={}
func bind(path:String,digest:String)->void:
	assert(FileAccess.get_sha256(path)==digest,"Stale checkpoint source "+path)
	if guards.has(path):assert(guards[path]==digest,"Conflicting report source "+path)
	guards[path]=digest
func _initialize()->void:call_deferred("run")
func run()->void:
	var summaries:Dictionary={};var captures:Dictionary={};var deep:Dictionary={}
	for name:String in REPORTS:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report is Dictionary and report.get("passed",false) and report.get("failures",[]).is_empty(),"Required scoped acceptance missing "+name);bind(path,FileAccess.get_sha256(path))
		for source:String in report.source_sha256:bind(source,report.source_sha256[source])
		summaries[name]={"report":path,"sha256":FileAccess.get_sha256(path),"checks":report.get("checks",0),"scope":report.get("scope","")}
		if name=="check_cave_live_deep_return":
			deep=report
			for picture:String in report.capture_sha256:assert(FileAccess.get_sha256(picture)==report.capture_sha256[picture]);captures[picture]=report.capture_sha256[picture]
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);bind(regression_path,FileAccess.get_sha256(regression_path))
	for source:String in regression.source_sha256:bind("res://"+source.replace("\\","/"),regression.source_sha256[source])
	# The short test's generic approach/return filenames are intentionally
	# reused by the deep test. Verify its preserved immutable pixels instead.
	var short_path:String="res://tools/biome_extensions/artifacts/check_cave_live_short_return.json";var short_archive:String="res://tools/biome_extensions/artifacts/revisions/experiment_check_cave_live_short_return_"+FileAccess.get_sha256(short_path).left(12)+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(short_archive));assert(manifest is Dictionary)
	for file:Dictionary in manifest.files:assert(FileAccess.get_sha256(file.snapshot)==file.sha256,"Damaged short-return evidence "+file.snapshot)
	bind(short_archive,FileAccess.get_sha256(short_archive));bind("res://tools/caves/save_live_checkpoint.gd",FileAccess.get_sha256("res://tools/caves/save_live_checkpoint.gd"))
	assert(not load("res://config/caves/cave_settings.tres").enabled,"Checkpoint must not silently enable unfinished cave phases")
	assert(deep.walk.finished and not deep.walk.failed and deep.walk.maximum_unsupported_drop_m<.75 and deep.walk.maximum_canonical_depth_m>=300 and deep.maximum_total_jobs<=4 and deep.maximum_simultaneous_portal_jobs>1)
	var report:Dictionary={"passed":true,"checks":guards.size()+REPORTS.size()+manifest.files.size()+3,"failures":[],"source_sha256":guards,"capture_sha256":captures,"created_utc":Time.get_datetime_string_from_system(true),"reports":summaries,"shared_regressions":31,"short_return_archive":short_archive,"deep_walk":deep.walk,"default_runtime_enabled":false,"all_user_tasks_complete":false,"default_cave_phase_complete":false,"chamber_profile_module_live":false,"seepage_module_live":false,"frozen_implemented":false,"crystal_caverns_implemented":false,"magma_caverns_implemented":false,"scope":"Current-source opt-in cave core integration checkpoint:original actual Spore full live surface/deepest-canonical-chamber/surface physical return,unchanged650s/1.8m/.4m/5mps/45degree/.75mdrop gates,four TOTAL workers including positive parallel portal jobs,complete payload/collider equality,native temporary seal and real roof shadowing,zero-density formations and31shared regressions. Render loop disabled only during accelerated motion;loading pauses explicit. Debug light temporary and separately labelled. Not all-world/custom-settings/art/LOD/performance acceptance,full Default geology/water,remaining Insect/Alien interiors or later cave biomes. Chamber/seepage component modules remain unconnected. Historical failures and Jolt job warning remain preserved."}
	var text:String=JSON.stringify(report,"  ");FileAccess.open("res://data/cave_live_foundation_checkpoint.json",FileAccess.WRITE).store_string(text);FileAccess.open("res://tools/biome_extensions/artifacts/cave_live_foundation_checkpoint.json",FileAccess.WRITE).store_string(text);print("CAVE_LIVE_FOUNDATION_CHECKPOINT sources=",guards.size()," reports=",REPORTS.size()," actual_depth=",deep.walk.maximum_canonical_depth_m," all_tasks_complete=false");quit()
