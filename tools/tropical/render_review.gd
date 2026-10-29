extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var output:String="res://tools/tropical/artifacts/views"
var sheets:Dictionary={}
var counts:Dictionary={}
var selected:String=""
var only_view:String=""
var previous_transition:bool=true
var source_hashes:Dictionary={}
var trail_direction:=Vector3.FORWARD
var sheet_rows:int=9
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>90000:push_error("Tropical streaming timeout");return false
	return true
func capture(name:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	if not only_view.is_empty() and kind!=only_view:return
	var point:Vector3=focus+offset
	var clearance:float=maxf(terrain._sampler.get_water_surface_height(point.x,point.z),terrain.get_height_at(point))
	point.y=maxf(point.y,clearance+(1.8 if kind=="ground" else 30))
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	assert(camera.global_position.distance_to(point)<.01,"Preview camera must reach the committed destination")
	camera.near=.1 if kind=="ground" else 1
	if kind=="ground":
		var look:Vector3=point+trail_direction*30+Vector3(0,-3,0) if name=="natural_path" else focus+Vector3(0,1,0);camera.look_at(look)
	else:camera.look_at(focus)
	terrain.set_debug_view(debug)
	var shader_debug:int=int(terrain._terrain_material.get_shader_parameter("debug_view"))
	if kind=="normals":assert(shader_debug==8,"Use the common mapped-normal diagnostic in mixed-owner scenes")
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();assert(image.save_png(output+"/"+name+"_"+kind+".png")==OK)
	if not sheets.has(kind):sheets[kind]=Image.create_empty(2560,360*sheet_rows,false,Image.FORMAT_RGBA8);counts[kind]=0
	var small:Image=image.duplicate();small.resize(640,360,Image.INTERPOLATE_LANCZOS);small.convert(Image.FORMAT_RGBA8)
	var tile:int=counts[kind];counts[kind]=tile+1;sheets[kind].blit_rect(small,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
	terrain._sampler._biome_weights(focus.x,focus.z)
	var foam_batches:int=0
	for node:MeshInstance3D in terrain._active_chunks.values():
		var features:MeshInstance3D=node.get_node_or_null("TerrainFeatures")
		if features==null or features.mesh==null:continue
		for surface in range(features.mesh.get_surface_count()):
			var material:ShaderMaterial=features.mesh.surface_get_material(surface)
			if int(material.get_shader_parameter("kind"))==3:foam_batches+=1
	records.append({"feature":name,"view":kind,"focus":str(focus),"camera":str(camera.global_position),"camera_forward":str(-camera.global_basis.z),"debug":debug,"shader_debug":shader_debug,"tropical_owner_at_focus":terrain._sampler._tropical_weight,"volcanic_owner_at_focus":terrain._sampler._extra_weights[2],"foam_batches":foam_batches,"leaves":terrain._active_chunks.size(),"committed_revision":terrain.committed_revision,"partition_revision":terrain.partition_revision,"png_sha256":FileAccess.get_sha256(output+"/"+name+"_"+kind+".png")});print("TROPICAL_CAPTURE ",name," ",kind)
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	for path:String in ["res://scripts/tropical_sampler.gd","res://scripts/tropical_settings.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_mesh_builder.gd","res://shaders/tropical_material.gdshaderinc","res://shaders/terrain_features.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://data/tropical_previews.json","res://tools/tropical/render_review.gd","res://scenes/main.tscn","res://project.godot"]:source_hashes[path]=FileAccess.get_sha256(path)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	source_hashes["res://shaders/biological_sampling.gdshaderinc"]=FileAccess.get_sha256("res://shaders/biological_sampling.gdshaderinc")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_previews.json"))
	var names:Array=manifest.features.keys()
	sheet_rows=maxi(1,ceili(float(names.size())/4))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("feature="):selected=arg.trim_prefix("feature=")
		if arg.begins_with("view="):only_view=arg.trim_prefix("view=")
	for name:String in names:
		if not selected.is_empty() and not selected.split(",").has(name):continue
		if not manifest.features.has(name):push_error("Missing feature "+name);quit(1);return
		var transition:bool=name.ends_with("_transition")
		if scene==null or transition or previous_transition:
			if scene!=null:scene.queue_free();await process_frame;await process_frame
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
			terrain=scene.get_node("Terrain");terrain.tropical_preview=true;terrain.tropical_preview_feature=name;terrain.target=camera
			root.add_child(scene);scene.get_node("Interface").hide()
		else:terrain.tropical_preview_feature=name
		previous_transition=transition
		if not await settle():quit(1);return
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=maxf(terrain.water_level,terrain.get_height_at(focus))
		focus.y=maxf(focus.y,terrain._sampler.get_water_surface_height(focus.x,focus.z))
		var ground:=Vector3(-2,0,-3) if name=="natural_path" else Vector3(-18,0,-26);ground.y=maxf(terrain.water_level,terrain.get_height_at(focus+ground))+1.8-focus.y
		await capture(name,"ground",focus,ground)
		await capture(name,"medium",focus,Vector3(-90,30,-130) if name=="rocky_cascade" else (Vector3(-600,350,-800) if name=="freshwater_lake" or name=="small_stream" else Vector3(-1800,1000,-2400)))
		await capture(name,"aerial",focus,Vector3(-220,180,-240) if name=="rocky_cascade" else Vector3(-6000,4200,-8000))
		if only_view=="albedo":await capture(name,"albedo",focus,Vector3(-1800,1000,-2400),3)
		await capture(name,"materials",focus,Vector3(-300,180,-420),138)
		await capture(name,"normals",focus,ground,8)
		await capture(name,"water",focus,Vector3(-300,180,-420),137)
	var suffix:String="" if selected.is_empty() else "_"+selected
	if not only_view.is_empty():suffix+="_"+only_view+"_only"
	for kind:String in sheets:sheets[kind].save_png(output+"/contact_"+kind+suffix+".png")
	var hashes:Dictionary={}
	for path:String in source_hashes:
		hashes[path]=FileAccess.get_sha256(path);assert(hashes[path]==source_hashes[path],"Terrain source changed during review")
	FileAccess.open("res://tools/tropical/artifacts/render_review"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"captures":records,"source_sha256":hashes,"far_mesh_metres":terrain._settings_snapshot.tropical.far_mesh_metres,"lighting":"unchanged main.tscn","foliage_rendered":false},"\t"))
	scene.queue_free();await process_frame;print("TROPICAL_REVIEW_DONE ",records.size());quit()
