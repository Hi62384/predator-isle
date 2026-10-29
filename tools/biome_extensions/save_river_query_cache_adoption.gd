extends SceneTree
var guards:Dictionary={}
func checked(path:String)->Dictionary:
	var report=JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.get("passed",report.get("completed",false)) and report.failures.is_empty())
	guards[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:
		assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale cache evidence "+source);guards[source]=report.source_sha256[source]
	return report
func _initialize()->void:
	var numeric:=checked("res://tools/biome_extensions/artifacts/check_river_query_identity.json")
	var meshes:=checked("res://tools/biome_extensions/artifacts/check_river_cached_meshes.json")
	checked("res://tools/biome_extensions/artifacts/check_river_formula_contract.json")
	var native:=checked("res://tools/biome_extensions/artifacts/render_river_cache_reference.json")
	var walk:=checked("res://tools/badlands/artifacts/check_streamed_wash.json")
	var aprons:=checked("res://tools/badlands/artifacts/check_fan_apron_collision.json")
	var prototype:=checked("res://tools/badlands/artifacts/check_fan_gradient_candidate.json")
	assert(numeric.assertions==486 and meshes.cases.size()==36 and native.phases.size()==9 and native.views.size()==18 and aprons.cases.size()==3)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);guards[path]=regression.source_sha256[relative]
	for name:String in ["check_river_query_identity","check_river_cached_meshes","check_river_formula_contract","render_river_cache_reference","cache_check_streamed_wash","cache_check_fan_apron_collision"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/biome_extensions/save_river_query_cache_adoption.gd","res://data/surface_regression_20261018.json"]:guards[path]=FileAccess.get_sha256(path)
	for path:String in native.capture_sha256:assert(FileAccess.get_sha256(path)==native.capture_sha256[path])
	var result:Dictionary={"passed":true,"failures":[],"source_sha256":guards,"capture_sha256":native.capture_sha256,"production_registration":true,"all_user_tasks_complete":false,"completed_utc":Time.get_datetime_string_from_system(true),"identity_assertions":numeric.assertions,"complete_payload_pairs":meshes.cases.size(),"native_phases":native.phases.size(),"native_cross_scene_pixel_equivalent":native.cross_scene_pixel_equivalent,"native_cross_scene_pixel_differences":native.cross_scene_pixel_differences,"graded_fan_private_assertions":prototype.assertions,"streamed_wash":walk,"static_apron_returns":aprons.cases,"sampled_resource_observations_transcribed":{"native_mib":1441.1,"native_limit_mib":4096,"wash_mib":551.0,"aprons_mib":112.7,"physics_limit_mib":1024,"sample_period_ms":500,"isolated":false},"scope":"Fix exact-input river cache identity only. Integer-X memo keys,active spacing namespaces,and fractional bypass preserve the original numerical formula in three exact frozen statement blocks. Capacities unchanged;31 shared regressions,486 cold-oracle identity checks,36 full payload pairs and9 actual cached/oracle/cached worker cuts pass over three seeds. Complete terrain/water/feature/structure/collision geometry exact and canonical worker probes pass.18 images retained;cross-scene bytes differ and are not certified equivalent. Existing2.74km accelerated streamed wash and three static apron returns pass;preload pauses retained. Jolt job-capacity warning recurred during wash test and is not fixed. Private graded-fan metadata differences disappear with this repair but its production/art/physical acceptance is separate. No changed river numerical formula,universal performance,all-surface or cave completion claim."}
	for path:String in ["res://data/river_query_cache_adoption.json","res://tools/biome_extensions/artifacts/river_query_cache_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("RIVER_QUERY_CACHE_ADOPTED ",guards.size()," guards /18 images");quit()
