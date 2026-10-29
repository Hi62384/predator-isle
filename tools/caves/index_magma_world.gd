extends "res://tools/caves/check_frozen_world_cohort.gd"
const Scope=preload("res://tools/caves/inspection_scope.gd")
func scan(studies:Array,configuration:Resource,worker:int)->Array:
	var rows:Array=[]
	for ordinal in range(worker,studies.size(),3):
		var study:Dictionary=studies[ordinal];var b=owner(study.host,study.seed);var work=Workload.new();var configured:bool=work.configure(b.settings,configuration,study.seed,0);var site:=Vector2i(study.site[0],study.site[1]);var region:Dictionary=work.network.region(site);var candidates:Array=[];var rooms:Array=[];var pools:Array=[]
		for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
			if candidate.biome_id=="magma":candidates.append(candidate)
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
			var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(room.id),str(room.id),0,0)
			if float(assignment.weights.get("magma",0))>=.7:rooms.append({"room":room,"assignment":assignment})
		for pool:Dictionary in region.get("pools",[]):
			if pool.get("fluid_kind","")=="magma":pools.append(pool)
		rows.append({"ordinal":ordinal,"host":study.host,"seed":study.seed,"site":study.site,"configured":configured,"valid":region.get("valid",false),"candidates":candidates,"rooms":rooms,"molten_pools":pools,"thermal_sources":region.get("cave_thermal_sources",[]),"heat_cache_counts":str(work._magma_heat.cache_counts())})
	return rows
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/magma_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var configuration=Config.new();configuration.biome_regions=FrozenFixture.registry(configuration.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));check(configuration.validation_errors().is_empty(),"Normal requested Magma controls on existing three-biome registry validate")
	var studies:Array=[]
	# All144 cases declared before discovery. No seed/chance/site replacement
	# after success;last18 are fixed neighbours of the two original real sources.
	for host:String in ["volcanic","mountain","wise_mountains","badlands","quarry","radiation_wasteland","desert"]:
		for seed_id:int in [73921,17,92881]:
			for site:Vector2i in SITES:studies.append({"host":host,"seed":seed_id,"site":[site.x,site.y]})
	for center:Vector2i in [Vector2i(157,-64),Vector2i(165,-12)]:
		for z in range(-1,2):
			for x in range(-1,2):studies.append({"host":"volcanic","seed":73921,"site":[center.x+x,center.y+z]})
	var outputs:Array=[[],[],[]];var tasks:Array=[]
	for worker in range(3):
		var target:Array=outputs[worker];var worker_id:int=worker
		tasks.append(WorkerThreadPool.add_task(func()->void:target.append_array(scan(studies,configuration,worker_id))))
	for task:int in tasks:
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task)
	var rows:Array=[]
	for output:Array in outputs:rows.append_array(output)
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.ordinal<b.ordinal)
	var first:Dictionary={};var first_molten:Dictionary={};var count:int=0;var hot:int=0;var molten:int=0
	for row:Dictionary in rows:
		check(row.configured,"Configured original case "+str(row.ordinal));count+=row.candidates.size();hot+=row.thermal_sources.size();molten+=row.molten_pools.size()
		for candidate:Dictionary in row.candidates:check(candidate.extent_m>=300 and candidate.extent_m<=1100 and candidate.depth_preference>0 and candidate.surface_preference>0,"Normal independent candidate physical extent/depth/surface suitability")
		if first.is_empty() and not row.rooms.is_empty():first=row
		if first_molten.is_empty() and not row.molten_pools.is_empty():first_molten=row
	check(rows.size()==144 and not first.is_empty(),"All144 positive and negative cases retained;positive normal cooled Magma room")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable catalogue source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_world_index.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"studies":studies,"rows":rows,"first_cooled":first,"first_molten":first_molten,"candidate_count":count,"thermal_source_count":hot,"molten_pool_count":molten,"scope":"Predeclared144case normal22percent/300–1100m catalogue with all negatives retained;first exact descriptors for subsequent native tests. Last18 fixed near two independently verified retained real sources;not representative global frequencies. No geometry/render/traversal/FPS/art completion claim."},"  "));print("MAGMA_WORLD_INDEX ",checks," candidates=",count," heat=",hot," molten=",molten," first=",first.get("ordinal",-1)," failures=",failures);quit(0 if failures.is_empty() else 1)
