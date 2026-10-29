extends "res://tools/biome_extensions/check_game_startup.gd"
var held_settings:Resource
var held_shader:Shader
func report_basename()->String:return "check_all_owner_startup_private"
func intervention()->Dictionary:return {"candidate_saved_world":true,"all_sixteen_surface_owners":true,"production_adoption":false}
func run()->void:
	held_settings=load("res://config/world/terrain_settings.tres")
	for owner:String in ["badlands"]+TerrainSettings.EXTENSION_KEYS:held_settings.set(owner+"_coverage",12.0)
	if OS.get_cmdline_user_args().has("dynamic_dispatch"):
		held_shader=load("res://shaders/terrain_biomes.gdshader");var source:String=held_shader.code;var loop:int=source.rfind("for(int i=0;i<8;i++){");var declaration:int=source.find(";",source.find("render_mode "));assert(loop>declaration)
		source=source.substr(0,loop)+source.substr(loop).replace("for(int i=0;i<8;i++){","for(int i=0;i<terrain_extension_dispatch_count;i++){")
		held_shader.code=source.insert(declaration+1,"\nuniform int terrain_extension_dispatch_count=8;\n")
		print("PRIVATE_DYNAMIC_ALL_OWNER_SHADER ",held_shader.code.sha256_text())
	print("ALL_OWNER_PRIVATE_STARTUP configured_mask=",load("res://scripts/terrain_shader_variants.gd").configured_mask(held_settings))
	await super.run()
