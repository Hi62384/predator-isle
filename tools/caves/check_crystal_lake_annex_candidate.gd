extends "res://tools/caves/check_crystal_world_cohort.gd"
const Candidate=preload("res://tools/caves/crystal_lake_annex_candidate.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/crystal_lake_annex_candidate.gd","res://tools/caves/check_crystal_world_cohort.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var records:Array=[];var cases:Array=[]
		for host:String in HOSTS_CRYSTAL:
			for seed_id:int in [73921,17,92881]:
				cases.append({"host":host,"seed":seed_id,"original":true})
		# Predeclared extension,not repeated sampling until a desirable result.
		# Every case runs and every negative is retained after any first positive.
		for host:String in ["crystal_wastes","quarry"]:
			for seed_id:int in range(1000,1033):cases.append({"host":host,"seed":seed_id,"original":false})
		for study:Dictionary in cases:
			var b=owner(study.host,study.seed);var work=Workload.new();work.configure(b.settings,config,study.seed,0)
			for site:Vector2i in SITES_CRYSTAL:
				var region:Dictionary=work.network.region(site);var original:PackedByteArray=var_to_bytes(region);var statistics:Dictionary={};var candidate:Dictionary=Candidate.prepare(region,work.builder._get_height,study.seed,definition.feature_configuration,400,10,statistics);var positives:Array=[]
				for pool:Dictionary in candidate.get("pools",[]):
					if pool.get("crystal_large_lake",false):positives.append({"id":pool.id,"radius_m":pool.radius,"water_y":pool.water_y,"center":pool.center})
				records.append({"host":study.host,"seed":study.seed,"original_cohort":study.original,"site":str(site),"valid":region.get("valid",false),"input_unchanged":original==var_to_bytes(region),"changed":original!=var_to_bytes(candidate),"large_basins":positives,"statistics":statistics,"pockets":candidate.get("pockets",[]).size()})
		output.append(records)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var records:Array=output[0] if not output.is_empty() else [];check(records.size()==522,"Original complete ordered126normal cases followed by396predeclared Crystal/Quarry cases including all negatives retained");var positives:int=0
	for record:Dictionary in records:check(record.input_unchanged and record.pockets<=24,"Private candidate leaves cached original unmodified and retains hard pocket bound");positives+=record.large_basins.size()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private lake-annex source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_lake_annex_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"large_basins":positives,"records":records,"scope":"Private same-volume geological lake-annex feasibility across original126normal cases THEN396predeclared Crystal/Quarry cases(1000..1032,seeds fixed before run),unchanged chance and six sites. Every case runs even after first positive. Original0remains0if none. Input immutability and bounds,existing whole dry-bank predicate. Not production adoption/native traversal/render/FPS/all-user completion."},"  "));print("CRYSTAL_LAKE_ANNEX ",checks," large_basins=",positives," failures=",failures);quit(0 if failures.is_empty() else 1)
