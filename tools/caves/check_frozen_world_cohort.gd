extends "res://tools/biome_extensions/check_all.gd"
const FrozenFixture=preload("res://tools/caves/frozen_fixture.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Features=preload("res://scripts/caves/frozen_features.gd")
const SITES=[Vector2i(6,-2),Vector2i(8,-4),Vector2i(9,-3),Vector2i(16,3),Vector2i(-56,-54),Vector2i(-31,-31)]
const HOSTS=["mountain","wise_mountains","forest","grass"]
func owner(host:String,seed_id:int):
	var b=make_builder(1,seed_id)
	if host!="wise_mountains":b.settings.wise_mountains_coverage=0;b.settings.set(host+"_coverage",100);b._configure_noise()
	return b
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/frozen_cave_definition.tres","res://config/caves/cave_biome_regions.tres","res://config/world/terrain_settings.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();config.biome_regions=config.biome_regions.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/frozen_cave_definition.tres"));check(config.validation_errors().is_empty(),"Private normal saved45percent Frozen controls;no forced chance/depth/surface/extent")
	var reports:Array=[];var first_wet:Dictionary={};var admitted:int=0;var frozen:int=0;var wet_frozen:int=0;var result:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var records:Array=[]
		for host:String in HOSTS:
			for seed_id:int in [73921,17,92881]:
				var b=owner(host,seed_id);var work=Workload.new();var configured:bool=work.configure(b.settings,config,seed_id,0)
				for site:Vector2i in SITES:
					var started:int=Time.get_ticks_usec();var region:Dictionary=work.network.region(site);var candidates:Array=region.get("cave_biome_regions",{}).get("candidates",[]);var selected:Array=[];var waters:Array=[]
					for candidate:Dictionary in candidates:
						if candidate.biome_id=="frozen":selected.append({"id":candidate.id,"point":candidate.point,"extent_m":candidate.extent_m,"depth_m":candidate.depth_m,"depth_preference":candidate.depth_preference,"surface_preference":candidate.surface_preference})
					for pool:Dictionary in region.get("pools",[]):
						var parent:String=str(pool.id).trim_suffix(":seepage");var amount:float=float(Regions.along_edge(region.get("cave_biome_regions",{}),parent,parent,0,0).weights.get("frozen",0))
						if amount>=.7:waters.append({"id":pool.id,"center":pool.center,"water_y":pool.water_y,"weight":amount,"stream":pool.has("stream_points")})
					records.append({"host":host,"seed":seed_id,"site":[site.x,site.y],"configured":configured,"valid":region.valid,"nodes":region.get("nodes",[]).size(),"edges":region.get("edges",[]).size(),"geology":region.get("geology",-1),"frozen":selected,"frozen_pools":waters,"single_order_generation_seconds":(Time.get_ticks_usec()-started)/1000000.0})
		result.append(records)
	)
	var started:int=Time.get_ticks_usec()
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task)
	if not result.is_empty():reports=result[0]
	check(reports.size()==72,"All predetermined4hosts×3seeds×6geographic sites retained,including every rejection")
	for record:Dictionary in reports:
		check(record.configured,"Actual worker configured without a new terrain owner")
		if record.valid:admitted+=1
		frozen+=record.frozen.size();wet_frozen+=record.frozen_pools.size()
		for candidate:Dictionary in record.frozen:check(candidate.extent_m>=150 and candidate.extent_m<=700 and candidate.depth_preference>0 and candidate.depth_m<340,"Configured specialized physical extent/local-depth suitability respected")
		if first_wet.is_empty() and not record.frozen_pools.is_empty():first_wet=record.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	check(admitted>0 and frozen>0,"Positive normal-settings geography,not only a controlled full-weight material fixture")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable predetermined cohort source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frozen_world_cohort.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":reports,"admitted":admitted,"frozen_candidates":frozen,"frozen_pools":wet_frozen,"first_wet_in_declared_order":first_wet,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"scope":"Private Frozen appended to existing saved Default registry;normal45percent/150–700m/100,80,40,5,0/surface100,50,25,5,5 controls. Four pure CURRENT owners,three fixed seeds,six original geographic sites each;all invalid/negative records retained. Normal regional activity.85. Snow remains dormant/no surface owner added. Deterministic cohort inspection,not world-volume distribution,isolated performance,rendered art or complete Frozen acceptance."},"  "));print("FROZEN_WORLD_COHORT ",checks," admitted=",admitted," candidates=",frozen," wet=",wet_frozen," first=",first_wet.get("site",[])," failures=",failures);quit(0 if failures.is_empty() else 1)
