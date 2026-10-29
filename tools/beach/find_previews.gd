extends SceneTree
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;
	b.settings.beaches_enabled=true;b.settings.beach.coverage=1;b.settings.rocky_coast.coverage=1
	for kind:String in ["grass","forest","jungle","savanna","swamp","mountain"]:b.settings.set(kind+"_coverage",100 if kind=="grass" else 0)
	b._configure_noise();var features:Dictionary={};var names:Array=b._coast.beach.NAMES
	for z in range(-196608,196609,1536):
		for x in range(-196608,196609,1536):
			if absf(b._island_mask(x,z)*b.settings.island_size*.5)>1600:continue
			var p:=Vector2(x,z)
			for k in range(24):
				var frame:Vector3=b._coast.coast_frame(p);p-=Vector2(frame.y,frame.z)*clampf(frame.x*.25,-500,500)
			var frame:Vector3=b._coast.coast_frame(p);var n:=Vector2(frame.y,frame.z);var weights:PackedFloat32Array=b._coast.region_weights(p)
			if absf(frame.x)>40:continue
			for i in range(16):
				if features.has(names[i]) and features[names[i]].score>=weights[i]:continue
				var offset:float=b.settings.beach.beach_width*.5
				if i in [2,3,4,5,13]:offset=b.settings.beach.beach_width+b.settings.beach.foredune_width
				if i in [7,9]:offset=b.settings.beach.beach_width+420
				if i==15:offset=-200
				var q:Vector2=p+n*offset
				for k in range(20):
					var f:Vector3=b._coast.coast_frame(q);q-=Vector2(f.y,f.z)*clampf((f.x-offset)*.25,-200,200)
				var f:Vector3=b._coast.coast_frame(q)
				if absf(f.x-offset)>40:continue
				var h:float=b._get_height(q.x,q.y);var s:PackedFloat64Array=b._coast.state
				if i in [2,3,4,5,13] and h<10:continue
				if i in [12,14] and h<3:continue
				if i==9 and h>0:continue
				if i==14:
					if s[19]<.25 or s[19]>.8:continue
				elif s[19]<.9:continue
				features[names[i]]={"x":q.x,"z":q.y,"height":h,"outward_x":-f.y,"outward_z":-f.z,"score":weights[i],"coast_distance":s[6],"sand":s[19],"region":int(round(s[20]*15))}
	assert(features.size()==16)
	for name:String in features:assert(features[name].score>.5 and (features[name].sand>.9 if name!="mixed_rock_sand" else features[name].sand>.25 and features[name].sand<.8),"No representative sandy region: "+name)
	for kind:String in ["grass","forest","jungle","savanna","swamp","mountain"]:
		features[kind+"_beach_transition"]=features.high_foredunes.duplicate(true)
	FileAccess.open("res://data/beach_previews.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":73921,"features":features,"source":"Actual canonical shoreline and regional sampler; previews override only sand/coast coverage and inland biome, never sculpt heights."},"\t"))
	print("BEACH_PREVIEWS ",features.size());quit()
