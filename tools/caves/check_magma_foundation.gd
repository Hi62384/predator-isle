extends "res://tools/caves/check_frozen_world_cohort.gd"
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/magma_cave_definition.tres","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres");check(definition.validation_errors().is_empty() and definition.minimum_extent_metres==300 and definition.maximum_extent_metres==1100,"Requested editable normal Magma definition valid")
	var admitted:int=0;var expected:float=.22*.8;var low:float=INF;var high:float=0
	for index in range(100000):
		var id:String="magma-independent-product/"+str(index);var proposal:Dictionary=Regions.proposal(definition,id,73921);admitted+=int(proposal.accepted and Regions.suitability_admitted(definition,id,73921,.8));low=minf(low,proposal.extent_m);high=maxf(high,proposal.extent_m)
	check(absf(float(admitted)/100000-expected)<.004 and low>=300 and high<=1100,"Independent22percent*80percent suitability product and physical extent bounds,not world coverage")
	var private_definition:Resource=definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);private_definition.spawn_chance_percent=2.0;private_definition.minimum_extent_metres=1000;private_definition.maximum_extent_metres=2000;var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,private_definition);check(config.validation_errors().is_empty() and config.biome_regions.discovery_halo()==2,"Private rare2percent/1000–2000m uses existing bounded5x5 discovery")
	var b=owner("volcanic",73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Rare control configures same worker")
	var output:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:output.append(work.discover(Vector2i(6,-2))))
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var bundle:Dictionary=output[0];check(not bundle.has("error") and bundle.regions.size()==25 and work.network._regions.size()<=32,"Actual rare large region compiles all25 canonical neighbours within32region cache")
	check(work.field.numeric_bytes()<32*1024*1024 and work.field.thermal_sources.size()<=2048,"Compiled rare field and localized sources remain bounded numeric data")
	var reload:Resource=ResourceLoader.load("res://config/caves/biomes/magma_cave_definition.tres","",ResourceLoader.CACHE_MODE_IGNORE);check(reload.spawn_chance_percent==22 and reload.minimum_extent_metres==300 and reload.maximum_extent_metres==1100,"Original normal controls restored/unchanged after independent rare test")
	for mode:String in ["chance_nan","extent_reversed","density_nan","active_pool_invalid","intrusion_type"]:
		var invalid:Resource=definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		match mode:
			"chance_nan":invalid.spawn_chance_percent=NAN
			"extent_reversed":invalid.minimum_extent_metres=1200;invalid.maximum_extent_metres=1100
			"density_nan":invalid.feature_configuration.density=NAN
			"active_pool_invalid":invalid.feature_configuration.active_pool_chance=1.1
			"intrusion_type":invalid.feature_configuration.geological_intrusions="not_boolean"
		check(not invalid.validation_errors().is_empty(),"Malformed Magma control rejected "+mode)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable foundation source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_foundation.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"admitted":admitted,"trials":100000,"expected_probability":expected,"extent_minimum":low,"extent_maximum":high,"rare_regions":bundle.regions.size(),"numeric_bytes":work.field.numeric_bytes(),"thermal_sources":work.field.thermal_sources.size(),"scope":"Normal independent product admission and extents;private rare2percent1000–2000m full25region compiled field on existing worker/cache;normal controls unchanged;nonfinite/malformed switches rejected. Not native render/full Magma traversal/art/FPS certification."},"  "));print("MAGMA_FOUNDATION ",checks," admitted=",admitted," numeric_bytes=",work.field.numeric_bytes()," failures=",failures);quit(0 if failures.is_empty() else 1)
