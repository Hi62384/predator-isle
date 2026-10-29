extends SceneTree
func _initialize()->void:
	var guards:Dictionary={};var images:Dictionary={};var reports:Dictionary={}
	for name:String in ["check_crystal_bulk_optics","admit_crystal_bulk_styles","render_crystal_bulk_candidate","render_crystal_bulk_actual_habits"]:
		var path:String="res://tools/biome_extensions/artifacts/"+name+".json";var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed and report.failures.is_empty());guards[path]=FileAccess.get_sha256(path)
		for source:String in report.source_sha256:assert(FileAccess.get_sha256(source)==report.source_sha256[source]);guards[source]=report.source_sha256[source]
		for capture:String in report.get("capture_sha256",{}):assert(FileAccess.get_sha256(capture)==report.capture_sha256[capture]);images[capture]=report.capture_sha256[capture]
		reports[name]={"checks":report.get("checks",null),"images":report.get("capture_sha256",{}).size()}
	assert(images.size()==55)
	for name:String in ["failed_diagnostic_render_crystal_bulk_candidate_2fbdaf0d2b3f","failed_diagnostic_admit_crystal_bulk_styles_195b2e8f3654"]:
		var path:String="res://tools/biome_extensions/artifacts/revisions/"+name+"/manifest.json";var manifest=JSON.parse_string(FileAccess.get_file_as_string(path));guards[path]=FileAccess.get_sha256(path)
		for copy:Dictionary in manifest.files:assert(FileAccess.get_sha256(copy.snapshot)==copy.sha256)
	guards["res://tools/biome_extensions/save_crystal_bulk_trial.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/save_crystal_bulk_trial.gd")
	FileAccess.open("res://tools/biome_extensions/artifacts/crystal_bulk_trial.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"production_registration":false,"source_sha256":guards,"capture_sha256":images,"reports":reports,"all_user_tasks_complete":false,"scope":"Private accepted optical trial before registration:actual emitted cross-section/growth metadata,six mineral optical families,18 complete geometry-preserving primitive pairs,49152 independent GPU/CPU absorption samples,12 original geographic views/36same-scene images plus six separately pre-admitted actual-habit positive views/18images,18exact original returns. Large masses mostly opaque,limited thin-material transmission,true depth writes,restrained growth zoning. Water heldTIME0 in private material duplicates for strict image returns;original live-time failures retained. Initial9x9 smoky-root admission failure retained;separate33x33 search fixed before positive views. No geometry/collision/lighting/production-time change. Not ray-traced refraction or measured PBR scans,CPU/GPU speedup,whole-surface art or cave completion."},"  "))
	print("CRYSTAL_BULK_TRIAL ",guards.size()," guards / ",images.size()," images");quit()
