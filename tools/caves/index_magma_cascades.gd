extends "res://tools/caves/check_frozen_world_cohort.gd"
func run()->void:
	var index_path:String="res://tools/biome_extensions/artifacts/check_cave_magma_fixed_lakes.json";var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(index_path));var guards:Dictionary={index_path:FileAccess.get_sha256(index_path),get_script().resource_path:FileAccess.get_sha256(get_script().resource_path),"res://config/caves/biomes/magma_cave_definition.tres":FileAccess.get_sha256("res://config/caves/biomes/magma_cave_definition.tres")}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	check(original.passed and original.originals.size()==8,"All eight original fixed molten identities retained before cascade discovery")
	var cases:Array=[];var first_normal:Dictionary={};var first_diagnostic:Dictionary={}
	for diagnostic:bool in [false,true]:
		for old:Dictionary in original.originals:
			var config=Config.new();var definition:Resource=load("res://config/caves/biomes/magma_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			if diagnostic:definition.feature_configuration.molten_cascade_chance=1.0
			config.biome_regions=FrozenFixture.registry(config.biome_regions,definition);var builder=owner("volcanic",int(old.seed));var work=Workload.new();check(work.configure(builder.settings,config,int(old.seed),0),"Actual source-backed normal worker configures")
			var region:Dictionary=work.network.region(Vector2i(old.site[0],old.site[1]));var pool:Dictionary={}
			for candidate:Dictionary in region.get("pools",[]):
				if str(candidate.id)==str(old.pool_id):pool=candidate;break
			check(not pool.is_empty() and pool.get("fluid_kind","")=="magma","Exact original retained source-backed pool survives cascade admission")
			var positive:bool=pool.has("molten_cascade");var row:Dictionary={"seed":int(old.seed),"host":"volcanic","site":old.site,"pool_id":old.pool_id,"diagnostic_cascade_chance_one":diagnostic,"cascade":positive,"pool":pool};cases.append(row)
			if positive:
				check(pool.molten_cascade.thermal_source==pool.thermal_source and pool.molten_cascade.free_fall_height<=3 and pool.molten_cascade.vertices.size()==288,"Actual source identity and finite supported-film/short-fall geometry")
				if diagnostic and first_diagnostic.is_empty():first_diagnostic=row
				elif not diagnostic and first_normal.is_empty():first_normal=row
	check(cases.size()==16,"All normal and diagnostic outcomes retained,including rejected geometry and rare rolls")
	check(not first_diagnostic.is_empty(),"At least one real original source-backed cave admits physical cascade when only its rare roll is diagnostic")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable original fixed-source cascade survey "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_cascade_index.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":cases,"first_normal":first_normal,"first_diagnostic":first_diagnostic,"scope":"All eight original molten identities,16normal6percent/diagnostic100percent cascade outcomes. Canonical source4percent/biome22percent/molten14percent controls unchanged;diagnostic overrides cascade chance only. Full2592site historical source survey not rebound;normal cascade frequencies,physical native render and art acceptance separate."},"  "));print("MAGMA_CASCADE_INDEX ",checks," normal=",first_normal.get("pool_id","none")," diagnostic=",first_diagnostic.get("pool_id","none")," failures=",failures);quit(0 if failures.is_empty() else 1)
