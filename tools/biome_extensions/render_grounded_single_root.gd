extends SceneTree
const INPUT="res://tools/biome_extensions/artifacts/revisions/experiment_ground_union_trial_4da5146ad6b0/sources/tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json.txt"
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_conduit_shoulder_candidate.gd")
	code=code.replace('const DIAGNOSTIC="res://tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json"','const DIAGNOSTIC="'+INPUT+'"')
	var old:String='for path:String in diagnostic.source_sha256:assert(FileAccess.get_sha256(path)==diagnostic.source_sha256[path]);hashes[path]=diagnostic.source_sha256[path]';assert(code.count(old)==1)
	code=code.replace(old,'''var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);hashes[path]=regression.source_sha256[relative]
	for path:String in ["res://data/surface_regression_20261018.json","res://tools/biome_extensions/render_grounded_single_root.gd"]:hashes[path]=FileAccess.get_sha256(path)''')
	var setting:String="terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);";assert(code.count(setting)==1);code=code.replace(setting,setting+"terrain.settings.alien_infected.hive_grounded_shoulders=false;")
	var generator:String="var candidate_script:GDScript=Candidate.script_for();";assert(code.count(generator)==1)
	code=code.replace(generator,'builder.settings.alien_infected.hive_grounded_shoulders=true;var candidate_script:GDScript=load("res://scripts/lod_biome_extension_structures.gd");')
	code=code.replace("shoulder_candidate_","grounded_single_root_").replace("render_conduit_shoulder_candidate.json","render_grounded_single_root.json")
	code=code.replace('"scope":"PRIVATE actual seed17','"scope":"REGISTERED code/settings same-scene ONE-root image comparison at exact original seed17 view. Actual production controller starts with saved flagfalse;full original root rebuild must match committed GPU arrays. Then the actual production geometry class reads flagtrue on the SAME canonical builder to produce the alternative displayed root;no private generator source. NOT a whole-world flag reload. Actual seed17')
	code=code.replace("No production file changed.","Only registered implementation code/settings are exercised.")
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
