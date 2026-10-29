extends "res://tools/biome_extensions/save_insect_dome_continuation.gd"
const DOME_BASE="res://tools/biome_extensions/artifacts/revisions/experiment_insect_dome_continuation_65670eaa290e"
const ORIGINAL_FAILURE="res://tools/biome_extensions/artifacts/revisions/failed_diagnostic_check_insect_burrow_structures_17_conflict0_with_155e9a310242"
const LEGACY_FAILURE="res://tools/biome_extensions/artifacts/revisions/failed_diagnostic_check_insect_burrow_structures_17_conflict0_with_legacy_af42709b502e"
const NO_MOUND_CONTROL="res://tools/biome_extensions/artifacts/revisions/experiment_check_insect_burrow_structures_17_conflict0_without_b9f07c34f234"
func historical(directory:String)->Dictionary:
	var manifest_path:String=directory+"/manifest.json";bind(manifest_path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for entry:Dictionary in manifest.files:
		assert(FileAccess.get_sha256(entry.snapshot)==entry.sha256,"Historical failure bytes changed");bind(entry.snapshot)
	var report_path:String=directory+"/evidence/"+String(manifest.report).trim_prefix("res://")
	return JSON.parse_string(FileAccess.get_file_as_string(report_path))
func _initialize()->void:
	for path:String in ["res://tools/biome_extensions/save_insect_burrow_continuation.gd","res://tools/biome_extensions/save_insect_dome_continuation.gd","res://tools/biome_extensions/save_insect_vent_continuation.gd"]:bind(path)
	var prior_path:String=DOME_BASE+"/evidence/tools/biome_extensions/artifacts/insect_dome_continuation.json";bind(prior_path)
	var prior=JSON.parse_string(FileAccess.get_file_as_string(prior_path));assert(prior.passed)
	var base_path:String=DOME_BASE+"/sources/scripts/biome_extension_structures.gd.txt";bind(base_path)
	assert(FileAccess.get_sha256(base_path)==prior.source_sha256["res://scripts/biome_extension_structures.gd"])
	var before:String=FileAccess.get_file_as_string(base_path).replace("\r\n","\n")
	var current:String=FileAccess.get_file_as_string("res://scripts/biome_extension_structures.gd").replace("\r\n","\n")
	var start_marker:String="\t\t\t\t\tvar broad_dome:bool=type==3 and sampler.settings.nest_broad_domes\n"
	var end_marker:String="\t\t\t\t\tvar mound_width:float=scale*(.84 if broad_dome else .4)\n"
	assert(before.count(start_marker)==1 and current.count(start_marker)==1 and before.count(end_marker)==1 and current.count(end_marker)==1)
	var a:int=before.find(start_marker);var b:int=before.find(end_marker,a);var c:int=current.find(start_marker);var d:int=current.find(end_marker,c)
	assert(a>=0 and b>a and c>=0 and d>c)
	assert(before.substr(0,a)+current.substr(c,d-c)+before.substr(b)==current,"Only the Insect admission/protection block may change the shared emitter")
	assert(current.contains("var footprint:float=scale*(.84*1.6 if broad_dome else .8)") and current.contains("sampler.settings.nest_height*1.45*1.344+512") and current.contains("if blocked:continue"))
	var settings_path:String=DOME_BASE+"/sources/scripts/biome_extension_settings.gd.txt";bind(settings_path)
	assert(FileAccess.get_sha256(settings_path)==prior.source_sha256["res://scripts/biome_extension_settings.gd"])
	var settings_text:String=FileAccess.get_file_as_string(settings_path).replace("\r\n","\n")
	var marker:String="@export var nest_broad_domes:bool=true\n"
	settings_text=replace_once(settings_text,marker,marker+"## Keep complete supplemental mound complexes clear of finite burrow access.\n## False is an explicit unsafe-placement reference, not a traversal guarantee.\n@export var nest_protect_burrows:bool=true\n")
	assert(settings_text==FileAccess.get_file_as_string("res://scripts/biome_extension_settings.gd").replace("\r\n","\n"))
	for path:String in prior.source_sha256:
		if path.begins_with("res://tools/") or path.begins_with("res://data/") or path in ["res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd"]:continue
		assert(FileAccess.get_sha256(path)==prior.source_sha256[path],"Unrelated production source changed "+path);bind(path)
	var original:Dictionary=historical(ORIGINAL_FAILURE);var legacy:Dictionary=historical(LEGACY_FAILURE)
	var no_mounds:Dictionary=historical(NO_MOUND_CONTROL)
	assert(not original.passed and not legacy.passed and not original.failures.is_empty() and not legacy.failures.is_empty())
	assert(no_mounds.passed and no_mounds.cases[0].finished and not no_mounds.mound_solids_included and no_mounds.supplemental_structure_vertices==0 and no_mounds.cases[0].site==original.cases[0].site,"Successful original-coverage control must retain the exact same portal")
	assert(original.cases[0].site.id=="6:22:25" and legacy.cases[0].site.id=="6:22:25" and original.cases[0].waypoint==0 and legacy.cases[0].waypoint==0 and original.supplemental_structure_vertices==37044 and legacy.supplemental_structure_vertices==37044)
	var policy:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_burrow_protection.json")
	var domes:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_domes.json")
	var vents:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_vents.json")
	var queries:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_dome_queries.json")
	var fixed:Array=[];var streams:Array=[]
	for index in range(2):
		var walk:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_burrow_structures_17_conflict"+str(index)+"_with.json")
		assert(walk.mound_solids_included and not walk.legacy_placement and walk.cases[0].finished)
		fixed.append(walk.cases[0])
		var stream:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_streamed_burrow_"+str(index)+"_bound.json")
		assert(stream.completed and stream.maximum_lod==6 and stream.worker_clearance.actual_worker_vertices==0 and stream.worker_clearance.independent_unsafe_vertices==37044)
		streams.append({"index":index,"site":stream.site,"movement_frames":stream.movement_frames,"committed_cuts":stream.committed_cuts,"max_unsupported_drop_m":stream.max_unsupported_drop_metres,"preload_pause_frames":stream.preload_pause_frames,"fill_seconds":stream.fill_seconds,"walk_wall_seconds":stream.walk_wall_seconds,"worker_clearance":stream.worker_clearance,"jolt_job_capacity_warning_count":stream.jolt_job_capacity_warning_count})
	assert(fixed[0].site==original.cases[0].site,"Repair must use the unchanged originally failed portal")
	var images:Array=[]
	for path:String in ["res://tools/biome_extensions/artifacts/render_insect_domes.json","res://tools/biome_extensions/artifacts/render_insect_vents.json","res://tools/biome_extensions/artifacts/render_insect_burrows.json"]:
		var native:Dictionary=validate(path);images.append_array(native.captures)
	assert(images.size()==24)
	for capture:Dictionary in images:
		var path:String="res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png";assert(FileAccess.get_sha256(path)==capture.sha256)
	var regression:Dictionary=validate("res://data/surface_regression_20261018.json");assert(regression.test_count==31)
	var cost:Dictionary=validate("res://tools/biome_extensions/artifacts/profile_insect_vents.json");assert(cost.pairs.size()==12)
	var report:Dictionary={"passed":true,"failures":[],"completed_utc":Time.get_datetime_string_from_system(true),"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"source_sha256":hashes,"captures":images,"policy_checks":policy.checks,"dome_checks":domes.checks,"vent_checks":vents.checks,"dome_only_query_checks":queries.checks,"fixed_site_returns":fixed,"actual_streamed_returns":streams,"original_failure_archive":ORIGINAL_FAILURE,"reproduced_legacy_failure_archive":LEGACY_FAILURE,"shared_regression_scripts":31,"combined_generation_cost_pairs":12,"combined_median_added_generation_ms":cost.median_added_ms,"combined_median_ratio":cost.median_ratio,"only_insect_admission_and_setting_changed":true,"samplers_terrain_collision_shaders_and_saved_preset_unchanged":true,"warning":"One Jolt job-capacity warning is preserved in the first accelerated headless stream; the second recorded none. Route completion does not establish its cause or certify performance. Preload pauses, four workers, 180s budgets and 1ms headless polling were not relaxed.","scope":"Whole supplemental Insect primary/satellite complexes are omitted near reserved finite-burrow access, behind independent nest_protect_burrows. The actual default-rarity seed17 portal6:22:25 previously failed at waypoint0 with37044 mound vertices while its no-mound control completed; original and current legacy-mode failures are immutable. The same portal/terrain/route/capsule now completes with protection, as does the second conservative overlap candidate. Two actual production streaming returns verify real committed-worker exclusion against independent unsafe rebuilds, with original full hierarchy and declared preload pauses. Twenty-four current native views and all31 shared regressions pass. This is a finite-feature access repair, not the ordered infinite cave foundation, general navigation/performance/art acceptance or completion of all user tasks."}
	report["runner_observations_transcribed"]={"dome_native_sampled_peak_private_mib":1335.1,"vent_native_sampled_peak_private_mib":1383.3,"burrow_native_sampled_peak_private_mib":1740.0,"native_cap_mib":2048,"streamed_sampled_peaks_private_mib":[518.3,525.9],"streamed_cap_mib":1024,"isolated_generation_sampled_peak_private_mib":81.9,"generation_cap_mib":512,"sample_period_ms":500,"note":"External runner receipts are transcribed, not independently recorded engine peaks. No other Godot process was observed at 500ms samples during the isolated cost run; shorter overlaps are not excluded."}
	report["original_no_mound_control_archive"]=NO_MOUND_CONTROL
	report["original_no_mound_control"]=no_mounds.cases[0]
	FileAccess.open("res://tools/biome_extensions/artifacts/insect_burrow_continuation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open("res://data/insect_burrow_continuation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INSECT_BURROW_CONTINUATION ",hashes.size()," source guards; ",images.size()," actual native images");quit()
