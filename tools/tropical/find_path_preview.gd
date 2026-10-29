extends SceneTree
var terrain:Node
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func settle()->void:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		assert(Time.get_ticks_msec()-start<120000,"Path preview streaming timeout")
func frame()->Image:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var scene:Node=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=500;camera.far=50000
	terrain=scene.get_node("Terrain");terrain.tropical_preview=true;terrain.tropical_preview_feature="lush_plain";terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();await settle()
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_previews.json"));var item:Dictionary=manifest.features.lush_plain;var found:Dictionary={}
	for attempt in range(16):
		var p:=Vector3(item.x+(attempt%4)*450,0,item.z+(attempt/4)*450);p.y=terrain.get_height_at(p)
		terrain.request_teleport(p+Vector3(0,1000,0));await settle();camera.look_at(p,Vector3.FORWARD);terrain.set_debug_view(137)
		for node:MeshInstance3D in terrain._active_chunks.values():
			var water:MeshInstance3D=node.get_node_or_null("SwampWater")
			if water!=null:water.hide()
		if terrain._water!=null:terrain._water.hide()
		var on:Image=await frame();var best:float=.03;var pixel:=Vector2i(-1,-1)
		for mat:ShaderMaterial in terrain._material_variants():mat.set_shader_parameter("tropical_paths",0)
		var off:Image=await frame()
		for mat:ShaderMaterial in terrain._material_variants():mat.set_shader_parameter("tropical_paths",terrain._settings_snapshot.tropical.paths)
		# Fog remains enabled in this actual scene. Compare the differential,
		# not absolute blue=0: atmospheric blue is not a path signal.
		for y in range(20,700,4):
			for x in range(20,1260,4):
				var delta:float=on.get_pixel(x,y).b-off.get_pixel(x,y).b
				if delta>best:best=delta;pixel=Vector2i(x,y)
		if pixel.x<0:continue
		assert(on.get_pixelv(pixel).b-off.get_pixelv(pixel).b>.03,"Path negative control removes wear signal")
		var origin:Vector3=camera.project_ray_origin(Vector2(pixel));var h:float=terrain.get_height_at(origin)
		found={"x":origin.x,"z":origin.z,"height":h,"water":terrain._sampler.get_water_surface_height(origin.x,origin.z),"score":best,"gpu_verified":true,"shader_sha256":FileAccess.get_sha256("res://shaders/tropical_material.gdshaderinc"),"sampler_sha256":FileAccess.get_sha256("res://scripts/tropical_sampler.gd"),"source":"Native Tropical terrain shader wear mask, paths=0 negative control"}
		on.save_png("res://tools/tropical/artifacts/path_mask_on.png");off.save_png("res://tools/tropical/artifacts/path_mask_off.png");break
	assert(not found.is_empty(),"No actual traversable Tropical wear path found")
	FileAccess.open("res://data/tropical_path_preview.json",FileAccess.WRITE).store_string(JSON.stringify(found,"\t"))
	manifest.features.natural_path=found
	FileAccess.open("res://data/tropical_previews.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("TROPICAL_PATH_PREVIEW ",JSON.stringify(found));scene.queue_free();await process_frame;quit()
