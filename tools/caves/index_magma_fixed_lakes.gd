extends "res://tools/caves/check_frozen_world_cohort.gd"
func run()->void:
	var guards:Dictionary={get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)};var plan_path:String="res://tools/biome_extensions/artifacts/magma_source_seed_cohort_plan.json";var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(plan_path));guards[plan_path]=FileAccess.get_sha256(plan_path)
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	var originals:Array=[]
	for seed_value in plan.seeds:
		var seed_id:int=int(seed_value);var path:String="res://tools/biome_extensions/artifacts/check_cave_magma_intrusive_source_index_"+str(seed_id)+".json";var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));guards[path]=FileAccess.get_sha256(path);check(report.passed,"Original preserved source inventory passed "+str(seed_id))
		for row:Dictionary in report.rows:
			for pool:Dictionary in row.molten_pools:originals.append({"seed":seed_id,"site":row.site,"pool_id":str(pool.id),"original_pool":pool})
	check(originals.size()==8,"All eight original positive molten pools fixed before large-profile discovery;no location replacement")
	var cases:Array=[];var first_normal:Dictionary={};var first_diagnostic:Dictionary={}
	for diagnostic:bool in [false,true]:
		for original:Dictionary in originals:
			var config=Config.new();var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			if diagnostic:definition.feature_configuration.large_lake_chance=1.0
			config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var b=owner("volcanic",original.seed);var work=Workload.new();check(work.configure(b.settings,config,original.seed,0),"Fixed original pool worker configures")
			var region:Dictionary=work.network.region(Vector2i(original.site[0],original.site[1]));var pool:Dictionary={}
			for candidate:Dictionary in region.get("pools",[]):
				if str(candidate.id)==original.pool_id:pool=candidate;break
			check(not pool.is_empty() and pool.get("fluid_kind","")=="magma","Exact original molten identity still present "+original.pool_id)
			var positive:bool=not pool.is_empty() and pool.get("magma_large_lake",false);var row:Dictionary={"seed":original.seed,"host":"volcanic","site":original.site,"pool_id":original.pool_id,"diagnostic_large_chance_one":diagnostic,"large_lake":positive,"pool":pool,"original_pool":original.original_pool};cases.append(row)
			if positive:
				if diagnostic and first_diagnostic.is_empty():first_diagnostic=row
				elif not diagnostic and first_normal.is_empty():first_normal=row
	check(cases.size()==16,"All original eight normal and eight diagnostic profile outcomes retained,including negatives")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable current fixed-location lake source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_fixed_lakes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"originals":originals,"cases":cases,"first_normal":first_normal,"first_diagnostic":first_diagnostic,"scope":"Current fixed-location revalidation of ALL eight original source-backed molten positives from historical complete2592case inventory. All16normal8percent/diagnostic100percent lake-profile cases retained;normal biome22percent/source4percent/molten14percent controls unchanged. Original full inventories remain historical under original hashes;not a rerun/rebinding of all2592cases or art/FPS/full traversal certification."},"  "));print("MAGMA_FIXED_LAKES ",checks," normal=",first_normal.get("pool_id","none")," diagnostic=",first_diagnostic.get("pool_id","none")," failures=",failures);quit(0 if failures.is_empty() else 1)
