extends SceneTree
var guards:Dictionary={}
var images:Dictionary={}
func checked(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty(),name);guards[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale variation evidence "+source);guards[source]=report.source_sha256[source]
	for path_image:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(path_image)==report.capture_sha256[path_image]);images[path_image]=report.capture_sha256[path_image]
	return report
func history(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/revisions/"+name+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(path));guards[path]=FileAccess.get_sha256(path)
	for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256)
	return {"manifest":path,"verified_copies":manifest.files.size(),"historical_not_current_source_proof":true}
func _initialize()->void:
	var registration:=checked("check_tissue_variation_registration");assert(registration.cases.size()==9)
	var transport:=checked("check_alien_tissue_transport");assert(transport.assertions==5466)
	var strain:=checked("check_tissue_growth_strain");assert(strain.checks==32774)
	var repeat:=checked("check_tissue_variation_gpu");assert(repeat.cases.size()==9)
	var minimum_variation:float=INF
	for item:Dictionary in repeat.cases:
		for shift:Dictionary in item.shifts:
			if item.phase==1:assert(shift.mean_absolute_rgb>.02);minimum_variation=minf(minimum_variation,shift.mean_absolute_rgb)
	var projection:=checked("check_tissue_variation_projection_registered");assert(projection.cases.size()==9)
	var native:=checked("render_tissue_variation_registered");var overlay:=checked("render_tissue_variation_overlay");assert(native.views.size()==9 and overlay.views.size()==3 and native.capture_sha256.size()==45 and overlay.capture_sha256.size()==15)
	for report:Dictionary in [native,overlay]:
		for view:Dictionary in report.views:assert(view.candidate_off_exact and view.candidate_return_exact and view.original_return_exact and view.changed_bytes>100)
	var binding:=checked("check_tissue_variation_binding");assert(binding.cases.size()==2)
	for item:Dictionary in binding.cases:assert(item.leaves==9 and item.flow_map_bytes>0)
	var sample:=checked("check_tissue_sample_equivalence");assert(sample.cases.size()==9)
	for item:Dictionary in sample.cases:assert(item.different_bytes==0)
	var mirrored:=checked("check_mirrored_tissue_projection_production_integer");assert(mirrored.records.size()==24)
	var profile:=checked("profile_tissue_variation_registered");assert(profile.samples.size()==24);var gpu:Array=[]
	for view:String in ["near","context","ground"]:
		var sums:Dictionary={false:0.0,true:0.0};var counts:Dictionary={false:0,true:0}
		for item:Dictionary in profile.samples:
			if item.view!=view:continue
			assert(item.gpu_p50_ms!=null);var enabled:bool=item.variation_enabled;sums[enabled]+=item.gpu_p50_ms;counts[enabled]+=1
		gpu.append({"view":view,"off_gpu_mean_block_median_ms":sums[false]/counts[false],"on_gpu_mean_block_median_ms":sums[true]/counts[true],"blocks_per_mode":counts[false]})
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);guards[path]=regression.source_sha256[relative]
	for path:String in ["res://tools/biome_extensions/save_tissue_variation_adoption.gd","res://data/surface_regression_20261018.json","res://tools/biome_extensions/run_test.ps1"]:guards[path]=FileAccess.get_sha256(path)
	for prefix:String in ["check_tissue_variation_registration","check_tissue_variation_registration_format","check_tissue_variation_registration_nine_pairs","render_tissue_variation_registered","render_tissue_variation_registered_isolated_scenes","render_tissue_variation_registered_nine_pairs","check_tissue_variation_binding","check_tissue_variation_binding_nine_roots","check_tissue_variation_binding_current","profile_tissue_variation_registered","profile_tissue_variation_registered_current","render_tissue_variation_overlay","render_tissue_variation_overlay_nine_pairs","variation_repeat_panel_current","variation_refresh_transport","check_tissue_variation_projection_registered","check_tissue_variation_projection_registered_nine_pairs","variation_reference_flow_gpu","variation_reference_four_sample","variation_reference_sample_equivalence","variation_original_mirrored_projection"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+prefix+"."+suffix
			if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	var old:Array=[]
	for name:String in ["experiment_tissue_variation_trial_f73e9ad05877","failed_diagnostic_check_tissue_variation_gpu_3c0d28350cc9","failed_diagnostic_render_tissue_variation_registered_7a73a24e8d9f"]:old.append(history(name))
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"completed_utc":Time.get_datetime_string_from_system(true),"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"caves_implemented":false,"source_sha256":guards,"capture_sha256":images,"registration_checks":registration.checks,"transport_checks":5466,"strain_checks":32774,"minimum_shift_mean_absolute_rgb":minimum_variation,"maximum_longitudinal_deflection_degrees":strain.maximum_longitudinal_deflection_degrees,"minimum_jacobian_determinant":strain.minimum_jacobian_determinant,"native_views":12,"native_images":60,"binding_checks":binding.checks,"original_sample_reference_panels":9,"original_projection_cases":24,"shared_regression_tests":31,"gpu_summary":gpu,"historical_proofs":old,"external_watch_observations_transcribed":{"pure_native_peak_mib":1059.4,"overlay_peak_mib":1029,"native_limit_mib":4096,"profile_peak_mib":976.3,"profile_limit_mib":4096,"binding_peak_mib":185.1,"binding_limit_mib":1024,"registered_projection_peak_mib":336.4,"repeat_panel_peak_mib":313.6,"original_projection_peak_mib":442.9,"gpu_panel_limit_mib":1536,"sample_period_ms":500,"machine_gpu_exclusive":false},"scope":"Registered independent default-on nerve_material_variation on terrain AND attached Alien shell material clones. Accepted private formula exactly retained:two mirrored/offset source samples with small continuous analytic-Jacobian growth strain,nonfolding and less than six-degree longitudinal deflection. Source image,actual path maps,global30m biological projection period,physical fields/geometry/water/ownership and lighting unchanged;no new atlas/texture. Original one-sample aligned mode is exact when independently disabled. Original repeat threshold retained after first failed trial;actual shader formula/controls,nine three-seed pure/overlay/unrelated full terrain payload pairs,nine enabled child/rectangular-parent GPU panels,12 frozen full native views with60 same-scene original/off/on/off/original images,two actual configured nine-root controller cuts,and31 shared regressions pass. Original no-variation four-sample reference remains exact across nine GPU panels;all24 original four-layer projection cases also pass.","limitations":"A bounded repeated-motif material improvement,not new measured PBR scans,native2K input albedo,reference-quality whole-biome art,all-world joins,broad performance or cave completion. Broad native ground-level material/geometry boundaries remain visible and separate work. Registered GPU observations use one cut/three views/24 alternating blocks with flow enabled throughout;wall presentation remains about16.67ms,not uncapped performance or universal speedup. Native4096MiB caps do not relabel old2048MiB cold failures. Initial registered native fixture failed because it left the frozen reference shader active before later controller creation;failed report preserved,corrected scene-isolated run accepted. Initial cold-binding fixture incorrectly assumed oneLOD0root;actual partition has nine,all nine now checked. Formatting-only formula assertion failure and failed binding logs remain distinct,not passing results."}
	# Latest complete source-bound round after explicitly adding the unrelated
	# controls;earlier distinct-prefix logs remain historical,not substituted.
	result.external_watch_observations_transcribed.merge({"pure_native_peak_mib":1068.1,"overlay_peak_mib":1047.1,"profile_peak_mib":980.6,"binding_peak_mib":181.8,"registered_projection_peak_mib":331.3},true)
	result.limitations+=" The recorder initially assumed nine stored historical transport cases;only six pure/overlay positives existed. Three actual unrelated Spore controls were then explicitly executed,bringing current registration to nine complete pairs/31 checks,and all source-bound native/binding/profile reports were refreshed. Initial failed recorder log remains distinct."
	for path:String in ["res://data/tissue_variation_adoption.json","res://tools/biome_extensions/artifacts/tissue_variation_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TISSUE_VARIATION_ADOPTED ",guards.size()," guards / ",images.size()," images / GPU ",gpu);quit()
