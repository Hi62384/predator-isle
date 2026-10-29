extends "res://tools/caves/check_crystal_features.gd"
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/check_crystal_features.gd","res://scripts/caves/crystal_features.gd","res://scripts/caves/crystal_geometry.gd","res://scripts/caves/field.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres");var settings:Dictionary=definition.feature_configuration.duplicate();settings.density=1.0;var seeds:Array=[73921,17,92881]
	for i in range(33):seeds.append(1000+i)
	var height:Callable=func(_x:float,_z:float)->float:return 200.0
	var records:Array=[];var cubes:int=0;var calcites:int=0;var worst_cube:float=0;var worst_calcite:float=0;var maximum_configured_height:float=0
	for amount:float in [1.0,.5]:
		var region:Dictionary=crystal_fixture()
		if amount<1:region.cave_biome_regions.candidates[0].distances.A=334.0
		var field=Field.new();field.include_surface_air=false;check(field.compile([region],height,[],region.cave_biome_regions),"Same controlled real full/transition mineral field compiles")
		for seed_id:int in seeds:
			var payload:Dictionary=Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],settings,{})
			for placement:Dictionary in payload.placements:
				if placement.kind!="crystal":continue
				if placement.family==4:
					var ratio:float=placement.height/(sqrt(2)*placement.width);cubes+=1;worst_cube=maxf(worst_cube,absf(ratio-1));check(ratio>=.8 and ratio<=1.25,"Generated fluorite keeps cubic edge/height proportions,not elongated four-sided quartz/ice posts,including transitions")
					if records.size()<40:records.append({"family":4,"seed":seed_id,"influence":amount,"height_m":placement.height,"width_m":placement.width,"cubic_ratio":ratio})
				elif placement.family==5:
					var ratio:float=placement.height/(2*placement.width);calcites+=1;worst_calcite=maxf(worst_calcite,absf(ratio-1));check(ratio>=.65 and ratio<=1.4,"Generated calcite retains blocky rhombohedral cleavage proportions,not a uniformly tall plank")
		var limited:Dictionary=settings.duplicate();limited.maximum_height=2.0
		for seed_id:int in seeds.slice(0,6):
			var payload:Dictionary=Crystal.new().build(field,Vector3i.ZERO,seed_id,[region],limited,{})
			for placement:Dictionary in payload.placements:
				if placement.kind=="crystal":maximum_configured_height=maxf(maximum_configured_height,placement.height);check(placement.height<=2.000001,"Editable maximum height applies to normal primaries,giants AND secondary mineral pieces")
	check(cubes>0 and calcites>0,"Fixed cohort contains positive actual generated cubic and rhombohedral families")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual mineral-habit configuration source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_crystal_habits.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cubic_forms":cubes,"rhombohedral_forms":calcites,"maximum_cube_ratio_error":worst_cube,"maximum_calcite_ratio_error":worst_calcite,"maximum_height_with_2m_setting":maximum_configured_height,"representative_records":records,"scope":"Actual transformed generated six-family cohort,same36fixed seeds/full and50percent transition fields. Tests cubic fluorite and blocky rhombohedral calcite proportions after physical scaling/transition,not merely correct unit prototypes;maximum-height control covers all primary/giant/secondary crystals. No world occurrence,rendered art or full live completion claim."},"  "));print("CRYSTAL_HABITS ",checks," cubes=",cubes," calcite=",calcites," max2=",maximum_configured_height," failures=",failures.slice(0,5));quit(0 if failures.is_empty() else 1)
