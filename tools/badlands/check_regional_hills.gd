extends SceneTree
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func builder(seed_id:int,strength:float,span:float=256):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=seed_id;b.chunk_size=span
	for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",0)
	b.settings.badlands_coverage=100;b.settings.badlands.rounded_hill_strength=strength;b.settings.beaches_enabled=false;b.settings.rocky_coast_enabled=false;b._configure_noise();return b
func digest(b,arrays:Array,resolution:int)->String:
	var hash_state:=HashingContext.new();hash_state.start(HashingContext.HASH_SHA256)
	for channel in arrays:hash_state.update(var_to_bytes(channel))
	hash_state.update(var_to_bytes(b.built_extension_data));hash_state.update(var_to_bytes(b.build_swamp_water(arrays,resolution)))
	return hash_state.finish().hex_encode()
func _initialize()->void:
	var source:String=FileAccess.get_sha256("res://scripts/badlands_sampler.gd");var records:Array=[];var unchanged:int=0
	for seed_id:int in [73921,17,92881]:
		var enabled=builder(seed_id,.75);var disabled=builder(seed_id,0)
		var site:=Vector2.INF
		for i in range(3000):
			var p:=Vector2(i*7919%180000-90000,i*11939%180000-90000)
			var w:PackedFloat32Array=enabled._badlands.region_weights(p)
			var rounded:float=w[0]+w[2]*.8+w[3]+w[10]*.65+w[11]*.55
			if rounded==0:
				check(enabled._badlands._raw(p)==disabled._badlands._raw(p),"Unrounded raw provinces are exactly unchanged");unchanged+=1
			if not site.is_finite() and w[0]>.99 and enabled._island_mask(p.x,p.y)>.15:
				var original:float=disabled._get_height(p.x,p.y)
				if disabled._badlands.state[7]>.6 and absf(enabled._get_height(p.x,p.y)-original)>10:site=p
			if site.is_finite() and i>=120:break
		check(site.is_finite(),"Actual inland painted upland with meaningful physical hill variation")
		if not site.is_finite():continue
		var maximum_delta:float=0;var heights:Array=[];var original_heights:Array=[]
		for i in range(-16,17):
			var p:Vector2=site+Vector2(i*16,0);var h:float=enabled._get_height(p.x,p.y);var old:float=disabled._get_height(p.x,p.y)
			check(is_finite(h),"Finite rounded-hill profile");maximum_delta=maxf(maximum_delta,absf(h-old));heights.append(h);original_heights.append(old)
		check(maximum_delta>10,"Physical profile differs by more than ten metres, not just material colour")
		# Zero is an exact compatibility mode against the archived analytic
		# sampler, including cap anchors, material controls and retained water.
		for dimensions:Vector2i in [Vector2i(256,64),Vector2i(4096,16)]:
			var current=builder(seed_id,0,dimensions.x);var reference=builder(seed_id,0,dimensions.x)
			reference._badlands=preload("res://tools/badlands/reference_pre_hill_variation_sampler.gd").new();reference._badlands.configure(reference.settings.badlands,seed_id,reference)
			var cell:=Vector2i(floori(site.x/dimensions.x),floori(site.y/dimensions.x))
			check(digest(current,current.build(cell,dimensions.y),dimensions.y)==digest(reference,reference.build(cell,dimensions.y),dimensions.y),"Zero strength preserves complete previous terrain, water and atlas arrays")
		records.append({"seed":seed_id,"position":site,"maximum_physical_change_m":maximum_delta,"sample_spacing_m":16,"enabled_profile":heights,"zero_strength_profile":original_heights})
	check(unchanged>100,"Unrounded provinces actually exercised")
	assert(FileAccess.get_sha256("res://scripts/badlands_sampler.gd")==source,"Source changed during hill comparison")
	var result:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"records":records,"unchanged_raw_samples":unchanged,"sampler_sha256":source,"builder_sha256":FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd"),"baseline_sha256":FileAccess.get_sha256("res://tools/badlands/reference_pre_hill_variation_sampler.gd"),"scope":"Physical painted-upland profiles at three actual inland sites; exact unaffected raw provinces and six full zero-strength terrain/water/atlas comparisons. Not an artistic sign-off."}
	FileAccess.open("res://tools/badlands/artifacts/check_regional_hills.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_REGIONAL_HILLS ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
