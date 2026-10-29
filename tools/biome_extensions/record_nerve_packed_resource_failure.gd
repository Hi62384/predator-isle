extends SceneTree
func _initialize()->void:
	var branch_free:bool=OS.get_cmdline_user_args().has("baseline2")
	var baseline:bool=OS.get_cmdline_user_args().has("baseline") or branch_free
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/render_nerve_film_trial.gd","res://tools/biome_extensions/run_test.ps1","res://tools/biome_extensions/record_nerve_packed_resource_failure.gd","res://shaders/biological_sampling.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://shaders/biome_structures.gdshader","res://scripts/chunk_terrain.gd","res://materials/biological_colors_v2.tres","res://materials/biological_colors_v3.tres","res://materials/biological_color_nerve_v3.res","res://.godot/extensions_render_nerve_film_trial.out.log","res://.godot/extensions_render_nerve_film_trial.err.log","res://.godot/extensions_render_nerve_film_trial.engine.log"]:hashes[path]=FileAccess.get_sha256(path)
	if baseline:
		for path:String in ["res://tools/biome_extensions/render_alien_memory_baseline.gd","res://.godot/extensions_render_alien_memory_baseline.out.log","res://.godot/extensions_render_alien_memory_baseline.err.log","res://.godot/extensions_render_alien_memory_baseline.engine.log"]:hashes[path]=FileAccess.get_sha256(path)
	else:assert(not FileAccess.file_exists("res://tools/biome_extensions/artifacts/render_nerve_film_packed_trial.json"))
	var observed:float=2069.1 if baseline else 2086.7;var engine_pid:int=33112 if baseline else 10508
	if branch_free:engine_pid=13844
	var report_name:String="render_alien_phase_baseline_resource_failure" if baseline else "render_nerve_film_packed_resource_failure"
	if branch_free:report_name+="_branch_free"
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"failures":["The fixture runner stopped its own engine PID"+str(engine_pid)+" after observing "+str(observed)+"MiB private memory against the predeclared 2048MiB limit, before any capture/result."],"source_sha256":hashes,"preserved_utc":Time.get_datetime_string_from_system(true),"memory_limit_mib":2048,"observed_private_mib":observed,"sample_period_ms":500,"engine_pid":engine_pid,"production_registration":false,"scope":"Forensic preservation-time source/log snapshot. Observation comes from the runner exception, not an engine-log metric or certified peak. Baseline uses original materials without private texture binding, but the newly corrected sampler; its failure shows the new texture is not necessary for the observed failure, not a definitive compiler/driver-cause diagnosis. No completed render, production adoption or art acceptance."},"  "))
	quit()
