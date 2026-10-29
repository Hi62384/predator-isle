extends SceneTree
const NAMES=["deciduous","conifer","mixed","old_growth","rolling_hills","rocky_woodland","mountain_forest","sheltered_valley","riparian","open_meadow"]
var features:Dictionary={}
var best:Dictionary={}
func candidate(name:String,score:float,p:Vector2,h:float,controls:Dictionary)->void:
	if score<=float(best.get(name,0)):return
	best[name]=score;features[name]={"x":p.x,"z":p.y,"height":h,"score":score,"controls":controls}
func _initialize()->void:
	var b=preload("res://tools/forest/check_invariants.gd").new()
	var sampler=b.builder();b.free()
	for z in range(-100000,100001,900):
		for x in range(-100000,100001,900):
			if sampler._island_mask(x,z)<.035:continue
			var h:float=sampler._get_height(x,z);var s=sampler._forest
			var controls:Dictionary={"region":s.region,"wetness":s.wetness,"drainage":s.drainage,"rock":s.rock,"clearing":s.clearing,"conifer":s.conifer,"river":s.river,"lake":s.lake}
			for i in range(10):
				var score:float=s.weights[i]*(1-maxf(s.river,s.lake))
				if h<5:score=0
				if i!=9:score*=1-s.clearing
				if i==6:score*=h/800
				candidate(NAMES[i],score,Vector2(x,z),h,controls)
			candidate("forest_river",s.river*s.weights[8],Vector2(x,z),h,controls)
			candidate("forest_stream",s.river*(1-s.weights[8])*s.drainage,Vector2(x,z),h,controls)
			candidate("forest_lake",s.lake,Vector2(x,z),h,controls)
			if h>5:
				candidate("forest_ravine",s.weights[7]*s.drainage,Vector2(x,z),h,controls)
				candidate("mossy_rock",s.rock*s.wetness*(s.weights[5]+s.weights[7]),Vector2(x,z),h,controls)
				candidate("forest_trail",s.weights[2]+s.weights[9]*.5,Vector2(x,z),h,controls)
	for kind in ["grass_forest_transition","forest_jungle_transition"]:
		sampler.settings.grass_coverage=50 if kind.begins_with("grass") else 0;sampler.settings.jungle_coverage=0 if kind.begins_with("grass") else 50;sampler.settings.forest_coverage=50;sampler.settings.grass_region_size=8000;sampler._configure_noise()
		for z in range(-40000,40001,450):
			for x in range(-40000,40001,450):
				if sampler._island_mask(x,z)<.04:continue
				var w:Vector4=sampler._biome_weights(x,z);var f:float=w.y;var h:float=sampler._get_height(x,z)
				if h>5:candidate(kind,1-absf(f-.5)*2,Vector2(x,z),h,{"forest":f})
	var report:Dictionary={"seed":73921,"features":features,"scope":"Terrain only; no trees, props or vegetation. Swamp/Snow transitions absent because those biomes are absent/retired. All water uses existing sea level.","trail_note":"forest_trail is a representative low-slope region; the shader generates the actual path network."}
	FileAccess.open("res://data/forest_previews.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("FOREST_PREVIEWS ",features.size()," ",best);quit(0 if features.size()==18 else 1)
