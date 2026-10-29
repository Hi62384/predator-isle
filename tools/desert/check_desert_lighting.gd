extends SceneTree
## Small optical calibration only. Eight cards: gray, white, six original packed
## source colors. No terrain, normals, custom attributes, global project changes.
const IDS := ["Ground092A","Ground054","Gravel020","Rock061","Ground031","Ground033"]
const HASHES := ["214bfb6bf50813d50252979fd1f72978337d22e88e720d5a6392c153bc47a8e0","e43bf1898f27e00a330eb6db6680c6762add42a11806e9d7e16a290c171b5a97","2388d4388aae0a52bff46b7ad5179c226f7694074ed2e648ffbc554ff90f29ea","4a5af237b49c742656119bc9db0ae419aace05d6ec6a0d6dc3e4fb67b9e400ae","6e8f0a948085c12665fc9e305cb8da2fb8eac038fd45308444ec9e3475d863f0","f708a3668a92dfda0241fb7a3d32ca4736b06c5ac21c75600acc7d6fc2e209ac"]
const SIZE := Vector2i(960,540)
var report: Dictionary={"completed":false,"actual_render":false,"captures":[],"sources":[],"failures":[]}
var begun: int

func _initialize()->void: call_deferred("run")
func save_report()->void:
	report["elapsed_s"]=(Time.get_ticks_msec()-begun)/1000.0
	var file:=FileAccess.open("res://lighting_report.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"))
func fail(message:String)->void:
	report.failures.append(message);push_error(message);save_report();quit(1)
func image_stats(image:Image)->Dictionary:
	var sum:=Vector3.ZERO;var clipped:=Vector3i.ZERO;var count:int=0
	for y in range(0,image.get_height(),maxi(1,image.get_height()/64)):
		for x in range(0,image.get_width(),maxi(1,image.get_width()/64)):
			var color:Color=image.get_pixel(x,y)
			for c in range(3):
				sum[c]+=color[c]
				if color[c]>=254.5/255.0:clipped[c]+=1
			count+=1
	return {"samples":count,"mean_rgb":[sum.x/count,sum.y/count,sum.z/count],"clipped_counts":[clipped.x,clipped.y,clipped.z]}
