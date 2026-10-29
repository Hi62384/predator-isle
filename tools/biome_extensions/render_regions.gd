extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var catalogue=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"));var failures:Array=[];var travel:Array=[]
	var selected:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):selected=arg.trim_prefix("only=")
	for key:String in TerrainSettings.EXTENSION_KEYS:
		if not selected.is_empty() and selected!=key:continue
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);terrain=scene.get_node("Terrain");terrain.extension_preview=key;terrain.target=camera;var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();await settle();fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
		var day:Environment=scene.get_node("WorldEnvironment").environment;var night:Environment=day.duplicate(true);night.ambient_light_energy=.035;night.ambient_light_color=Color(.12,.17,.24)
		var sky:ProceduralSkyMaterial=night.sky.sky_material;sky.sky_top_color=Color(.003,.006,.012);sky.sky_horizon_color=Color(.009,.015,.025);sky.ground_horizon_color=Color(.009,.015,.025)
		for region_key:String in catalogue.families[key].regions:
			var site:Dictionary=catalogue.families[key].regions[region_key];var p:=Vector3(site.x,0,site.z);p.y=terrain.get_height_at(p)
			if not p.is_finite():failures.append(key+region_key+" nonfinite");continue
			var before:int=Time.get_ticks_usec();scene.get_node("WorldEnvironment").environment=day;scene.get_node("Sun").light_energy=1.15
			await capture(key,"region_"+region_key+"_day",p,Vector3(-420,250,-600));travel.append({"biome":key,"region":region_key,"teleport_and_capture_s":(Time.get_ticks_usec()-before)/1000000.0})
			scene.get_node("WorldEnvironment").environment=night;scene.get_node("Sun").light_energy=.025
			await capture(key,"region_"+region_key+"_night",p,Vector3(-420,250,-600))
		scene.queue_free();await process_frame;await process_frame
	FileAccess.open("res://tools/biome_extensions/artifacts/render_regions"+("_"+selected if not selected.is_empty() else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"captures":records,"travel":travel,"failures":failures,"scope":"All six current major regional families, day and low-light states; teleport stress, not continuous-flight certification","artistic_signoff":false},"\t"));print("REGIONAL_RENDER_DONE ",records.size());quit(0 if failures.is_empty() else 1)
