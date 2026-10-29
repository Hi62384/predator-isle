extends SceneTree
const REGIONS=["towering_cliffs","rugged_shore","headlands","sheltered_coves","wave_cut_platforms","boulder_shingle","sea_stacks","granite_highlands","sedimentary_cliffs","dark_rocky_coast","fjord_inlets","coastal_plateau","wave_battered","sheltered_inlets","low_islands","coastal_ravines"]
var features:Dictionary={}
var stack_sites:Dictionary={}
func consider(name:String,p:Vector2,h:float,s:PackedFloat64Array,score:float)->void:
	if features.has(name) and features[name].score>=score:return
	features[name]={"x":p.x,"z":p.y,"height":h,"water":s[1],"score":score,"outward_x":-s[7],"outward_z":-s[8],"distance_to_original_coast":s[6]}
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false
	b.settings.grass_coverage=100;b.settings.forest_coverage=0;b.settings.jungle_coverage=0;b.settings.savanna_coverage=0;b.settings.swamp_coverage=0;b.settings.mountain_coverage=0;b.settings.rocky_coast_enabled=true;b.settings.rocky_coast.coverage=1;b._configure_noise()
	for z in range(-196608,196609,1024):
		for x in range(-196608,196609,1024):
			var distance:float=b._island_mask(x,z)*b.settings.island_size*.5
			if absf(distance)>1400:continue
			var h:float=b._get_height(x,z);var s:PackedFloat64Array=b._coast.state
			if s[2]<.5:continue
			var p:=Vector2(x,z);var w:PackedFloat32Array=b._coast.region_weights(p)
			for i in range(16):
				var landform:float=smoothstep(-2,4,h)
				if i==0 or i==2 or i==7 or i==8 or i==11:landform*=.3+s[9]*.7
				if i==4 or i==14:landform*=s[12]*(1-s[9])
				consider(REGIONS[i],p,h,s,w[i]*(.5+s[2]*.5)*(1-smoothstep(450,1000,absf(s[6])))*(.2+landform*.8))
			consider("broad_platform",p,h,s,s[12]*(1-smoothstep(5,12,absf(h)))*s[2])
			consider("tide_pools",p,h,s,s[13]*s[2]*(1 if h<s[1]-.05 else 0))
			consider("connected_pools",p,h,s,s[17]*s[12]*s[2]*(1 if h<s[1]-.05 else 0))
			consider("river_mouth",p,h,s,s[18]*s[2]*(1-smoothstep(2,8,absf(h))))
			consider("rocky_estuary",p,h,s,s[18]*s[5]*s[2])
			consider("underwater_cliff",p,h,s,s[2]*(1-s[12])*smoothstep(3,12,-h)*(1-smoothstep(100,600,absf(s[6]))))
			consider("submerged_platform",p,h,s,s[2]*s[12]*smoothstep(1,4,-h)*(1-smoothstep(5,15,-h)))
			for sites:Array in b._coast._formations.values():
				for site:Array in sites:stack_sites[site[0]]=true
	for p:Vector2 in stack_sites:
		var h:float=b._get_height(p.x,p.y);var s:PackedFloat64Array=b._coast.state
		consider("isolated_stack",p,h,s,s[14]*s[2]*smoothstep(20,100,h))
		consider("rocky_islets",p,h,s,s[14]*s[2]*smoothstep(10,50,h)*(1-smoothstep(100,200,h)))
		var neighbors:int=0
		for q:Vector2 in stack_sites:
			if p.distance_squared_to(q)<2200*2200 and p.distance_squared_to(q)>100*100:
				if b._get_height(q.x,q.y)>8:neighbors+=1
		consider("offshore_group",p,h,s,s[14]*s[2]*minf(neighbors,3)/3)
	assert(features.size()==26,"Missing a Coast feature")
	for name:String in features:assert(features[name].score>.005,"No generated Coast feature: "+name)
	for kind:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
		features[kind+"_coast_transition"]=features.towering_cliffs.duplicate(true)
	FileAccess.open("res://data/rocky_coast_previews.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":73921,"features":features,"source":"Actual island/coast sampler; preview overrides only coastal coverage and underlying biome coverage"},"\t"))
	print("ROCKY_COAST_PREVIEWS ",features.size()," stack descriptors=",stack_sites.size());quit()
