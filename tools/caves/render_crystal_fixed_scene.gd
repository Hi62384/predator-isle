extends "res://tools/caves/render_crystal_indexed_scene.gd"
func scene_index_path()->String:return "res://tools/biome_extensions/artifacts/check_cave_crystal_fixed_scene_"+target_key+".json"
func inspection_name()->String:return "crystal_current_fixed_"+target_key
func selection_label()->String:return "Exact original preserved "+target_key+" location revalidated under current normal production source"
func inspection_control_scope()->String:return "Current fixed-location native validation only;original complete catalogue remains historical under original hashes. No seed/site/theme/chance/size/density replacement or whole-cohort rebind."
