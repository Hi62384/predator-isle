extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var sheets:Dictionary={}
var counts:Dictionary={}
var output:String="res://tools/snow/artifacts/views"
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>90000:push_error("Snow review streaming timeout");return false
	return true
func capture(name:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	var point:Vector3=focus+offset
	var clearance:float=1.8 if kind=="ground" or kind=="normals" else maxf(40.0,offset.y*.15)
	point.y=maxf(point.y,terrain.get_height_at(point)+clearance)
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	camera.near=clampf((point.y-terrain.get_height_at(point))*.01,.1,10)
	if kind=="ground":
		var gx:float=terrain.get_height_at(focus+Vector3(64,0,0))-terrain.get_height_at(focus-Vector3(64,0,0))
		var gz:float=terrain.get_height_at(focus+Vector3(0,0,64))-terrain.get_height_at(focus-Vector3(0,0,64))
		var heading:=Vector3(-gx,0,-gz).normalized() if absf(gx)+absf(gz)>2 else Vector3(1,0,1).normalized()
		var look:Vector3=point+heading*180;look.y=point.y-8
		camera.look_at(look)
	else:camera.look_at(focus)
	terrain.set_debug_view(debug)
	for i in range(18):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();assert(image!=null and not image.is_empty())
	assert(image.save_png(output+"/"+name+"_"+kind+".png")==OK)
	if not sheets.has(kind):sheets[kind]=Image.create_empty(2560,1800,false,Image.FORMAT_RGBA8);counts[kind]=0
	var thumbnail:Image=image.duplicate();thumbnail.resize(640,360,Image.INTERPOLATE_LANCZOS);thumbnail.convert(Image.FORMAT_RGBA8)
	var tile:int=counts[kind];counts[kind]=tile+1;sheets[kind].blit_rect(thumbnail,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
	records.append({"feature":name,"view":kind,"camera":str(camera.position),"focus":str(focus),"debug":debug,"leaves":terrain._active_chunks.size(),"gpu_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	print("SNOW_CAPTURE ",name," ",kind)
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Rendered review requires a display");quit(2);return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/snow_previews.json"))
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.snow_preview=true;terrain.target=camera;terrain.world_seed=manifest.seed
	root.add_child(scene);scene.get_node("Interface").hide()
	if not await settle():quit(1);return
	var previous_partial:bool=false
	for name:String in preload("res://tools/snow/find_previews.gd").NAMES:
		var selected:String=""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("feature="):selected=argument.trim_prefix("feature=")
		if not selected.is_empty() and selected!=name:continue
		if name=="grass_snow_transition" or name=="partial_lake" or previous_partial:
			# Separate runtime controller to apply the declared mixed preset.
			scene.queue_free();await process_frame;await process_frame
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
			terrain=scene.get_node("Terrain");terrain.snow_preview=true;terrain.snow_preview_feature=name;terrain.target=camera
			root.add_child(scene);scene.get_node("Interface").hide()
			if not await settle():quit(1);return
		previous_partial=name=="partial_lake"
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=terrain.get_height_at(focus)
		var ground:=Vector3(-18,0,-26);ground.y=terrain.get_height_at(focus+ground)+1.8-focus.y
		await capture(name,"ground",focus,ground)
		await capture(name,"medium",focus,Vector3(-300,180,-420))
		if not selected.is_empty():await capture(name,"albedo",focus,Vector3(-300,180,-420),3)
		await capture(name,"aerial",focus,Vector3(-2200,1600,-2800))
		await capture(name,"regions",focus,Vector3(-800,600,-1100),42)
		await capture(name,"normals",focus,Vector3(-18,ground.y,-26),52)
	for kind:String in sheets:sheets[kind].save_png(output+"/contact_"+kind+".png")
	var result:Dictionary={"captures":records,"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"lighting":"unchanged main.tscn environment and sun","seed":73921,"features":manifest.features.size()}
	var file:=FileAccess.open("res://tools/snow/artifacts/render_review.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	scene.queue_free();await process_frame;print("SNOW_RENDER_REVIEW_DONE ",records.size());quit()
