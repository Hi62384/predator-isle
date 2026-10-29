extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func settle()->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-start<90000)
func frame(mode:int)->Image:
	terrain.set_debug_view(mode)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.near=.1;terrain=scene.get_node("Terrain");terrain.jungle_preview=true;terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();await settle()
	# Freeze only this test scene's animated water, so shoreline motion cannot
	# be mistaken for an effect of changing terrain normal strength.
	if terrain._water!=null:terrain._water.mesh.material.set_shader_parameter("wave_speed",0)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/jungle_previews.json"));var records:Array=[];var failures:Array=[]
	for name:String in ["lowland_rainforest","rocky_jungle","floodplain"]:
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=terrain.get_height_at(focus)
		var point:Vector3=focus+Vector3(-6,0,-8);point.y=maxf(terrain.water_level,terrain.get_height_at(point))+2;terrain.request_teleport(point);await settle();camera.look_at(point+Vector3(12,-4,16))
		var on:Image=await frame(0);var off:Image=await frame(7)
		var config:JungleSettings=terrain._settings_snapshot.jungle
		for mat:ShaderMaterial in terrain._material_variants():mat.set_shader_parameter("jungle_normal_strength",0);mat.set_shader_parameter("jungle_rock_normal",0)
		var zero:Image=await frame(0)
		for mat:ShaderMaterial in terrain._material_variants():mat.set_shader_parameter("jungle_normal_strength",config.normal_strength);mat.set_shader_parameter("jungle_rock_normal",config.rock_normal_strength)
		var albedo:Image=await frame(3);var mask:Image=await frame(33);var mean:float=0;var maximum_error:float=0;var count:int=0;var changed:int=0
		for z in range(image_top(on),on.get_height()-20,3):
			for x in range(20,on.get_width()-20,3):
				# Exclude sky, ocean, and non-Jungle coast/background. Zeroing
				# Jungle controls must not disable those legacy material normals.
				var m:Color=mask.get_pixel(x,z)
				if maxf(m.r,maxf(m.g,m.b))<.35 or minf(m.r,minf(m.g,m.b))>.05:continue
				var a:Color=on.get_pixel(x,z);var b:Color=off.get_pixel(x,z);var c:Color=zero.get_pixel(x,z)
				var delta:float=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3;mean+=delta;count+=1
				if delta>.003:changed+=1
				maximum_error=maxf(maximum_error,maxf(absf(b.r-c.r),maxf(absf(b.g-c.g),absf(b.b-c.b))))
		mean/=maxi(count,1)
		var passed:bool=count>100 and mean>.0001 and changed>10 and maximum_error<.008
		if not passed:failures.append(name)
		records.append({"feature":name,"pixels_tested":count,"mean_rgb_difference":mean,"changed_pixels":changed,"zero_strength_vs_normal_off_error":maximum_error,"passed":passed})
		on.save_png("res://tools/jungle/artifacts/normal_"+name+"_on.png");off.save_png("res://tools/jungle/artifacts/normal_"+name+"_off.png");albedo.save_png("res://tools/jungle/artifacts/albedo_"+name+".png")
	var report:Dictionary={"records":records,"failures":failures,"actual_render":true,"lighting":"original scene unchanged"}
	FileAccess.open("res://tools/jungle/artifacts/normal_visibility.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("JUNGLE_NORMAL_VISIBILITY ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
func image_top(image:Image)->int:return int(image.get_height()*.48)
