extends "res://tools/biome_extensions/check_all_owner_runtime_loop.gd"
func report_basename()->String:return "check_all_owner_shared_fields_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners_enabled":true,"common_noise_evaluated_once_before_family_dispatch":true}
func extra_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://tools/biome_extensions/shared_extension_fields_candidate.gd","res://shaders/biome_extensions.gdshaderinc"]:result[path]=FileAccess.get_sha256(path)
	return result
func run()->void:
	held_shader=load("res://shaders/terrain_biomes.gdshader")
	held_shader.code=preload("res://tools/biome_extensions/shared_extension_fields_candidate.gd").source_for(held_shader.code)
	await super.run()
