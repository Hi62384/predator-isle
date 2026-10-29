extends SceneTree
func _initialize()->void:
	var path:String="res://tools/biome_extensions/check_collision_spatial_dense.gd";var source:String=FileAccess.get_file_as_string(path)
	source=source.replace("res://tools/biome_extensions/structure_collision_spatial_candidate.gd","res://scripts/structure_collision_index.gd")
	source=source.replace("check_collision_spatial_dense.gd","check_collision_index_native_dense.gd").replace("check_collision_spatial_dense.json","check_collision_index_native_dense.json")
	source=source.replace('"production_registration":false','"production_registration":true').replace("PRIVATE SPATIALLY INDEXED BOUNDS-PRESERVING ADDITIONAL","REGISTERED SPATIALLY INDEXED BOUNDS-PRESERVING ADDITIONAL")
	source=source.replace("no production integration,streaming/capsule or whole-world claim.","Actual registered index,not a whole-world or streamed capsule claim;motion covered separately.")
	var marker:String='var script:=GDScript.new();';assert(source.count(marker)==1)
	source=source.replace(marker,'source=source.replace(\'var b=make_builder(7,92881);\',\'guards["'+path+'"]=FileAccess.get_sha256("'+path+'");var b=make_builder(7,92881);\')\n\tsource=source.replace(\'"production_registration":false\',\'"production_registration":true\').replace("no production integration,streaming/capsule or whole-world claim.","Actual registered index;streamed capsule covered separately,not a whole-world claim.")\n\t'+marker)
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("_initialize")
