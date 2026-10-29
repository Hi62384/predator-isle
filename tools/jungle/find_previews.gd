extends SceneTree
const NAMES=["lowland_rainforest","rolling_jungle","rugged_hills","foothills","jungle_mountains","river_rainforest","floodplain","rocky_jungle","karst","jungle_plateau","jungle_gorge","humid_basin","upland_rainforest"]
var features:Dictionary={}
var best:Dictionary={}
func candidate(name:String,score:float,p:Vector2,h:float,region:int,controls:Dictionary)->void:
	if score<=float(best.get(name,0)):return
	best[name]=score;features[name]={"x":p.x,"z":p.y,"height":h,"region":region,"score":score,"controls":controls}
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.mountain_coverage=0;b.settings.rocky_coast_enabled=false
	b.settings.forest_coverage=0;b.settings.swamp_coverage=0;b.settings.savanna_coverage=0;b.settings.grass_coverage=0;b.settings.jungle_coverage=100;b.settings.temperature_enabled=false;b._configure_noise()
	for z in range(-200000,200001,1250):
		for x in range(-200000,200001,1250):
			if b._island_mask(x,z)<.035:continue
			var h:float=b._get_height(x,z);var s=b._jungle;var w:PackedFloat32Array=s.region_weights(Vector2(x,z));var controls:Dictionary={"wetness":s.wetness,"drainage":s.drainage,"rock":s.rock,"river":s.river,"lake":s.lake}
			for i in range(13):
				var score:float=w[i]*(1-maxf(s.river,s.lake))
				if h<5:score=0
				elif i==4:score*=h/800
				elif i==5 or i==6:score=w[i]*(.1+s.drainage)
				elif i==7 or i==8 or i==9:score*=h/300
				candidate(NAMES[i],score,Vector2(x,z),h,i,controls)
			candidate("jungle_river",s.river,Vector2(x,z),h,s.region,controls)
			candidate("jungle_lake",s.lake,Vector2(x,z),h,s.region,controls)
	b.settings.grass_coverage=50;b.settings.jungle_coverage=50;b._configure_noise()
	for z in range(-30000,30001,450):
		for x in range(-30000,30001,450):
			if b._island_mask(x,z)<.05:continue
			b._biome_weights(x,z);var w:float=b._jungle_weight;var h:float=b._get_height(x,z)
			if h>5:candidate("grass_jungle_transition",1-absf(w-.5)*2,Vector2(x,z),h,0,{"jungle":w})
	var report:Dictionary={"seed":73921,"features":features,"unsupported":["Populated forest/canopy (no foliage renderer or plant assets)","Tropical and Swamp transitions (biomes absent)","Rendered waterfalls/elevated water (sea-level ocean only)"],"note":"Canonical discovered coordinates, not sculpted showcase geometry. Jungle preview overrides coverage only at runtime."}
	var file:=FileAccess.open("res://data/jungle_previews.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));print("JUNGLE_PREVIEWS ",features.size()," ",best);quit(0 if features.size()==16 else 1)
