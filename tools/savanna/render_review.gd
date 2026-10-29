extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var output:String="res://tools/savanna/artifacts/views"
var sheets:Dictionary={}
var counts:Dictionary={}
var selected:String=""
var trail_direction:=Vector3.FORWARD
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>90000:push_error("Savanna streaming timeout");return false
	return true
func capture(name:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	var point:Vector3=focus-trail_direction*4 if name=="worn_trail" and kind=="ground" else focus+offset;point.y=maxf(point.y,maxf(terrain.water_level,terrain.get_height_at(point))+(1.8 if kind=="ground" else 30))
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	camera.near=.1 if kind=="ground" else 1
	if kind=="ground":
		var look:Vector3=focus+Vector3(0,10,0) if name=="isolated_kopje" or name=="kopje_country" else (point+trail_direction*30+Vector3(0,-3,0) if name=="worn_trail" else point+Vector3(60,-5,80));camera.look_at(look)
	else:camera.look_at(focus)
	terrain.set_debug_view(debug)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();assert(image.save_png(output+"/"+name+"_"+kind+".png")==OK)
	if not sheets.has(kind):sheets[kind]=Image.create_empty(2560,2160,false,Image.FORMAT_RGBA8);counts[kind]=0
	var small:Image=image.duplicate();small.resize(640,360,Image.INTERPOLATE_LANCZOS);small.convert(Image.FORMAT_RGBA8)
	var tile:int=counts[kind];counts[kind]=tile+1;sheets[kind].blit_rect(small,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
	records.append({"feature":name,"view":kind,"focus":str(focus),"camera":str(point),"debug":debug,"leaves":terrain._active_chunks.size()});print("SAVANNA_CAPTURE ",name," ",kind)
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/savanna_previews.json"))
	var names:Array=preload("res://tools/savanna/find_previews.gd").NAMES.duplicate();names.append_array(preload("res://tools/savanna/find_previews.gd").EXTRA)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("feature="):selected=arg.trim_prefix("feature=")
	for name:String in names:
		if not selected.is_empty() and not selected.split(",").has(name):continue
		if not manifest.features.has(name):push_error("Missing feature "+name);quit(1);return
		if scene!=null:scene.queue_free();await process_frame;await process_frame
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.savanna_preview=true;terrain.savanna_preview_feature=name;terrain.target=camera
		root.add_child(scene);scene.get_node("Interface").hide()
		if not await settle():quit(1);return
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=maxf(terrain.water_level,terrain.get_height_at(focus))
		if name=="worn_trail":focus=await find_trail(focus)
		var ground:=Vector3(-500,0,-650) if name=="isolated_kopje" or name=="kopje_country" else (Vector3(-2,0,-3) if name=="worn_trail" else Vector3(-18,0,-26));ground.y=maxf(terrain.water_level,terrain.get_height_at(focus+ground))+1.8-focus.y
		await capture(name,"ground",focus,ground)
		await capture(name,"medium",focus,Vector3(-300,180,-420))
		await capture(name,"aerial",focus,Vector3(-2200,1600,-2800))
		await capture(name,"materials",focus,Vector3(-300,180,-420),57)
		await capture(name,"normals",focus,ground,60)
		if name=="worn_trail":await capture(name,"paths",focus,Vector3(-50,55,-70),59)
	var suffix:String="" if selected.is_empty() else "_"+selected
	for kind:String in sheets:sheets[kind].save_png(output+"/contact_"+kind+suffix+".png")
	FileAccess.open("res://tools/savanna/artifacts/render_review"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"captures":records,"far_mesh_metres":terrain._settings_snapshot.savanna.far_mesh_metres,"lighting":"unchanged main.tscn","foliage_rendered":false},"\t"))
	scene.queue_free();await process_frame;print("SAVANNA_REVIEW_DONE ",records.size());quit()


func find_trail(focus:Vector3)->Vector3:
	for offset:Vector2 in [Vector2.ZERO,Vector2(800,0),Vector2(-800,0),Vector2(0,800),Vector2(0,-800),Vector2(800,800),Vector2(-800,-800),Vector2(1600,0),Vector2(0,1600)]:
		var search:Vector3=focus+Vector3(offset.x,0,offset.y);search.y=terrain.get_height_at(search)
		var found:Vector3=await probe_trail(search)
		if found.is_finite():return found
	push_error("No rendered Savanna trail found in nine bounded preview probes");return focus
func probe_trail(focus:Vector3)->Vector3:
	var point:Vector3=focus+Vector3(-300,220,-420);point.y=maxf(point.y,terrain.get_height_at(point)+80);terrain.request_teleport(point)
	await settle();camera.look_at(focus);terrain.set_debug_view(59)
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var mask:Image=root.get_texture().get_image();mask.save_png(output+"/trail_probe.png")
	for y in range(260,680,2):
		for x in range(60,1220,2):
			var c:Color=mask.get_pixel(x,y)
			if c.r<.1 or absf(c.r-c.g)>.025 or absf(c.r-c.b)>.025:continue
			var screen:=Vector2(x,y);var origin:Vector3=camera.project_ray_origin(screen);var ray:Vector3=camera.project_ray_normal(screen)
			var previous:float=1
			for t in range(10,2000,10):
				var hit:Vector3=origin+ray*float(t);var h:float=terrain.get_height_at(hit)
				if hit.y<=h:
					var lo:float=previous;var hi:float=t
					for k in range(14):
						var mid:float=(lo+hi)*.5;var sample:Vector3=origin+ray*mid
						if sample.y>terrain.get_height_at(sample):lo=mid
						else:hi=mid
					hit=origin+ray*((lo+hi)*.5);hit.y=terrain.get_height_at(hit)
					if hit.y>terrain.water_level+1:
						var cxx:float=0;var cyy:float=0;var cxy:float=0
						for py in range(-8,9,2):
							for px in range(-8,9,2):
								var c2:Color=mask.get_pixel(x+px,y+py)
								if c2.r<.1 or absf(c2.r-c2.g)>.025 or absf(c2.r-c2.b)>.025:continue
								cxx+=px*px*c2.r;cyy+=py*py*c2.r;cxy+=px*py*c2.r
						var angle:float=.5*atan2(2*cxy,cxx-cyy)
						var next:Vector3=trace_pixel(screen+Vector2.from_angle(angle)*6)
						if next.is_finite():
							trail_direction=Vector3(next.x-hit.x,0,next.z-hit.z).normalized()
						print("SAVANNA_ACTUAL_TRAIL ",hit," tangent=",trail_direction);return hit
					break
				previous=t
	return Vector3(INF,INF,INF)


func trace_pixel(screen:Vector2)->Vector3:
	var origin:Vector3=camera.project_ray_origin(screen);var ray:Vector3=camera.project_ray_normal(screen);var previous:float=1
	for t in range(10,2000,10):
		var hit:Vector3=origin+ray*float(t)
		if hit.y<=terrain.get_height_at(hit):
			var lo:float=previous;var hi:float=t
			for k in range(14):
				var mid:float=(lo+hi)*.5;var sample:Vector3=origin+ray*mid
				if sample.y>terrain.get_height_at(sample):lo=mid
				else:hi=mid
			return origin+ray*((lo+hi)*.5)
		previous=t
	return Vector3(INF,INF,INF)
