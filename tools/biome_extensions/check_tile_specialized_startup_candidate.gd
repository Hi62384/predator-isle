extends "res://tools/biome_extensions/check_game_startup.gd"
var held_settings:Resource
var held_boot:GDScript
var held_preparation:GDScript
func report_basename()->String:return "check_tile_specialized_all_owner_startup_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"all_sixteen_owners_enabled":true,"production_adoption":false,"mesh_branch_union":true}
func extra_guards()->Dictionary:return {"res://tools/biome_extensions/tile_owner_mask_candidate.gd":FileAccess.get_sha256("res://tools/biome_extensions/tile_owner_mask_candidate.gd")}
func run()->void:
	held_settings=load("res://config/world/terrain_settings.tres")
	for owner:String in ["badlands"]+TerrainSettings.EXTENSION_KEYS:held_settings.set(owner+"_coverage",12.0)
	# Private in-memory script interventions; saved game sources stay intact.
	held_preparation=load("res://scripts/terrain_shader_preparation.gd")
	var preparation:String=held_preparation.source_code.replace('var shader:Shader=Variants.select(load("res://shaders/terrain_biomes.gdshader"),settings)','var shader:Shader=Shader.new();shader.code=Variants.source_for(load("res://shaders/terrain_biomes.gdshader").code,0)')
	if OS.get_cmdline_user_args().has("canonical-legacy"):preparation=preparation.replace('.code,0)','.code,255)')
	if OS.get_cmdline_user_args().has("regional-window"):preparation=preparation.replace('.code,0)','.code,preload("res://tools/biome_extensions/tile_specialization_patch_candidate.gd").prepare_mask(settings))')
	assert(preparation!=held_preparation.source_code);held_preparation.source_code=preparation;assert(held_preparation.reload()==OK)
	held_boot=load("res://scripts/world_startup.gd")
	var source:String=held_boot.source_code;var needle:String='\tget_tree().change_scene_to_file('
	assert(source.count(needle)==1);held_boot.source_code=source.replace(needle,'\tpreload("res://tools/biome_extensions/tile_specialization_patch_candidate.gd").apply()\n'+needle);assert(held_boot.reload()==OK)
	if OS.get_cmdline_user_args().has("validate-only"):
		print("PRIVATE_TILE_SPECIALIZATION compiled;no GPU acceptance");quit();return
	await super.run()
