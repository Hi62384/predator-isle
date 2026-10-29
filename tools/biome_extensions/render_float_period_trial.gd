extends "res://tools/biome_extensions/render_all.gd"
## Cold private shader trial. Production source files are never edited.
var held_shader:Shader
func run()->void:
	var original_only:bool=OS.get_cmdline_user_args().has("original")
	var renamed_control:bool=OS.get_cmdline_user_args().has("renamed_original")
	var integer_mode:bool=OS.get_cmdline_user_args().has("integer")
	var label:String="float_period_original" if original_only else "float_period_private"
	if renamed_control:label="float_period_renamed_original"
	if integer_mode:label="integer_period_private"
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	assert(not ResourceLoader.has_cached("res://materials/terrain.tres"),"No prewarmed terrain image banks")
	for path:String in ["res://tools/biome_extensions/render_float_period_trial.gd","res://tools/biome_extensions/biological_float_period_candidate.gd","res://tools/biome_extensions/biological_integer_period_candidate.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scenes/main.tscn"]:hashes[path]=FileAccess.get_sha256(path)
	var tissue:String=preload("res://tools/biome_extensions/biological_float_period_candidate.gd").apply_to(FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
	if integer_mode:tissue=preload("res://tools/biome_extensions/biological_integer_period_candidate.gd").apply_to(FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
	if renamed_control:tissue=FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc").replace("biological_sample(","biological_sample_cold_baseline(")
	var extensions:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc").replace('#include "res://shaders/biological_sampling.gdshaderinc"',tissue)
	if renamed_control:extensions=extensions.replace("biological_sample(","biological_sample_cold_baseline(")
	held_shader=load("res://shaders/terrain_biomes.gdshader")
	if not original_only or renamed_control:held_shader.code=held_shader.code.replace('#include "res://shaders/biome_extensions.gdshaderinc"',extensions)
	var generated_sha:String=held_shader.code.sha256_text()
	print("FLOAT_PERIOD_COLD_SHADER ",label," ",generated_sha," engine_shader_cache_disabled=",OS.get_cmdline_args().has("--disable-shader-cache"))
	if renamed_control:assert(not held_shader.code.contains("biological_sample("),"Rename every declaration/call,change no arithmetic")
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=6000
	terrain=scene.get_node("Terrain");terrain.target=camera;terrain.maximum_lod=3;terrain.specialize_terrain_shader=false
	for property:Dictionary in terrain.get_property_list():
		if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
	terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false;terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for owner:String in ["grass","forest","jungle","savanna","swamp","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:terrain.settings.set(owner+"_coverage",0)
	for owner:String in ["grass","forest","badlands","spore_forest","alien_infected"]:terrain.settings.set(owner+"_coverage",20)
	terrain.settings.biome_size=.2;terrain.settings.island_size=100400;terrain.settings.island_spacing=585;terrain.settings.beaches_enabled=true;terrain.settings.rocky_coast_enabled=true
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=terrain.world_seed;b._configure_noise()
	var p:=Vector2.ZERO;var best:float=-1
	for i in range(1200):
		var q:=Vector2(i*7919%120000-60000,i*11939%120000-60000)
		if b._island_mask(q.x,q.y)<.03:continue
		var legacy:Vector4=b._biome_weights(q.x,q.y);var spore:float=b._extra_weights[3];var score:float=minf(spore,1-spore)
		if score>best:best=score;p=q
	assert(best>.01,"Actual mixed Spore ownership required")
	var focus:=Vector3(p.x,b._get_height(p.x,p.y)+8,p.y);camera.position=focus+Vector3(-130,70,-180)
	var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());camera.look_at(focus)
	assert(terrain._terrain_material.shader==held_shader and terrain._terrain_material.shader.code.sha256_text()==generated_sha,"Actual worker material uses the cold private master shader")
	await capture(label,"mixed",focus,Vector3(-130,70,-180))
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	var path:String="res://tools/biome_extensions/artifacts/"+label+"_mixed.png"
	FileAccess.open("res://tools/biome_extensions/artifacts/render_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"production_registration":false,"original_only":original_only,"engine_shader_cache_disabled":OS.get_cmdline_args().has("--disable-shader-cache"),"driver_cache_not_controlled":true,"source_sha256":hashes,"generated_shader_sha256":generated_sha,"capture_sha256":{path:FileAccess.get_sha256(path)},"captures":records,"point":[p.x,p.y],"mixed_spore_selection_score":best,"fill_seconds":(Time.get_ticks_usec()-started)/1000000.0,"scope":"Original or private full master shader, loaded before materials/scene without warmup or production file edits. Explicit mixed Grass/Forest/Badlands/Spore/Alien with coasts; boundedLOD3/6km fixture. Optional engine shader-cache disable does not clear the separate driver cache. Original sun/environment; one capture only, not equivalent pixels, full range precision, production adoption, performance gain or art acceptance."},"  "))
	scene.queue_free();await process_frame;quit()
