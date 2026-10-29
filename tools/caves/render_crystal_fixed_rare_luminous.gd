extends "res://tools/caves/render_crystal_rare_luminous.gd"
func scene_index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_crystal_fixed_scene_rare_luminous.json"
func inspection_name()->String:return "crystal_current_fixed_rare_luminous"
func selection_label()->String:return "Original normally rare seed19 chamber retained and revalidated under current production source"
func inspection_control_scope()->String:return "Current fixed-location native check;original24576case catalogue stays historical under original source hashes. Normal probabilities/theme/seed/site/density unchanged;no new FIRST-cohort claim."
func additional_guards()->Dictionary:
	var result:Dictionary=super.additional_guards();result["res://tools/caves/render_crystal_rare_luminous.gd"]=FileAccess.get_sha256("res://tools/caves/render_crystal_rare_luminous.gd");return result
