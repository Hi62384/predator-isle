extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var output:String="res://tools/badlands/artifacts/views"
var sheets:Dictionary={}
var counts:Dictionary={}
var selected:String=""
var only_view:String=""
var previous_transition:bool=true
var source_hashes:Dictionary={}
var trail_direction:=Vector3.FORWARD
var captured:Dictionary={}
var checkpoint_path:String=""
const HILL_VIEWS=["painted_hills","red_mudstone","gray_clay","bentonite_hills","eroded_ridges","hoodoo_country","hoodoo_cluster","badlands_canyon","dissected_plateau","stratified_clay","pale_badlands","rocky_highlands","stratified_escarpment","knife_edge_ridges","talus_slope"]
func foot_view(focus:Vector3)->Vector3:
	var sunward:Vector3=scene.get_node("Sun").global_basis.z;sunward.y=0;sunward=sunward.normalized()
	var best:Vector3=Vector3(-18,0,-26);var score:float=INF
	for radius:float in [60.0,90.0,140.0,200.0]:
		for sector in range(16):
			var offset:=Vector3(cos(sector*TAU/16),0,sin(sector*TAU/16))*radius
			var p:Vector3=focus+offset;var h:float=terrain.get_height_at(p)
			if h<terrain._sampler.get_water_surface_height(p.x,p.z)+.2:continue
			var slope:float=maxf(absf(terrain.get_height_at(p+Vector3(4,0,0))-terrain.get_height_at(p-Vector3(4,0,0))),absf(terrain.get_height_at(p+Vector3(0,0,4))-terrain.get_height_at(p-Vector3(0,0,4))))/8
			var obstruction:float=0
			for station in range(1,10):
				var t:float=station*.1;var q:Vector3=p.lerp(focus,t)
				obstruction=maxf(obstruction,terrain.get_height_at(q)-lerpf(h+1.8,focus.y+1.8,t))
			var backlit:float=maxf(.35-offset.normalized().dot(sunward),0)
			var candidate:float=h+maxf(slope-.4,0)*80+radius*.04+obstruction*4000+backlit*15
			if candidate<score:score=candidate;best=Vector3(offset.x,h+1.8-focus.y,offset.z)
	return best
func save_checkpoint()->void:
	FileAccess.open(checkpoint_path,FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"complete":false,"captures":records,"source_sha256":source_hashes},"\t"))
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-start>180000:push_error("Badlands streaming timeout: "+str(terrain.get_loaded_chunk_count())+" loaded, "+str(terrain._jobs.size())+" jobs, "+str(terrain._pending_chunks.size())+" pending");return false
	return true
