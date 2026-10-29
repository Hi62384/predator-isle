extends SceneTree
func _initialize()->void:
	var hashes:Dictionary={};var images:Dictionary={};var reports:Dictionary={}
	for name:String in ["check_fan_geometry","check_fan_apron_collision","render_fan_aprons","check_streamed_wash","check_catchment_support","check_segment_index","check_incised_profiles"]:
		var path:String="res://tools/badlands/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(report is Dictionary and report.failures.is_empty() and report.get("passed",true))
		if report.has("sampler_sha256"):assert(report.sampler_sha256==FileAccess.get_sha256("res://scripts/badlands_sampler.gd"))
		for source:String in report.get("source_sha256",{}):assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale fan evidence "+source);hashes[source]=report.source_sha256[source]
		for image:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(image)==report.capture_sha256[image]);images[image]=report.capture_sha256[image]
		hashes[path]=FileAccess.get_sha256(path);reports[name]=report
	assert(images.size()==18 and reports.render_fan_aprons.phases.size()==9 and reports.check_fan_apron_collision.cases.size()==3)
	for record:Dictionary in reports.check_fan_apron_collision.cases:assert(record.completed and record.dry and record.max_unsupported_drop<.1 and record.walked_metres>1080)
	for phase:Dictionary in reports.render_fan_aprons.phases:
		assert(phase.worker_probes>0)
		if int(phase.phase)==2:assert(phase.reference_return_exact)
	assert(reports.check_streamed_wash.completed and reports.check_streamed_wash.committed_cuts==27 and reports.check_streamed_wash.max_unsupported_drop_metres<.1)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var source:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(source)==regression.source_sha256[relative]);hashes[source]=regression.source_sha256[relative]
	# Keep raw warning-bearing logs in the immutable source/evidence snapshot.
	# The engine and stderr copies describe the same event, not two warnings.
	var logs:Array=[]
	for name:String in ["check_fan_geometry","check_fan_apron_collision","render_fan_aprons","fan_streamed_wash","fan_check_catchment_support","fan_check_segment_index","fan_check_incised_profiles","fan_check_invariants"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(path):hashes[path]=FileAccess.get_sha256(path);logs.append(path)
	for path:String in ["res://tools/badlands/save_fan_apron_adoption.gd","res://tools/badlands/check_catchment_support.gd","res://tools/badlands/check_segment_index.gd","res://tools/badlands/check_incised_profiles.gd","res://tools/badlands/check_invariants.gd","res://data/surface_regression_20261018.json"]:hashes[path]=FileAccess.get_sha256(path)
	var warning_path:String="res://.godot/extensions_check_fan_apron_collision.engine.log"
	var warning:bool=FileAccess.get_file_as_string(warning_path).contains("job system exceeded the maximum number of jobs")
	assert(warning,"Preserve the observed engine warning, do not silently relabel it clean")
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":hashes,"capture_sha256":images,"numeric_assertions":reports.check_fan_geometry.assertions,"native_phases":reports.render_fan_aprons.phases,"apron_collision_returns":reports.check_fan_apron_collision.cases,"existing_streamed_wash":reports.check_streamed_wash,"shared_regression_scripts":31,"raw_logs":logs,"warning":{"observed":warning,"engine":"Godot4.6.1 Jolt","scope":"One warning printed by WARN_PRINT_ONCE during the static apron collision test; stderr repeats that same message. All three routes completed. The exact engine source waits100 microseconds and reclaims completed jobs when allocation fails. This does not establish the cause, underlying frequency, a project fix or a performance pass.","primary_source":"https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/modules/jolt_physics/spaces/jolt_job_system.cpp"},"runner_observation_transcribed":{"native_sampled_private_peak_mib":1272.6,"native_limit_mib":2048,"collision_sampled_private_peak_mib":112.5,"collision_limit_mib":1024,"sample_period_ms":500,"not_isolated":true},"scope":"Finite trunk-aligned widening aprons with narrow feeder throats, finite toes, unchanged conservative support and independent exact zero mode against the full frozen original sampler. Primary wash floor protection retained.7398 numeric checks,18 native views and three actual1.09km static mesh/capsule returns across fixed on-land fan provinces. Separate original2.74km production-streamed wash return passes27 cuts. All31 shared surface checks pass. Original scene lighting unchanged. Visually modest geometry improvement: lowland sediment materials/distant terrain remain soft, broad and repetitive; these views do not confer reference-quality sign-off. No general performance, all-world traversal or cave completion claim."}
	for target:String in ["res://data/badlands_fan_apron_adoption.json","res://tools/biome_extensions/artifacts/badlands_fan_apron_adoption.json"]:FileAccess.open(target,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BADLANDS_FAN_ADOPTION_SAVED ",hashes.size()," guards / ",images.size()," native images");quit()
