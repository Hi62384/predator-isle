extends SceneTree
## Refresh measurements after tuning without moving any established preview.
func _initialize()->void:
	var path:String="res://data/snow_previews.json"
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for name:String in manifest.features:
		var builder=preload("res://scripts/terrain_mesh_builder.gd").new()
		builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=int(manifest.seed)
		builder.settings.grass_coverage=0;builder.settings.desert_coverage=0;builder.settings.snow_coverage=100;builder.settings.stone_coverage=0;builder.settings.temperature_enabled=false
		if name=="partial_lake":builder.settings.snow.lake_ice_coverage=.5
		if name=="grass_snow_transition":
			builder.settings.grass_coverage=50;builder.settings.snow_coverage=50
			builder.settings.grass_region_size=24000;builder.settings.snow_region_size=24000;builder.settings.biome_size=1
		builder._configure_noise()
		var item:Dictionary=manifest.features[name];var x:float=item.x;var z:float=item.z
		item.height=builder._get_height(x,z)
		if name=="grass_snow_transition":
			var weights:Vector4=builder._biome_weights(x,z);item.controls={"grass":weights.x,"snow":weights.z}
		elif name!="partial_lake":
			var a:Vector4=builder._snow.a;var b:Vector4=builder._snow.b;var c:Vector4=builder._snow.c
			item.controls={"depth":a.w*12,"exposure":b.x,"glacier":b.y,"lake":b.z,"river":b.w,"rock":c.x,"strain":c.y}
		if item.has("score"):item.discovery_score=item.score;item.erase("score")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("Refreshed measurements for 17 unchanged Snow preview coordinates.");quit()
