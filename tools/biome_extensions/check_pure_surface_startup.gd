extends "res://tools/biome_extensions/check_prepared_tile_programs.gd"
func helper_path()->String:return "res://tools/biome_extensions/pure_surface_runtime_candidate.gd"
func report_basename()->String:return "check_pure_surface_startup"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners":true,"exact_original_triangle_payloads":true,"far_surface_shader_partition":true,"near_cave_surface_layout_unchanged":true}
func extra_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in [helper_path(),"res://tools/biome_extensions/pure_surface_partition_candidate.gd","res://tools/biome_extensions/pure_owner_shader_candidate.gd","res://tools/biome_extensions/tile_owner_mask_candidate.gd","res://tools/biome_extensions/unreachable_shader_blocks_candidate.gd","res://shaders/biome_extensions.gdshaderinc"]:result[path]=FileAccess.get_sha256(path)
	return result
