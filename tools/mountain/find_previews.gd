extends SceneTree
const FEATURES=["jagged_alpine","massive_ranges","rocky_mountains","ancient_highlands","glacial_country","granite_massifs","stratified_mountains","foothills","alpine_plateaus","basin_country","deep_valleys","escarpments","dry_mountains","scree_highlands","arete_country","meadow_valleys"]
const EXTRA=["ridge_system","secondary_ridge","high_pass","v_valley","u_valley","cirque","hanging_valley","tarn","valley_lake","mountain_river","cliff_face","alluvial_fan"]
var features:Dictionary={}
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false
	b.settings.grass_coverage=0;b.settings.forest_coverage=0;b.settings.jungle_coverage=0;b.settings.savanna_coverage=0;b.settings.swamp_coverage=0;b.settings.mountain_coverage=100;b._configure_noise()
	for z in range(-98304,98305,1024):
		for x in range(-98304,98305,1024):
			if b._island_mask(x,z)<.15:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._mountain.state;var w:PackedFloat32Array=b._mountain.region_weights(Vector2(x,z))
			for i in range(16):
				var preference:float=s[6] if i==9 or i==10 or i==15 else s[11]
				consider(FEATURES[i],Vector2(x,z),h,b._last_swamp_water,w[i]*(.65+preference*.35))
			consider("ridge_system",Vector2(x,z),h,b._last_swamp_water,s[7]*(.6+w[1]*.4))
			consider("secondary_ridge",Vector2(x,z),h,b._last_swamp_water,s[8])
			consider("high_pass",Vector2(x,z),h,b._last_swamp_water,s[7]*(1-s[11]))
			consider("v_valley",Vector2(x,z),h,b._last_swamp_water,s[6]*(1-s[5])*(w[10]+w[2]))
			consider("u_valley",Vector2(x,z),h,b._last_swamp_water,s[6]*s[5])
			consider("cirque",Vector2(x,z),h,b._last_swamp_water,s[14])
			consider("hanging_valley",Vector2(x,z),h,b._last_swamp_water,s[14]*(1-s[6]))
			var flooded:float=1 if h<b._last_swamp_water-.1 else 0
			consider("tarn",Vector2(x,z),h,b._last_swamp_water,s[14]*s[12]*flooded)
			consider("valley_lake",Vector2(x,z),h,b._last_swamp_water,s[12]*(1-s[14])*flooded)
			consider("mountain_river",Vector2(x,z),h,b._last_swamp_water,s[13]*flooded)
			consider("cliff_face",Vector2(x,z),h,b._last_swamp_water,s[2]*s[7]*(w[5]+w[11]+w[6]))
			consider("alluvial_fan",Vector2(x,z),h,b._last_swamp_water,s[15])
	for biome:String in ["grass","forest","jungle","savanna","swamp"]:
		b.settings.grass_coverage=0;b.settings.forest_coverage=0;b.settings.jungle_coverage=0;b.settings.savanna_coverage=0;b.settings.swamp_coverage=0;b.settings.mountain_coverage=50
		b.settings.set(biome+"_coverage",50);b.settings.set(biome+"_region_size",16000);b._configure_noise()
		for z in range(-24576,24577,1024):
			for x in range(-24576,24577,1024):
				b._biome_weights(x,z)
				if b._mountain_weight<.25 or b._mountain_weight>.75 or b._island_mask(x,z)<.1:continue
				var h:float=b._get_height(x,z);consider(biome+"_mountain_transition",Vector2(x,z),h,b._last_swamp_water,1-absf(b._mountain_weight-.5))
	for name:String in features:
		assert(features[name].score>.05,"No actual generator feature: "+name)
	FileAccess.open("res://data/mountain_previews.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":73921,"features":features,"source":"Canonical procedural Mountain sampler; no static showcases"},"\t"))
	print("MOUNTAIN_PREVIEWS ",features.size());quit()
func consider(name:String,p:Vector2,h:float,water:float,score:float)->void:
	if features.has(name) and features[name].score>=score:return
	features[name]={"x":p.x,"z":p.y,"height":h,"water":water,"score":score}
