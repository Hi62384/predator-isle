extends SceneTree
const NAMES=["huge_snowfield","arctic_tundra","rolling_hills","rugged_highlands","alpine_mountains","exposed_peaks","mountain_valley","valley_glacier","ice_field","frozen_lakes","partial_lake","frozen_river","snow_plateau","scoured_ridge","snowdrifts","snowy_coast","grass_snow_transition"]
var features:Dictionary={}
var best:Dictionary={}
func candidate(name:String,score:float,p:Vector2,h:float,region:int,controls:Dictionary)->void:
	if score<=float(best.get(name,0)):return
	best[name]=score;features[name]={"x":p.x,"z":p.y,"height":h,"region":region,"score":score,"controls":controls}
func _initialize()->void:
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new()
	builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	builder.settings.grass_coverage=0;builder.settings.desert_coverage=0;builder.settings.snow_coverage=100;builder.settings.stone_coverage=0;builder.settings.temperature_enabled=false
	builder._configure_noise()
	for z in range(-100000,100001,900):
		for x in range(-100000,100001,900):
			var shore:float=builder._island_mask(x,z)*builder.settings.island_size*.5
			if shore< -150:continue
			var p:=Vector2(x,z);var h:float=builder._get_height(x,z)
			var sampler=builder._snow;var a:Vector4=sampler.a;var b:Vector4=sampler.b;var c:Vector4=sampler.c
			var w:PackedFloat32Array=sampler.region_weights(p)
			var region:int=0
			for i in range(1,8):
				if w[i]>w[region]:region=i
			var controls:Dictionary={"depth":a.w*12,"exposure":b.x,"glacier":b.y,"lake":b.z,"river":b.w,"rock":c.x,"strain":c.y}
			if shore<0:
				candidate("snowy_coast",b.z,p,h,region,controls);continue
			if shore<600:continue
			candidate("huge_snowfield",w[0]*(1.0-maxf(b.z,b.w)),p,h,region,controls)
			candidate("arctic_tundra",w[1]*b.x,p,h,region,controls)
			candidate("rolling_hills",w[1]*(1.0-b.x)*a.w,p,h,region,controls)
			candidate("rugged_highlands",w[5]*h/900,p,h,region,controls)
			candidate("alpine_mountains",w[2]*h/1200,p,h,region,controls)
			candidate("exposed_peaks",w[2]*c.x*b.x*h/1200,p+Vector2(300,200),h,region,controls)
			candidate("mountain_valley",w[7]*(1.0-b.y*.5),p,h,region,controls)
			candidate("valley_glacier",b.y,p,h,region,controls)
			candidate("ice_field",b.y*(1.0-c.y),p,h,region,controls)
			candidate("frozen_lakes",b.z*w[4],p,h,region,controls)
			candidate("frozen_river",b.w,p,h,region,controls)
			candidate("snow_plateau",w[6]*h/500,p,h,region,controls)
			candidate("scoured_ridge",w[5]*b.x*c.x,p,h,region,controls)
			candidate("snowdrifts",sampler.last_drift*(w[0]+w[6])*(1.0-maxf(b.z,b.w)),p,h,region,controls)
	# The partial-freeze inspection preset changes only the exposed ice-coverage
	# knob. Find an actual lake with both solid ice and open water, not its shore.
	builder.settings.snow.lake_ice_coverage=.5;builder._configure_noise()
	for z in range(-100000,100001,1300):
		for x in range(-100000,100001,1300):
			for site:Vector4 in builder._lake_sites(Vector2i(floori(x/1300.0),floori(z/1300.0)),1300):
				var p:=Vector2(site.x,site.y)
				if builder._island_mask(p.x,p.y)<.02:continue
				var w:PackedFloat32Array=builder._snow.region_weights(p)
				if w[4]<.8:continue
				var low:float=1;var high:float=0
				for offset in [Vector2(-.5,0),Vector2(.5,0),Vector2(0,-.5),Vector2(0,.5)]:
					var point:Vector2=p+offset*site.z;builder._get_height(point.x,point.y)
					if builder._snow_water_mask.x>.8:
						low=minf(low,builder._snow_freeze_mask.x);high=maxf(high,builder._snow_freeze_mask.x)
				var h:float=builder._get_height(p.x,p.y)
				if low<.1 and high>.99:candidate("partial_lake",(high-low)*w[4],p,h,4,{"min_freeze":low,"max_freeze":high,"runtime_ice_coverage":.5})
	# Find a real transition under one declared runtime-only mixed preset.
	builder.settings.grass_coverage=50;builder.settings.snow_coverage=50
	builder.settings.grass_region_size=24000;builder.settings.snow_region_size=24000;builder.settings.biome_size=1
	builder._configure_noise()
	for z in range(-49750,50001,500):
		for x in range(-49750,50001,500):
			if builder._island_mask(x,z)<=.05:continue
			var w:Vector4=builder._biome_weights(x,z)
			candidate("grass_snow_transition",1.0-absf(w.x-.5)*2.0,Vector2(x,z),builder._get_height(x,z),0,{"grass":w.x,"snow":w.z})
	for name in NAMES:
		if not features.has(name):push_error("Missing preview: "+name)
	var file:=FileAccess.open("res://data/snow_previews.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":73921,"features":features,"note":"Discovered canonical world features, not sculpted demo geometry. Partial lake uses runtime lake_ice_coverage=.5; Grass transition uses runtime 50/50 coverage and 24000 m regions."},"\t"));file.close()
	print("SNOW_PREVIEWS ",features.size()," ",best);quit(0 if features.size()==17 else 1)
