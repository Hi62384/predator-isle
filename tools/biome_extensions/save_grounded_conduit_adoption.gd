extends SceneTree
var guards:Dictionary={}
var images:Dictionary={}
func checked(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/"+name+".json"
	var report=JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.passed and report.failures.is_empty(),name)
	guards[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:
		assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale evidence "+source)
		guards[source]=report.source_sha256[source]
	for capture:String in report.get("capture_sha256",{}):
		assert(FileAccess.get_sha256(capture)==report.capture_sha256[capture])
		images[capture]=report.capture_sha256[capture]
	return report
func _initialize()->void:
	var reports:Dictionary={}
	for name:String in ["check_grounded_conduit_registration","check_grounded_conduit_cache","check_grounded_worker_payloads","check_conduit_shoulders","check_production_conduit_memo","check_junction_admission","render_grounded_conduits","render_grounded_overlay","render_grounded_single_root","check_grounded_positive_walks","check_grounded_local_walk","profile_grounded_worker","check_nerve_fibre_walk","check_junction_walk"]:
		var report:=checked(name)
		reports[name]={"checks":report.get("checks",null),"scope":report.scope}
	assert(images.size()==48)
	var regression_path:String="res://data/surface_regression_20261018.json"
	var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path))
	assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/")
		assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);guards[path]=regression.source_sha256[relative]
	guards[regression_path]=FileAccess.get_sha256(regression_path)
	var history:Array=[]
	for name:String in ["experiment_ground_union_trial_4da5146ad6b0","failed_diagnostic_check_ground_union_worker_walk_domains_aa07f8884a27","failed_diagnostic_check_ground_union_additional_walk_4ba31210453d"]:
		var path:String="res://tools/biome_extensions/artifacts/revisions/"+name+"/manifest.json"
		var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
		for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256)
		guards[path]=FileAccess.get_sha256(path);history.append({"manifest":path,"verified_copies":manifest.files.size(),"historical_not_current_source_proof":true})
	for path:String in ["res://tools/biome_extensions/save_grounded_conduit_adoption.gd","res://tools/biome_extensions/run_test.ps1"]:guards[path]=FileAccess.get_sha256(path)
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"completed_utc":Time.get_datetime_string_from_system(true),"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"caves_implemented":false,"source_sha256":guards,"capture_sha256":images,"reports":reports,"shared_regression_tests":31,"native_images":48,"historical_proofs":history,"median_actual_worker_on_off_ratio":JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/profile_grounded_worker.json")).median_candidate_to_original_ratio,"scope":"Independent default-on hive_grounded_shoulders samples actual canonical support across both near and retained-contact far conduit profiles. Small branches and protected finite-cave approaches retain original shape. Independent false restores complete frozen prior arrays;true matches the archived accepted prototype. No new vertices,texture,atlas,canonical terrain or water change. Both memo classes namespace and propagate the control. Actual configured production controller workers,collision payloads and native images are exercised,not private constructor substitutions.48 native images include same-scene one-root false/true/false in four debug modes,with four exact original returns. Separate actual worker collision and unchanged capsule checks cover two original positive sites and one explicitly additional local route;existing streamed fibre and three junction returns also pass.","limitations":"Not CSG/Boolean union,whole-biome reference-art acceptance,all-world traversal,uninterrupted streaming or a speedup. Full worker median on/off1.030 is added work. The original seed92881 coarse efficacy fixture still fails its original20mm intervention gate;dense independent reference shows a smaller real change. The additional site's long80m approach fails both old and new geometry identically and is NOT repaired by its separate local120m return. Cross-cold-scene image bytes are not certified exact. Original rejected minimum-scale approach and four older light-through intersection pixels remain separate unresolved diagnostics. All ordered cave phases remain queued.","external_watch_observations_transcribed":{"pure_native_peak_mib":1092.3,"overlay_peak_mib":1089.0,"native_limit_mib":2048,"single_root_peak_mib":null,"single_root_peak_note":"Completion report verified;earlier tool result with watcher receipt was not retained in the available context. No peak invented.","positive_walk_peak_mib":324.3,"local_walk_peak_mib":313.2,"walk_limit_mib":1536,"worker_profile_peak_mib":81.1,"worker_profile_limit_mib":1024,"sample_period_ms":500,"machine_gpu_exclusive":false}}
	for path:String in ["res://data/grounded_conduit_adoption.json","res://tools/biome_extensions/artifacts/grounded_conduit_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("GROUNDED_CONDUIT_ADOPTED ",guards.size()," guards / ",images.size()," images");quit()
