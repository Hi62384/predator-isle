extends "res://tools/caves/check_frozen_world_cohort.gd"
func scan(studies:Array,worker:int)->Array:
	var result:Array=[]
	for ordinal in range(worker,studies.size(),3):
		var study:Dictionary=studies[ordinal];var builder=owner(study.host,study.seed);var work=Workload.new();var config=Config.new();var configured:bool=work.configure(builder.settings,config,study.seed,0);var region:Dictionary=work.network.region(Vector2i(study.site[0],study.site[1]));var transitions:Dictionary={};var nodes:Dictionary={};var cold_violations:int=0
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):nodes[str(room.id)]=room
		var assignment:Dictionary=region.get("cave_biome_regions",{})
		for edge:Dictionary in region.get("edges",[])+region.get("pocket_passages",[]):
			if edge.entrance or not nodes.has(str(edge.from)) or not nodes.has(str(edge.to)):continue
			var length_m:float=0
			for i in range(1,edge.points.size()):length_m+=edge.points[i-1].distance_to(edge.points[i])
			var count:int=maxi(1,ceili(length_m/8));var low:float=1;var high:float=0;var overlap:Dictionary={};var samples:Array=[]
			for i in range(count+1):
				var distance:float=length_m*i/count;var weights:Dictionary=Regions.along_edge(assignment,str(edge.from),str(edge.to),distance,length_m).weights;var magma:float=weights.get("magma",0);low=minf(low,magma);high=maxf(high,magma)
				for other:String in ["default","crystal","frozen"]:
					if magma>.05 and float(weights.get(other,0))>.05:overlap[other]=true
				samples.append({"distance_m":distance,"weights":weights})
			if high<.1:continue
			for other:String in overlap:
				var key:String=other+"_magma"
				if not transitions.has(key) and high-low>.1:transitions[key]={"host":study.host,"seed":study.seed,"site":study.site,"room_id":edge.to,"parent_id":edge.from,"room":nodes[str(edge.to)],"parent":nodes[str(edge.from)],"edge":edge,"length_m":length_m,"minimum_magma":low,"maximum_magma":high,"samples":samples,"ordinal":ordinal}
		for heat:Dictionary in region.get("thermal_sources",[]):
			cold_violations+=int(str(heat.get("source_id","")).is_empty())
		result.append({"ordinal":ordinal,"study":study,"configured":configured,"valid":region.get("valid",false),"transitions":transitions,"invalid_thermal_ids":cold_violations})
	return result
func run()->void:
	var studies:Array=[]
	for host:String in ["volcanic","mountain","badlands","quarry","radiation_wasteland","wise_mountains"]:
		for seed_id:int in [73921,17,92881,1000,1001,1002]:
			for site:Vector2i in [Vector2i(6,-2),Vector2i(9,-3),Vector2i(8,-4)]:studies.append({"host":host,"seed":seed_id,"site":[site.x,site.y]})
	var guards:Dictionary=FrozenFixture.guards()
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	FileAccess.open("res://tools/biome_extensions/artifacts/magma_transition_plan.json",FileAccess.WRITE).store_string(JSON.stringify({"studies":studies,"scope":"Predeclared108 normal saved-registry cases;all outcomes retained;no probability override."},"  "))
	var outputs:Array=[[],[],[]];var tasks:Array=[]
	for worker in range(3):
		var target:Array=outputs[worker];var index:int=worker
		tasks.append(WorkerThreadPool.add_task(func()->void:target.append_array(scan(studies,index))))
	for task:int in tasks:
		while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task)
	var rows:Array=[];var first:Dictionary={};var counts:Dictionary={}
	for part:Array in outputs:rows.append_array(part)
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.ordinal<b.ordinal)
	for row:Dictionary in rows:
		check(row.configured and row.invalid_thermal_ids==0,"Actual normal workload configured with identified heat sources "+str(row.ordinal))
		for key:String in row.transitions:
			counts[key]=int(counts.get(key,0))+1
			if not first.has(key):first[key]=row.transitions[key]
	check(rows.size()==108 and first.has("default_magma"),"Complete original108case catalogue with actual Default-Magma join")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable transition runtime "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/index_cave_magma_transitions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"first":first,"counts":counts,"rows":rows,"scope":"Actual normal saved four-biome registry over108predeclared cases,negative outcomes retained. Original graph edge weights every8m;no forced probabilities. Physical/native transition returns separate."},"  "))
	print("MAGMA_TRANSITIONS ",checks," counts=",counts," failures=",failures);quit(0 if failures.is_empty() else 1)
