extends "res://tools/biome_extensions/render_all.gd"
## Cold private shader trial. Production source files are never edited.
var held_shader:Shader
func run()->void:
	var original_only:bool=OS.get_cmdline_user_args().has("original")
	var label:String="prepared_tissue_target_private"
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	assert(not ResourceLoader.has_cached("res://materials/terrain.tres"),"No prewarmed terrain image banks")
	for path:String in [get_script().resource_path,"res://tools/biome_extensions/render_all.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scenes/main.tscn","res://project.godot"]:hashes[path]=FileAccess.get_sha256(path)
	held_shader=load("res://shaders/terrain_biomes.gdshader")
	assert(root.has_meta("prepared_tissue_target_shader"),"Run through the private tiny-image preparation bootstrap")
	var prepared:Dictionary=root.get_meta("prepared_tissue_target_shader");hashes.merge(prepared.source_sha256)
	assert(held_shader==prepared.shader and held_shader.code.sha256_text()==prepared.generated_sha256,"Exact already-prepared program survives image-bank/scene load")
	var generated_sha:String=held_shader.code.sha256_text()
	print("FLOAT_PERIOD_COLD_SHADER ",label," ",generated_sha," engine_shader_cache_disabled=",OS.get_cmdline_args().has("--disable-shader-cache"))
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
