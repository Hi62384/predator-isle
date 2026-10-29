extends "res://tools/caves/render_magma_scenic_target.gd"
func world_definition()->Resource:
	var definition:Resource=super.world_definition().duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_provider=load("res://tools/caves/candidate_weathered_magma_features.gd");return definition
func report_basename()->String:return "render_cave_weathered_magma_candidate_"+target_key
func capture_prefix()->String:return "weathered_magma_candidate_"+target_key.sha256_text().left(8)
func world_guards()->Dictionary:
	var guards:Dictionary=super.world_guards()
	for path:String in [get_script().resource_path,"res://tools/caves/candidate_weathered_magma_features.gd","res://tools/caves/candidate_weathered_magma_geometry.gd"]:guards[path]=FileAccess.get_sha256(path)
	return guards
