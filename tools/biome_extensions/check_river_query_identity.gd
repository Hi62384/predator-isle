extends SceneTree
var failures:Array=[]
var checks:int=0
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func builder(seed_id:int):
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.world_seed=seed_id;b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.grass_river_frequency=.05;b._configure_noise();return b
func _initialize()->void:call_deferred("run")
func run()->void:
	var sources:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_river_query_identity.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/badlands_sampler.gd","res://scripts/mountain_sampler.gd","res://scripts/tropical_sampler.gd","res://scripts/terrain_settings.gd"]:sources[path]=FileAccess.get_sha256(path)
	var records:Array=[];var aliases:int=0;var maximum_error:float=0
	for seed_id:int in [73921,17,92881]:
		var reference=builder(seed_id);var field=preload("res://scripts/badlands_sampler.gd").new();field.configure(reference.settings.badlands,seed_id,reference)
		var requests:Array=[]
		# Both are actual simultaneous caller regimes in THIS valid world:
		# Grass/Tropical/Badlands clamp frequency at.01; Mountain clamps at.1.
		var grass_spacing:float=4000/maxf(reference.settings.grass_river_frequency,.01)
		var mountain_spacing:float=4000/maxf(reference.settings.grass_river_frequency,.1)
		for lane:int in [-30,-3,5]:
			for index:int in [-30,-8,19]:
				var x:float=(index+.25+field.random(index,lane,42)*.5)*reference.settings.badlands.drainage_spacing
				var rounded:float=Vector2(x,0).x
				verify(x!=rounded and Vector2(x,lane)==Vector2(rounded,lane),"Real tree double-X collision witness")
				for spacing:float in [grass_spacing,mountain_spacing]:requests.append([x,lane,spacing]);requests.append([rounded,lane,spacing])
		var expected:Array=[]
		for query:Array in requests:
			reference._river_cache.clear();reference._river_columns.clear()
			var center:float=reference._grass_river_center(query[0],query[1],query[2])
			reference._river_cache.clear();reference._river_columns.clear()
			expected.append([center,reference._river_column(query[0],query[1],query[2])])
		for reverse:bool in [false,true]:
			var cached=builder(seed_id);var order:Array=range(requests.size())
			if reverse:order.reverse()
			var changed:int=0;var changed_columns:int=0
			for index:int in order:
				var query:Array=requests[index];var center:float=cached._grass_river_center(query[0],query[1],query[2]);var column:Vector3=cached._river_column(query[0],query[1],query[2])
				var error:float=absf(center-expected[index][0]);maximum_error=maxf(maximum_error,error)
				if error!=0:changed+=1
				if column!=expected[index][1]:changed_columns+=1
				verify(center==expected[index][0],"Cached center equals exact uncached function "+str([seed_id,reverse,index]))
				verify(column==expected[index][1],"Cached column equals exact uncached function "+str([seed_id,reverse,index]))
			records.append({"seed":seed_id,"reverse":reverse,"queries":requests.size(),"changed_centers":changed,"changed_columns":changed_columns})
		# Negative: reproduce the previous key alone using valid uncached values.
		var legacy:Dictionary={};var negative_count:int=0
		for index in range(requests.size()):
			var query:Array=requests[index];var key:=Vector2(query[0],query[1])
			if legacy.has(key) and legacy[key]!=expected[index][0]:negative_count+=1
			else:legacy[key]=expected[index][0]
		verify(negative_count>0,"Old float32/spacing-omitting key must be detected");aliases+=negative_count
		# Separately exercise the Mountain accessor's fractional-X admission.
		var mountain=preload("res://scripts/mountain_sampler.gd").new();mountain.configure(reference.settings.mountain,seed_id,reference)
		var mountain_requests:Array=[[1000.1,-3],[1000.4,-3],[-104857.1,5],[-104857.4,5]];var mountain_expected:Array=[]
		for query:Array in mountain_requests:
			mountain._carriers.clear();reference._river_cache.clear();mountain_expected.append(mountain._carrier(query[0],query[1]))
		mountain._carriers.clear();reference._river_cache.clear()
		var mountain_changed:int=0
		for index in range(mountain_requests.size()):
			var query:Array=mountain_requests[index];var actual:Vector3=mountain._carrier(query[0],query[1])
			if actual!=mountain_expected[index]:mountain_changed+=1
			verify(actual==mountain_expected[index],"Mountain fractional accessor remains the actual continuous function")
		records.append({"seed":seed_id,"mountain_fractional_queries":4,"mountain_changed":mountain_changed})
		# Existing capacities remain fixed after heavy cache fill.
		for index in range(4207):reference._river_column(index,-3,4000)
		verify(reference._river_cache.size()<=4096 and reference._river_columns.size()<=2048,"Original cache capacities retained")
		reference._configure_noise();verify(reference._river_cache.is_empty() and reference._river_columns.is_empty(),"Reconfiguration reclaims query caches")
	for path:String in sources:verify(FileAccess.get_sha256(path)==sources[path],"Stable query-identity source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_river_query_identity.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"assertions":checks,"source_sha256":sources,"cases":records,"maximum_center_error_metres":maximum_error,"legacy_key_negative_collisions":aliases,"scope":"Actual shared river center/column accessors versus their own uncached function,forward/reverse orders,three seeds,actual tree double-X/float32 aliases and two valid spacing regimes. Separate Mountain fractional-X probes,capacity/reconfigure checks,and an explicit old-key negative. No new formula,geometry or production fix inferred from the diagnostic."},"  "))
	print("RIVER_QUERY_IDENTITY ",checks," checks / maxerror=",maximum_error," / failures=",failures.size());quit(0 if failures.is_empty() else 1)
