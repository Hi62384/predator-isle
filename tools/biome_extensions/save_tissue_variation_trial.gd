extends SceneTree
func _initialize()->void:
	var guards:Dictionary={};var images:Dictionary={};var reports:Dictionary={}
	for name:String in ["check_tissue_variation_gpu","check_tissue_variation_projection","check_tissue_growth_strain","render_tissue_variation_candidate","profile_tissue_variation_candidate"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty());guards[path]=FileAccess.get_sha256(path);reports[name]=report
		for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source]);guards[source]=report.source_sha256[source]
		for capture:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(capture)==report.capture_sha256[capture]);images[capture]=report.capture_sha256[capture]
	assert(reports.check_tissue_variation_gpu.cases.size()==9 and reports.check_tissue_variation_projection.cases.size()==9 and reports.render_tissue_variation_candidate.views.size()==9 and reports.profile_tissue_variation_candidate.samples.size()==24)
	var summary:Array=[]
	for view:String in ["near","context","ground"]:
		var sums:Dictionary={false:0.0,true:0.0};var counts:Dictionary={false:0,true:0}
		for sample:Dictionary in reports.profile_tissue_variation_candidate.samples:
			if sample.view!=view:continue
			assert(sample.gpu_p50_ms!=null);var mode:bool=sample.variation_enabled;sums[mode]+=sample.gpu_p50_ms;counts[mode]+=1
		summary.append({"view":view,"original_gpu_mean_block_median_ms":sums[false]/counts[false],"candidate_gpu_mean_block_median_ms":sums[true]/counts[true]})
	for history:String in ["failed_diagnostic_check_tissue_variation_gpu_3c0d28350cc9","experiment_render_tissue_variation_candidate_3d2dc46eb944"]:
		var path:String="res://tools/biome_extensions/artifacts/revisions/"+history+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(path));guards[path]=FileAccess.get_sha256(path)
		for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256)
	for prefix:String in ["check_tissue_variation_gpu_diagnostic","check_tissue_variation_gpu_strain","check_tissue_variation_gpu_strain_clean","check_tissue_variation_projection","check_tissue_growth_strain","render_tissue_variation_candidate_strain","profile_tissue_variation_candidate"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+prefix+"."+suffix
			if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	guards["res://tools/biome_extensions/save_tissue_variation_trial.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/save_tissue_variation_trial.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/tissue_variation_trial.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"capture_sha256":images,"math_checks":reports.check_tissue_growth_strain.checks,"native_views":9,"native_images":45,"gpu_summary":summary,"external_watch_transcriptions":{"native_peak_mib":1542.4,"native_limit_mib":4096,"profile_peak_mib":984,"profile_limit_mib":4096,"panel_peak_mib":369.8,"projection_peak_mib":392.1,"panel_and_projection_limit_mib":1536,"sample_period_ms":500},"scope":"PRIVATE pre-registration study. One mirrored-offset trial failed the original mean-RGB repeat criterion,archived unchanged;its native opt-out controls passed but were not art acceptance. Continuous bounded strain with analytic footprints then passes the SAME.02 mean-RGB bound at1.5/3/6/12m translations across three signed origins;32774 math checks,nine overlapping-parent GPU panels and nine unchanged native views/45 exact-control captures pass. Candidate/source math remains private;production is not changed by this report. GPU observations are one cut,24 alternating blocks;not universal speedups. Prior cleanup compilation error in the strain panel is retained in its distinct log;only corrected clean-prefix panel is accepted. No all-user/surface/cave completion claim."},"  "));print("TISSUE_VARIATION_TRIAL ",guards.size()," guards / ",images.size()," images");quit()
