extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var output:String="res://tools/beach/artifacts/views"
var sheets:Dictionary={}
var counts:Dictionary={}
var selected:String=""
var only_view:String=""
var batch_label:String=""
var previous_transition:bool=true
var trail_direction:=Vector3.FORWARD
var revision:Dictionary={}
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>90000:push_error("Beach streaming timeout");return false
	return true
func capture(name:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	if not only_view.is_empty() and kind!=only_view:return
	var point:Vector3=focus+offset
	var ground_family:bool=["ground","materials","normals","water"].has(kind)
	var clearance:float=maxf(terrain._sampler.get_water_surface_height(point.x,point.z),terrain.get_height_at(point))
	point.y=maxf(point.y,clearance+(1.8 if ground_family else 30))
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	camera.near=.1 if ground_family else 1
	if kind=="ground":
		camera.look_at(focus)
	else:camera.look_at(focus)
	terrain.set_debug_view(debug)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();assert(image.save_png(output+"/"+name+"_"+kind+".png")==OK)
	if not sheets.has(kind):sheets[kind]=Image.create_empty(2560,3240,false,Image.FORMAT_RGBA8);counts[kind]=0
	var small:Image=image.duplicate();small.resize(640,360,Image.INTERPOLATE_LANCZOS);small.convert(Image.FORMAT_RGBA8)
	var tile:int=counts[kind];counts[kind]=tile+1;sheets[kind].blit_rect(small,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
	records.append({"feature":name,"view":kind,"focus":str(focus),"camera":str(point),"debug":debug,"leaves":terrain._active_chunks.size()});print("BEACH_CAPTURE ",name," ",kind)
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for path:String in ["scripts/beach_sampler.gd","scripts/rocky_coast_sampler.gd","scripts/terrain_mesh_builder.gd","shaders/beach_material.gdshaderinc","shaders/coastal_ocean.gdshader"]:revision[path]=FileAccess.get_sha256("res://"+path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_previews.json"))
	var names:Array=manifest.features.keys()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("feature="):selected=arg.trim_prefix("feature=")
		if arg.begins_with("view="):only_view=arg.trim_prefix("view=")
		if arg.begins_with("batch="):batch_label=arg.trim_prefix("batch=")
	for name:String in names:
		if not selected.is_empty() and not selected.split(",").has(name):continue
		if not manifest.features.has(name):push_error("Missing feature "+name);quit(1);return
		var transition:bool=name.ends_with("_transition")
		if scene==null or transition or previous_transition:
			if scene!=null:scene.queue_free();await process_frame;await process_frame
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
			terrain=scene.get_node("Terrain");terrain.beach_preview=true;terrain.beach_preview_feature=name;terrain.target=camera
			root.add_child(scene);scene.get_node("Interface").hide()
		else:terrain.beach_preview_feature=name
		previous_transition=transition
		if not await settle():quit(1);return
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=maxf(terrain.water_level,terrain.get_height_at(focus))
		focus.y=maxf(focus.y,terrain._sampler.get_water_surface_height(focus.x,focus.z))
		var outward:=Vector3(item.outward_x,0,item.outward_z);var side:=Vector3(-outward.z,0,outward.x)
		var ground:Vector3=-outward*20+side*12;ground.y=maxf(terrain.water_level,terrain.get_height_at(focus+ground))+1.8-focus.y
		await capture(name,"ground",focus,ground)
		if name=="tide_pools" or name=="connected_pools":await capture(name,"pool_close",focus,outward*15+side*10+Vector3(0,18,0))
		if name in ["wide_beach","high_foredunes","lagoon","mixed_rock_sand"]:
			await capture(name,"materials",focus,ground,127)
			await capture(name,"normals",focus,ground,128)
			await capture(name,"water",focus,ground,121)
		await capture(name,"medium",focus,outward*900+side*250+Vector3(0,350,0))
		await capture(name,"aerial",focus,outward*3200+side*1400+Vector3(0,2200,0))
		if only_view=="albedo":await capture(name,"albedo",focus,Vector3(-1800,1000,-2400),3)
		FileAccess.open("res://tools/beach/artifacts/review_progress_"+batch_label+".json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	var suffix:String="" if selected.is_empty() else "_"+selected
	if not batch_label.is_empty():suffix="_batch_"+batch_label
	if not only_view.is_empty():suffix+="_"+only_view+"_only"
	for kind:String in sheets:sheets[kind].save_png(output+"/contact_"+kind+suffix+".png")
	FileAccess.open("res://tools/beach/artifacts/render_review"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"source_sha256":revision,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"captures":records,"far_mesh_metres":terrain._settings_snapshot.rocky_coast.far_mesh_metres,"lighting":"unchanged main.tscn","foliage_rendered":false},"\t"))
	scene.queue_free();await process_frame;print("BEACH_REVIEW_DONE ",records.size());quit()
