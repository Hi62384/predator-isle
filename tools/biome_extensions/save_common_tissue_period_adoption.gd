extends SceneTree
var hashes:Dictionary={}
var images:Dictionary={}
func current_report(path:String)->Dictionary:
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty())
	hashes[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale common-period proof "+source);hashes[source]=report.source_sha256[source]
	for capture:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(capture)==report.capture_sha256[capture]);images[capture]=report.capture_sha256[capture]
	for capture:Dictionary in report.get("captures",[]):
		if capture.has("path"):assert(FileAccess.get_sha256(capture.path)==capture.sha256);images[capture.path]=capture.sha256
	return report
func historical(name:String)->Dictionary:
	var base:String="res://tools/biome_extensions/artifacts/revisions/"+name
	var path:String=base+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(path));hashes[path]=FileAccess.get_sha256(path)
	for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256);hashes[copy.snapshot]=copy.sha256
	return {"archive":base,"files":manifest.files.size(),"source_time":"Historical immutable copies,not rebound to current production source"}
func _initialize()->void:
	var integer:=current_report("res://tools/biome_extensions/artifacts/check_common_tissue_period.json")
	var gpu:=current_report("res://tools/biome_extensions/artifacts/check_integer_period_gpu.json")
	var wide:=current_report("res://tools/biome_extensions/artifacts/check_integer_period_gpu_wide.json")
	assert(gpu.integer_mode and wide.integer_mode and wide.wide and gpu.cases==65536 and wide.cases==65536)
	assert(gpu.detected_negatives==2260 and wide.detected_negatives==2260)
	var texture:=current_report("res://tools/biome_extensions/artifacts/check_mirrored_tissue_projection_production_integer.json")
	assert(texture.production_registration and texture.records.size()==24 and texture.regional_continuity.size()==4 and texture.original_phase_negative.detected and texture.original_phase_negative.changed_pixels==4788)
	var maximum_rgb:float=0
	for record:Dictionary in texture.records:maximum_rgb=maxf(maximum_rgb,record.maximum_rgb_error)
	assert(maximum_rgb<=2.0/255.0)
	var policy:=current_report("res://tools/biome_extensions/artifacts/check_terrain_shader_variants.json")
	var runtime:Array=[]
	for domain:String in ["spore","alien","mixed","default"]:
		var report:=current_report("res://tools/biome_extensions/artifacts/render_terrain_shader_variants_"+domain+".json")
		assert(report.captures.size()==15);runtime.append({"domain":domain,"captures":15,"maximum_lod":report.maximum_lod,"camera_far":report.camera_far,"leaves":report.leaves})
	assert(images.size()==87)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var source:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(source)==regression.source_sha256[relative]);hashes[source]=regression.source_sha256[relative]
	for source:String in ["res://data/surface_regression_20261018.json","res://tools/biome_extensions/save_common_tissue_period_adoption.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var history:Array=[]
	for archive:String in ["experiment_render_float_period_renamed_original_aeb5c1637bbe","experiment_render_integer_period_private_834fc707542b","failed_diagnostic_float_period_resource_failure_5f4c734bb9df","failed_diagnostic_renamed_original_shader_resource_failure_7bdd1ba6d624","failed_diagnostic_check_integer_period_gpu_5ec90b2b5e6c","failed_diagnostic_check_integer_period_gpu_wide_e3ec1612a7cf","failed_diagnostic_check_mirrored_tissue_projection_production_integer_f2557f970a3f","failed_diagnostic_check_float_period_gpu_8c59e72d5873"]:history.append(historical(archive))
	for name:String in ["check_production_integer_projection","render_integer_runtime_spore","render_integer_runtime_alien","render_integer_runtime_mixed","render_integer_runtime_default","check_integer_period_gpu","check_integer_period_gpu_wide","check_common_tissue_period","characterize_renamed_original_4096","characterize_integer_period_4096"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(path):hashes[path]=FileAccess.get_sha256(path)
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":hashes,"capture_sha256":images,"cpu_checks":integer.checks,"original_integer_parity_negatives":integer.original_odd_mirror_quotient_cases,"gpu_remainder_cases":131072,"gpu_detected_negatives":4520,"texture_cases":24,"texture_maximum_rgb_error":maximum_rgb,"texture_rgb_bound_unchanged":2.0/255.0,"original_phase_negative":texture.original_phase_negative,"current_shader_policy_checks":policy.assertions,"runtime_scenes":runtime,"historical_evidence":history,"shared_regression_scripts":31,"external_runner_observations_transcribed":{"settled_runtime_limit_mib":2048,"spore_peak_mib":1428.1,"alien_peak_mib":1527.9,"mixed_peak_mib":1191.1,"default_peak_mib":1473.7,"separate_compiler_characterization_limit_mib":4096,"arithmetic_identical_renamed_original_compiler_peak_mib":3841.7,"sign_safe_candidate_compiler_peak_mib":3851.3,"arithmetic_identical_original_old_2048_gate_failed_at_mib":2054.1,"float_candidate_old_2048_gate_failed_at_mib":2188.6,"sample_period_ms":500,"isolated":false,"driver_cache_cleared":false,"engine_cache_disabled_in_characterizations":true},"scope":"Corrected shared mirrored mycelium origin phase behind actual existing terrain/shell include. Constant30m signed-safe common period fits the current fixed2.5m mirrored/2m/1.5m repeating scales and integer chunk origins,without new varyings,image banks,geometry,lighting or renderer change.131072 actual GPU remainder cases over near and signed far ranges;24 actual texture/origin cases including distant sites with real local derivatives;four region transitions;restoring only original arithmetic reproduces4788 changed pixels/maxRGB.435294. Sixty actual runtime original/optimized/original images remain byte-exact across four scenes;25 texture images and two arithmetic images bound. All31 current shared regressions pass. This repairs the original mirrored-origin defect,not whole-scene physical joins,all-world arbitrary transforms/scales,art,performance or caves.","resource_caveat":"The old2048MiB fresh-compiler failures remain FAILED and immutable. New evidence showed an arithmetic-identical renamed ORIGINAL also fails2048MiB. A separate predeclared4096MiB compiler characterization completed for both baseline and candidate at3841.7/3851.3MiB,not a pass of the old gate or a memory/performance gain. Current actual scenes pass2048MiB after compiler preparation; compiler/driver caches are not cleared for those scenes. Broad first-launch preparation/frame spikes remain unfinished.","rejected_fixture_caveat":"Original enlarged projection fixture differentiated huge world positions although both production callers use small local derivatives,and its separate transition fixture accidentally retained the previous distant site with a near origin. Failed sources/25images are preserved before the corrected explicit production mode;all original and extra far cases remain,existing2/255 threshold unchanged. The first arithmetic fixture also retained project1280px canvas scaling;its51px-square failure is preserved before one-to-one correction. An earlier signed-negative modulo candidate failed both ranges and was replaced with original nonnegative operands/sign handling,not relabelled as passing."}
	for path:String in ["res://data/common_tissue_period_adoption.json","res://tools/biome_extensions/artifacts/common_tissue_period_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("COMMON_TISSUE_ADOPTION ",hashes.size()," guards / ",images.size()," current images");quit()
