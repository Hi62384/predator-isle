extends SceneTree
var failures:Array=[]
func report_basename()->String:return "check_production_game_startup"
func intervention()->Dictionary:return {}
func extra_guards()->Dictionary:return {}
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720))
	var paths:Array[String]=[get_script().resource_path,"res://project.godot","res://scenes/world_startup.tscn","res://scripts/world_startup.gd","res://scripts/terrain_shader_preparation.gd","res://scripts/terrain_shader_variants.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biological_sampling.gdshaderinc","res://scenes/main.tscn","res://scripts/chunk_terrain.gd","res://config/caves/cave_settings.tres","res://config/caves/cave_biome_regions.tres"]
	var guards:Dictionary={}
	for path:String in paths:guards[path]=FileAccess.get_sha256(path)
	guards["res://tools/biome_extensions/check_game_startup.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_game_startup.gd");guards.merge(extra_guards())
	verify(not ResourceLoader.has_cached("res://materials/terrain.tres"),"Actual startup begins before large terrain image banks")
	verify(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/world_startup.tscn","Production entry scene uses actual preparation path")
	var start:int=Time.get_ticks_msec();var boot=load("res://scenes/world_startup.tscn").instantiate();root.add_child(boot);current_scene=boot
	while current_scene==boot or current_scene==null:
		await process_frame
		if Time.get_ticks_msec()-start>180000:verify(false,"Production startup within180s");quit(1);return
	var scene=current_scene;verify(scene.scene_file_path=="res://scenes/main.tscn","Actual original game scene follows preparation")
	var terrain=scene.get_node("Terrain");var camera=scene.get_node("FreeCamera");camera.set_process(false);camera.set_physics_process(false)
	terrain.profile_streaming=true
	var first_visible_s:float=-1;var local_visible_s:float=-1;var last_count:int=-1
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if first_visible_s<0 and not terrain._active_chunks.is_empty():first_visible_s=(Time.get_ticks_msec()-start)/1000.0
		if local_visible_s<0:
			var local_key:=Vector3i(terrain._target_chunk.x,terrain._target_chunk.y,0)
			if terrain._active_chunks.has(local_key):local_visible_s=(Time.get_ticks_msec()-start)/1000.0
		if last_count!=terrain._active_chunks.size():
			last_count=terrain._active_chunks.size()
			var keys:Array=terrain._active_chunks.keys()
			for i in keys.size():
				verify(terrain._active_chunks[keys[i]].visible,"Published startup leaf visible")
				for j in range(i+1,keys.size()):verify(not terrain._partition.bounds(keys[i]).intersects(terrain._partition.bounds(keys[j])),"No overlapping startup leaves")
		if Time.get_ticks_msec()-start>180000:verify(false,"Actual saved fullLOD6 game fills within180s");quit(1);return
	var prepared:Dictionary=root.get_meta("terrain_shader_preparation",{})
	verify(not prepared.is_empty() and not prepared.large_image_banks_loaded_before_preparation,"Preparation precedes original large image banks")
	verify(terrain._terrain_material.shader==prepared.shader,"Actual production game reuses exact prepared shader")
	verify(terrain.maximum_lod==6 and camera.far==50000,"Original saved fullLOD6 and50km camera retained")
	verify(terrain.cave_settings.enabled and is_instance_valid(terrain._cave_streamer),"Saved enabled caves create actual runtime streamer")
	var ids:Array=[]
	for definition:Resource in terrain.cave_settings.biome_regions.definitions:ids.append(str(definition.biome_id))
	verify(ids==["default","frozen","crystal","magma"],"All four actual cave definitions registered")
	verify(scene.get_node_or_null("BlobWorkshop")!=null,"Existing concurrent Blob workshop retained")
	for frame in range(60):await process_frame
	await RenderingServer.frame_post_draw
	var path:String="res://tools/biome_extensions/artifacts/"+report_basename()+".png";verify(root.get_texture().get_image().save_png(path)==OK,"Saved original game startup capture")
	for source:String in guards:verify(FileAccess.get_sha256(source)==guards[source],"Stable actual startup dependency "+source)
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"capture_sha256":{path:FileAccess.get_sha256(path)},"startup_seconds":(Time.get_ticks_msec()-start)/1000.0,"shader_preparation_seconds":prepared.get("seconds",-1),"configured_mask":prepared.get("configured_mask",-1),"active_surface_chunks":terrain._active_chunks.size(),"root_enabled":true,"cave_ids":ids,"maximum_lod":terrain.maximum_lod,"camera_far_m":camera.far,"scope":"Actual saved application entry,preparation,unmodified main content/fullLOD6/50km camera,enabled four-biome runtime. Engine shader cache optionally disabled;driver cache not cleared,other Godot sessions running.500ms process memory receipt separate;not uninterrupted traversal FPS or reference-art acceptance."}
	report["private_intervention"]=intervention()
	report["first_visible_terrain_seconds"]=first_visible_s;report["local_full_detail_seconds"]=local_visible_s
	report["streaming_records"]=terrain.streaming_records
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_basename()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("PRODUCTION_GAME_STARTUP ",report.startup_seconds,"s mask=",report.configured_mask," chunks=",report.active_surface_chunks," failures=",failures)
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