func run()->void:
	begun=Time.get_ticks_msec()
	var headless:bool=DisplayServer.get_name()=="headless"
	if headless:root.size=SIZE
	report.merge({"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":[root.size.x,root.size.y],"source_mode":"synthetic structural fixture" if headless else "original hash-pinned packed sources"})
	if OS.get_cmdline_user_args().has("require-render") and headless:fail("Actual GL display required");return
	if root.size!=SIZE:fail("Unexpected viewport size");return
	if not headless and RenderingServer.get_current_rendering_method()!="gl_compatibility":fail("Actual GL required");return
	var source_images:Array[Image]=[]
	for i in range(6):
		var image:Image
		if headless:
			image=Image.create_empty(8,8,false,Image.FORMAT_RGBA8);image.fill(Color(0.72,0.57,0.39,0.9))
		else:
			var path:String="res://materials/desert_color_"+IDS[i]+".res"
			if FileAccess.get_sha256(path)!=HASHES[i]:fail("Packed source hash mismatch: "+IDS[i]);return
			image=load(path) as Image
			if image==null or image.is_empty():fail("Cannot load packed image "+IDS[i]);return
			var inspect:Image=image.duplicate()
			if inspect.is_compressed() and inspect.decompress()!=OK:fail("Cannot inspect packed source "+IDS[i]);return
			report.sources.append({"id":IDS[i],"sha256":HASHES[i],"width":image.get_width(),"height":image.get_height(),"mipmaps":image.has_mipmaps(),"sampled":image_stats(inspect)})
		source_images.append(image)
	var texture:=Texture2DArray.new()
	if texture.create_from_images(source_images)!=OK:fail("Cannot create actual source-color array");return
	var lit:=Shader.new();lit.code='''shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, fog_disabled;
uniform sampler2DArray source_colors:source_color,filter_linear_mipmap;
uniform int layer=-1;
uniform vec3 solid=vec3(0.5);
void fragment(){ALBEDO=layer<0?solid:texture(source_colors,vec3(UV,float(layer))).rgb;ROUGHNESS=1.0;SPECULAR=0.0;}
'''
	var unlit:=Shader.new();unlit.code=lit.code.replace("cull_disabled, diffuse_lambert","unshaded, cull_disabled, diffuse_lambert")
	lit.get_shader_uniform_list();unlit.get_shader_uniform_list()
	var scene:=Node3D.new();root.add_child(scene)
	var materials:Array[ShaderMaterial]=[]
	for i in range(8):
		var m:=ShaderMaterial.new();m.shader=lit;m.set_shader_parameter("source_colors",texture);m.set_shader_parameter("layer",i-2)
		m.set_shader_parameter("solid",Vector3.ONE*(0.5 if i==0 else 0.9));materials.append(m)
		var card:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1.8,1.8);card.mesh=quad;card.material_override=m
		card.position=Vector3(-3.0+(i%4)*2.0,1.0-(i/4)*2.0,0);scene.add_child(card)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.5;camera.position=Vector3(0,0,6);scene.add_child(camera);camera.current=true
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0.05,0.05,0.05);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment=env;scene.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-25,0);scene.add_child(sun)
	var modes:Array=[
		["original_shadow_white1",0.55,1.4,true,Environment.TONE_MAPPER_FILMIC,1.0,false,true],
		["original_no_shadow_white1",0.55,1.4,false,Environment.TONE_MAPPER_FILMIC,1.0,false,true],
		["original_shadow_white6",0.55,1.4,true,Environment.TONE_MAPPER_FILMIC,6.0,false,true],
		["original_no_shadow_white6",0.55,1.4,false,Environment.TONE_MAPPER_FILMIC,6.0,false,true],
		["neutral_shadow_linear",0.12,0.8,true,Environment.TONE_MAPPER_LINEAR,1.0,false,false],
		["neutral_no_shadow_linear",0.12,0.8,false,Environment.TONE_MAPPER_LINEAR,1.0,false,false],
		["ambient_only_linear",1.0,0.0,false,Environment.TONE_MAPPER_LINEAR,1.0,false,false],
		["sun_only_linear",0.0,1.0,false,Environment.TONE_MAPPER_LINEAR,1.0,false,false],
		["source_unshaded_linear",0.0,0.0,false,Environment.TONE_MAPPER_LINEAR,1.0,true,false],
		["source_unshaded_white6",0.0,0.0,false,Environment.TONE_MAPPER_FILMIC,6.0,true,false]]
	if not headless:RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	for mode:Array in modes:
		env.ambient_light_energy=mode[1];sun.light_energy=mode[2];sun.shadow_enabled=mode[3];env.tonemap_mode=mode[4];env.tonemap_white=mode[5]
		env.ambient_light_color=Color(0.78,0.84,0.95) if mode[7] else Color.WHITE
		sun.light_color=Color(1.0,0.93,0.82) if mode[7] else Color.WHITE
		for m:ShaderMaterial in materials:m.shader=unlit if mode[6] else lit
		for frame in range(8):await process_frame
		var capture:Dictionary={"name":mode[0],"rendered":not headless,"ambient_energy":mode[1],"sun_energy":mode[2],"shadows":mode[3],"tonemap":mode[4],"white":mode[5],"unshaded":mode[6],"colored_lights":mode[7],"cards":[]}
		if not headless:
			await RenderingServer.frame_post_draw
			var image:Image=root.get_texture().get_image()
			if image==null or image.get_size()!=SIZE:fail("Invalid framebuffer");return
			if image.save_png("res://captures/"+mode[0]+".png")!=OK:fail("Cannot save capture");return
			for i in range(8):
				# 120 px/metre at this orthographic size. Exclude card edges/background.
				var rect:=Rect2i(36+(i%4)*240,54+(i/4)*240,168,168)
				capture.cards.append({"label":"gray_0.5" if i==0 else ("white_0.9" if i==1 else IDS[i-2]),"stats":image_stats(image.get_region(rect))})
		capture.merge({"frame":Engine.get_frames_drawn(),"static_memory_bytes":OS.get_static_memory_usage(),"gpu_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) if not headless else null})
		report.captures.append(capture);save_report()
	report["actual_render"]=not headless;report["completed"]=true
	report["scope"]="Calibration only. Actual images need review before any terrain visual acceptance. Ground033 is pale sediment, not a verified salt-crust source."
	save_report();print(JSON.stringify(report));scene.queue_free();await process_frame;quit()
