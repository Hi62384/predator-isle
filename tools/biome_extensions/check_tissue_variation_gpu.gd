extends SceneTree
const CANDIDATE=preload("res://tools/biome_extensions/tissue_variation_candidate.gd")
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);print("FAILED_VARIATION_CHECK ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(512,512));root.size=Vector2i(512,512)
	var guards:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_tissue_variation_gpu.gd","res://tools/biome_extensions/tissue_variation_candidate.gd",CANDIDATE.BASE,"res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://materials/biological_colors_v3.tres","res://materials/biological_color_nerve_v3.res"]:guards[path]=FileAccess.get_sha256(path)
	var shell:String=FileAccess.get_file_as_string("res://shaders/biome_structures.gdshader");var begin:int=shell.find("float field(vec2 p)");var end:int=shell.find("#include",begin)
	# Compile the actual candidate lookup directly. Restoring a shared include
	# while this dedicated panel still calls its private function is invalid;
	# the separate whole-scene fixture tests the live include intervention.
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,fog_disabled;uniform sampler2DArray biological_colors:source_color,filter_linear_mipmap_anisotropic,repeat_enable;uniform vec2 probe_origin=vec2(0);\n"+shell.substr(begin,end-begin)+CANDIDATE.FUNCTIONS+"\nvoid fragment(){vec2 p=UV*16.0+probe_origin;ALBEDO=alien_flow_varied(p,dFdx(p),dFdy(p));}"
	var scene:=Node3D.new();root.add_child(scene);var quad:=MeshInstance3D.new();quad.mesh=QuadMesh.new();scene.add_child(quad)
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"));quad.material_override=material
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1;camera.position.z=2;camera.current=true;scene.add_child(camera)
	var records:Array=[];var captures:Dictionary={}
	for origin:Vector2 in [Vector2.ZERO,Vector2(-17.25,-31.75),Vector2(98.25,-122.5)]:
		material.set_shader_parameter("probe_origin",origin);var original:Image=null
		for phase in range(3):
			material.set_shader_parameter("alien_tissue_variation_enabled",phase==1)
			for frame in range(16):await process_frame
			await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image()
			if phase==0:original=image
			elif phase==2:verify(image.get_data()==original.get_data(),"Private variation opt-out returns exact baseline bytes")
			var shifts:Array=[]
			for shift:int in [32,64,128,256]:
				var total:float=0;var maximum:float=0;var count:int=0
				for y in range(2,510,2):
					for x in range(2,510-shift,2):
						var a:Color=image.get_pixel(x,y);var b:Color=image.get_pixel(x+shift,y);var d:float=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3
						total+=d;maximum=maxf(maximum,d);count+=1
				var average:float=total/count;shifts.append({"metres":shift/32.0*1.5,"mean_absolute_rgb":average,"maximum_mean_rgb":maximum})
				if phase==1:verify(average>.02,"No exact short repeating tile at measured1.5/3/6/12m offsets")
				else:verify(average<.0001,"Negative control retains original1.5m exact repeated motif")
			var path:String="res://tools/biome_extensions/artifacts/tissue_variation_panel_%d_%d.png"%[records.size()/3,phase];verify(image.save_png(path)==OK,"Variation panel saved");captures[path]=FileAccess.get_sha256(path)
			records.append({"origin":str(origin),"phase":phase,"shifts":shifts,"capture":path})
	for path:String in guards:verify(FileAccess.get_sha256(path)==guards[path],"Stable candidate source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_tissue_variation_gpu.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":guards,"capture_sha256":captures,"cases":records,"scope":"Private actual GPU16x16 motif atlas using real nerve albedo and analytic gradients. Original lookup is exact repeating negative control;candidate is measured at1.5/3/6/12m translations,including negative canonical coordinates. Exact opt-out return. No whole-scene or universal art-quality claim."},"  "));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
