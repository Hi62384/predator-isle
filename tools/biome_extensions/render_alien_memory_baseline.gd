extends "res://tools/biome_extensions/render_all.gd"
## Unmodified production renderer under the SAME bound as the private trial.
var private_shader_override:bool=false
func prepare_shader()->void:pass
func output_basename()->String:return "render_alien_memory_baseline"
func report_metadata()->Dictionary:return {}
func run()->void:
	print("ALIEN_MEMORY_BASELINE_BEGIN")
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed)
	for path:String in regression.source_sha256:
		# Inventory the prior regression's files, but hash CURRENT bytes. This is
		# a new baseline for the sampler correction, not reuse of an old result.
		var canonical:String="res://"+path.replace("\\","/");hashes[canonical]=FileAccess.get_sha256(canonical)
	for path:String in ["res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_alien_memory_baseline.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	await prepare_shader()
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(manifest.passed);var site:Dictionary=manifest.cases[0]
	var p:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	print("ALIEN_MEMORY_BASELINE_INSTANTIATED")
	terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();print("ALIEN_MEMORY_BASELINE_SCENE_ADDED");assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
	print("ALIEN_MEMORY_BASELINE_INITIAL_SETTLE_DONE")
	var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y)
	await capture(output_basename(),"ground",focus,Vector3(-90,4-site.junction_height*.4,-130))
	for path:String in hashes:assert(hashes[path]==FileAccess.get_sha256(path))
	var report:Dictionary={"passed":true,"failures":[],"actual_render":true,"unmodified_production_shaders":not private_shader_override,"source_sha256":hashes,"captures":records,"scope":"One same-root full-production-hierarchy rendering control with unchanged camera/lighting. The unmodified_production_shaders flag distinguishes an inherited private process-local shader override, if any; overrides are never saved by this fixture. Runner bounds are external; a separately declared characterization is NOT a pass of an earlier lower memory gate. Not an isolated shader-only, broad memory/performance or art certificate."}
	report.merge(report_metadata(),false)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+output_basename()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	scene.queue_free();await process_frame;quit()
