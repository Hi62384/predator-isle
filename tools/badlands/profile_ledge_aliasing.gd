extends SceneTree
func make_builder(ledges:float):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.badlands_coverage=100;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b.settings.badlands.ledges=ledges;b._configure_noise();return b
func statistics(heights:PackedFloat64Array)->Dictionary:
	var energy:float=0;var maxima:int=0
	for i in range(1,heights.size()-1):
		energy+=pow(heights[i-1]+heights[i+1]-2*heights[i],2)
		if heights[i]>heights[i-1] and heights[i]>=heights[i+1]:maxima+=1
	return {"second_difference_rms_m":sqrt(energy/(heights.size()-2)),"local_maxima":maxima}
func _initialize()->void:
	var on=make_builder(.65);var off=make_builder(0);var records:Array=[]
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"));var site:Dictionary=manifest.features.knife_edge_ridges
	for offset:float in [-32.0,0.0,32.0]:
		var a:=PackedFloat64Array();var b:=PackedFloat64Array();var maximum_delta:float=0
		for i in range(-128,129):
			var x:float=site.x+i*4.0;var z:float=site.z+offset
			a.append(on._get_height(x,z));b.append(off._get_height(x,z));maximum_delta=maxf(maximum_delta,absf(a[-1]-b[-1]))
		records.append({"z_offset_m":offset,"four_metre_spacing":true,"ledges_on":statistics(a),"ledges_off":statistics(b),"maximum_height_difference_m":maximum_delta,"on_heights":a,"off_heights":b})
	var report:Dictionary={"records":records,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Controlled canonical profile diagnostic at one actual ridge; independent configs, ledges 0.65 versus zero. Not a hydraulic or artistic acceptance test."}
	FileAccess.open("res://tools/badlands/artifacts/profile_ledge_aliasing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for record:Dictionary in records:print("BADLANDS_LEDGE_ALIASING ",record.z_offset_m," on=",record.ledges_on," off=",record.ledges_off," maximum_delta=",record.maximum_height_difference_m)
	quit()
