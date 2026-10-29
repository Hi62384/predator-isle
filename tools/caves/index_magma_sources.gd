extends "res://tools/caves/check_frozen_world_cohort.gd"
const Heat=preload("res://scripts/caves/magma_heat.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
func allow_intrusive_sources()->bool:return false
func source_seed()->int:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("source_seed="):return int(arg.trim_prefix("source_seed="))
	return 73921
func source_report_name()->String:return "check_cave_magma_source_index"+("_"+str(source_seed()) if source_seed()!=73921 else "")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/index_magma_sources.gd","res://tools/caves/check_frozen_world_cohort.gd","res://tools/biome_extensions/check_all.gd","res://tools/caves/inspection_scope.gd","res://config/caves/biomes/magma_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var outputs:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var b=owner("volcanic",source_seed());var heat=Heat.new();heat.geological_intrusions=allow_intrusive_sources();heat.configure(b);var sampler=b._extras[2];var span:float=7200*sampler.settings.feature_scale;var sources:Array=[];var active:int=0
		# Fixed seed and97x97 descriptor grid declared before discovery. Every
		# actual retained source is kept,then every unique3x3 cave neighbour.
		for z in range(-48,49):
			for x in range(-48,49):
				var descriptor:Dictionary=sampler.descriptor(Vector2i(x,z),span)
				if descriptor.chance>=sampler.settings.active_frequency:continue
				active+=1;var source:Dictionary=heat.source_descriptor(b,sampler,descriptor)
				if source.is_empty() and allow_intrusive_sources():source=heat.intrusion_descriptor(b,sampler,descriptor)
				if not source.is_empty():sources.append(source)
		var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));var work=Workload.new();var configured:bool=work.configure(b.settings,config,source_seed(),0);var sites:Dictionary={};var rows:Array=[]
		for source:Dictionary in sources:
			var center:=Vector2i(floori(source.center.x/1536),floori(source.center.y/1536))
			for z in range(-1,2):
				for x in range(-1,2):sites[center+Vector2i(x,z)]=true
		var ordered:Array=sites.keys();ordered.sort_custom(func(a:Vector2i,c:Vector2i)->bool:return a.y<c.y or (a.y==c.y and a.x<c.x))
		for site:Vector2i in ordered:
			var region:Dictionary=work.network.region(site);var molten:Array=[]
			for pool:Dictionary in region.get("pools",[]):
				if pool.get("fluid_kind","")=="magma":molten.append(pool)
			rows.append({"site":[site.x,site.y],"valid":region.get("valid",false),"thermal_sources":region.get("cave_thermal_sources",[]),"molten_pools":molten})
		outputs.append({"sources":sources,"active_hashes":active,"configured":configured,"rows":rows})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(outputs.size()==1 and outputs[0].configured,"Fixed canonical source/cave worker survey completed")
	var result:Dictionary=outputs[0];var hot:int=0;var molten:int=0;var first:Dictionary={}
	for row:Dictionary in result.rows:
		hot+=row.thermal_sources.size();molten+=row.molten_pools.size()
		if first.is_empty() and not row.molten_pools.is_empty():first=row
	check(not result.sources.is_empty(),"Positive actual retained normal sources,not eligibility hashes alone")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual source survey "+path)
	result.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"first_molten":first,"thermal_source_count":hot,"molten_pool_count":molten,"scope":"Fixed73921seed/97x97descriptor grid;all normal active retained surface sources and every unique3x3 cave neighbour retained,including negatives. Normal Magma22percent/source4percent/pool14percent controls unchanged;targeted source inventory is not global prevalence. A zero molten result remains zero,not a fabricated positive."})
	result["includes_explicit_intrusive_bodies"]=allow_intrusive_sources()
	result["seed"]=source_seed()
	if allow_intrusive_sources():result["scope"]="Fixed73921seed/97x97descriptor grid;all eligible normal active volcanic centres with retained-surface OR EXPLICIT modeled intrusive sources and every unique3x3 cave neighbour,all negatives retained. Modeled sources are not reclassified as surface lava;normal22percent/source4percent/pool14percent controls unchanged. Targeted inventory,not global prevalence,rendering/traversal/FPS/art certification."
	result.scope=str(result.scope).replace("Fixed73921seed","Fixed"+str(source_seed())+"seed")
	FileAccess.open("res://tools/biome_extensions/artifacts/"+source_report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("MAGMA_SOURCE_INDEX ",checks," sources=",result.sources.size()," cave_sites=",result.rows.size()," hot=",hot," molten=",molten," first=",first.get("site",[])," failures=",failures);quit(0 if failures.is_empty() else 1)
