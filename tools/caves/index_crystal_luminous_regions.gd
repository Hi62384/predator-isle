extends "res://tools/caves/check_crystal_world_cohort.gd"
const Scope=preload("res://tools/caves/inspection_scope.gd")
func seed_records(seed_id:int,definition:Resource,config:Resource)->Array:
	var records:Array=[];var workers:Dictionary={};var hosts:Array=["crystal_wastes","quarry","mountain","wise_mountains"]
	for site_index in range(SITES_CRYSTAL.size()):
		var site:Vector2i=SITES_CRYSTAL[site_index];var possible:Dictionary={};var admitted:Dictionary={}
		for level in range(4):
			for corner in range(4):
				var main_id:String="%d:%d:%d:%d"%[site.x,site.y,level,corner]
				for anchor:String in [main_id,main_id+":lobe:0",main_id+":lobe:1"]:
					possible[anchor]=true
					if Regions.proposal(definition,anchor,seed_id).accepted and Regions.random(anchor+"/crystal",seed_id,"crystal/fictional_region")<float(definition.feature_configuration.luminous_region_chance):admitted[anchor+"/crystal"]=true
		for host_index in range(hosts.size()):
			var host:String=hosts[host_index];var row:Dictionary={"ordinal":(seed_id*6+site_index)*4+host_index,"host":host,"seed":seed_id,"site":[site.x,site.y],"necessary_channel_candidates":admitted.keys(),"generated":not admitted.is_empty(),"gates":{},"descriptors":[]}
			if admitted.is_empty():row["rejection"]="All48possible original main/lobe anchors fail necessary normal spawn or rare channel;terrain generation cannot turn these into luminous anchors";records.append(row);continue
			if not workers.has(host):
				var b=owner(host,seed_id);var work=Workload.new();var configured:bool=work.configure(b.settings,config,seed_id,0);workers[host]={"work":work,"configured":configured}
			var work=workers[host].work;var region:Dictionary=work.network.region(site);row.gates["configured"]=workers[host].configured;var enumerated:bool=true
			for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
				if str(candidate.biome_id)=="crystal" and not possible.has(str(candidate.anchor)):enumerated=false
			row.gates["necessary_anchor_superset_verified"]=enumerated;row["valid"]=region.get("valid",false);var rooms:Array=region.get("nodes",[])+region.get("pockets",[]);var by_id:Dictionary={}
			for room:Dictionary in rooms:by_id[str(room.id)]=room
			for room_index in range(rooms.size()):
				var room:Dictionary=rooms[room_index]
				if int(room.get("level",-1))<0:continue
				var coverage:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(room.id),str(room.id),0,0);var theme:String=str(coverage.candidate_ids.get("crystal",""))
				if float(coverage.weights.get("crystal",0))<.8 or not admitted.has(theme):continue
				var parent_id:String=str(room.get("parent",""))
				if parent_id.is_empty():
					for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
						var other:String=str(edge.to) if str(edge.from)==str(room.id) else (str(edge.from) if str(edge.to)==str(room.id) else "")
						if by_id.has(other) and int(by_id[other].get("level",-1))>=0:parent_id=other;break
				if not by_id.has(parent_id):continue
				var depth:float=work.builder._get_height(room.point.x,room.point.z)-room.point.y;var band:int=5
				for level in range(5):
					if depth<config.biome_regions.depth_bands[level+1]:band=level+1;break
				row.descriptors.append({"host":host,"seed":seed_id,"site":[site.x,site.y],"ordinal":row.ordinal,"room_order":room_index,"room_id":room.id,"parent_id":parent_id,"theme":theme,"family":mini(5,int(Regions.random(theme,seed_id,"crystal/mineral")*6)),"depth_m":depth,"depth_level":band,"graph_level":room.level,"point":room.point,"radius_m":room.chamber_radius,"headroom_m":room.chamber_height,"selection_rule":"FIRST full-weight normally rare existing main/pocket descriptor in complete seed0..1023/site/host/room order,before native imagery;all channel/terrain negatives retained."})
			records.append(row)
	return records
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);check(definition.spawn_chance_percent==18 and definition.feature_configuration.luminous_region_chance==.005 and definition.feature_configuration.luminous_form_chance==.12,"Original normal biome and rare-emission probabilities unchanged");var output:Array=[];var tasks:Array[int]=[];var mutex:=Mutex.new()
	for worker in range(2):
		var slot:int=worker;tasks.append(WorkerThreadPool.add_task(func()->void:
			var rows:Array=[]
			for seed_id in range(slot,1024,2):rows.append_array(seed_records(seed_id,definition,config))
			mutex.lock();output.append(rows);mutex.unlock()
		))
	var complete:bool=false
	while not complete:
		complete=true
		for task:int in tasks:complete=complete and WorkerThreadPool.is_task_completed(task)
		if not complete:await process_frame;OS.delay_usec(1000)
	for task:int in tasks:WorkerThreadPool.wait_for_task_completion(task)
	var records:Array=[]
	for rows:Array in output:records.append_array(rows)
	records.sort_custom(func(a,b):return a.ordinal<b.ordinal);var first:Dictionary={};var descriptors:int=0;var generated:int=0;check(records.size()==24576,"ALL predeclared1024seeds×6originalsites×4hosts retained,including exact necessary-channel rejections")
	for index in range(records.size()):
		var row:Dictionary=records[index];check(row.ordinal==index,"Complete original fixed order without substitution");generated+=int(row.generated)
		for gate:String in row.gates:check(row.gates[gate],"Actual generated rare-region check "+gate)
		for descriptor:Dictionary in row.descriptors:
			descriptors+=1
			if first.is_empty():first=descriptor
	check(descriptors>0 and not first.is_empty(),"Actual normally admitted rare mineral domain exists without probability overrides")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Unchanged normal rare-region source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/index_cave_crystal_luminous_regions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"generated_cases":generated,"normal_descriptors":descriptors,"first_candidates":{"rare_luminous":first},"scope":"Normal fixed24576host/seed/site cases. Exact necessary-channel rejection over superset of48initial main/lobe anchors avoids unnecessary terrain construction;all logical negative cases retained and every actual candidate anchor checked against superset. Two pure numeric workers,no probability/size/density/host changes. FIRST normal main/pocket descriptor selected BEFORE native imagery. Not yet positive native emission/geometry/physics/FPS/art acceptance."},"  "));print("NORMAL_LUMINOUS_INDEX ",checks," generated=",generated," descriptors=",descriptors," first=",first," failures=",failures);quit(0 if failures.is_empty() else 1)
