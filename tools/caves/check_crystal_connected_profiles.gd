extends "res://tools/biome_extensions/check_all.gd"
const Candidate=preload("res://tools/caves/crystal_connected_profiles_candidate.gd")
const Field=preload("res://scripts/caves/portal_field.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func fixture()->Dictionary:
	var a:Dictionary={"id":"A","point":Vector3(32,20,32),"level":1,"chamber_radius":26.0,"chamber_height":46.0};var b:Dictionary={"id":"B","point":Vector3(-32,20,32),"level":1,"chamber_radius":8.0,"chamber_height":8.0};var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([a.point,b.point]),"half_width":4.0,"headroom":8.0,"entrance":false};var candidate:Dictionary={"id":"A/crystal","biome_id":"crystal","anchor":"A","point":a.point,"reach_m":350.0,"extent_m":700.0,"transition_m":48.0,"distances":{"A":0.0,"B":64.0},"connected_growth":true}
	return {"valid":true,"id":Vector2i.ZERO,"nodes":[a,b],"edges":[edge],"pockets":[],"pocket_passages":[],"cave_biome_regions":{"fallback":"default","candidates":[candidate],"edges":[{"from":"A","to":"B","length":64.0}]}}
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/crystal_connected_profiles_candidate.gd","res://scripts/caves/field.gd","res://scripts/caves/biome_regions.gd","res://scripts/caves/chamber_profiles.gd","res://scripts/caves/seepage_basins.gd","res://scripts/caves/workload.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var low_roof:Callable=func(_x:float,_z:float)->float:return 45.0
	var seed_values:Array=[73921,17,92881]
	for i in range(33):seed_values.append(1000+i)
	var geode_lobes:int=0;var ravine_lobes:int=0;var lake_count:int=0;var records:Array=[]
	for seed_id:int in seed_values:
		for style:String in ["geode","ravine"]:
			var region:Dictionary=fixture();var bytes:PackedByteArray=var_to_bytes(region);var settings:Dictionary={"geode_frequency":1.0 if style=="geode" else 0.0,"ravine_frequency":1.0 if style=="ravine" else 0.0,"large_lake_frequency":0.0};var result:Dictionary=Candidate.decorate(region,height,seed_id,settings,400,10);check(var_to_bytes(region)==bytes,"Private profile never mutates original cached graph "+style);check(var_to_bytes(result)==var_to_bytes(Candidate.decorate(region,height,seed_id,settings,400,10)),"Exact cold candidate repeat with original stable identities "+style);check(var_to_bytes(result)==var_to_bytes(Candidate.decorate(result,height,seed_id,settings,400,10)),"Finalized profile idempotent,no duplicated graph nodes on repeat")
			check(result.pockets.size()>0 and result.pockets.size()<=4,"Positive bounded extra connected lobes,not decorative false hollow texture "+style);var topology:Dictionary=Regions.graph(result);check(not topology.is_empty(),"Every extra room and flat capsule-wide neck is part of valid SAME graph topology")
			var field=Field.new();field.include_surface_air=false;check(field.compile([result],height,[],result.cave_biome_regions),"Actual existing shared field accepts complete private geological profile")
			for room:Dictionary in result.pockets:
				if style=="geode":geode_lobes+=1
				else:ravine_lobes+=1
				check(room.point.y==20 and room.chamber_height>=26 and field.sample(room.point+Vector3.UP*2)<0,"Unequal real geological rooms retain same original floor and sufficient actual air")
				check(result.cave_biome_regions.candidates[0].distances.has(room.id) and field.biome_weights_at(room.point+Vector3.UP*2,["crystal"]).x>.7,"Crystal extends by finite actual connected graph distance into new rooms,not only room metadata")
			for i in range(33):
				var p:=Vector3(32-i*2,20,32);check(field.sample(p-Vector3.UP*.25)==.25 and field.sample(p+Vector3.UP*.25)==-.25,"Original mandatory flat passage floor unchanged by extra joined profile")
			check(var_to_bytes(Candidate.decorate(region,low_roof,seed_id,settings,400,10))==bytes,"Insufficient original roof rejects all extra rooms without rerolling or corrupting original")
			var off:Dictionary={"geode_frequency":0.0,"ravine_frequency":0.0,"large_lake_frequency":0.0};check(var_to_bytes(Candidate.decorate(region,height,seed_id,off,400,10))==bytes,"Independent three-controls-off restores exact original graph")
			records.append({"seed":seed_id,"profile":style,"added_lobes":result.pockets.size(),"numeric_features":field.begins.size(),"numeric_bytes":field.numeric_bytes()})
		var wet:Dictionary=fixture();wet["pools"]=[{"id":"A:seepage","center":Vector3(32,20,50),"radius":5.0,"water_radius":4.0,"water_y":19.6,"bed_y":17.0,"depth":3.0,"bed":{"id":"A:bed","point":Vector3(32,17,50),"level":1,"chamber_radius":4.25,"chamber_height":4.5},"bed_lobes":[]}];var wet_bytes:PackedByteArray=var_to_bytes(wet);var enlarged:Dictionary=Candidate.decorate(wet,height,seed_id,{"geode_frequency":0.0,"ravine_frequency":0.0,"large_lake_frequency":1.0},400,10);check(var_to_bytes(wet)==wet_bytes,"Large basin control does not mutate original cached retained water")
		if enlarged.pools[0].has("crystal_large_lake"):lake_count+=1;check(enlarged.pools[0].radius>=8 and enlarged.pools[0].radius<=12,"Positive actual retained8–12m mineral basin,not a new floating water plane")
	check(geode_lobes>30 and ravine_lobes>30 and lake_count>0,"Same36fixed seeds retain positive geode/ravine and large-water profile breadth")
	# One original normal world and its exact rare user-control case. The saved
	# providers/resources remain untouched;only this private numeric hook wraps
	# the already configured production decorator.
	var output:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		var worlds:Array=[]
		for rare:bool in [false,true]:
			var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			if rare:definition.spawn_chance_percent=2;definition.minimum_extent_metres=1000;definition.maximum_extent_metres=2000
			config.biome_regions=Fixture.registry(config.biome_regions,definition);var b=make_builder(5,73921);var work=Workload.new();var valid:bool=work.configure(b.settings,config,73921,0);var original_decorator:Callable=work._biomes.geometry_provider;var canonical_height:Callable=work.builder._get_height
			work._biomes.geometry_provider=func(region:Dictionary)->Dictionary:return Candidate.decorate(original_decorator.call(region),canonical_height,73921,{},400,10)
			var bundle:Dictionary=work.discover(Vector2i(6,-2));var additions:int=0;var lakes:int=0
			for region:Dictionary in bundle.get("regions",[]):
				for room:Dictionary in region.get("pockets",[]):additions+=int(room.has("crystal_profile"))
				for pool:Dictionary in region.get("pools",[]):lakes+=int(pool.get("crystal_large_lake",false))
			worlds.append({"rare":rare,"configured":valid,"valid":not bundle.has("error"),"regions":bundle.get("regions",[]).size(),"numeric_features":work.field.begins.size(),"numeric_bytes":work.field.numeric_bytes(),"cache_regions":work.network._regions.size(),"additional_profile_lobes":additions,"large_lakes":lakes})
		output.append(worlds)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var worlds:Array=output[0] if not output.is_empty() else [];check(worlds.size()==2,"Both normal and requested rare2percent1000–2000m cases retained")
	for world:Dictionary in worlds:check(world.configured and world.valid and world.numeric_features<=65536 and world.cache_regions<=32 and world.regions==(25 if world.rare else 9),"Actual private whole normal/rare discovery stays within ORIGINAL field/cache/worker bounds")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Production and private candidate stable throughout "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_connected_profiles.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"geode_lobes":geode_lobes,"ravine_lobes":ravine_lobes,"large_basins":lake_count,"cohort":records,"worlds":worlds,"scope":"PRIVATE NOT REGISTERED extra unequal connected geode/ravine lobes,original flat floors/actual graph geodesic,real retained8–12mbasin admission.36fixed seeds,both forced profile controls only for positive mechanism breadth,original roof/off/idempotence/cached input controls. Additional normal and requested rare actual world/halo/numeric bounds. No rendered scenic/native full-profile travel/production adoption or full-user completion claim."},"  "));print("CRYSTAL_CONNECTED_PROFILES ",checks," geodes=",geode_lobes," ravines=",ravine_lobes," lakes=",lake_count," worlds=",worlds," failures=",failures);quit(0 if failures.is_empty() else 1)
