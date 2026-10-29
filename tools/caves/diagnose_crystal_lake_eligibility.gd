extends "res://tools/caves/check_crystal_world_cohort.gd"
const Annex=preload("res://tools/caves/crystal_lake_annex_candidate.gd")
func run()->void:
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");config.biome_regions=FrozenFixture.registry(config.biome_regions,definition)
	for study:Dictionary in [{"host":"crystal_wastes","seed":73921,"site":Vector2i(6,-2)},{"host":"crystal_wastes","seed":17,"site":Vector2i(9,-3)},{"host":"quarry","seed":17,"site":Vector2i(6,-2)},{"host":"volcanic","seed":17,"site":Vector2i(6,-2)},{"host":"radiation_wasteland","seed":17,"site":Vector2i(6,-2)}]:
		var b=owner(study.host,study.seed);var work=Workload.new();work.configure(b.settings,config,study.seed,0);var region:Dictionary=work.network.region(study.site);print("HOST ",study," valid=",region.valid," family=",region.get("cave_family",-1)," pockets=",region.get("pockets",[]).size()," pools=",region.get("pools",[]).size())
		for pool:Dictionary in region.get("pools",[]):
			var parent:String=str(pool.id).trim_suffix(":seepage");var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),parent,parent,0,0);print("POOL ",pool.id," weight=",assignment.weights.get("crystal",0)," hash=",Regions.random(str(pool.id),study.seed,"crystal/large_lake")," threshold=",definition.feature_configuration.large_lake_frequency)
		var stats:Dictionary={};var result:Dictionary=Annex.prepare(region,work.builder._get_height,study.seed,definition.feature_configuration,400,10,stats);print("ANNEX_STATS ",stats," changed=",var_to_bytes(result)!=var_to_bytes(region))
	quit()
