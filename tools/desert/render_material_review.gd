extends SceneTree
# Historical broad fixture, not the user game lighting. Its legacy exposure clipped
# prior captures; use optical calibration before judging these material colors.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
const DesertSettings=preload("res://scripts/desert_settings.gd")
var builder
var scene:Node3D
var patch:Node3D
var camera:Camera3D
var material:ShaderMaterial
var baseline:ShaderMaterial
var captures:Array=[]
var feature_checks:Array=[]
var contact_sheets:Dictionary={}
var contact_counts:Dictionary={}
var headless:bool
var run_started:int
var peak_static:int=0
var capture_dir:String="res://captures"
func _initialize()->void:call_deferred("run")
func fallback_array(normal:bool)->Texture2DArray:
 var images:Array[Image]=[]
 for i in range(9):
  var image:=Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
  image.fill(Color(0.5,0.5,1,1) if normal else Color(0.6,0.5,0.35,0.9));images.append(image)
 var texture:=Texture2DArray.new();assert(texture.create_from_images(images)==OK);return texture
func make_material(path:String)->ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=load(path)
 m.set_shader_parameter("palette_color",fallback_array(false));m.set_shader_parameter("palette_normal",fallback_array(true));m.set_shader_parameter("cliff_ambient_normals",fallback_array(true))
 m.set_shader_parameter("desert_color",load("res://materials/desert_color_roughness.tres"));m.set_shader_parameter("desert_normal",load("res://materials/desert_normals.tres"));m.set_shader_parameter("desert_palette_ready",true)
 m.set_shader_parameter("cliff_world_seed",73921.0);m.set_shader_parameter("water_level",0.0)
 m.set_shader_parameter("desert_wind_angle",deg_to_rad(builder.settings.desert.wind_direction_degrees));m.set_shader_parameter("desert_wind_variation",builder.settings.desert.wind_variation)
 for key in builder.settings.desert.shader_uniforms():m.set_shader_parameter(key,builder.settings.desert.shader_uniforms()[key])
 for key in ["sand_tint","normal_strength","detail_distance","texture_blend_sharpness","shore_width","shore_strength","slope_rock_start","slope_rock_end","grass_roughness_floor","grass_specular","grass_normal_scale"]:m.set_shader_parameter(key,builder.settings.get(key))
 return m
func build_patch(focus:Vector3,span:float,radius:int,resolution:int)->void:
 if is_instance_valid(patch):
  patch.queue_free();await process_frame;await process_frame
 patch=Node3D.new();scene.add_child(patch);builder.chunk_size=span
 var center:=Vector2i(floori(focus.x/span),floori(focus.z/span))
 material.set_shader_parameter("chunk_size_metres",span);baseline.set_shader_parameter("chunk_size_metres",span)
 material.set_shader_parameter("chunk_lod",log(span/256.0)/log(2.0));baseline.set_shader_parameter("chunk_lod",log(span/256.0)/log(2.0))
 for z in range(-radius,radius+1):
  for x in range(-radius,radius+1):
   var key:=center+Vector2i(x,z);var arrays:Array=builder.build(key,resolution)
   var flags:int=Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
   if arrays[Mesh.ARRAY_CUSTOM1]!=null:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
   if arrays[Mesh.ARRAY_CUSTOM2]!=null:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
   var node:=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(key.x*span,0,key.y*span);node.material_override=material;patch.add_child(node)
   peak_static=maxi(peak_static,OS.get_static_memory_usage())
   await process_frame
