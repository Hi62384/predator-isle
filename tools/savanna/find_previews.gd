extends SceneTree
const NAMES=["golden_plains","rolling","dry_rocky","lush","rugged_hills","kopje_country","highlands","dry_valley","floodplain","semi_arid","laterite","escarpment","basin_country"]
const EXTRA=["isolated_kopje","dry_riverbed","perennial_river","seasonal_lake","cracked_basin","worn_trail","rocky_soil_transition","grass_savanna_transition","forest_savanna_transition","jungle_savanna_transition"]
var features:Dictionary={}
var best:Dictionary={}
func candidate(name:String,score:float,p:Vector2,h:float,controls:Dictionary)->void:
	if score<=float(best.get(name,0)):return
	best[name]=score;features[name]={"x":p.x,"z":p.y,"height":h,"score":score,"controls":controls}
func _initialize()->void:
	var helper=preload("res://tools/savanna/check_invariants.gd").new();var b=helper.builder();helper.free()
	for z in range(-100000,100001,700):
		for x in range(-100000,100001,700):
			if b._island_mask(x,z)<.04:continue
			var h:float=b._get_height(x,z);var s=b._savanna;var p:=Vector2(x,z)
			var controls:Dictionary={"region":s.region,"wetness":s.wetness,"drainage":s.drainage,"rock":s.rock,"soil":s.soil,"laterite":s.laterite,"channel":s.river,"basin":s.lake,"water":s.water}
			if h>5:
				for i in range(13):
					var score:float=s.weights[i]*(1-s.water)
					if i==5:score*=s.rock*h/150
					if i==6:score*=h/700
					if i==11:score*=s.rock+.2
					candidate(NAMES[i],score,p,h,controls)
				candidate("isolated_kopje",s.weights[5]*s.rock*h/150,p,h,controls)
				candidate("dry_riverbed",s.river*(1-s.water)*(s.weights[7]+.2),p,h,controls)
				candidate("cracked_basin",s.lake*(1-s.water)*(1-s.wetness),p,h,controls)
				candidate("worn_trail",s.weights[0]*(1-s.river)*(1-s.lake),p,h,controls)
				candidate("rocky_soil_transition",s.rock*(1-s.rock)*s.soil,p,h,controls)
			candidate("perennial_river",s.water*s.river,p,h,controls)
			candidate("seasonal_lake",s.water*s.lake,p,h,controls)
	for kind in ["grass","forest","jungle"]:
		b.settings.grass_coverage=50 if kind=="grass" else 0;b.settings.forest_coverage=50 if kind=="forest" else 0;b.settings.jungle_coverage=50 if kind=="jungle" else 0;b.settings.swamp_coverage=0;b.settings.savanna_coverage=50;b.settings.grass_region_size=10000;b._configure_noise()
		for z in range(-40000,40001,450):
			for x in range(-40000,40001,450):
				if b._island_mask(x,z)<.04:continue
				var w:Vector4=b._biome_weights(x,z);var f:float=w.z;var h:float=b._get_height(x,z)
				if h>5:candidate(kind+"_savanna_transition",1-absf(f-.5)*2,Vector2(x,z),h,{"savanna":f})
	var report:Dictionary={"seed":73921,"features":features,"scope":"Terrain only; no props, foliage or collision. Desert/Snow retired; Mesa absent. Water uses existing sea-level renderer; season changes materials, never canonical geometry.","trail_note":"worn_trail marks a suitable plain; render_review searches the actual shader path mask for its ground-level trail view."}
	FileAccess.open("res://data/savanna_previews.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SAVANNA_PREVIEWS ",features.size()," ",best);quit(0 if features.size()==23 else 1)
