extends SceneTree
## Same real controller/environment and coverage for baseline/current comparisons.
## Run with rendering, after explicit local approval. No result is pre-populated.
var failures:Array[String]=[]
var terrain:Node
var camera:Camera3D
var scene:Node
var previous_revision:int=-1
var swaps:int=0
var peak_static:int=0
var records:Array=[]
var baseline:bool=false

func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func percentile(values:Array,p:float)->float:
 if values.is_empty():return -1.0
 values.sort();return values[clampi(int((values.size()-1)*p),0,values.size()-1)]
func validate_partition()->void:
 peak_static=maxi(peak_static,OS.get_static_memory_usage())
 if terrain.committed_revision==previous_revision:return
 previous_revision=terrain.committed_revision;swaps+=1
 var keys:Array=terrain._active_chunks.keys()
 for i in range(keys.size()):
  check(terrain._active_chunks[keys[i]].visible,"Active chunk hidden")
  for j in range(i+1,keys.size()):
   check(not terrain._partition.bounds(keys[i]).intersects(terrain._partition.bounds(keys[j])),"Visible chunk overlap")
   check(not terrain._partition.adjacent(keys[i],keys[j]) or absi(keys[i].z-keys[j].z)<=1,"Unbalanced visible LOD edge")
 for node in terrain._staged.values():check(not node.visible,"Uncommitted chunk visible")
 check(terrain._mesh_cache.size()<=terrain.cached_mesh_limit,"Mesh cache exceeded bound")
func settle()->float:
 var tick:int=Time.get_ticks_usec()
 while terrain.committed_revision!=terrain.partition_revision:
  await process_frame;validate_partition()
  if Time.get_ticks_usec()-tick>120000000:
   check(false,"Partition settle timeout");return -1.0
 validate_partition()
 return (Time.get_ticks_usec()-tick)/1000000.0
func measure(label:String,seconds:float,speed:float=0.0)->void:
 var frames:Array=[];var gpu:Array=[];var render_cpu:Array=[]
 var tick:int=Time.get_ticks_usec();var last:int=tick
 while Time.get_ticks_usec()-tick<seconds*1000000.0:
  await process_frame
  var now:int=Time.get_ticks_usec();var delta:float=(now-last)/1000000.0;last=now
  frames.append(delta*1000.0)
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
  camera.position.x+=speed*delta
  camera.position.y=maxf(terrain.water_level,terrain.get_height_at(camera.position))+80.0
  validate_partition()
  var covered:bool=false
  for key:Vector3i in terrain._active_chunks:
   if terrain._partition.bounds(key).has_point(Vector2(camera.position.x,camera.position.z)):covered=true;break
  check(covered,"Camera left committed coverage")
 var median_gpu:float=percentile(gpu,0.5)
 records.append({"case":label,"speed_m_s":speed,"frames":frames.size(),"frame_p50_ms":percentile(frames,0.5),"frame_p95_ms":percentile(frames,0.95),"frame_max_ms":percentile(frames,1.0),"gpu_p50_ms":median_gpu if median_gpu>0.0 else null,"gpu_p95_ms":percentile(gpu,0.95) if median_gpu>0.0 else null,"render_cpu_p95_ms":percentile(render_cpu,0.95),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"leaves":terrain._active_chunks.size(),"settle_s":await settle()})
