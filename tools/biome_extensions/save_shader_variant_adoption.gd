extends SceneTree
func _initialize()->void:
	var hashes:Dictionary={};var images:Dictionary={};var reports:Array=[]
	var names:Array[String]=["check_terrain_shader_variants","check_shader_variant_payloads"]
	for domain:String in ["alien","spore","quarry","wise_mountains","volcanic","radiation_wasteland","crystal_wastes","insect_colony","mixed","default","empty"]:names.append("render_terrain_shader_variants_"+domain)
	for name:String in names:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json"
		var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty())
		hashes[path]=FileAccess.get_sha256(path)
		for source:String in report.source_sha256:
			assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale source "+source);hashes[source]=report.source_sha256[source]
		for capture:Dictionary in report.get("captures",[]):
			assert(FileAccess.get_sha256(capture.path)==capture.sha256);images[capture.path]=capture.sha256
		reports.append({"report":path,"domain":report.get("domain","numeric"),"assertions":report.get("assertions",0),"captures":report.get("captures",[]).size(),"maximum_lod":report.get("maximum_lod",null)})
	assert(images.size()==165)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var source:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(source)==regression.source_sha256[relative]);hashes[source]=regression.source_sha256[relative]
	for source:String in ["res://data/surface_regression_20261018.json","res://tools/biome_extensions/save_shader_variant_adoption.gd"]:hashes[source]=FileAccess.get_sha256(source)
	var result:Dictionary={"passed":true,"failures":[],"production_registration":true,"all_user_tasks_complete":false,"completed_utc":Time.get_datetime_string_from_system(true),"source_sha256":hashes,"capture_sha256":images,"reports":reports,"scope":"Bounded eight-entry shader cache for globally configured Grass fallback plus at most one extension, including Alien overlays. Mixed legacy/coastal/multiple-extension domains use the exact original shader. 65536 mask configurations, 150238 packed-payload assertions, eleven native five-view exact original/optimized/original comparisons (fallbacks remain original), and all31 shared regressions. Native sampled peaks below2048MiB; not a shader-only timing gain or an all-surface/cave completion certificate.","rejected_trials":"Broader specialization failed the native 2048MiB gate, observed 2130.7/2099.9/2089.1/2083.9MiB across the unrolled/single-loop/body-pruned trials; the original same LOD3 mixed scene passed at1153.2MiB. Removing disabled branch bodies also changed two lit-image bytes and was rejected. These console observations are not a source-bound forensic archive or a production pass. The shipped policy retains bodies and original mixed-domain shaders."}
	for target:String in ["res://data/terrain_shader_variant_adoption.json","res://tools/biome_extensions/artifacts/terrain_shader_variant_adoption.json"]:FileAccess.open(target,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SHADER_VARIANT_ADOPTION_SAVED ",hashes.size()," guards / ",images.size()," captures");quit()
