extends SceneTree
const Desert=preload("res://scripts/desert_sampler.gd")
const Settings=preload("res://scripts/desert_settings.gd")
var failures:Array[String]=[]
var peak_static:int=0
var comparisons:int=0
var reports:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:
  failures.append(label)
  if failures.size()<10:push_error(label)
func record(s,x:float,z:float,water:bool)->Array:
 var h:float=s.sample(x,z,water)
 peak_static=maxi(peak_static,OS.get_static_memory_usage())
 check(is_finite(h),"Nonfinite height")
 check(s.control_region.is_finite() and s.control_surface.is_finite() and s.control_wind.is_finite() and s.control_detail.is_finite(),"Nonfinite controls")
 return [h,s.control_region,s.control_surface,s.control_wind,s.last_family,s.last_region,s.last_fan,s.last_crest,s.control_detail]
func _initialize()->void:
 var started:int=Time.get_ticks_usec()
 for seed_value in [73921,12345,90317]:
  var a=Desert.new();var b=Desert.new();var c=Settings.new()
  if seed_value==12345:c.dune_width_range=Vector2(230,540);c.wind_direction_degrees=-17;c.slip_face_sharpness=0.0
  if seed_value==90317:c.dune_asymmetry=0.82;c.wind_variation=0.8;c.dune_spacing=2.0
  a.configure(c,seed_value);b.configure(c.duplicate(true),seed_value)
  var points:Array[Vector2]=[];var expected:Array=[]
  for i in range(512):
   var p:=Vector2(float((i*3793)%211)*737.0-77553.0,float((i*1913)%227)*641.0-70291.0)
   if i%3==0:p+=Vector2(0.125,-0.25)
   points.append(p);expected.append(record(a,p.x,p.y,i%2==0))
  for i in range(511,-1,-1):
   var p:Vector2=points[i]
   check(record(b,p.x,p.y,i%2==0)==expected[i],"Order/controls mismatch");comparisons+=1
  for i in range(1800):a.sample(i*1311.0,i*-797.0,i%2==0)
  for i in range(0,512,7):
   var p:Vector2=points[i]
   check(record(a,p.x,p.y,i%2==0)==expected[i],"Cache eviction mismatch");comparisons+=1
  check(a._region_cache.size()<=a.CACHE_LIMIT and a._site_cache.size()<=a.CACHE_LIMIT and a._dune_cache.size()<=512,"Descriptor bound")
  check(a._drainage_graph._catchments.size()<=128 and a._drainage_graph._tiles.size()<=a._drainage_graph.MAX_TILES,"Drainage cache bound")
  a.configure(c,seed_value)
  for i in range(0,512,19):
   var p:Vector2=points[i]
   check(record(a,p.x,p.y,i%2==0)==expected[i],"Reconfigure mismatch");comparisons+=1
  reports.append({"seed":seed_value,"comparisons":comparisons,"static_peak_bytes":peak_static})
  print("Finished bounded core seed ",seed_value)
 var result={"engine":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name(),"project":ProjectSettings.globalize_path("res://"),"scope":"Loaded canonical sampler/settings/drainage: signed queries, order/cache/reconfigure checks including CUSTOM2. No mesh, GPU, PBR or visual claim.","elapsed_s":(Time.get_ticks_usec()-started)/1000000.0,"static_peak_bytes":peak_static,"comparisons":comparisons,"seeds":reports,"failures":failures}
 FileAccess.open("res://tools/diagnostics/artifacts/native_core_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("Bounded core failures=",failures.size())
 quit(0 if failures.is_empty() else 1)
