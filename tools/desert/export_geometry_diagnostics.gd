extends SceneTree
## Scientific heightfield diagnostic only. Not a native PBR render or screenshot.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
func _initialize() -> void:
 var locations:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/desert/preview_locations.json"))
 var metadata:Array=[]
 var folder:String="res://tools/desert/artifacts/geometry_diagnostics"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for name in locations.features:
  var b=Builder.new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
  var mixed:bool=name=="desert_grass_transition"
  b.settings.grass_coverage=50.0 if mixed else 0.0;b.settings.desert_coverage=50.0 if mixed else 100.0
  b.settings.snow_coverage=0;b.settings.stone_coverage=0;b.settings.temperature_enabled=false;b.world_seed=73921
  if mixed:b.settings.grass_region_size=24000;b.settings.desert_region_size=24000;b.settings.biome_size=1.0
  b._configure_noise()
  var item:Dictionary=locations.features[name]
  for span in [256.0,2048.0,16384.0]:
   var data:=PackedFloat32Array();data.resize(129*129)
   for z in range(129):
    for x in range(129):data[z*129+x]=b._get_height(float(item.x)+(x/128.0-0.5)*span,float(item.z)+(z/128.0-0.5)*span)
   var file:String=name+"_"+str(int(span))+".bin"
   FileAccess.open(folder+"/"+file,FileAccess.WRITE).store_buffer(data.to_byte_array())
   metadata.append({"feature":name,"center":[item.x,item.z],"span_m":span,"grid":129,"format":"float32 little-endian heights, row Z then X","file":file})
  print("Exported ",name)
 FileAccess.open(folder+"/index.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":73921,"note":"Data sampled from canonical builder. Scientific diagnostic, not native PBR screenshots.","grids":metadata},"\t"))
 quit()
