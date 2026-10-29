extends SceneTree
const BENCHMARK="res://tools/biome_extensions/artifacts/revisions/experiment_profile_coastal_height_cache_41712d017913"
var hashes:Dictionary={}
func bind(path:String)->void:
	assert(FileAccess.file_exists(path));hashes[path]=FileAccess.get_sha256(path)
func current_report(path:String)->Dictionary:
	bind(path)
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed)
	if report.has("failures"):assert(report.failures.is_empty())
	for raw:String in report.source_sha256:
		var canonical:String=raw if raw.begins_with("res://") else "res://"+raw.replace("\\","/")
		assert(FileAccess.get_sha256(canonical)==report.source_sha256[raw],"Stale current report "+canonical);bind(canonical)
	return report
func _initialize()->void:
	bind("res://tools/biome_extensions/save_coastal_cache_adoption.gd")
	var manifest_path:String=BENCHMARK+"/manifest.json";bind(manifest_path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for record:Dictionary in manifest.files:
		assert(FileAccess.get_sha256(record.snapshot)==record.sha256,"Changed historical benchmark bytes");bind(record.snapshot)
	var benchmark_path:String=BENCHMARK+"/evidence/tools/biome_extensions/artifacts/profile_coastal_height_cache.json"
	var benchmark=JSON.parse_string(FileAccess.get_file_as_string(benchmark_path));assert(benchmark.passed and benchmark.cases.size()==3)
	var ratios:Array=[]
	for pair:Dictionary in benchmark.cases:
		assert(pair.ratio<1.0 and pair.original_8192.vertices==2068590 and pair.trial_65536.vertices==2068590)
		ratios.append(pair.ratio)
	ratios.sort()
	# Require that the production builder differs from the timed original ONLY
	# by the explicit capacity policy. Normalize line endings for this text-only
	# comparison; both complete physical files remain separately hash-bound.
	var before:String=FileAccess.get_file_as_string(BENCHMARK+"/sources/scripts/terrain_mesh_builder.gd.txt").replace("\r\n","\n")
	var after:String=FileAccess.get_file_as_string("res://scripts/terrain_mesh_builder.gd").replace("\r\n","\n")
	var declaration:String="## Worker-only height memo. Coarse coastal organic footings revisit several\n## support lattices; their measured workload benefits from a bounded larger\n## memo. Near/unrelated tiles retain the original capacity. No payloads or\n## GPU resources are stored here; the independent switch restores the limit.\nvar coastal_structure_height_cache_enabled:bool=true\nvar _normal_height_cache_capacity:int=8192\n"
	assert(after.count(declaration)==1);after=after.replace(declaration,"")
	var reset:String="\t_normal_height_cache_capacity=8192\n";assert(after.count(reset)==1);after=after.replace(reset,"")
	var selection:String="\t_select_normal_height_cache_capacity()\n";assert(after.count(selection)==1);after=after.replace(selection,"")
	var first:int=after.find("func _select_normal_height_cache_capacity()->void:\n")
	var last:int=after.find("func _sample_normal_height(x: float, z: float) -> float:\n",first)
	assert(first>=0 and last>first);after=after.substr(0,first)+after.substr(last)
	assert(after.count("if _normal_height_cache.size()>=_normal_height_cache_capacity:")==1)
	after=after.replace("if _normal_height_cache.size()>=_normal_height_cache_capacity:","if _normal_height_cache.size()>=8192:")
	assert(after==before,"Only the declared worker cache-capacity policy may change production")
	var policy:Dictionary=current_report("res://tools/biome_extensions/artifacts/check_coastal_height_cache_policy.json")
	var native:Dictionary=current_report("res://tools/biome_extensions/artifacts/render_coastal_cache_policy.json")
	var regression:Dictionary=current_report("res://data/surface_regression_20261018.json")
	assert(policy.checks==280135 and policy.cases.size()==18 and native.captures.size()==9 and native.worker_cache_proofs.size()>=12 and regression.test_count==31)
	assert(FileAccess.get_sha256("res://shaders/biological_sampling.gdshaderinc")=="471d766b176f7690c956a37b1b315fbabcfae9b660462d15813ab97c8a1e9d20","Rejected phase correction must remain out of production")
	for capture:Dictionary in native.captures:
		var path:String="res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png"
		assert(FileAccess.get_sha256(path)==capture.sha256)
	var report:Dictionary={"passed":true,"failures":[],"completed_utc":Time.get_datetime_string_from_system(true),"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"only_declared_builder_capacity_policy_changed":true,"source_sha256":hashes,"captures":native.captures,"policy_checks":policy.checks,"exact_real_output_cases":policy.cases.size(),"shared_regression_scripts":31,"actual_idle_worker_checks":native.worker_cache_proofs,"benchmark_reference":benchmark_path,"paired_workload_ratios":ratios,"paired_median_ratio":ratios[1],"retained_serialized_bytes_old":175348,"retained_serialized_bytes_new":1524724,"original_height_cache_entries":8192,"coastal_coarse_height_cache_entries":65536,"worker_count_unchanged":4,"support_cache_entries_unchanged":16384,"runner_observations_transcribed":{"benchmark_sampled_peak_private_mib":303.3,"benchmark_cap_mib":768,"isolation":"No other Godot process observed at 500ms samples; shorter overlaps not excluded. This receipt is transcribed from the external runner, not independently recorded in the engine log."},"scope":"Registered bounded worker-only height memo for coastal Alien coarse tiles of at least 8192m. Actual fields, features and structure arrays stay exact, with immediate small-budget restoration for near tiles, independent opt-out and reconfiguration reset. Three isolated alternating dense-tile pairs support only this numeric workload gain; third-pair baseline was slower, so report every ratio rather than a universal speedup. Extra bytes are serialized numeric dictionary data, not total heap usage. Nine native shore views and idle-worker bounds, plus 31 shared regressions, do not confer uninterrupted streaming, whole-surface art, original failed navigation-site repair, mycelium phase correction or any cave acceptance."}
	report.runner_observations_transcribed["native_sampled_peak_private_mib"]=1413.3
	report.runner_observations_transcribed["native_cap_mib"]=2048
	var output:String="res://tools/biome_extensions/artifacts/coastal_height_cache_adoption.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open("res://data/coastal_height_cache_adoption.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COASTAL_CACHE_ADOPTION ",hashes.size()," source guards, nine native images, scoped median ratio ",ratios[1]);quit()
