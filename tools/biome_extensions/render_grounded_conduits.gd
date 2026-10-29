extends SceneTree
const INPUT="res://tools/biome_extensions/artifacts/revisions/experiment_ground_union_trial_4da5146ad6b0/sources/tools/biome_extensions/artifacts/render_tissue_variation_registered.json.txt"
func _initialize()->void:call_deferred("prepare")
func prepare()->void:
	var code:String=FileAccess.get_file_as_string("res://tools/biome_extensions/render_ground_union_worker_domains.gd")
	code=code.replace('const INPUT="res://tools/biome_extensions/artifacts/render_tissue_variation_registered.json"','const INPUT="'+INPUT+'"')
	var old:String='for path:String in input.source_sha256:verify(FileAccess.get_sha256(path)==input.source_sha256[path],"Fresh original native fixture source "+path);hashes[path]=input.source_sha256[path]';assert(code.count(old)==1)
	code=code.replace(old,'''var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\\\","/");verify(FileAccess.get_sha256(path)==regression.source_sha256[relative],"Fresh registered regression source "+path);hashes[path]=regression.source_sha256[relative]
	for path:String in ["res://data/surface_regression_20261018.json","res://tools/biome_extensions/render_grounded_conduits.gd"]:hashes[path]=FileAccess.get_sha256(path)''')
	assert(code.count("Fixture.configure(terrain,phase==1);")==1);code=code.replace("Fixture.configure(terrain,phase==1);","")
	var settings:String="terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);";assert(code.count(settings)==1);code=code.replace(settings,settings+"terrain.settings.alien_infected.hive_grounded_shoulders=phase==1;")
	var commit:String="var current:Dictionary=cut();";assert(code.count(commit)==1)
	code=code.replace(commit,'verify(terrain._settings_snapshot.alien_infected.hive_grounded_shoulders==(phase==1),"Actual production controller snapshot carries configured setting");verify(terrain._idle_builders.size()>0,"Actual production workers present");\n\t\t\tfor worker in terrain._idle_builders:verify(worker.settings.alien_infected.hive_grounded_shoulders==(phase==1),"Actual production worker snapshot carries configured setting")\n\t\t\t'+commit)
	code=code.replace("ground_union_worker_%d_%d_%s.png","grounded_conduits_worker_%d_%d_%s.png").replace("render_ground_union_worker_domains.json","render_grounded_conduits.json")
	code=code.replace('"scope":"PRIVATE actual four-worker/controller original/candidate/original','"scope":"REGISTERED actual unmodified production controller/workers,independent hive_grounded_shoulders Resource setting false/true/false. Original frozen view coordinates only;CURRENT31-test regression guards all production sources. No private constructor or script substitution. Actual four-worker/controller original/grounded/original')
	code=code.replace("Only one constructor in inherited original dispatch changes;","No constructor in production dispatch changes;the actual saved setting controls geometry.").replace("No production edits.","Only the registered implementation is exercised.")
	var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK);set_script(script);call_deferred("run")
