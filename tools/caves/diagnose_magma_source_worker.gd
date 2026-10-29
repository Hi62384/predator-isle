extends "res://tools/caves/check_frozen_world_cohort.gd"
func run()->void:
	var b=owner("volcanic",73921);var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Worker configured")
	for p:Vector3 in [Vector3(241955,290,-97306.7),Vector3(253826.8,-140,-18163.32)]:print("WORKER_SOURCE ",p," height=",work.builder._get_height(p.x,p.z)," heat=",work._magma_heat.sample(p))
	for site:Vector2i in [Vector2i(157,-63),Vector2i(164,-12),Vector2i(164,-13)]:
		var region:Dictionary=work.network.region(site);print("WORKER_REGION ",site," valid=",region.valid," rooms=",region.get("nodes",[]).size()+region.get("pockets",[]).size()," heat=",region.get("cave_thermal_sources",[]))
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
			if work._magma_heat.sample(room.point+Vector3.UP*4).heat>0:print("POSITIVE_ROOM ",room)
	quit()