func capture(name:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	if not only_view.is_empty() and kind!=only_view:return
	if captured.has(name+"/"+kind):return
	var point:Vector3=focus+offset
	var clearance:float=maxf(terrain._sampler.get_water_surface_height(point.x,point.z),terrain.get_height_at(point))
	point.y=maxf(point.y,clearance+(1.8 if kind=="ground" else 30))
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	assert(camera.global_position.distance_to(point)<.01,"Capture camera did not reach the committed destination")
	camera.near=.1 if kind=="ground" else 1
	if kind=="ground":
		var look:Vector3=point+trail_direction*30+Vector3(0,-3,0) if name=="natural_path" else (Vector3(focus.x,lerpf(point.y,focus.y,.8),focus.z) if name in HILL_VIEWS else focus+Vector3(0,1,0));camera.look_at(look)
	else:camera.look_at(focus)
	terrain.set_debug_view(debug)
	var shader_debug:int=int(terrain._terrain_material.get_shader_parameter("debug_view"))
	if debug>=141 and debug<=148:assert(shader_debug==debug+99,"Requested Badlands debug mode did not reach the production material")
	for i in range(16):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();assert(image.save_png(output+"/"+name+"_"+kind+".png")==OK)
	records.append({"feature":name,"view":kind,"focus":str(focus),"camera":str(camera.global_position),"camera_forward":str(-camera.global_basis.z),"debug":debug,"shader_debug":shader_debug,"leaves":terrain._active_chunks.size(),"committed_revision":terrain.committed_revision,"partition_revision":terrain.partition_revision,"png_sha256":FileAccess.get_sha256(output+"/"+name+"_"+kind+".png")});print("BADLANDS_CAPTURE ",name," ",kind)
	captured[name+"/"+kind]=true;save_checkpoint()
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/badlands_settings.gd","res://config/biomes/badlands_settings.tres","res://scripts/badlands_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://shaders/badlands_material.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://tools/badlands/render_review.gd","res://data/badlands_previews.json"]:source_hashes[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scenes/main.tscn","res://project.godot","res://config/world/terrain_settings.tres","res://config/rendering/cliff_normals.tres","res://config/rendering/ground_materials.tres"]:source_hashes[path]=FileAccess.get_sha256(path)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	var names:Array=manifest.features.keys()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("feature="):selected=arg.trim_prefix("feature=")
		if arg.begins_with("view="):only_view=arg.trim_prefix("view=")
	var suffix:String="" if selected.is_empty() else "_"+selected
	if not only_view.is_empty():suffix+="_"+only_view+"_only"
	checkpoint_path="res://tools/badlands/artifacts/render_review_checkpoint"+suffix+".json"
	if OS.get_cmdline_user_args().has("resume-review") and FileAccess.file_exists(checkpoint_path):
		var prior=JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path));assert(prior is Dictionary and prior.source_sha256==source_hashes,"Checkpoint source changed; start a fresh review")
		for record:Dictionary in prior.captures:
			assert(FileAccess.get_sha256(output+"/"+record.feature+"_"+record.view+".png")==record.png_sha256,"Checkpoint pixels changed")
			records.append(record);captured[record.feature+"/"+record.view]=true
		print("BADLANDS_REVIEW_RESUMED ",records.size()," verified captures")
	for name:String in names:
		if not selected.is_empty() and not selected.split(",").has(name):continue
		var needed:bool=false
		for kind:String in ([only_view] if not only_view.is_empty() else ["ground","medium","aerial","materials","normals","water"]):
			if not captured.has(name+"/"+kind):needed=true
		if not needed:continue
		if not manifest.features.has(name):push_error("Missing feature "+name);quit(1);return
		var transition:bool=name.ends_with("_transition")
		if scene==null or transition or previous_transition:
			if scene!=null:scene.queue_free();await process_frame;await process_frame
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
			terrain=scene.get_node("Terrain");terrain.badlands_preview=true;terrain.badlands_preview_feature=name;terrain.target=camera
			root.add_child(scene);scene.get_node("Interface").hide()
		else:terrain.badlands_preview_feature=name
		previous_transition=transition
		if not await settle():quit(1);return
		var item:Dictionary=manifest.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=maxf(terrain.water_level,terrain.get_height_at(focus))
		focus.y=maxf(focus.y,terrain._sampler.get_water_surface_height(focus.x,focus.z))
		var ground:=Vector3(-2,0,-3) if name=="natural_path" else Vector3(-18,0,-26);ground.y=maxf(terrain.water_level,terrain.get_height_at(focus+ground))+1.8-focus.y
		if name in HILL_VIEWS or name=="rare_pool":
			# A ground view belongs at a natural foot slope, not on top of the
			# remnant cap. Pick an existing low point; never alter the landform.
			ground=foot_view(focus)
		await capture(name,"ground",focus,ground)
		await capture(name,"medium",focus,Vector3(-230,100,-300) if name.begins_with("hoodoo") else (Vector3(-650,300,-850) if transition else Vector3(-300,130,-420)))
		await capture(name,"aerial",focus,Vector3(-2400,1800,-3200))
		if only_view=="albedo":await capture(name,"albedo",focus,Vector3(-1800,1000,-2400),3)
		await capture(name,"materials",focus,Vector3(-300,180,-420),146)
		await capture(name,"normals",focus,ground,147)
		await capture(name,"water",focus,Vector3(-300,180,-420),145)
	# Rebuild every contact sheet from verified records, including resumed ones.
	for record:Dictionary in records:
		var kind:String=record.view
		if not sheets.has(kind):sheets[kind]=Image.create_empty(2560,3240,false,Image.FORMAT_RGBA8);counts[kind]=0
		var small:=Image.load_from_file(output+"/"+record.feature+"_"+kind+".png");small.resize(640,360,Image.INTERPOLATE_LANCZOS);small.convert(Image.FORMAT_RGBA8)
		var tile:int=counts[kind];counts[kind]=tile+1;sheets[kind].blit_rect(small,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
	for kind:String in sheets:sheets[kind].save_png(output+"/contact_"+kind+suffix+".png")
	var hashes:Dictionary={}
	for path:String in source_hashes:
		hashes[path]=FileAccess.get_sha256(path);assert(hashes[path]==source_hashes[path],"Terrain source changed during review")
	FileAccess.open("res://tools/badlands/artifacts/render_review"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"complete":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"captures":records,"source_sha256":hashes,"far_mesh_metres":load("res://config/biomes/badlands_settings.tres").far_mesh_metres,"camera_far_m":camera.far,"maximum_lod":terrain.maximum_lod,"lighting":"unchanged main.tscn","foliage_rendered":false},"\t"))
	if scene!=null:scene.queue_free();await process_frame
	print("BADLANDS_REVIEW_DONE ",records.size());quit()
