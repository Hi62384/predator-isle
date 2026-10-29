extends SceneTree
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beach.coverage=1;b.settings.rocky_coast.coverage=1
	for kind:String in ["grass","forest","jungle","savanna","swamp","mountain"]:b.settings.set(kind+"_coverage",100 if kind=="grass" else 0)
	b._configure_noise();var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/beach_previews.json"));var records:Array=[];var all:Array=[]
	for name:String in ["wide_beach","high_foredunes","parabolic_dunes","storm_scarps","backdunes"]:
		var item:Dictionary=manifest.features[name];var maximum:float=0;var slopes:Array=[];var worst:Dictionary={}
		for z in range(-800,801,64):
			for x in range(-800,801,64):
				var p:=Vector2(item.x+x,item.z+z);var h:float=b._get_height(p.x,p.y)
				if b._coast.state[19]*b._coast.state[2]<.98 or h<2 or h>200:continue
				var gradient:=Vector2(b._get_height(p.x+8,p.y,false)-b._get_height(p.x-8,p.y,false),b._get_height(p.x,p.y+8,false)-b._get_height(p.x,p.y-8,false))/16
				var angle:float=rad_to_deg(atan(gradient.length()));slopes.append(angle);all.append(angle)
				if angle>maximum:
					maximum=angle;b._get_height(p.x,p.y)
					worst={"x":p.x,"z":p.y,"height":h,"influence":b._coast.state[2],"sand":b._coast.state[19],"shore_distance":b._coast.beach.shore_distance(p)}
		assert(slopes.size()>20);slopes.sort()
		assert(slopes[int(slopes.size()*.95)]<40,"Sandy regional slopes: "+name)
		records.append({"region":name,"samples":slopes.size(),"slope_p95_degrees":slopes[int(slopes.size()*.95)],"slope_max_degrees":maximum,"worst":worst})
	all.sort();assert(all[int(all.size()*.95)]<40,"Broad sandy slopes should not become cliff walls")
	FileAccess.open("res://tools/beach/artifacts/profiles.json",FileAccess.WRITE).store_string(JSON.stringify({"records":records,"total":all.size(),"passed":true},"\t"));print("BEACH_PROFILES ",JSON.stringify(records));quit()
