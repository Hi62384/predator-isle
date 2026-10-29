extends "res://tools/biome_extensions/check_game_startup.gd"
var generated_sha:String=""
func report_basename()->String:return "check_private_cached_game_startup"
func intervention()->Dictionary:return {"candidate":true,"generated_shader_sha256":generated_sha,"production_adoption":false}
func extra_guards()->Dictionary:return {"res://tools/biome_extensions/legacy_target_cache_candidate.gd":FileAccess.get_sha256("res://tools/biome_extensions/legacy_target_cache_candidate.gd")}
func run()->void:
	var shader:Shader=load("res://shaders/terrain_biomes.gdshader")
	var settings:Resource=load("res://config/world/terrain_settings.tres");var variants=load("res://scripts/terrain_shader_variants.gd");var mask:int=variants.configured_mask(settings)
	shader.code=preload("res://tools/biome_extensions/legacy_target_cache_candidate.gd").apply_to(shader.code)
	for index in range(variants.LEGACY.size()):
		if (mask & (1<<index))==0:shader.code=shader.code.replace(".001<"+variants.CONTROLS[index],"false")
	generated_sha=shader.code.sha256_text();print("PRIVATE_CACHED_STARTUP mask=",mask," generated=",generated_sha)
	await super.run()
