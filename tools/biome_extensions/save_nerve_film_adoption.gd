extends SceneTree
var hashes:Dictionary={}
var evidence:Dictionary={}
var pixels:Dictionary={}
func verify_sources(report:Dictionary)->void:
	for path:String in report.source_sha256:
		assert(FileAccess.get_sha256(path)==report.source_sha256[path],"Current adoption source "+path);hashes[path]=report.source_sha256[path]
func load_passed(name:String)->Dictionary:
	var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.passed and report.failures.is_empty());verify_sources(report);hashes[path]=FileAccess.get_sha256(path);evidence[name]={"path":path,"sha256":hashes[path],"scope":report.get("scope","")}
	for capture:Dictionary in report.get("captures",[]):
		var png:String="res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png";assert(FileAccess.get_sha256(png)==capture.sha256);pixels[png]=capture.sha256
	for png:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(png)==report.capture_sha256[png]);pixels[png]=report.capture_sha256[png]
	return report
func _initialize()->void:
	var asset_manifest:String="res://tools/biome_extensions/artifacts/revisions/experiment_check_assets_2e0eefc13b5d/manifest.json"
	var bundle=JSON.parse_string(FileAccess.get_file_as_string(asset_manifest));var gpu_report_path:String=""
	for item:Dictionary in bundle.files:
		assert(FileAccess.get_sha256(item.snapshot)==item.sha256);hashes[item.snapshot]=item.sha256
		if item.original==bundle.report:gpu_report_path=item.snapshot
	var gpu=JSON.parse_string(FileAccess.get_file_as_string(gpu_report_path));assert(gpu.passed and gpu.gpu_readback_performed and gpu.readbacks.size()==4 and gpu.compressed_array_bytes==11184864);verify_sources(gpu)
	hashes[asset_manifest]=FileAccess.get_sha256(asset_manifest);evidence["immutable_gpu_asset_readback"]={"path":gpu_report_path,"sha256":FileAccess.get_sha256(gpu_report_path),"manifest":asset_manifest,"array_gpu_bytes":11184864}
	var native:Dictionary=load_passed("render_registered_nerve_film_same_scene");assert(native.production_registration and native.captures.size()==9 and native.same_scene_runtime_manual_binding_matches==3 and native.material_binding_checks==2022 and not native.cross_run_exact_equivalence)
	var projection:Dictionary=load_passed("check_biological_projection");assert(projection.actual_render and projection.records.size()==9)
	var normal:Dictionary=load_passed("check_normal_controls");assert(normal.actual_render and normal.records.size()==8)
	# This pre-existing fixture records numeric GPU controls but not PNG hashes;
	# bind its saved images here at adoption time, without calling them runtime
	# image-hash guards or whole-scene equivalence.
	for owner:String in ["quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"]:
		for view:String in ["on","off","zero"]:
			var png:String="res://tools/biome_extensions/artifacts/normal_control_"+owner+"_"+view+".png";var image:=Image.load_from_file(png);assert(image.get_size()==Vector2i(1280,720));pixels[png]=FileAccess.get_sha256(png)
	var shell:Dictionary=load_passed("check_structure_normal_controls");assert(shell.actual_render and shell.records.size()==6)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31)
	for path:String in regression.source_sha256:
		var canonical:String="res://"+path.replace("\\","/");assert(FileAccess.get_sha256(canonical)==regression.source_sha256[path]);hashes[canonical]=regression.source_sha256[path]
	hashes[regression_path]=FileAccess.get_sha256(regression_path);evidence["shared_surface_regression"]={"path":regression_path,"sha256":hashes[regression_path],"test_count":31}
	var known_path:String="res://tools/biome_extensions/artifacts/check_mirrored_tissue_projection_legacy.json";var known=JSON.parse_string(FileAccess.get_file_as_string(known_path));assert(not known.passed and known.failures.size()==1 and known.failures[0].layer==0);verify_sources(known);hashes[known_path]=FileAccess.get_sha256(known_path)
	assert(FileAccess.get_sha256("res://shaders/biological_sampling.gdshaderinc")=="471d766b176f7690c956a37b1b315fbabcfae9b660462d15813ab97c8a1e9d20","Validated production sampler restored, private phase change not shipped")
	for path:String in ["res://tools/biome_extensions/save_nerve_film_adoption.gd","res://data/biological_nerve_v1_provenance.json"]:hashes[path]=FileAccess.get_sha256(path)
	assert(FileAccess.get_sha256("res://assets/textures/biological/nerve_albedo_v1.png")=="117a445b33f7d3e47e8f23c3d393f4c6da75a1aa74636a4317013d5fd2152853")
	var result:Dictionary={"passed":true,"failures":[],"completed_utc":Time.get_datetime_string_from_system(true),"production_registration":true,"source_sha256":hashes,"capture_sha256":pixels,"evidence":evidence,"asset":"res://assets/textures/biological/nerve_albedo_v3.png","array":"res://materials/biological_colors_v3.tres","array_gpu_bytes":11184864,"native_source_dimensions":[1254,1254],"creation_mode":"built-in image_gen","full_prompt":"res://tools/biome_extensions/experiments/nerve_film_v3_provenance.json","legacy_provenance":"res://data/biological_nerve_v1_provenance.json","private_phase_correction_adopted":false,"private_shader_specialization_adopted":false,"larger_cache_adopted":false,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"known_issues":["Original mycelium mirrored-origin phase defect remains; its actual four-layer diagnostic is preserved failed, not hidden by the passing three-layer control. Private correction fails full-scene resource acceptance.","Strict cross-run image identity remains unproven: seed17 differed at five pixels by at most two codes. Exact same-commit runtime/manual material binding passes without excluding pixels or relaxing thresholds; it does not repair or pass that failed cross-run test.","Cold shader preparation, frame spikes, overly smooth distant landforms, broader joins/traversal and whole-biome art targets remain open. No new startup/performance certificate or cave implementation."],"scope":"Scoped adoption of one generated opaque tissue albedo layer, both actual terrain/shell bindings, same total BC1 array size and preserved old resources. Three-seed nine-view runtime rendering plus three exact same-commit binding controls, four native asset readbacks, three-layer projection, eight terrain and six shell control cases, and all31 shared regressions. Material component acceptance only, not complete surface/cave work; creation-time private provenance remains historical."}
	var encoded:String=JSON.stringify(result,"  ");FileAccess.open("res://data/nerve_film_v3_adoption.json",FileAccess.WRITE).store_string(encoded);FileAccess.open("res://tools/biome_extensions/artifacts/nerve_film_v3_adoption.json",FileAccess.WRITE).store_string(encoded)
	print("NERVE_FILM_ADOPTION ",hashes.size()," source guards; ",pixels.size()," native images bound; all-user-tasks-complete=false");quit()