func capture(name:String,focus:Vector3,offset:Vector3,debug:int=0,use_baseline:bool=false)->void:
 camera.position=focus+offset;camera.position.y=maxf(camera.position.y,builder._get_height(camera.position.x,camera.position.z)+1.8);camera.look_at(focus+Vector3.UP*0.7)
 for node:MeshInstance3D in patch.get_children():node.material_override=baseline if use_baseline else material
 var current:ShaderMaterial=baseline if use_baseline else material;current.set_shader_parameter("debug_view",debug)
 for i in range(12):await process_frame
 if not headless:
  await RenderingServer.frame_post_draw
  var image:Image=root.get_texture().get_image();assert(image!=null and not image.is_empty());assert(image.save_png(capture_dir+"/"+name+".png")==OK)
  for suffix:String in ["ground","medium","aerial","material_weights"]:
   if name.ends_with("_"+suffix):
    if not contact_sheets.has(suffix):
     contact_sheets[suffix]=Image.create_empty(2560,1080,false,Image.FORMAT_RGBA8)
     contact_counts[suffix]=0
    var thumbnail:Image=image.duplicate();thumbnail.convert(Image.FORMAT_RGBA8);thumbnail.resize(640,360,Image.INTERPOLATE_LANCZOS)
    var tile:int=contact_counts[suffix];contact_counts[suffix]=tile+1
    contact_sheets[suffix].blit_rect(thumbnail,Rect2i(0,0,640,360),Vector2i((tile%4)*640,(tile/4)*360))
 captures.append({"name":name,"rendered":not headless,"camera":str(camera.position),"focus":str(focus),"debug":debug,"baseline_shader":use_baseline,"chunks":patch.get_child_count(),"frame_number":Engine.get_frames_drawn(),"gpu_render_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) if not headless else null,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"gpu_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
 current.set_shader_parameter("debug_view",0);print("Checked ",name)
func run()->void:
 run_started=Time.get_ticks_msec()
 headless=DisplayServer.get_name()=="headless"
 if OS.get_cmdline_user_args().has("require-render"):
  assert(not headless,"Native visual acceptance requires a real display and GPU renderer")
 if not headless:
  assert(RenderingServer.get_current_rendering_method()=="gl_compatibility", "Fixture requires actual GL compatibility renderer")
  RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
 builder=Builder.new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.settings.grass_coverage=0;builder.settings.desert_coverage=100;builder.settings.snow_coverage=0;builder.settings.stone_coverage=0;builder.settings.temperature_enabled=false;builder.settings.desert=DesertSettings.new();builder.world_seed=73921;builder._configure_noise()
 material=make_material("res://shaders/terrain_biomes.gdshader");baseline=make_material("res://shaders/terrain_baseline.gdshader")
 scene=Node3D.new();root.add_child(scene)
 var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0.55,0.67,0.79);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(0.78,0.84,0.95);environment.ambient_light_energy=0.55;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=environment;scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-28,0);sun.light_color=Color(1.0,0.93,0.82);sun.light_energy=1.4;sun.shadow_enabled=true;scene.add_child(sun)
 camera=Camera3D.new();camera.far=50000;camera.near=0.05;scene.add_child(camera);camera.current=true
 var locations:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://preview_locations.json"))
 var wanted:Array=locations.features.keys();wanted.erase("desert_grass_transition")
 if OS.get_cmdline_user_args().has("quick"):wanted=["sand_sea","major_canyon","salt_flat"]
 for name:String in wanted:
  var item:Dictionary=locations.features[name];var focus:=Vector3(item.x,0,item.z);focus.y=builder._get_height(focus.x,focus.z)
  var sampler=builder._desert
  var actual_region:String=sampler.REGION_NAMES[sampler.last_region]
  assert(actual_region==item.region,"Preview macroregion changed: "+name)
  assert(sampler.last_family==int(item.family),"Preview dune family changed: "+name)
  assert(absf(focus.y-float(item.height))<0.001,"Preview height changed: "+name)
  feature_checks.append({"name":name,"x":focus.x,"z":focus.z,"height":focus.y,"region":actual_region,"family":sampler.last_family,"weights":Array(sampler.last_weights),"surface":str(sampler.control_surface),"wind_salt_wet":str(sampler.control_wind)})
  var views=[{"name":"ground","span":256.0,"radius":1,"res":64,"offset":Vector3(-8,1.8,-13)},{"name":"medium","span":512.0,"radius":2,"res":64,"offset":Vector3(550,210,620)},{"name":"aerial","span":8192.0,"radius":1,"res":64,"offset":Vector3(3900,2300,4100)}]
  for view in views:
   await build_patch(focus,view.span,view.radius,view.res)
   await capture(name+"_"+view.name,focus,view.offset)
   if name=="sand_sea" and view.name=="ground":
    await capture(name+"_ground_baseline",focus,view.offset,0,true)
    await capture(name+"_normal_wind",focus,view.offset,8)
    await capture(name+"_normal_baseline",focus,view.offset,8,true)
  await capture(name+"_material_weights",focus,Vector3(3900,2300,4100),48)
 if not headless:
  for key:String in contact_sheets:
   assert(contact_sheets[key].save_png(capture_dir+"/contact_"+key+".png")==OK)
 var report={"contact_sheet_order":wanted,"elapsed_s":(Time.get_ticks_msec()-run_started)/1000.0,"viewport":str(root.size),"rendered_frames":Engine.get_frames_drawn(),"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"seed":73921,"headless":headless,"peak_static_bytes":peak_static,"captures":captures,"feature_checks":feature_checks,"scope":"Isolated canonical builder and real Desert shader/PBR arrays, bounded patches. Uniform scene lighting, not full game/controller performance. Dummy fallback Grass textures are bound but pure Desert coverage only; no Grass/transition acceptance. No oasis water plane in this fixture.","shader_candidate":"Wind-coordinate/normal correction staged only; original baseline included for sand comparison."}
 FileAccess.open("res://visual_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));scene.queue_free();await process_frame;quit()
