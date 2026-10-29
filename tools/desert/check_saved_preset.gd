extends SceneTree
const New=preload("res://scripts/terrain_mesh_builder.gd")
const Old=preload("res://tools/desert/baseline/builder.gd")
func _initialize():
 var samples:Array=[]
 var failures:Array[String]=[]
 for item in [[Vector2i.ZERO,256.0,64],[Vector2i(-18,35),256.0,128],[Vector2i.ZERO,16384.0,16]]:
  var stats:Array=[];var equal:bool=true;var grass_only:bool=true;var old_arrays:Array=[]
  for script in [Old,New]:
   var times:Array=[]
   for repetition in range(5):
    var b=script.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.chunk_size=item[1];b._configure_noise()
    var tick:int=Time.get_ticks_usec();var arrays:Array=b.build(item[0],item[2]);times.append((Time.get_ticks_usec()-tick)/1000.0)
    if script==Old:old_arrays=arrays
    else:equal=equal and arrays==old_arrays
    for c:Color in arrays[Mesh.ARRAY_COLOR]:grass_only=grass_only and c.r==1.0
   times.sort();stats.append({"baseline":script==Old,"median_ms":times[2],"all_ms":times})
  samples.append({"coordinate":str(item[0]),"chunk_size":item[1],"resolution":item[2],"all_vertex_weights_pure_grass":grass_only,"exact_full_arrays":equal,"timings":stats})
  # Saved coverage includes other enabled defaults; not every old anchor is
  # pure Grass. Comparing complete mixed-biome arrays to simple Desert would
  # incorrectly reject the intended Desert changes. Preserve the actual preset.
  if grass_only and not equal:failures.append("Saved-preset pure Grass complete mesh arrays changed: "+str(item[0]))
 if not samples.any(func(row): return row.all_vertex_weights_pure_grass):failures.append("No pure Grass anchor checked")
 var report={"settings":"Actual saved preset without coverage override","engine":Engine.get_version_info().string,"os":OS.get_name(),"samples":samples,"failures":failures,"scope":"Exact CPU mesh-array regression at recorded saved-preset locations; no rendered Grass acceptance."}
 FileAccess.open("res://tools/desert/current_saved_preset_grass.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
