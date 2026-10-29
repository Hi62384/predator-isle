extends RefCounted
static var held:Array[GDScript]=[]
static func apply()->void:
	var folder:String="res://tools/maintenance/artifacts/before_inactive_region_pruning/"
	var base:GDScript=load("res://scripts/biome_extension_sampler.gd");base.source_code=FileAccess.get_file_as_string(folder+"candidate_base.gd.txt");assert(base.reload()==OK);held.append(base)
	for key:String in TerrainSettings.EXTENSION_KEYS:
		var script:GDScript=load("res://scripts/"+key+"_sampler.gd")
		if key=="alien_infected":script.source_code=FileAccess.get_file_as_string(folder+"candidate_alien.gd.txt")
		assert(script.reload()==OK);held.append(script)
