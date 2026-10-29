extends "res://tools/biome_extensions/render_all.gd"
func vector(text:String)->Vector2:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector2(float(parts[0]),float(parts[1]))
func start(key:String,p:Vector2,cave_fixture:bool=false)->void:
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);terrain=scene.get_node("Terrain");terrain.extension_preview=key;terrain.extension_preview_position=p;terrain.target=camera
	if cave_fixture:
		terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.get(key).cave_frequency=.5
	var start_time:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();await settle();fill_seconds=(Time.get_ticks_usec()-start_time)/1000000.0
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_features.json"))
	for item:Dictionary in report.cavity_cases:
		var key:String=TerrainSettings.EXTENSION_KEYS[item.family];var site:Dictionary=item.site;var p:Vector2=vector(site.position)
		await start(key,p,true)
		var focus:=Vector3(p.x,site.floor,p.y)
		await capture("cave_"+key,"opening",focus,Vector3(-140,180,-150))
		allow_subsurface=true
		await capture("cave_"+key,"interior",Vector3(p.x+160,site.floor+8,p.y),Vector3(-40,0,0))
		allow_subsurface=false
		scene.queue_free();await process_frame;await process_frame
	var liquids=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_liquids.json"));var seen:Dictionary={}
	for item:Dictionary in liquids.cases:
		if seen.has(item.family):continue
		seen[item.family]=true;var key:String=TerrainSettings.EXTENSION_KEYS[item.family];var p:Vector2=vector(item.position);await start(key,p)
		var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y))+3,p.y)
		await capture("liquid_"+key,"day",focus,Vector3(-160,140,-190))
		scene.get_node("Sun").light_energy=.025
		var env:Environment=scene.get_node("WorldEnvironment").environment.duplicate(true);scene.get_node("WorldEnvironment").environment=env;env.ambient_light_energy=.035;env.ambient_light_color=Color(.12,.17,.24)
		var sky:ProceduralSkyMaterial=env.sky.sky_material;sky.sky_top_color=Color(.003,.006,.012);sky.sky_horizon_color=Color(.009,.015,.025);sky.ground_horizon_color=Color(.009,.015,.025)
		await capture("liquid_"+key,"night",focus,Vector3(-160,140,-190))
		scene.queue_free();await process_frame;await process_frame
	var falls=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_waterfalls.json"));var p:Vector2=vector(falls.cases[0].position);await start("wise_mountains",p)
	var outlet:Vector2=vector(falls.cases[0].outlet)
	await capture("waterfall","connected",Vector3(p.x,24,p.y),Vector3(-4,5,-85*signf(p.y-outlet.y)));scene.queue_free();await process_frame
	FileAccess.open("res://tools/biome_extensions/artifacts/render_features.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"captures":records,"cave_frequency_for_physics_fixtures":.5,"liquids_default_frequency":true,"artistic_signoff":false},"\t"));print("FEATURE_RENDER_DONE ",records.size());quit()
