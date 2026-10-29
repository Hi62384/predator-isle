extends SceneTree
var scene:Node
var terrain:Node
var camera:Camera3D
var records:Array=[]
var hashes:Dictionary={}
var fill_seconds:float=0
var allow_subsurface:bool=false
var stream_wait_frames:Array=[]
func median(values:Array)->float:
	values.sort();return values[values.size()/2] if not values.is_empty() else -1
func _initialize()->void:call_deferred("run")
func settle()->bool:
	var start:int=Time.get_ticks_msec();var last:int=Time.get_ticks_usec();stream_wait_frames=[]
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		var now:int=Time.get_ticks_usec();stream_wait_frames.append((now-last)/1000.0);last=now
		if Time.get_ticks_msec()-start>240000:push_error("Extension stream timeout "+terrain.extension_preview);return false
	return true
func capture(key:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	var point:Vector3=focus+offset
	if not allow_subsurface:point.y=maxf(point.y,terrain.get_height_at(point)+3)
	terrain.request_teleport(point)
	if not await settle():quit(1);return
	var loading_frames:Array=stream_wait_frames.duplicate();loading_frames.sort()
	camera.look_at(focus);terrain.set_debug_view(debug)
	for i in range(20):await process_frame
	var frames:Array=[];var gpu:Array=[];var last:int=Time.get_ticks_usec()
	for i in range(60):
		await process_frame
		var now:int=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		var time:float=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		if time>0:gpu.append(time)
	await RenderingServer.frame_post_draw
	var path:String="res://tools/biome_extensions/artifacts/"+key+"_"+kind+".png"
	var image:Image=root.get_texture().get_image();assert(image.save_png(path)==OK)
	var structures:int=0;var texture_bytes:int=0
	for node:MeshInstance3D in terrain._active_chunks.values():
		if node.mesh.has_meta("extension_structures"):structures+=node.mesh.get_meta("extension_structures").get_surface_count()
		var material:ShaderMaterial=node.mesh.surface_get_material(0);var atlas:Texture2D=material.get_shader_parameter("extension_payload")
		if atlas!=null:texture_bytes+=atlas.get_width()*atlas.get_height()*4
	records.append({"biome":key,"view":kind,"focus":str(focus),"camera":str(point),"leaves":terrain._active_chunks.size(),"structure_batches":structures,"metadata_bytes":texture_bytes,"committed":terrain.committed_revision==terrain.partition_revision,"sha256":FileAccess.get_sha256(path),"frame_p50_ms":median(frames),"gpu_p50_ms":median(gpu) if not gpu.is_empty() else null,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"initial_stream_fill_s":fill_seconds})
	records[-1]["stream_wait_frame_count"]=loading_frames.size()
	records[-1]["stream_wait_max_ms"]=loading_frames[-1] if not loading_frames.is_empty() else 0
	records[-1]["stream_wait_p99_ms"]=loading_frames[mini(loading_frames.size()-1,floori(loading_frames.size()*.99))] if not loading_frames.is_empty() else 0
	print("EXTENSION_CAPTURE ",key," ",kind," ",structures," structure batches")
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/biome_extensions/artifacts"))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_settings.gd","res://scripts/biome_extension_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/biome_extension_structures.gd","res://scripts/terrain_collision.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader"]:hashes[path]=FileAccess.get_sha256(path)
	for k:String in TerrainSettings.EXTENSION_KEYS:
		hashes["res://scripts/"+k+"_sampler.gd"]=FileAccess.get_sha256("res://scripts/"+k+"_sampler.gd");hashes["res://"+k+"_settings.tres"]=FileAccess.get_sha256("res://"+k+"_settings.tres")
	for path:String in ["res://scripts/terrain_feature_meshes.gd","res://shaders/terrain_features.gdshader","res://shaders/crystal_transmission.gdshader","res://scripts/badlands_sampler.gd","res://shaders/badlands_material.gdshaderinc"]:hashes[path]=FileAccess.get_sha256(path)
	var selected:String=""
	hashes["res://shaders/biological_sampling.gdshaderinc"]=FileAccess.get_sha256("res://shaders/biological_sampling.gdshaderinc")
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):selected=arg.trim_prefix("only=")
	var tests=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"))
	for family_id in range(8):
		var key:String=TerrainSettings.EXTENSION_KEYS[family_id]
		if not selected.is_empty() and key!=selected:continue
		var item:Dictionary=tests.families[key].primary
		var p:=Vector2(item.x,item.z)
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.extension_preview=key;terrain.extension_preview_position=p;terrain.target=camera;var fill_start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide()
		if not await settle():quit(1);return
		fill_seconds=(Time.get_ticks_usec()-fill_start)/1000000.0
		var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
		await capture(key,"medium",focus,Vector3(-220,140,-320) if family_id==6 else (Vector3(-450,300,-650) if family_id==5 else Vector3(-800,500,-1100)))
		await capture(key,"aerial",focus,Vector3(-2800,2200,-3500))
		await capture(key,"ground",focus,Vector3(-160,4,-200) if family_id==6 else (Vector3(-100,4,-130) if family_id==7 else (Vector3(-60,4,-85) if family_id==5 else Vector3(-20,4,-25))))
		await capture(key,"regions",focus,Vector3(-800,500,-1100),150)
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(hashes[path]==FileAccess.get_sha256(path),"Source changed during render review: "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_all"+("_"+selected if not selected.is_empty() else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"view_distance":50000,"captures":records,"source_sha256":hashes,"timing_note":"60 settled frames per view, VSync may limit frame timings; not an isolated shader-only benchmark"},"\t"))
	print("EXTENSION_RENDER_DONE ",records.size());quit()
