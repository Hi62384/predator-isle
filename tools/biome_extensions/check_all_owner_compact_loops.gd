extends "res://tools/biome_extensions/check_all_owner_runtime_loop.gd"
func report_basename()->String:return "check_all_owner_compact_loops_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners":true,"dynamic_projection_and_flow_loops":true}
func extra_guards()->Dictionary:
	var paths:Array[String]=["res://tools/biome_extensions/check_all_owner_runtime_loop.gd","res://tools/biome_extensions/tissue_projection_loop_candidate.gd","res://tools/biome_extensions/tissue_flow_loop_candidate.gd","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/alien_tissue_flow.gdshaderinc"]
	var result:Dictionary={}
	for path:String in paths:result[path]=FileAccess.get_sha256(path)
	return result
func run()->void:
	held_shader=load("res://shaders/terrain_biomes.gdshader")
	var flow:String=preload("res://tools/biome_extensions/tissue_flow_loop_candidate.gd").apply_to(FileAccess.get_file_as_string("res://shaders/alien_tissue_flow.gdshaderinc"))
	var tissue:String=preload("res://tools/biome_extensions/tissue_projection_loop_candidate.gd").apply_to(FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
	tissue=tissue.replace('#include "res://shaders/alien_tissue_flow.gdshaderinc"',flow)
	var extensions:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc").replace('#include "res://shaders/biological_sampling.gdshaderinc"',tissue)
	held_shader.code=held_shader.code.replace('#include "res://shaders/biome_extensions.gdshaderinc"',extensions)
	await super.run()
