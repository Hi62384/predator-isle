extends "res://tools/caves/check_crystal_world_cohort.gd"
const Shallow=preload("res://tools/caves/crystal_shallow_candidate.gd")
const Scope=preload("res://tools/caves/inspection_scope.gd")
func study_records(study:Dictionary,config:Resource,ordinal:int)->Array:
	var b=owner(study.host,int(study.seed));var work=Workload.new();var configured:bool=work.configure(b.settings,config,int(study.seed),0);var records:Array=[]
	for site_index in range(SITES_CRYSTAL.size()):
		var site:Vector2i=SITES_CRYSTAL[site_index];var region:Dictionary=work.network.region(site);var before:PackedByteArray=var_to_bytes(region);var proposal:Dictionary=Shallow.prepare(region,work.builder._get_height);var added:int=proposal.get("pockets",[]).size()-region.get("pockets",[]).size();var gates:Dictionary={"configured":configured,"input_and_off_exact":added in [0,1] and var_to_bytes(region)==before and var_to_bytes(Shallow.prepare(region,work.builder._get_height,false))==before};var record:Dictionary={"ordinal":ordinal*6+site_index,"host":study.host,"seed":study.seed,"site":[site.x,site.y],"valid":region.get("valid",false),"added":added,"gates":gates}
		if added==1:
			var room:Dictionary=proposal.pockets[-1];var coverage:Dictionary=Regions.along_edge(proposal.cave_biome_regions,str(room.id),str(room.id),0,0);var depth:float=work.builder._get_height(room.point.x,room.point.z)-room.point.y;gates["real_level_one_normal_coverage"]=depth>=24 and depth<40 and float(coverage.weights.get("crystal",0))>=.8;gates["old_main_nodes_and_routes_exact"]=var_to_bytes(proposal.nodes)==var_to_bytes(region.nodes) and var_to_bytes(proposal.edges)==var_to_bytes(region.edges);var anchors:bool=true;var distances:bool=true
			for index in range(region.cave_biome_regions.candidates.size()):
				var old:Dictionary=region.cave_biome_regions.candidates[index];var fresh:Dictionary=proposal.cave_biome_regions.candidates[index];anchors=anchors and old.id==fresh.id and old.anchor==fresh.anchor and old.extent_m==fresh.extent_m
				for id:String in old.distances:distances=distances and fresh.distances[id]==old.distances[id]
			gates["original_anchors_and_extents"]=anchors;gates["old_graph_distances_exact"]=distances;record["room"]=room;record["passage"]=proposal.pocket_passages[-1];record["depth_m"]=depth;record["theme"]=coverage.candidate_ids.get("crystal","")
		records.append(record)
	return records
func run()->void:
	var batch:int=-1
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("batch="):batch=int(arg.trim_prefix("batch="))
	check(batch>=0 and batch<9,"Explicit fixed batch0..8 required;all nine aggregate to original2070cases")
	if not failures.is_empty():quit(1);return
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/crystal_shallow_candidate.gd","res://tools/caves/shallow_chamber_candidate.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var cases:Array=[]
	for host:String in HOSTS_CRYSTAL:
		for seed_id:int in [73921,17,92881]:cases.append({"host":host,"seed":seed_id})
	for host:String in ["crystal_wastes","quarry","mountain","wise_mountains"]:
		for seed_id:int in range(1000,1033):cases.append({"host":host,"seed":seed_id})
	for host:String in ["crystal_wastes","quarry"]:
		for seed_id:int in range(1033,1129):cases.append({"host":host,"seed":seed_id})
	check(cases.size()==345,"Unchanged2070case configuration inventory");var start:int=batch*39;var end:int=mini(cases.size(),start+39);var tasks:Array[int]=[];var output:Array=[];var mutex:=Mutex.new()
	for worker in range(3):
		var slot:int=worker;tasks.append(WorkerThreadPool.add_task(func()->void:
			var rows:Array=[]
			for ordinal in range(start+slot,end,3):rows.append_array(study_records(cases[ordinal],config,ordinal));print("CRYSTAL_SHALLOW_BATCH_PROGRESS batch=",batch," config=",ordinal," host=",cases[ordinal].host," seed=",cases[ordinal].seed)
			mutex.lock();output.append(rows);mutex.unlock()
		))
	var finished:bool=false
	while not finished:
		finished=true
		for task:int in tasks:finished=finished and WorkerThreadPool.is_task_completed(task)
		if not finished:await process_frame;OS.delay_usec(1000)
	for task:int in tasks:WorkerThreadPool.wait_for_task_completion(task)
	var records:Array=[];var first:Dictionary={};var positives:int=0
	for rows:Array in output:records.append_array(rows)
	records.sort_custom(func(a,b):return a.ordinal<b.ordinal)
	check(records.size()==(end-start)*6,"Every predeclared batch case completed;negative cases retained")
	for index in range(records.size()):
		var record:Dictionary=records[index];check(record.ordinal==start*6+index,"Exact original2070case ordinal without missing/replaced cases")
		for gate:String in record.gates:check(record.gates[gate],"Actual shallow survey "+gate+" case="+str(record.ordinal))
		if record.added==1:
			positives+=1
			if first.is_empty():first=record.duplicate(true)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable private shallow Crystal survey "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_shallow_batch_"+str(batch)+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"batch":batch,"first_ordinal":start*6,"last_ordinal_exclusive":end*6,"maximum_survey_workers":3,"records":records,"positives":positives,"first_positive":first,"scope":"PRIVATE fixed batch of unchanged2070normal actual cases;all9batches required for aggregate acceptance. Original918prefix/all negatives retained. Three pure numeric workers,not additional terrain/cave streaming jobs. No new lottery/anchor/size/depth weights;existing Crystal reach must cover24–40m branch. Zero-positive batches are retained as negatives,not proof of positive mechanism. Not native/adoption/FPS/art acceptance."},"  "));print("CRYSTAL_SHALLOW_BATCH ",batch," checks=",checks," positives=",positives," failures=",failures);quit(0 if failures.is_empty() else 1)
