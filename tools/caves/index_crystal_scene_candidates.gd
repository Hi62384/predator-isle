extends "res://tools/caves/check_crystal_world_cohort.gd"
const Scope=preload("res://tools/caves/inspection_scope.gd")
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();Scope.capture_terrain_dependencies(guards)
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			var path:String=folder+"/"+name
			if (name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc")) and Scope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_world_cohort.gd","res://tools/caves/check_frozen_world_cohort.gd","res://tools/caves/inspection_scope.gd"]:guards[path]=FileAccess.get_sha256(path)
	check(Scope.dependency_closure_valid(guards),"Actual terrain/cave dependency closure does not use excluded character shaders")
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var cases:Array=[];var records:Array=[];var first:Dictionary={}
		for host:String in HOSTS_CRYSTAL:
			for seed_id:int in [73921,17,92881]:cases.append({"host":host,"seed":seed_id,"original":true})
		for host:String in ["crystal_wastes","quarry","mountain","wise_mountains"]:
			for seed_id:int in range(1000,1033):cases.append({"host":host,"seed":seed_id,"original":false})
		for study:Dictionary in cases:
			var b=owner(study.host,study.seed);var work=Workload.new();var configured:bool=work.configure(b.settings,config,study.seed,0)
			for site:Vector2i in SITES_CRYSTAL:
				var region:Dictionary=work.network.region(site);var rooms:Array=region.get("nodes",[])+region.get("pockets",[]);var by_id:Dictionary={};var tagged:int=0
				for room:Dictionary in rooms:by_id[str(room.id)]=room
				# Rare mineral selection includes existing MAIN chambers too. Keep
				# the old pocket-only first keys/ordering exact for every other target.
				if not first.has("rare_luminous") and definition.feature_configuration.get("luminous_minerals",false):
					for body:Dictionary in rooms:
						if int(body.get("level",-1))<0:continue
						var coverage:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(body.id),str(body.id),0,0);var theme:String=str(coverage.candidate_ids.get("crystal",""))
						if float(coverage.weights.get("crystal",0))<.8 or theme.is_empty() or Regions.random(theme,study.seed,"crystal/fictional_region")>=float(definition.feature_configuration.get("luminous_region_chance",.005)):continue
						var parent_id:String=str(body.get("parent",""))
						if parent_id.is_empty():
							for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
								var other:String=str(edge.to) if str(edge.from)==str(body.id) else (str(edge.from) if str(edge.to)==str(body.id) else "")
								if by_id.has(other) and int(by_id[other].get("level",-1))>=0:parent_id=other;break
						if not by_id.has(parent_id):continue
						var depth:float=work.builder._get_height(body.point.x,body.point.z)-body.point.y;var band:int=5
						for level:int in range(5):
							if depth<config.biome_regions.depth_bands[level+1]:band=level+1;break
						first["rare_luminous"]={"host":study.host,"seed":study.seed,"site":[site.x,site.y],"original_cohort":study.original,"room_id":body.id,"parent_id":parent_id,"theme":theme,"family":mini(5,int(Regions.random(theme,study.seed,"crystal/mineral")*6)),"layout":int(body.get("crystal_layout",-1)),"profile":str(body.get("crystal_profile","ordinary")),"graph_level":body.level,"depth_level":band,"depth_m":depth,"point":body.point,"radius_m":body.chamber_radius,"headroom_m":body.chamber_height,"selection_rule":"FIRST normal.005luminous theme in original case order and original nodes THEN pockets;actual original incident neighbor selected for main room. No probability override. Descriptor only;native owned emission must still be verified."};break
				for room:Dictionary in region.get("pockets",[]):
					var parent_id:String=str(room.get("parent",""))
					if not by_id.has(parent_id):continue
					var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(room.id),str(room.id),0,0)
					if float(assignment.weights.get("crystal",0))<.8:continue
					var identity:String=str(assignment.candidate_ids.get("crystal",room.id));var family:int=mini(5,int(Regions.random(identity,study.seed,"crystal/mineral")*6));var depth:float=work.builder._get_height(room.point.x,room.point.z)-room.point.y;var profile:String=str(room.get("crystal_profile","ordinary"));var layout:int=int(room.get("crystal_layout",-1));var depth_level:int=5
					for band:int in range(5):
						if depth<config.biome_regions.depth_bands[band+1]:depth_level=band+1;break
					var keys:Array=["family_"+str(family),"host_"+str(study.host),"graph_level_"+str(room.level),"depth_level_"+str(depth_level),"profile_"+profile,"layout_"+str(layout)];var extent:float=0
					for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
						if str(candidate.id)==identity:extent=candidate.extent_m;break
					keys.append("extent_small" if extent<600 else ("extent_medium" if extent<1000 else "extent_large"))
					if extent>=1400:keys.append("extent_near_1500")
					if profile=="geode" and family==1:keys.append("amethyst_geode")
					var selection:Dictionary={"host":study.host,"seed":study.seed,"site":[site.x,site.y],"original_cohort":study.original,"room_id":room.id,"parent_id":parent_id,"theme":identity,"family":family,"layout":layout,"profile":profile,"graph_level":room.level,"depth_level":depth_level,"depth_m":depth,"candidate_extent_m":extent,"point":room.point,"radius_m":room.chamber_radius,"headroom_m":room.chamber_height,"selection_rule":"FIRST descriptor matching this key in complete fixed original126 THEN792-case order,before native images;actual mineral geometry and art remain unverified. Depth levels use actual saved boundaries0/40/100/180/280/400m;graph routing levels are separate."}
					for key:String in keys:
						if not first.has(key):first[key]=selection
					tagged+=1
				records.append({"host":study.host,"seed":study.seed,"site":[site.x,site.y],"original_cohort":study.original,"configured":configured,"valid":region.get("valid",false),"full_weight_crystal_pockets":tagged})
			print("CRYSTAL_SCENE_INDEX_PROGRESS ",study.host," seed=",study.seed," cases=",records.size()," keys=",first.size())
		output.append({"records":records,"first":first})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var result:Dictionary=output[0] if not output.is_empty() else {};check(result.get("records",[]).size()==918,"Every original126 and predeclared792normal case completed;original522prefix retained before Mountain/Wise extension,no stopping after first positive or replacing negatives")
	for record:Dictionary in result.get("records",[]):check(record.configured,"Actual owner and unmodified normal definition configure")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual scene-candidate source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/index_cave_crystal_scene_candidates.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":result.get("records",[]),"first_candidates":result.get("first",{}),"evidence_dependency_scope":Scope.description(),"scope":"Actual normal unchanged18percent/.65density procedural descriptor index,not manually sculpted test scenes. Complete original126plus predeclared792seed1000..1032Crystal/Quarry/Mountain/Wise six-site cases;original522prefix and every negative retained. First per family/host/graph level/actual saved depth band/layout/profile/extent is selected BEFORE native images. A descriptor is NOT positive crystal mesh/native traversal/reference-art evidence;each selected case requires the original numeric/native world pipeline and can fail without rerolling. Not completion of50visual targets/FPS/all-user request."},"  "));print("CRYSTAL_SCENE_INDEX ",checks," keys=",result.get("first",{}).keys()," failures=",failures);quit(0 if failures.is_empty() else 1)
