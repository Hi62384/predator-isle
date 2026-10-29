extends SceneTree
var guards:Dictionary={}
var images:Dictionary={}
func checked(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty(),"Failed tissue evidence "+name);guards[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale tissue evidence "+source);guards[source]=report.source_sha256[source]
	for image_path:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(image_path)==report.capture_sha256[image_path]);images[image_path]=report.capture_sha256[image_path]
	return report
func historical(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/revisions/"+name+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(path));guards[path]=FileAccess.get_sha256(path)
	for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256)
	return {"manifest":path,"verified_copies":manifest.files.size(),"historical_sources_not_current":true}
func gpu_summary(report:Dictionary,key:String)->Array:
	var result:Array=[]
	for view:String in ["near","context","ground"]:
		var sums:Dictionary={false:0.0,true:0.0};var counts:Dictionary={false:0,true:0}
		for sample:Dictionary in report.samples:
			if sample.view!=view or sample.gpu_p50_ms==null:continue
			var mode:bool=sample[key];sums[mode]+=sample.gpu_p50_ms;counts[mode]+=1
		result.append({"view":view,"reference_mean_gpu_block_medians_ms":sums[false]/counts[false] if counts[false]>0 else null,"current_mean_gpu_block_medians_ms":sums[true]/counts[true] if counts[true]>0 else null,"reference_blocks":counts[false],"current_blocks":counts[true]})
	return result
func _initialize()->void:
	var numeric:=checked("check_alien_tissue_transport");assert(numeric.assertions==5466)
	var lifecycle:=checked("check_tissue_material_lifecycle");assert(lifecycle.checks==28)
	var packed:=checked("check_packed_tissue_coordinates");assert(packed.cases.size()==27)
	checked("check_alien_tissue_flow_gpu");var samples:=checked("check_tissue_sample_equivalence");assert(samples.cases.size()==9)
	var native:=checked("render_alien_tissue_flow");assert(native.views.size()==27 and native.phases.size()==9 and native.sample_reference_cases.size()==9 and native.capture_sha256.size()==46)
	var overlay:=checked("render_tissue_flow_overlay");assert(overlay.views.size()==9 and overlay.phases.size()==3 and overlay.sample_reference_cases.size()==3 and overlay.capture_sha256.size()==16)
	for report:Dictionary in [native,overlay]:
		for sample:Dictionary in report.sample_reference_cases:assert(sample.reference_different_bytes==0 and sample.return_different_bytes==0)
	var derivative:=checked("check_tissue_derivative_control");assert(derivative.detected_prior_derivative_outliers==7)
	for point:Dictionary in derivative.cases:assert(point.corrected_luminance_dip<=.02 and point.prior_derivative_luminance_dip>.05)
	var worker:=checked("profile_tissue_flow_worker");assert(worker.cases.size()==9)
	var runtime:=checked("profile_tissue_flow_runtime");var sampler:=checked("profile_tissue_sampler_reference");assert(runtime.samples.size()==24 and sampler.samples.size()==24)
	var mirror:=checked("check_mirrored_tissue_projection_production_integer");assert(mirror.records.size()==24)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);guards[path]=regression.source_sha256[relative]
	for path:String in ["res://tools/biome_extensions/save_tissue_flow_adoption.gd","res://data/surface_regression_20261018.json"]:guards[path]=FileAccess.get_sha256(path)
	for name:String in ["check_packed_tissue_coordinates","check_alien_tissue_transport","check_tissue_material_lifecycle_packed","check_alien_tissue_flow_gpu","run_tissue_sample_reference","check_tissue_sample_equivalence","render_alien_tissue_flow","render_tissue_flow_overlay_current","diagnose_tissue_flow_contacts","run_tissue_derivative_negative_held","check_tissue_derivative_control","profile_tissue_flow_worker_verified","profile_tissue_flow_runtime","profile_tissue_sampler_reference","tissue_check_mirrored_projection_current"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	var history:Array=[]
	for name:String in ["experiment_render_alien_tissue_flow_d9a111d59fab","experiment_render_alien_tissue_flow_fc1f200ac1af","experiment_check_tissue_derivative_control_5e68df65f0b2"]:history.append(historical(name))
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"completed_utc":Time.get_datetime_string_from_system(true),"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"source_sha256":guards,"capture_sha256":images,"transport_assertions":numeric.assertions,"lifecycle_checks":lifecycle.checks,"packed_map_pairs":27,"packed_map_median_time_ratio":packed.median_packed_to_frozen_ratio,"native_primary_views":36,"native_sample_reference_cases":12,"native_sample_and_return_images":24,"native_wrong_uv_negatives":2,"derivative_control_points":7,"worker_median_on_to_off_ratio":worker.median_on_to_off_ratio,"feature_off_on_gpu_mean_block_medians":gpu_summary(runtime,"enabled"),"matched_four_sample_vs_skip_gpu_mean_block_medians":gpu_summary(sampler,"skip_empty_samples"),"historical_proofs":history,"external_watch_observations_transcribed":{"pure_native_sampled_peak_mib":1485.4,"pure_native_limit_mib":4096,"overlay_sampled_peak_mib":1076.2,"overlay_limit_mib":4096,"worker_sampled_peak_mib":81.7,"worker_limit_mib":1024,"feature_runtime_sampled_peak_mib":974.9,"feature_runtime_limit_mib":2048,"matched_sampler_runtime_sampled_peak_mib":974.4,"matched_sampler_runtime_limit_mib":4096,"sample_period_ms":500,"runtime_other_godot_observed":false,"machine_gpu_exclusive":false},"scope":"Registered default-on nerve_flow_texturing with independent exact-off mode. Canonical finite-hive arc/side coordinates fade at nodes,bends and competing paths. Separate bounded129x129 RGBA32F maps cover terrain and the ENTIRE owned shell,not only its root tile. Active/staged/cached structure-material clones receive debug changes. Analytic normalized-bilinear Jacobians eliminate reconstructed-UV derivative streaks;held prior arithmetic alone restores all seven fixed original dips. Lower-allocation construction matches27 frozen maps exactly;empty-group sample skipping matches all image bytes under nine GPU panels and twelve full actual scene reference/return views across three pure-Alien seeds plus one zero-coverage Grass overlay seed. Actual worker-map GPU data,bounds,complete terrain/water/feature/structure/collision array equivalence,ground views,24 original mirrored-tissue cases and31 shared regressions pass. Original source images/scales/lighting,fields/geometry,worker count,resource caps and old failed diagnostics are not relabelled.","limitations":"This is hive-directed material-coordinate correctness and bounded cost,not new measured PBR maps,native2K source albedo,all-world joins,reference-quality surfaces,arbitrary settings or cave completion. Existing geometric/material contact limitations and repeated albedo motifs remain separate work. Full-worker feature cost is still positive despite faster coordinate construction. GPU timer results are bounded to one committed cut/three views;wall presentation stayed about16.67ms despite requesting uncapped/VSync off. Other-Godot isolation was sampled500ms,not machine/GPU exclusivity. Declared4096MiB native caps are not passes of old2048MiB cold-compilation gates;old source-specific failures remain failures. Cross-scene off/return pixel differences remain diagnostics,not certified exact;strict exactness applies to the SAME-scene sampler-reference comparisons."}
	for path:String in ["res://data/tissue_flow_adoption.json","res://tools/biome_extensions/artifacts/tissue_flow_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TISSUE_FLOW_ADOPTED ",guards.size()," guards / ",images.size()," images /worker ratio=",worker.median_on_to_off_ratio);quit()
