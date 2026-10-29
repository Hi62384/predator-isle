extends "res://tools/caves/check_crystal_world_cohort.gd"
const Scope=preload("res://tools/caves/inspection_scope.gd")
func scan(studies:Array,configuration:Resource,worker:int)->Dictionary:
	var rows:Array=[];var filter_errors:int=0
	for study_index in range(worker,studies.size(),3):
		var study:Dictionary=studies[study_index];var host:String=study.host;var seed_id:int=study.seed;var b=owner(host,seed_id);var work=Workload.new();var configured:bool=work.configure(b.settings,configuration,seed_id,0);var sites:Array=[Vector2i(6,-2),Vector2i(9,-3),Vector2i(8,-4)]
		for site_index in range(sites.size()):
			var site:Vector2i=sites[site_index];var ordinal:int=study_index*3+site_index;var region:Dictionary=work.network.region(site);var positives:Array=[];var first:Dictionary={};var nodes:Dictionary={};var counts:Dictionary={"crystal":0,"frozen":0};var assignment:Dictionary=region.get("cave_biome_regions",{}).duplicate()
			# Fallback is explicitly recomputed after specialized fields in
			# along_edge. Its redundant candidates cannot change raw weights.
			var specialized:Array=[]
			for candidate:Dictionary in assignment.get("candidates",[]):
				if counts.has(str(candidate.biome_id)):counts[str(candidate.biome_id)]+=1;specialized.append(candidate)
			assignment["candidates"]=specialized
			for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):nodes[str(room.id)]=room
			if counts.crystal>0:
				for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
					if edge.entrance or not nodes.has(str(edge.from)) or not nodes.has(str(edge.to)):continue
					var length_m:float=0
					for index in range(1,edge.points.size()):length_m+=edge.points[index-1].distance_to(edge.points[index])
					if length_m<=0:continue
					for fraction:float in [0.0,.5,1.0]:filter_errors+=int(var_to_bytes(Regions.along_edge(assignment,str(edge.from),str(edge.to),length_m*fraction,length_m).weights)!=var_to_bytes(Regions.along_edge(region.cave_biome_regions,str(edge.from),str(edge.to),length_m*fraction,length_m).weights))
					var minimum:=Vector3(1,1,1);var maximum:=Vector3.ZERO;var overlap:bool=false;var samples:Array=[];var count:int=ceili(length_m/2)
					for station in range(count+1):
						var distance:float=length_m*station/count;var weights:Dictionary=Regions.along_edge(assignment,str(edge.from),str(edge.to),distance,length_m).weights;var values:=Vector3(weights.get("default",0),weights.get("frozen",0),weights.get("crystal",0));minimum=minimum.min(values);maximum=maximum.max(values);overlap=overlap or (values.y>.05 and values.z>.05);samples.append({"distance_m":distance,"weights":values})
					var keys:Array=[]
					if minimum.z<.1 and maximum.z>.9:keys.append("default_crystal")
					if overlap and maximum.y>=.45 and maximum.z>=.45 and (maximum-minimum).length()>.25:keys.append("frozen_crystal")
					for key:String in keys:
						positives.append(key)
						if not first.has(key):first[key]={"host":host,"seed":seed_id,"site":[site.x,site.y],"room_id":edge.to,"parent_id":edge.from,"room":nodes[str(edge.to)],"parent":nodes[str(edge.from)],"edge":edge,"length_m":length_m,"minimum_weights":minimum,"maximum_weights":maximum,"samples":samples,"original_ordinal":ordinal}
			rows.append({"ordinal":ordinal,"host":host,"seed":seed_id,"site":[site.x,site.y],"configured":configured,"valid":region.get("valid",false),"candidate_counts":counts,"transition_edges":positives,"first_transitions":first})
	return {"rows":rows,"filter_errors":filter_errors}
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	var configuration=Config.new();configuration.biome_regions=FrozenFixture.registry(configuration.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var studies:Array=[]
	# Preserve the complete original36case prefix. Predeclare all384 additional
	# cases before discovering a result;normal probabilities remain unchanged.
	for host:String in ["mountain","wise_mountains"]:
		for seed_id:int in [73921,17,92881,1000,1001,1002]:studies.append({"host":host,"seed":seed_id})
	for host:String in ["mountain","wise_mountains"]:
		for seed_id in range(64):studies.append({"host":host,"seed":seed_id})
	var outputs:Array=[[],[],[]];var tasks:Array=[]
	for worker in range(3):
		var target:Array=outputs[worker];var worker_index:int=worker
		tasks.append(WorkerThreadPool.add_task(func()->void:target.append(scan(studies,configuration,worker_index))))
	for task:int in tasks:
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task)
	var rows:Array=[];var filter_errors:int=0;var first:Dictionary={}
	for part:Array in outputs:
		check(part.size()==1,"Every bounded numeric worker completes")
		if not part.is_empty():rows.append_array(part[0].rows);filter_errors+=part[0].filter_errors
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.ordinal)<int(b.ordinal));check(rows.size()==420 and filter_errors==0,"Complete original36plus384case inventory,all negatives retained;optimized weights exact full unfiltered controls")
	for index in range(rows.size()):
		var row:Dictionary=rows[index];check(row.configured and int(row.ordinal)==index,"Actual unchanged normal host/seed controls and every original ordinal retained")
		for key:String in row.first_transitions:
			if not first.has(key):first[key]=row.first_transitions[key]
	for key:String in ["default_crystal","frozen_crystal"]:check(first.has(key),"Positive actual original graph transition "+key+" selected before native images/physics")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual transition inventory source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/index_cave_crystal_transitions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"first_transitions":first,"filter_errors":filter_errors,"maximum_numeric_workers":3,"scope":"All420predeclared actual normal Mountain/Wise cases,original36prefix/all negatives retained,three pure numeric workers,complete original graph-edge raw biome controls sampled every<=2m. Exact unfiltered weight controls at three stations per eligible edge. First descriptor chosen before native imagery/physics;no probability/size/depth/affinity or site override. Not native material/ice/crystal geometry or traversal acceptance yet."},"  "));print("CRYSTAL_TRANSITION_INDEX ",checks," cases=",rows.size()," keys=",first.keys()," filter_errors=",filter_errors," failures=",failures);quit(0 if failures.is_empty() else 1)