func run()->void:
 baseline=OS.get_cmdline_user_args().has("baseline")
 if baseline and not FileAccess.file_exists("res://tools/snow/baseline/controller.gd"):
  push_error("Baseline comparison requires the local pre-Snow snapshot.");quit(2);return
 if DisplayServer.get_name()=="headless":push_error("Native rendering benchmark requires a rendered viewport");quit(2);return
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/desert/artifacts"))
 scene=load("res://scenes/main.tscn").instantiate()
 camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000.0
 terrain=scene.get_node("Terrain")
 if baseline:terrain.set_script(preload("res://tools/maintenance/resource_paths.gd").load_snapshot("res://tools/snow/baseline/controller.gd"))
 terrain.target=camera;terrain.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
 terrain.settings.grass_coverage=0;terrain.settings.desert_coverage=0;terrain.settings.snow_coverage=100;terrain.settings.stone_coverage=0;terrain.settings.temperature_enabled=false
 if OS.get_cmdline_user_args().has("normal-reference"):terrain.settings.snow.fast_normal_sampling=false
 if OS.get_cmdline_user_args().has("legacy-mesh"):terrain.settings.snow.far_mesh_metres=0.0
 if OS.get_cmdline_user_args().has("generic-shader"):terrain.settings.snow.specialize_pure_snow_shader=false
 terrain.world_seed=73921;terrain.profile_streaming=true
 camera.position=Vector3(0,120,0)
 root.add_child(scene);scene.get_node("Interface").hide()
 camera.position.y=maxf(terrain.water_level,terrain.get_height_at(camera.position))+80.0
 camera.near=.8
 if baseline:
  for material:ShaderMaterial in terrain._lod_materials.values():material.shader=load("res://tools/snow/baseline/terrain.gdshader")
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var initial:float=await settle()
 if OS.get_cmdline_user_args().has("fill-only"):
  var probe:Dictionary={"initial_s":initial,"args":Array(OS.get_cmdline_user_args()),"failures":failures,"far_mesh_metres":terrain.settings.snow.far_mesh_metres}
  print("FILL_PROBE ",JSON.stringify(probe))
  scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
 for i in range(90):await process_frame
 camera.look_at(camera.position+Vector3(400,-80,400))
 await measure("snow_ground_static",3.0)
 for speed in [1.5,7.0,1500.0,5000.0]:await measure("travel",3.0,speed)
 for point in [Vector3(16000,900,-7000),Vector3(-24000,900,16000),Vector3(-768,1200,256),Vector3(0,120,0)]:
  point.y=maxf(terrain.water_level,terrain.get_height_at(point))+80.0
  terrain.request_teleport(point)
  var duration:float=await settle()
  check(camera.position.is_equal_approx(point),"Teleport committed without its target position")
  records.append({"teleport":str(point),"settle_s":duration,"leaves":terrain._active_chunks.size()})
  camera.look_at(point+Vector3(400,-80,400))
  for i in range(45):await process_frame
  await measure("regional_static",2.0)
 var result:Dictionary={"baseline":baseline,"seed":73921,"coverage":"pure Desert, temperature disabled; otherwise saved settings","engine":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name(),"desert_pbr_ready":false if baseline else bool(terrain._terrain_material.get_shader_parameter("desert_palette_ready")),"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(root.size),"initial_s":initial,"partition_swaps":swaps,"plan_max_ms":terrain.max_plan_ms,"partition_commit_max_ms":terrain.max_partition_swap_ms,"peak_static_memory_bytes":peak_static,"records":records,"streaming_records":terrain.streaming_records,"failures":failures,"gpu_note":"Null GPU timing is unavailable, never zero-cost. Includes normal scene fill, shadows and water; no renderer settings changed."}
 result["fast_snow_normals"]=false if baseline else terrain.settings.snow.fast_normal_sampling
 result["snow_shader_specialization"]=false if baseline else terrain.settings.snow.specialize_pure_snow_shader
 result["far_mesh_metres"]=0.0 if baseline else terrain.settings.snow.far_mesh_metres
 result["view_protocol"]="Matched XZ, 80 m above terrain/water, fixed pitch, 0.8 m near plane; per-frame height-follow sampling included in travel CPU cost. Old absolute camera could be underground in new mountains."
 var report_name: String="generic_shader" if OS.get_cmdline_user_args().has("generic-shader") else ("normal_reference" if OS.get_cmdline_user_args().has("normal-reference") else ("baseline" if baseline else "current"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/snow/artifacts"))
 result["coverage"]="pure Snow, temperature disabled; otherwise saved settings"
 FileAccess.open("res://tools/snow/artifacts/native_"+report_name+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("Native benchmark finished; failures=",failures.size())
 scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
