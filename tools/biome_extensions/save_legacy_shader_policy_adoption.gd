extends SceneTree
var hashes:Dictionary={}
var images:Dictionary={}
func report_at(path:String)->Dictionary:
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty());hashes[path]=FileAccess.get_sha256(path)
	for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale policy evidence "+source);hashes[source]=report.source_sha256[source]
	for capture:Dictionary in report.get("captures",[]):assert(FileAccess.get_sha256(capture.path)==capture.sha256);images[capture.path]=capture.sha256
	return report
func archive_at(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/revisions/"+name+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(path));hashes[path]=FileAccess.get_sha256(path)
	for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256);hashes[copy.snapshot]=copy.sha256
	return {"archive":path,"verified_copies":manifest.files.size(),"historical_not_current_source":true}
func _initialize()->void:
	var policy:=report_at("res://tools/biome_extensions/artifacts/check_terrain_shader_variants.json")
	var matrix:=report_at("res://tools/biome_extensions/artifacts/check_legacy_owner_matrix.json")
	var payloads:=report_at("res://tools/biome_extensions/artifacts/check_shader_variant_payloads.json")
	assert(matrix.cases.size()==768 and matrix.real_meshes==2304 and matrix.assertions==1339507 and payloads.assertions==150238)
	var variants=preload("res://scripts/terrain_shader_variants.gd");var admitted:int=0
	for mask in range(65536):
		if variants.supported(mask):admitted+=1
	assert(admitted==264 and variants.CAPACITY==8)
	var runtime:Array=[];var domains:Array[String]=["default","legacy_mix","mixed","empty","jungle","forest","savanna","swamp","mountain","tropical","badlands","spore","alien","quarry","wise_mountains","volcanic","radiation_wasteland","crystal_wastes","insect_colony"]
	for domain:String in domains:
		var current:=report_at("res://tools/biome_extensions/artifacts/render_terrain_shader_variants_"+domain+".json");assert(current.captures.size()==15)
		runtime.append({"domain":domain,"configured_mask":current.configured_mask,"maximum_lod":current.maximum_lod,"camera_far":current.camera_far,"leaves":current.leaves,"captures":15,"uses_registered_variant":variants.supported(int(current.configured_mask))})
	assert(images.size()==285)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);hashes[path]=regression.source_sha256[relative]
	for path:String in ["res://tools/biome_extensions/save_legacy_shader_policy_adoption.gd","res://data/surface_regression_20261018.json"]:hashes[path]=FileAccess.get_sha256(path)
	var historical:Array=[]
	for name:String in ["experiment_render_broad_shader_trial_default_6500abaa916e","experiment_render_broad_shader_trial_mixed_f56da52034a1","experiment_render_broad_shader_trial_legacy_mix_bc55b9035721","failed_diagnostic_broad_original_control_resource_failure_6ac3bbb8611c"]:historical.append(archive_at(name))
	for name:String in ["check_terrain_shader_variants","check_legacy_owner_matrix","check_shader_variant_payloads","characterize_broad_shader_default","characterize_broad_shader_mixed","characterize_broad_shader_legacy_mix","characterize_broad_default_cold_control"]:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+name+"."+suffix
			if FileAccess.file_exists(path):hashes[path]=FileAccess.get_sha256(path)
	for domain:String in domains:
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_render_legacy_policy_"+domain+"."+suffix
			if FileAccess.file_exists(path):hashes[path]=FileAccess.get_sha256(path)
	var peaks:Dictionary={"default":1370.7,"legacy_mix":1667.9,"mixed":1241.7,"spore":1109.3,"alien":1204.1,"jungle":1362.4,"forest":1443.3,"savanna":1366.4,"swamp":1419.8,"mountain":1432.5,"tropical":1531.7,"badlands":1722.9,"quarry":1412.5,"wise_mountains":1462.7,"volcanic":1408.6,"radiation_wasteland":1406.2,"crystal_wastes":1378.5,"insect_colony":1560.0,"empty":954.4}
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":hashes,"capture_sha256":images,"admitted_configurations":admitted,"cache_capacity":8,"policy_assertions":policy.assertions,"legacy_packed_assertions":matrix.assertions,"other_packed_assertions":payloads.assertions,"actual_meshes_in_legacy_matrix":2304,"runtime_cases":runtime,"historical_private_proofs":historical,"shared_regression_scripts":31,"external_watch_observations_transcribed":{"current_runtime_sampled_peak_private_mib":peaks,"runtime_declared_limit_mib":{"default":2048,"legacy_mix":2048,"mixed":2048,"spore":2048,"alien":2048,"other14_domains":4096},"sample_period_ms":500,"private_first_preparation_4096_limit_peaks_mib":{"default":2928.1,"mixed":2323.8,"legacy_mix":2367.7},"matched_arithmetic_identical_fresh_default_control_failed_4096_at_mib":4171.7,"isolated":false,"driver_cache_cleared":false},"scope":"Extend only the existing bounded global configured-owner policy: legacy/coastal configurations WITHOUT extensions now specialize too; Grass fallback+one extension remains supported unchanged. Mixed legacy+extension and multiple-extension worlds retain the exact original resource. Independent specialize_terrain_shader=false restores full shader. Keep every branch body,original fallback/ordering,one original extension loop and fail-open source guards;no unrolling/body pruning/scene-lighting changes. All65536 configuration masks,264 supported domains,eight-entry eviction,all256 legacy/coastal subsets across2304 actual meshes/three seeds,existing extension/overlay payload proof and285 exact full-image original/variant/original captures across19 runtime domains pass,as do all31 refreshed shared regressions. Existing original nine source variants and all256 new legacy/coastal variants match the frozen historical source_for output exactly. Geometry,canonical fields and saved presets unchanged.","performance_caveat":"One matched private default pruning preparation completed at2928.1MiB under4096MiB while the arithmetic-identical function-renamed original control exceeded4096MiB at4171.7MiB before captures. This is a bounded compiler-preparation outcome,not a repeatable isolated speedup,old2GiB cold-gate pass,uninterrupted-streaming guarantee or universal memory bound. Current five named runtime domains were tested with2048MiB;the other14 used the predeclared4096MiB ceiling but observed at most1722.9MiB. Driver/compiler caches were not globally cleared;do not call these nineteen fresh cold launches. Earlier rejected unroll/body-pruning failures remain separate. All terrain/surface art,broader preparation/performance and ordered cave work are not declared finished."}
	for path:String in ["res://data/legacy_shader_policy_adoption.json","res://tools/biome_extensions/artifacts/legacy_shader_policy_adoption.json"]:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LEGACY_SHADER_POLICY_ADOPTED ",hashes.size()," guards / ",images.size()," images / ",admitted," domains");quit()
