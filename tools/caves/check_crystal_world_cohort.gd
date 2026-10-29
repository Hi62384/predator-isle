extends "res://tools/caves/check_frozen_world_cohort.gd"
const Crystal=preload("res://scripts/caves/crystal_features.gd")
const SITES_CRYSTAL=[Vector2i(6,-2),Vector2i(8,-4),Vector2i(9,-3),Vector2i(16,3),Vector2i(-56,-54),Vector2i(-31,-31)]
const HOSTS_CRYSTAL=["crystal_wastes","quarry","mountain","wise_mountains","badlands","volcanic","radiation_wasteland"]
func run()->void:
	var guards:Dictionary=FrozenFixture.guards()
	for folder:String in ["res://scripts/caves","res://shaders"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd") or name.ends_with(".gdshader") or name.ends_with(".gdshaderinc"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://tools/caves/check_frozen_world_cohort.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://config/caves/cave_biome_regions.tres","res://config/world/terrain_settings.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));check(config.validation_errors().is_empty(),"Private normal18percent/350–1500m Crystal with unchanged actual depth/surface affinities and.85regional activity")
	var results:Array=[];var first_crystal:Dictionary={};var first_wet:Dictionary={};var actual:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var records:Array=[];var first:Dictionary={}
		for host:String in HOSTS_CRYSTAL:
			for seed_id:int in [73921,17,92881]:
				var b=owner(host,seed_id);var work=Workload.new();var configured:bool=work.configure(b.settings,config,seed_id,0)
				for site:Vector2i in SITES_CRYSTAL:
					var start:int=Time.get_ticks_usec();var region:Dictionary=work.network.region(site);var selected:Array=[];var waters:Array=[]
					for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
						if candidate.biome_id=="crystal":selected.append({"id":candidate.id,"anchor":candidate.anchor,"point":candidate.point,"extent_m":candidate.extent_m,"depth_m":candidate.depth_m,"depth_preference":candidate.depth_preference,"surface_preference":candidate.surface_preference})
					for pool:Dictionary in region.get("pools",[]):
						var parent:String=str(pool.id).trim_suffix(":seepage");var weight:float=float(Regions.along_edge(region.get("cave_biome_regions",{}),parent,parent,0,0).weights.get("crystal",0))
						if weight>=.7:waters.append({"id":pool.id,"center":pool.center,"water_y":pool.water_y,"radius":pool.radius,"weight":weight,"stream":pool.has("stream_points")})
					var record:Dictionary={"host":host,"seed":seed_id,"site":[site.x,site.y],"configured":configured,"valid":region.valid,"nodes":region.get("nodes",[]).size(),"edges":region.get("edges",[]).size(),"geology":region.get("geology",-1),"crystal":selected,"crystal_pools":waters,"single_order_generation_seconds":(Time.get_ticks_usec()-start)/1000000.0};records.append(record)
					if first.is_empty() and not selected.is_empty():
						first=record.duplicate(true);var bundle:Dictionary=work.discover(site);var cells:Array=[];var anchor:Vector3=selected[0].point;var center:Vector3i=work.field.cell(anchor+Vector3.UP*2);var forms:int=0;var vertices:int=0;var batches:int=0;var crystals:int=0;var veins:int=0;var rejections:Dictionary={}
						if not bundle.has("error"):
							for dz in range(-1,2):
								for dy in range(-1,2):
									for dx in range(-1,2):
										var key:Vector3i=center+Vector3i(dx,dy,dz);var payload:Dictionary=Crystal.new().build(work.field,key,seed_id,bundle.regions,load("res://config/caves/biomes/crystal_cave_definition.tres").feature_configuration,{})
										forms+=payload.placements.size();batches+=payload.batches.size()
										for placement:Dictionary in payload.placements:
											if placement.kind=="crystal":crystals+=1
											elif placement.kind=="mineral_vein":veins+=1
										for reason:String in payload.get("rejections",{}):rejections[reason]=int(rejections.get(reason,0))+int(payload.rejections[reason])
										for batch:Dictionary in payload.batches:vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
										cells.append({"key":str(key),"valid":payload.valid,"forms":payload.placements.size()})
						actual.append({"host":host,"seed":seed_id,"site":record.site,"anchor":str(anchor),"bundle_valid":not bundle.has("error"),"regions":bundle.get("regions",[]).size(),"features":work.field.begins.size(),"numeric_bytes":work.field.numeric_bytes(),"forms":forms,"crystals":crystals,"vein_segments":veins,"rejections":rejections,"vertices":vertices,"batches":batches,"cells":cells})
		results.append(records)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var records:Array=results[0] if not results.is_empty() else [];var admitted:int=0;var candidates:int=0;var wet:int=0;var depths:Dictionary={}
	check(records.size()==126,"All predeclared seven real hosts×three seeds×six original sites retained,including every negative/rejection")
	for record:Dictionary in records:
		check(record.configured,"Actual normal worker configuration without a new surface owner")
		admitted+=int(record.valid);candidates+=record.crystal.size();wet+=record.crystal_pools.size()
		for candidate:Dictionary in record.crystal:
			check(candidate.extent_m>=350 and candidate.extent_m<=1500 and candidate.depth_preference>0 and candidate.surface_preference>0,"Actual independent candidate retains normal physical extent/depth/owner suitability")
			depths[str(int(candidate.depth_m/100))]=true
		if first_crystal.is_empty() and not record.crystal.is_empty():first_crystal=record.duplicate(true)
		if first_wet.is_empty() and not record.crystal_pools.is_empty():first_wet=record.duplicate(true)
	check(admitted>0 and candidates>0 and actual.size()==1 and actual[0].bundle_valid and actual[0].crystals>0 and actual[0].vertices>0,"First normal-settings Crystal positive has actual physical crystal geometry in original3x3 worker,not only veins/candidate metadata")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable Crystal normal-world cohort source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_world_cohort.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"admitted":admitted,"crystal_candidates":candidates,"crystal_pools":wet,"depth_hundred_metre_bins":depths.keys(),"first_crystal_in_declared_order":first_crystal,"first_wet_in_declared_order":first_wet,"actual_first_positive_worker":actual,"scope":"Private requested Crystal definition appended to saved Default+Frozen without forced probability,size,depth,surface,density or regional activity. All126original host/seed/site records including negatives. First positive selected BEFORE actual physical worker inspection,complete27cell neighborhood retained. Not world-volume distribution,rendered normal cave art,native full live return,FPS or complete Crystal/all-user acceptance. Desert remains dormant and Rocky Coast is an overlay,not either a new owner."},"  "));print("CRYSTAL_WORLD_COHORT ",checks," admitted=",admitted," candidates=",candidates," wet=",wet," first=",first_crystal.get("host",""),"/",first_crystal.get("seed",0),"/",first_crystal.get("site",[])," forms=",actual[0].forms if not actual.is_empty() else 0," failures=",failures);quit(0 if failures.is_empty() else 1)
