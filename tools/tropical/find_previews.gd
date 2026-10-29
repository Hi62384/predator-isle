extends SceneTree
const FEATURES=["coastal_lowland","lush_plain","rolling_hills","rugged_hills","rocky_highland","mountain_belt","river_valley","humid_basin","lake_country","ancient_volcanic_highland","limestone_highland","plateau_country","ravine_country","coastal_bluff","uplifted_terrace","weathered_escarpment"]
var features:Dictionary={}
func builder():
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","jungle","swamp","mountain","badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(biome+"_coverage",0)
	b.settings.tropical_coverage=100;b._configure_noise();return b
func _initialize()->void:
	var b=builder()
	for z in range(-98304,98305,1024):
		for x in range(-98304,98305,1024):
			var island:float=b._island_mask(x,z)
			if island<.02:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._tropical.state;var w:PackedFloat32Array=b._tropical.region_weights(Vector2(x,z));var water:float=b._last_swamp_water
			for i in range(16):
				if (i==0 or i==13 or i==14) and island*b.settings.island_size*.5>6000:continue
				var preference:float=1-s[6] if i<3 else s[7]
				consider(FEATURES[i],Vector2(x,z),h,water,w[i]*(.65+preference*.35))
			var flooded:float=1 if h<water-.2 else 0
			consider("freshwater_lake",Vector2(x,z),h,water,s[9]*flooded)
			consider("large_river",Vector2(x,z),h,water,s[13]*flooded)
			consider("small_stream",Vector2(x,z),h,water,s[12]*flooded)
			consider("red_soil",Vector2(x,z),h,water,s[10]*(1-s[6]))
			consider("humid_soil",Vector2(x,z),h,water,s[2]*(1-flooded)*(w[7]+w[6]))
			consider("rocky_gorge",Vector2(x,z),h,water,s[6]*s[4]*(w[12]+w[5]))
			consider("rocky_soil_transition",Vector2(x,z),h,water,4*s[4]*(1-s[4])*(1-s[6]*.5))
			if w[15]>.8 and s[6]>.05 and s[6]<.8:
				for offset:Vector2 in [Vector2(64,0),Vector2(-64,0),Vector2(0,64),Vector2(0,-64)]:
					var foot:Vector2=Vector2(x,z)+offset;var lower:float=b._get_height(foot.x,foot.y);var drop:float=h-lower
					if drop<15:continue
					consider("waterfall_ledge",Vector2(x,z),h,water,drop/100)
					if features.waterfall_ledge.x==x and features.waterfall_ledge.z==z and features.waterfall_ledge.score==drop/100:
						features.waterfall_ledge["candidate"]={"lip":[x,h,z],"foot":[foot.x,lower,foot.y],"drop_metres":drop,"renderer_supported":false,"flow_connected":false,"kind":"Dry escarpment ledge; terrain attachment candidate only, not a rendered or routed waterfall"}
	# Streams are small. Inspect actual finite tributary descriptors, not a coarse-grid guess.
	for lane in range(-14,15):
		for segment in range(-17,18):
			var r:float=b._tropical.random(segment,lane,151)
			if r>b.settings.tropical.lake_frequency*b.settings.tropical.basin_frequency:continue
			var x:float=roundf((segment+.25+r*.5)*6000/b._tropical.STEP)*b._tropical.STEP
			var z:float=b._tropical._carrier(x,lane).x
			if b._island_mask(x,z)<.15:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._tropical.state
			consider("freshwater_lake",Vector2(x,z),h,b._last_swamp_water,s[9]*(1 if h<b._last_swamp_water-.2 else 0))
		for segment in range(-30,31):
			var r:float=b._tropical.random(segment,lane,131)
			if r>b.settings.tropical.stream_frequency:continue
			var span:float=b._tropical._spacing()*.6;var t:float=.45
			var x:float=(segment+.15+r*.3)*span+t*span*.7
			var carrier:Vector3=b._tropical._carrier(x,lane)
			var side:float=-1 if b._tropical.random(segment,lane,137)<.5 else 1
			var z:float=carrier.x+side*b._tropical._spacing()*.22*t*t
			if b._island_mask(x,z)<.15:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._tropical.state
			consider("small_stream",Vector2(x,z),h,b._last_swamp_water,s[12]*(1 if h<b._last_swamp_water-.15 else 0))
			if r<b.settings.tropical.basin_frequency*b.settings.tropical.stream_frequency:
				x=(segment+.15+r*.3)*span+.55*span*.7
				z=b._tropical._carrier(x,lane).x+side*b._tropical._spacing()*.22*.55*.55
				if b._island_mask(x,z)<.15:continue
				h=b._get_height(x,z);s=b._tropical.state
				consider("freshwater_pool",Vector2(x,z),h,b._last_swamp_water,s[9]*(1 if h<b._last_swamp_water-.2 else 0))
	# Admit a real connected cascade, never relabel the old dry escarpment ledge.
	if FileAccess.file_exists("res://tools/tropical/artifacts/check_cascades.json"):
		var cascades=JSON.parse_string(FileAccess.get_file_as_string("res://tools/tropical/artifacts/check_cascades.json"))
		if cascades.passed and cascades.source_sha256.get("res://scripts/tropical_sampler.gd","")==FileAccess.get_sha256("res://scripts/tropical_sampler.gd"):
			b=builder()
			for item:Dictionary in cascades.records:
				if int(item.seed)!=b.world_seed:continue
				var identity:PackedStringArray=item.id.split(":");var p:Vector2=b._tropical.cascade_point(int(identity[1]),int(identity[2]),.5)
				var result:Dictionary=preload("res://scripts/terrain_feature_meshes.gd").new().build(b,Vector2i(floori(p.x/256),floori(p.y/256)))
				if result.is_empty():continue
				for fall:Dictionary in result.waterfalls:
					if fall.id!=item.id:continue
					var h:float=b._get_height(p.x,p.y);consider("rocky_cascade",p,h,b._last_swamp_water,fall.drop_metres)
					features.rocky_cascade["candidate"]={"id":fall.id,"renderer_supported":true,"flow_connected":true,"drop_metres":fall.drop_metres,"lip":fall.canonical_water_profile.back(),"foot":fall.canonical_water_profile.front(),"kind":"Actual rocky tributary cascade using the existing foam renderer; not a detached free-falling waterfall"}
				break
	for biome:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
		b=builder();b.settings.set(biome+"_coverage",50);b.settings.set(biome+"_region_size",14000);b.settings.tropical_coverage=50;b._configure_noise()
		for z in range(-24576,24577,512):
			for x in range(-24576,24577,512):
				b._biome_weights(x,z)
				if b._tropical_weight<.25 or b._tropical_weight>.75 or b._island_mask(x,z)<.1:continue
				var h:float=b._get_height(x,z);consider(biome+"_tropical_transition",Vector2(x,z),h,b._last_swamp_water,1-absf(b._tropical_weight-.5))
	b=preload("res://tools/tropical/volcanic_transition_fixture.gd").builder()
	var volcanic_overlap:Vector2=preload("res://tools/tropical/volcanic_transition_fixture.gd").locate(b)
	assert(volcanic_overlap.is_finite(),"Actual live Tropical/Volcanic overlap")
	var volcanic_height:float=b._get_height(volcanic_overlap.x,volcanic_overlap.y)
	consider("volcanic_tropical_transition",volcanic_overlap,volcanic_height,b._last_swamp_water,1-absf(b._tropical_weight-.5))
	for sandy:bool in [false,true]:
		b=builder();b.settings.rocky_coast_enabled=true;b.settings.beaches_enabled=sandy;b.settings.rocky_coast.coverage=1;b.settings.beach.coverage=1;b._configure_noise()
		var coast_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_previews.json" if sandy else "res://data/rocky_coast_previews.json"))
		for item:Dictionary in coast_manifest.features.values():
			for d in range(-3000,3001,100):
				var p:=Vector2(item.x-item.outward_x*d,item.z-item.outward_z*d)
				var h:float=b._get_height(p.x,p.y);var influence:float=b._last_coast.x
				if influence<.2 or influence>.8 or b._last_tropical.x<.5:continue
				consider("beach_tropical_transition" if sandy else "coast_tropical_transition",p,h,b._last_swamp_water,1-absf(influence-.5))
	b=builder();b.settings.rocky_coast_enabled=true;b._configure_noise()
	var outlet=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocky_coast_previews.json")).features.river_mouth
	var mouth:=Vector2(outlet.x,outlet.z);var outlet_height:float=b._get_height(mouth.x,mouth.y)
	consider("river_mouth",mouth,outlet_height,b._last_swamp_water,b._coast.inherited_river(mouth))
	assert(features.river_mouth.score>.1,"Inherited channel must actually reach coastal mouth")
	b._tropical.sample(mouth.x,mouth.y)
	assert(b._tropical.state[13]>.1,"Tropical freshwater carrier must be active at the coast")
	for name:String in FEATURES:assert(features.has(name) and features[name].score>.05,"No actual region: "+name)
	for name:String in ["freshwater_lake","large_river","small_stream"]:assert(features.has(name) and features[name].score>.05,"No actual water feature: "+name)
	if FileAccess.file_exists("res://data/tropical_path_preview.json"):
		var path=JSON.parse_string(FileAccess.get_file_as_string("res://data/tropical_path_preview.json"))
		if path.shader_sha256==FileAccess.get_sha256("res://shaders/tropical_material.gdshaderinc") and path.get("sampler_sha256","")==FileAccess.get_sha256("res://scripts/tropical_sampler.gd"):features.natural_path=path
	FileAccess.open("res://data/tropical_previews.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":73921,"features":features,"source":"Searched actual Tropical sampler and verified connected cascade profiles; no static showcases","pending_dependencies":[],"unsupported":["Detached free-falling waterfall volumes; steep tributary cascades are rendered","Heightfield caves and overhangs"]},"\t"))
	print("TROPICAL_PREVIEWS ",features.size());quit()
func consider(name:String,p:Vector2,h:float,water:float,score:float)->void:
	if features.has(name) and features[name].score>=score:return
	features[name]={"x":p.x,"z":p.y,"height":h,"water":water,"score":score}
