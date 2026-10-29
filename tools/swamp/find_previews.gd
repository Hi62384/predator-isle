extends SceneTree
const FEATURES=["flooded_lowland","shallow_water","mudflat","river_floodplain","blackwater","peatland","muddy_islands","bayou","seasonal_basin","hummock_hollow","deep_backwater","swamp_lake","rocky_wetland","coastal_wetland","drained_upland"]
var features:Dictionary={}
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=preload("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false
	b.settings.grass_coverage=0;b.settings.forest_coverage=0;b.settings.savanna_coverage=0;b.settings.jungle_coverage=0;b.settings.swamp_coverage=100;b._configure_noise()
	for z in range(-100000,100001,600):
		for x in range(-100000,100001,600):
			if b._island_mask(x,z)<.07:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._swamp.state;var w:PackedFloat32Array=b._swamp.region_weights(Vector2(x,z))
			for i in range(15):consider(FEATURES[i],Vector2(x,z),h,b._last_swamp_water,w[i]*(.7+.3*(1-absf(h-b._last_swamp_water)/15)))
			consider("major_channel",Vector2(x,z),h,b._last_swamp_water,s[5]*(.5+w[7]*.5))
			consider("narrow_channels",Vector2(x,z),h,b._last_swamp_water,s[5]*w[6])
			consider("natural_levee",Vector2(x,z),h,b._last_swamp_water,s[7]*w[3]*(1-s[5]))
			consider("backswamp_basin",Vector2(x,z),h,b._last_swamp_water,s[13]*s[2]*(1-s[5])*(w[3]+w[10]))
			consider("oxbow",Vector2(x,z),h,b._last_swamp_water,s[12])
			consider("irregular_ponds",Vector2(x,z),h,b._last_swamp_water,s[6]*(w[8]+w[9]))
			consider("muddy_shore",Vector2(x,z),h,b._last_swamp_water,(1-smoothstep(.05,.45,absf(h-b._last_swamp_water)))*(1-s[9]))
			consider("sediment_bank",Vector2(x,z),h,b._last_swamp_water,s[4]*s[7]*(1-s[5]))
	for biome:String in ["grass","forest","jungle","savanna"]:
		b.settings.grass_coverage=0;b.settings.forest_coverage=0;b.settings.savanna_coverage=0;b.settings.jungle_coverage=0;b.settings.swamp_coverage=50;b.settings.set(biome+"_coverage",50);b.settings.set(biome+"_region_size",9000);b._configure_noise()
		for z in range(-22000,22001,500):
			for x in range(-22000,22001,500):
				var w:Vector4=b._biome_weights(x,z)
				if w.w<.25 or w.w>.75 or b._island_mask(x,z)<.1:continue
				var h:float=b._get_height(x,z);consider(biome+"_swamp_transition",Vector2(x,z),h,b._last_swamp_water,1-absf(w.w-.5))
	for name:String in features:
		assert(features[name].score>.05,"No valid actual generator feature: "+name)
	var f=FileAccess.open("res://data/swamp_previews.json",FileAccess.WRITE);f.store_string(JSON.stringify({"seed":73921,"features":features,"source":"Actual canonical procedural sampler, no manually built scenes"},"\t"))
	print("SWAMP_PREVIEWS ",features.size());quit()
func consider(name:String,p:Vector2,h:float,water:float,score:float)->void:
	if features.has(name) and features[name].score>=score:return
	features[name]={"x":p.x,"z":p.y,"height":h,"water":water,"score":score}
