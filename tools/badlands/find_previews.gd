extends SceneTree
const FEATURES=["painted_hills","red_mudstone","gray_clay","bentonite_hills","eroded_ridges","hoodoo_country","badlands_canyon","dissected_plateau","sediment_basin","dry_wash_country","stratified_clay","pale_badlands","rocky_highlands","stratified_escarpment","sediment_fans","barren_plain"]
var features:Dictionary={}
func consider(name:String,p:Vector2,height:float,water:float,score:float)->void:
	if score<=0 or (features.has(name) and features[name].score>=score):return
	features[name]={"x":p.x,"z":p.y,"height":height,"water":water,"score":score}
func builder():
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:b.settings.set(biome+"_coverage",0)
	b.settings.badlands_coverage=100;b._configure_noise();return b
func measured_crest_site(b)->void:
	var path:String="res://tools/badlands/artifacts/check_incised_profiles.json"
	if not FileAccess.file_exists(path):return
	var report=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not report is Dictionary or not report.failures.is_empty() or report.sampler_sha256!=FileAccess.get_sha256("res://scripts/badlands_sampler.gd"):return
	var expression:=RegEx.new();assert(expression.compile("[-+]?[0-9]+(?:\\.[0-9]+)?")==OK)
	for item:Dictionary in report.cases:
		if int(item.seed)!=b.world_seed:continue
		for section:Dictionary in item.sections:
			var crest:Dictionary=section.measured_crest
			if crest.is_empty() or crest.prominence_at_32m<3 or crest.prominence_at_64m<8:continue
			var coordinates:Array=expression.search_all(crest.position);assert(coordinates.size()==2)
			var p:=Vector2(float(coordinates[0].get_string()),float(coordinates[1].get_string()))
			var score:float=minf(crest.prominence_at_32m/3.0,crest.prominence_at_64m/12.0)
			consider("knife_edge_ridges",p,b._get_height(p.x,p.y),b._last_swamp_water,score)
			if features.knife_edge_ridges.score==score:
				features.knife_edge_ridges.merge({"selection":"Actual measured crest, not just an upland regional label","prominence_at_32m":crest.prominence_at_32m,"prominence_at_64m":crest.prominence_at_64m,"evidence":path})
func _initialize()->void:
	var b=builder()
	for z in range(-98304,98305,1536):
		for x in range(-98304,98305,1536):
			if b._island_mask(x,z)<.12:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._badlands.state;var w:PackedFloat32Array=b._badlands.region_weights(Vector2(x,z));var p:=Vector2(x,z)
			var range_height:float=0
			for offset:Vector2 in [Vector2(128,0),Vector2(-128,0),Vector2(0,128),Vector2(0,-128)]:
				range_height=maxf(range_height,absf(b._badlands.sample(x+offset.x,z+offset.y,false)-s[0]))
			for i in range(16):
				var score:float=w[i]
				if i!=8 and i!=9 and i!=14 and i!=15:
					# A province label alone can select its flat wash floor as the
					# showcase for hills. Require real local relief and surviving
					# elevation; do not alter geometry to fit a named preview.
					score*=(.25+clampf(range_height/45,0,1)*.75)*(.15+.85*clampf((h-35)/65,0,1))*(1-s[8]*.9)*(1-s[9]*.5)
				consider(FEATURES[i],p,h,b._last_swamp_water,score)
			consider("knife_edge_ridges",p,h,b._last_swamp_water,w[4]*s[7])
			consider("dense_gullies",p,h,b._last_swamp_water,w[4]*s[9])
			consider("narrow_ravine",p,h,b._last_swamp_water,s[9]*(w[4]+w[6]+w[7]))
			consider("talus_slope",p,h,b._last_swamp_water,s[4]*(1-s[7])*(w[12]+w[13]))
	# Descriptor-aware search for uncommon connected features, not fabricated sites.
	for lane in range(-12,13):
		for index in range(-45,46):
			for side in [-1,1]:
				var tree:Dictionary=b._badlands._tree(index,lane,side)
				for label:String in ["root","remnant"]:
					var v:Vector3=tree.root if label=="root" else tree.ends[0]+Vector3(80,0,0)
					var p:=Vector2(v.x,v.z)
					if b._island_mask(p.x,p.y)<.04:continue
					var h:float=b._get_height(p.x,p.y);var s:PackedFloat64Array=b._badlands.state;var w:PackedFloat32Array=b._badlands.region_weights(p)
					if label=="remnant":consider("hoodoo_cluster",p,h,b._last_swamp_water,s[10]);continue
					consider("major_dry_wash",p,h,b._last_swamp_water,s[8]*(1-s[14]));consider("alluvial_fan",p,h,b._last_swamp_water,s[13])
					if h<b._last_swamp_water-.2:consider("rare_pool",p,h,b._last_swamp_water,s[14])
	for biome:String in ["grass","forest","jungle","savanna","swamp","mountain","tropical"]:
		var mixed=builder();mixed.settings.badlands_coverage=50;mixed.settings.set(biome+"_coverage",50);mixed.settings.set(biome+"_region_size",14000);mixed._configure_noise()
		var name:String=biome+"_badlands_transition"
		for z in range(-90000,90001,2600):
			for x in range(-90000,90001,2600):
				mixed._biome_weights(x,z);var bw:float=mixed._badlands_weight
				if bw<.15 or bw>.85 or mixed._island_mask(x,z)<.05:continue
				var h:float=mixed._get_height(x,z);consider(name,Vector2(x,z),h,mixed._last_swamp_water,1-absf(bw-.5))
	measured_crest_site(b)
	var report:Dictionary={"seed":73921,"features":features,"unsupported_transitions":["Desert: retired/inactive in current live ownership","Mesa: not installed in current live ownership"],"heightfield":"No detached caps, overhangs or decorative rock objects"}
	FileAccess.open("res://data/badlands_previews.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("BADLANDS_PREVIEWS ",features.size()," ",features.keys());quit()
