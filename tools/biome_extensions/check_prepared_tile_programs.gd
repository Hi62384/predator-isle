extends "res://tools/biome_extensions/check_game_startup.gd"
var held_settings:Resource
var held_boot:GDScript
func helper_path()->String:return "res://tools/biome_extensions/prepared_tile_programs_candidate.gd"
func report_basename()->String:return "check_prepared_tile_programs_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners":true,"fixed_startup_cohort_only":true,"all_programs_before_image_banks":true}
func extra_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://tools/biome_extensions/prepared_tile_programs_candidate.gd","res://tools/biome_extensions/tile_owner_mask_candidate.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
func run()->void:
	held_settings=load("res://config/world/terrain_settings.tres")
	for key:String in ["badlands"]+TerrainSettings.EXTENSION_KEYS:held_settings.set(key+"_coverage",12.0)
	held_boot=load("res://scripts/world_startup.gd");var source:String=held_boot.source_code
	source=source.replace('preload("res://scripts/terrain_shader_preparation.gd").prepare(', 'preload("'+helper_path()+'").prepare(')
	var needle:String='\tget_tree().change_scene_to_file(';assert(source.count(needle)==1)
	held_boot.source_code=source.replace(needle,'\tpreload("'+helper_path()+'").apply()\n'+needle);assert(held_boot.reload()==OK)
	await super.run()
