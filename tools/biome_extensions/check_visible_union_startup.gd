extends "res://tools/biome_extensions/check_prepared_tile_programs.gd"
func helper_path()->String:return "res://tools/biome_extensions/visible_union_program_candidate.gd"
func report_basename()->String:return "check_visible_union_startup_candidate"
func intervention()->Dictionary:return {"private_candidate":true,"production_adoption":false,"all_sixteen_owners_enabled":true,"one_mutable_program_for_actual_visible_owner_union":true,"final_visible_owner_mask":root.get_meta("visible_owner_mask",-1)}
func extra_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in [helper_path(),"res://tools/biome_extensions/check_prepared_tile_programs.gd","res://tools/biome_extensions/tile_owner_mask_candidate.gd","res://tools/biome_extensions/unreachable_shader_blocks_candidate.gd","res://shaders/biome_extensions.gdshaderinc"]:result[path]=FileAccess.get_sha256(path)
	return result
