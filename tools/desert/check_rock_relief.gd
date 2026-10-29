extends "res://tools/desert/preview_desert.gd"
## Framebuffer test: broad relief must visibly change exposed-rock normals,
## but must not change albedo-family masks or diagnostic albedo.
func grab()->Image:
	for frame in range(10):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Rendered viewport required");quit(2);return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(800,450));root.size=Vector2i(800,450)
	scene=load("res://scenes/main.tscn").instantiate();terrain=scene.get_node("Terrain")
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	terrain.settings.grass_coverage=0;terrain.settings.desert_coverage=100;terrain.settings.snow_coverage=0;terrain.settings.stone_coverage=0;terrain.settings.temperature_enabled=false
	camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	root.add_child(scene);scene.get_node("Interface").hide()
	var focus:=Vector3(-19968,0,35584);focus.y=terrain.get_height_at(focus)
	var position:Vector3=focus+Vector3(550,210,620)
	position.y=maxf(position.y,terrain.get_height_at(position)+20)
	terrain.request_teleport(position)
	if not await settle():quit(1);return
	camera.look_at(focus)
	set_view_parameter("debug_view",48)
	var mask:Image=await grab()
	set_view_parameter("debug_view",8)
	set_view_parameter("desert_rock_form_strength",0.0)
	var off:Image=await grab()
	set_view_parameter("desert_rock_form_strength",0.65)
	var on:Image=await grab()
	set_view_parameter("debug_view",0);set_view_parameter("diagnostic_surface",2)
	var albedo_on:Image=await grab()
	set_view_parameter("desert_rock_form_strength",0.0)
	var albedo_off:Image=await grab()
	var exposed:int=0;var changed:int=0;var albedo_changed:int=0
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			var m:Color=mask.get_pixel(x,y)
			if m.g<m.r*1.5 or m.g<m.b*1.5 or m.g<0.2:continue
			exposed+=1
			var delta:Color=on.get_pixel(x,y)-off.get_pixel(x,y)
			if maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b)))>0.01:changed+=1
			if albedo_on.get_pixel(x,y)!=albedo_off.get_pixel(x,y):albedo_changed+=1
	var failures:Array[String]=[]
	if exposed<1000:failures.append("Insufficient exposed rock pixels")
	if changed<exposed/20:failures.append("Broad relief not visibly affecting normals")
	if albedo_changed>0:failures.append("Normal-only control changed diagnostic albedo")
	var report:Dictionary={"exposed_rock_pixels":exposed,"visibly_changed_normal_pixels":changed,"albedo_changed_pixels":albedo_changed,"failures":failures,"source_hashes":{"shaders/desert_material.gdshaderinc":FileAccess.get_sha256("res://shaders/desert_material.gdshaderinc"),"scripts/desert_settings.gd":FileAccess.get_sha256("res://scripts/desert_settings.gd")}}
	FileAccess.open("res://tools/desert/rock_relief_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for failure in failures:push_error(failure)
	print(JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
