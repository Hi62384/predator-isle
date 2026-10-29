extends SceneTree
func _initialize()->void:
	var mapping=JSON.parse_string(FileAccess.get_file_as_string("res://config/resource_path_migration.json"));assert(mapping is Dictionary)
	var resources:int=0
	for original:String in mapping:
		var target:String="res://"+str(mapping[original]);assert(FileAccess.file_exists(target),"Relocated file exists: "+target);assert(not FileAccess.file_exists("res://"+original),"Old loose root file removed: "+original)
		if target.ends_with(".tres") or target.ends_with(".tscn"):assert(ResourceLoader.load(target)!=null,"Native relocated resource loads: "+target);resources+=1
	var definitions:Resource=load("res://config/caves/cave_biome_regions.tres");assert(definitions.definitions.size()==4 and definitions.validation_errors().is_empty());assert(load("res://config/caves/cave_settings.tres").enabled)
	assert(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/world_startup.tscn")
	assert(preload("res://tools/maintenance/resource_paths.gd").configuration_files().size()==28,"Complete recursively guarded configuration set")
	var untouched:String="const TEST=preload(\"res://terrain_settings.tres\")";var relocated:String=preload("res://tools/maintenance/resource_paths.gd").remap_source(untouched);assert(relocated.contains("res://config/world/terrain_settings.tres"))
	print("PROJECT_LAYOUT_PASS ",mapping.size()," relocated files; ",resources," native resources; enabled four-biome registry and startup paths valid");quit()
