extends "res://tools/caves/check_crystal_world_cohort.gd"
const InspectionScope=preload("res://tools/caves/inspection_scope.gd")
## Same original126 normal-world cases in their original order. Keep every
## negative;select FIRST profile positives before any native scenic inspection.
func run()->void:
	var guards:Dictionary=FrozenFixture.guards();var unrelated_before:Dictionary=InspectionScope.observations();guards["res://tools/caves/inspection_scope.gd"]=FileAccess.get_sha256("res://tools/caves/inspection_scope.gd")
	InspectionScope.capture_terrain_dependencies(guards)
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):
				var path:String=folder+"/"+name
				if InspectionScope.is_dependency(path):guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_world_cohort.gd","res://tools/caves/check_frozen_world_cohort.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://config/world/terrain_settings.tres"]:guards[path]=FileAccess.get_sha256(path)
	check(InspectionScope.dependency_closure_valid(guards),"No excluded character shader is a cave/terrain dependency")
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);check(config.validation_errors().is_empty(),"Original normal Crystal controls and new finite profile controls validate")
	var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var records:Array=[];var first:Dictionary={};var workers:Array=[]
		for host:String in HOSTS_CRYSTAL:
			for seed_id:int in [73921,17,92881]:
				var b=owner(host,seed_id);var work=Workload.new();var configured:bool=work.configure(b.settings,config,seed_id,0)
				for site:Vector2i in SITES_CRYSTAL:
					var region:Dictionary=work.network.region(site);var rooms:Array=[];var pools:Array=[];var candidates:Array=[]
					for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
						if candidate.biome_id=="crystal":candidates.append({"id":candidate.id,"anchor":candidate.anchor,"extent_m":candidate.extent_m,"depth_m":candidate.depth_m})
					for room:Dictionary in region.get("pockets",[]):
						if room.has("crystal_profile"):rooms.append(room)
					for pool:Dictionary in region.get("pools",[]):
						if pool.get("crystal_large_lake",false):pools.append(pool)
					var record:Dictionary={"host":host,"seed":seed_id,"site":[site.x,site.y],"configured":configured,"valid":region.valid,"candidates":candidates,"new_rooms":rooms,"large_basins":pools};records.append(record)
					for room:Dictionary in rooms:
						var style:String=room.crystal_profile
						if first.has(style):continue
						var selected:Dictionary={"host":host,"seed":seed_id,"site":[site.x,site.y],"room":room,"canonical_depth_m":b._get_height(room.point.x,room.point.z)-room.point.y};first[style]=selected
						var bundle:Dictionary=work.discover(site);var forms:int=0;var vertices:int=0;var cells:Array=[];var center:Vector3i=work.field.cell(room.point+Vector3.UP*2)
						if not bundle.has("error"):
							for dz in range(-1,2):
								for dy in range(-1,2):
									for dx in range(-1,2):
										var key:Vector3i=center+Vector3i(dx,dy,dz);var data:Dictionary=Crystal.new().build(work.field,key,seed_id,bundle.regions,definition.feature_configuration,{});var crystals:int=0
										for placement:Dictionary in data.placements:crystals+=int(placement.kind=="crystal")
										forms+=crystals
										for batch:Dictionary in data.batches:vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
										cells.append({"key":str(key),"valid":data.valid,"crystals":crystals})
						workers.append({"profile":style,"selection":selected,"valid":not bundle.has("error"),"features":work.field.begins.size(),"numeric_bytes":work.field.numeric_bytes(),"cache_regions":work.network._regions.size(),"crystals":forms,"vertices":vertices,"cells":cells})
					for pool:Dictionary in pools:
						if not first.has("large_basin"):first["large_basin"]={"host":host,"seed":seed_id,"site":[site.x,site.y],"pool":pool}
		output.append({"records":records,"first":first,"workers":workers})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1,"Complete original ordered occurrence cohort returned")
	if output.is_empty():quit(1);return
	var result:Dictionary=output[0];var admitted:int=0;var candidates:int=0;var profiles:Dictionary={"geode":0,"ravine":0};var basins:int=0
	check(result.records.size()==126,"All seven hosts/three seeds/six original sites,including every negative retained")
	for record:Dictionary in result.records:
		check(record.configured,"Original host worker configuration accepted");admitted+=int(record.valid);candidates+=record.candidates.size();basins+=record.large_basins.size();check(record.new_rooms.size()<=4,"Original per-region connected-profile cap never exceeded")
		for room:Dictionary in record.new_rooms:profiles[room.crystal_profile]+=1
	check(admitted==52 and candidates==40,"New geological profiles preserve original52admitted regions and40Crystal candidate admissions exactly")
	check(profiles.geode>0 and profiles.ravine>0 and result.workers.size()==2,"Actual unchanged normal cohort contains both connected geode and ravine profiles")
	for work:Dictionary in result.workers:
		check(work.valid and work.features<=65536 and work.cache_regions<=32 and work.crystals>0 and work.vertices>0,"FIRST normal profile has actual measured mineral geometry within original numeric/cache limits")
		for cell:Dictionary in work.cells:check(cell.valid,"Every27cell first-positive mineral worker payload remains valid")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable production occurrence source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_profile_occurrence.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":result.records,"first_positive_in_original_order":result.first,"first_positive_workers":result.workers,"admitted":admitted,"crystal_candidates":candidates,"profile_lobes":profiles,"large_basins":basins,"evidence_dependency_scope":InspectionScope.description(),"unrelated_character_shader_observations":{"before":unrelated_before,"after":InspectionScope.observations()},"scope":"All126original normal host/seed/sites with every negative retained,not a new selected/rerolled cohort. Actual production geode/ravine/large-lake normal controls and first selected profile27cell mineral geometry. A zero normal large-basin count remains explicit,not disguised by forced mechanism controls. No native traversal/scenic/FPS/registry/all-user completion claim."},"  "));print("CRYSTAL_PROFILE_OCCURRENCE ",checks," regions=",admitted," candidates=",candidates," profiles=",profiles," basins=",basins," first=",result.first," failures=",failures);quit(0 if failures.is_empty() else 1)
