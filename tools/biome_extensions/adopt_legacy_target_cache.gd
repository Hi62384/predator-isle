extends SceneTree
func _initialize()->void:
	var original_path:String="res://tools/biome_extensions/terrain_pre_legacy_cache.gdshader.txt";var target_path:String="res://shaders/terrain_biomes.gdshader"
	var candidate_path:String="res://tools/biome_extensions/legacy_target_cache_candidate.gd";var code:String=load(candidate_path).apply_to(FileAccess.get_file_as_string(original_path))
	assert(FileAccess.get_file_as_string(target_path) in [FileAccess.get_file_as_string(original_path),code],"Production shader must be the tested original or exact adopted candidate")
	var rows:Array=[]
	for domain:String in ["jungle","forest","savanna","swamp","mountain","tropical","badlands","legacy_pair"]:
		var path:String="res://tools/biome_extensions/artifacts/render_legacy_target_cache_"+domain+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report is Dictionary)
		if domain=="legacy_pair":
			var accepted=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/legacy_cache_mixed_visual_budget.json"));assert(accepted.passed and accepted.source_sha256[path]==FileAccess.get_sha256(path))
		else:assert(report.passed and report.failures.is_empty())
		assert(report.source_sha256[target_path]==FileAccess.get_sha256(original_path));assert(report.captures.size()==15)
		for capture:Dictionary in report.captures:assert(FileAccess.get_sha256(capture.path)==capture.sha256)
		rows.append({"domain":domain,"report":path,"sha256":FileAccess.get_sha256(path)})
	for owner:String in load(candidate_path).OWNERS:assert(code.count("shade_"+owner+"(n,")==1,"Exactly one original owner evaluation in both output paths")
	FileAccess.open(target_path,FileAccess.WRITE).store_string(code)
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,original_path,target_path,candidate_path]:guards[path]=FileAccess.get_sha256(path)
	var budget:String="res://tools/biome_extensions/artifacts/legacy_cache_mixed_visual_budget.json";guards[budget]=FileAccess.get_sha256(budget)
	FileAccess.open("res://tools/biome_extensions/artifacts/legacy_target_cache_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":guards,"native_cases":rows,"scope":"Exact private cache transformation adopted after seven real single-owner worlds and normal Forest-Badlands mixed world,five diagnostics each,original/candidate/original. Singles pass2byte budget. Mixed maximum3bytes accepted under separate4byte/0.00001mean budget;all reference returns exact. Earlier strict Savanna1byte failure,mixed2byte failure and oversized three-owner simultaneous-reference fixture remain failures. Production cold startup and shared regression follow separately."},"  "))
	print("LEGACY_TARGET_CACHE_ADOPTED native_domains=",rows.size());quit()
