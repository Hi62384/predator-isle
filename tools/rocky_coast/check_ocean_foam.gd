extends SceneTree
func _initialize()->void:call_deferred("run")
func settle(terrain:Node)->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame;assert(Time.get_ticks_msec()-start<120000)
func frame()->Image:
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var scene=load("res://scenes/main.tscn").instantiate();var camera:Camera3D=scene.get_node("FreeCamera");camera.set_script(null)
	var terrain=scene.get_node("Terrain");terrain.coast_preview=true;terrain.coast_preview_feature="isolated_stack";terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();await settle(terrain)
	var item:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocky_coast_previews.json")).features.isolated_stack
	var focus:=Vector3(item.x,0,item.z);focus.y=terrain.get_height_at(focus);var point:Vector3=focus+Vector3(item.outward_x*900,350,item.outward_z*900)
	terrain.request_teleport(point);await settle(terrain);camera.look_at(focus)
	var ocean:ShaderMaterial=terrain._water.mesh.material;ocean.set_shader_parameter("wave_speed",0);ocean.set_shader_parameter("wave_height",0)
	for node:MeshInstance3D in terrain._active_chunks.values():
		var local:MeshInstance3D=node.get_node_or_null("SwampWater")
		if local!=null:local.hide()
	var on:Image=await frame();ocean.set_shader_parameter("coast_foam_strength",0);var off:Image=await frame()
	ocean.set_shader_parameter("coast_foam_debug",true);var mask:Image=await frame()
	var changed:int=0;var water:int=0;var dry_changes:int=0;var maximum:float=0
	for z in range(10,on.get_height()-10,2):
		for x in range(10,on.get_width()-10,2):
			var a:Color=on.get_pixel(x,z);var b:Color=off.get_pixel(x,z);var m:Color=mask.get_pixel(x,z)
			var delta:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			if m.b>.8 and m.b>m.r+.5 and m.b>m.g+.5:
				water+=1;maximum=maxf(maximum,delta)
				if delta>.01:changed+=1
			elif delta>.01:dry_changes+=1
	var passed:bool=water>1000 and changed>30 and maximum>.03 and dry_changes==0
	var report:Dictionary={"passed":passed,"water_pixels":water,"foam_changed_pixels":changed,"non_water_changes":dry_changes,"maximum_difference":maximum,"actual_render":true,"ocean_model":"existing waves and colors; depth-reading variant only when Coast enabled"}
	FileAccess.open("res://tools/rocky_coast/artifacts/ocean_foam.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));on.save_png("res://tools/rocky_coast/artifacts/ocean_foam_on.png");off.save_png("res://tools/rocky_coast/artifacts/ocean_foam_off.png")
	mask.save_png("res://tools/rocky_coast/artifacts/ocean_foam_mask.png")
	print("COAST_OCEAN_FOAM ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if passed else 1)
