extends "res://tools/biome_extensions/check_all_owner_runtime_loop.gd"
func report_basename()->String:return "check_active_bit_startup"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners":true,"same_ascending_family_order":true,"active_bit_dispatch":true}
func extra_guards()->Dictionary:return {"res://tools/biome_extensions/active_bit_dispatch_candidate.gd":FileAccess.get_sha256("res://tools/biome_extensions/active_bit_dispatch_candidate.gd")}
func run()->void:
	held_shader=load("res://shaders/terrain_biomes.gdshader")
	held_shader.code=preload("res://tools/biome_extensions/active_bit_dispatch_candidate.gd").source_for(held_shader.code)
	await super.run()
