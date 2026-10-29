extends SceneTree
## Diagnose old showcase coordinates after physical erosion revisions.
func make_builder(uncut:bool=false):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.badlands_coverage=100;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false
	if uncut:b.settings.badlands.erosion=0;b.settings.badlands.secondary_gullies=0
	b._configure_noise();return b
func _initialize()->void:
	var b=make_builder();var uncut=make_builder(true);var records:Array=[]
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	for name:String in manifest.features:
		if name.ends_with("transition"):continue
		var site:Dictionary=manifest.features[name];var p:=Vector2(site.x,site.z)
		var h:float=b._get_height(p.x,p.y);var s:PackedFloat64Array=b._badlands.state.duplicate()
		var region:int=0;var weights:PackedFloat32Array=b._badlands.region_weights(p)
		for i in range(16):
			if weights[i]>weights[region]:region=i
		records.append({"name":name,"position":p,"height_m":h,"dominant_province":b._badlands.NAMES[region],"province_mass":weights[region],"actual_network_incision_m":uncut._get_height(p.x,p.y)-h,"secondary_cut_control":s[9],"primary_wash_control":s[8],"remnant_control":s[10]})
	var result:Dictionary={"records":records,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"manifest_sha256":FileAccess.get_sha256("res://data/badlands_previews.json"),"scope":"Diagnostic actual-field admission at existing showcase coordinates; not an acceptance pass or artistic sign-off"}
	FileAccess.open("res://tools/badlands/artifacts/profile_preview_admission.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_PREVIEW_ADMISSION ",JSON.stringify(records));quit()
