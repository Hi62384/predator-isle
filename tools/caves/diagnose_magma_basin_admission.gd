extends "res://tools/caves/check_frozen_world_cohort.gd"
const Basins=preload("res://scripts/caves/seepage_basins.gd")
func run()->void:
	var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_cave_magma_intrusive_source_index.json"));var config=Config.new();config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));var b=owner("volcanic",73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Configured")
	var room_count:int=0;var magma_count:int=0;var probability_count:int=0;var fit_count:int=0;var rows:Array=[]
	for record:Dictionary in input.rows:
		if not record.thermal_sources.any(func(source:Dictionary)->bool:return str(source.id).ends_with("/intrusive_heat")):continue
		var region:Dictionary=work.network.region(Vector2i(record.site[0],record.site[1]))
		for room:Dictionary in region.get("nodes",[])+region.get("pockets",[]):
			var heat:Dictionary=work._magma_heat.sample(room.point)
			if float(heat.heat)<.5:continue
			room_count+=1;var weight:float=float(Regions.along_edge(region.cave_biome_regions,str(room.id),str(room.id),0,0).weights.get("magma",0))
			if weight<.7:continue
			magma_count+=1;var chance:float=Regions.random(str(room.id)+":seepage",73921,"magma/active_pool")
			if chance>.14:continue
			probability_count+=1;var basin_region:Dictionary=region.duplicate();basin_region.nodes=[room];basin_region["pockets"]=[];var proposals:Array=Basins.make(basin_region,73921,1.0,false);fit_count+=proposals.size();rows.append({"site":record.site,"room":room,"heat":heat,"weight":weight,"chance":chance,"proposals":proposals})
	print("MAGMA_BASIN_ADMISSION hot_rooms=",room_count," magma=",magma_count," chance=",probability_count," proposals=",fit_count," rows=",rows);quit()
