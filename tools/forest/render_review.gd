extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var output:String="res://tools/forest/artifacts/views"
var sheets:Dictionary={}
var counts:Dictionary={}
var selected:String=""
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>90000:push_error("Forest streaming timeout");return false
	return true
func capture(name:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	var point:Vector3=focus+offset;point.y=maxf(point.y,maxf(terrain.water_level,terrain.get_height_at(point))+(1.8 if kind=="ground" else 30))
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	camera.near=.1 if kind=="ground" else 1
	if kind=="ground":
		var look:Vector3=point+Vector3(60,-5,80);camera.look_at(look)
	else:camera.look_at(focus)
	terrain.set_debug_view(debug)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();assert(image.save_png(output+"/"+name+"_"+kind+".png")==OK)
	if not sheets.has(kind):sheets[kind]=Image.create_empty(2560,1800,false,Image.FORMAT_RGBA8);counts[kind]=0
	var small:Image=image.duplicate();small.resize(640,360,Image.INTERPOLATE_LANCZOS);small.convert(Image.FORMAT_RGBA8)
	var tile:int=counts[kind];counts[kind]=tile+1;sheets[kind].blit_rect(small,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
	records.append({"feature":name,"view":kind,"focus":str(focus),"camera":str(point),"debug":debug,"leaves":terrain._active_chunks.size()});print("FOREST_CAPTURE ",name," ",kind)
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_previews.json"))
	var names:Array=preload("res://tools/forest/find_previews.gd").NAMES.duplicate();names.append_array(["forest_river","forest_stream","forest_lake","forest_ravine","mossy_rock","forest_trail","grass_forest_transition","forest_jungle_transition"])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("feature="):selected=arg.trim_prefix("feature=")
	for name:String in names:
		if not selected.is_empty() and selected!=name:continue
		if not manifest.features.has(name):push_error("Missing feature "+name);quit(1);return
		if scene!=null:scene.queue_free();await process_frame;await process_frame
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.forest_preview=true;terrain.forest_preview_feature=name;terrain.target=camera
		root.add_child(scene);scene.get_node("Interface").hide()
		if not await settle():quit(1);return
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=maxf(terrain.water_level,terrain.get_height_at(focus))
		var ground:=Vector3(-18,0,-26);ground.y=maxf(terrain.water_level,terrain.get_height_at(focus+ground))+1.8-focus.y
		await capture(name,"ground",focus,ground)
		await capture(name,"medium",focus,Vector3(-300,180,-420))
		await capture(name,"aerial",focus,Vector3(-2200,1600,-2800))
		await capture(name,"materials",focus,Vector3(-300,180,-420),45)
		await capture(name,"normals",focus,ground,46)
	var suffix:String="" if selected.is_empty() else "_"+selected
	for kind:String in sheets:sheets[kind].save_png(output+"/contact_"+kind+suffix+".png")
	FileAccess.open("res://tools/forest/artifacts/render_review"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"captures":records,"far_mesh_metres":terrain._settings_snapshot.forest.far_mesh_metres,"lighting":"unchanged main.tscn","foliage_rendered":false},"\t"))
	scene.queue_free();await process_frame;print("FOREST_REVIEW_DONE ",records.size());quit()
