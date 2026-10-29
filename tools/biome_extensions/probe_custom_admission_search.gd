extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/check_junction_custom_admission.gd","res://tools/biome_extensions/probe_custom_admission_search.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var b=make_builder(7,92881);b.settings.alien_infected.feature_scale=.2;b._configure_noise();var field=b._extras[7];var span:float=4096*.2
	var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(baseline.passed,"Known actual land example")
	var land:=Vector2.ZERO
	for site:Dictionary in baseline.cases:
		if int(site.seed)==92881:land=Vector2(site.position[0],site.position[1])
	check(land!=Vector2.ZERO,"Actual seed-specific landmark, not an invented replacement seed")
	var cases:Array=[]
	for center:Vector2i in [Vector2i.ZERO,Vector2i(floori(land.x/span),floori(land.y/span))]:
		var stats:Dictionary={"center_cell":center,"total_cells":0,"default_rarity_membrane_candidates":0,"island_candidates":0,"dry_candidates":0,"dry_positions":[]}
		for z in range(center.y-24,center.y+25):
			for x in range(center.x-24,center.x+25):
				stats.total_cells+=1;var cell:=Vector2i(x,z);var d:Dictionary=field.descriptor(cell,span)
				if d.chance>field.settings.structure_density or field.random(x,z,246)>=field.settings.hive_junction_frequency or field.random(x,z,248)>=field.settings.hive_membrane_frequency:continue
				stats.default_rarity_membrane_candidates+=1;var p:Vector2=field.hive_node(cell)
				if b._island_mask(p.x,p.y)<.1:continue
				stats.island_candidates+=1;var height:float=b._get_height(p.x,p.y)
				if height<=maxf(b.water_level,b.get_water_surface_height(p.x,p.y))+2:continue
				stats.dry_candidates+=1;stats.dry_positions.append(p)
		cases.append(stats)
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable missing-case search diagnostic source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/probe_custom_admission_search.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"seed":92881,"feature_scale":.2,"cases":cases,"normal_guard_geometry_admission_tested":false,"scope":"Diagnoses the missing min-scale seed using the same bounded 49x49 cell/rareness/dry tests around world origin and a previously verified seed-specific land landmark. No change to seed, rarity, caves, carapace or production geometry; no forced/missing-case acceptance. Geometry and native walks remain separate."},"  "))
	print("CUSTOM_SEARCH_DIAGNOSTIC ",cases);quit(0 if failures.is_empty() else 1)
