extends "res://tools/caves/render_magma_large_lake_world.gd"
func world_definition()->Resource:
	var definition:Resource=super.world_definition();definition.feature_provider=preload("res://tools/caves/candidate_magma_wall_features.gd");return definition
func world_guards()->Dictionary:
	var result:Dictionary={}
	for path:String in ["res://tools/caves/candidate_magma_wall_features.gd","res://tools/caves/candidate_magma_wall_geometry.gd"]:result[path]=FileAccess.get_sha256(path)
	return result
func report_basename()->String:return "render_cave_magma_wall_candidate"
func capture_prefix()->String:return "magma_wall_candidate"
func scope_description()->String:return "PRIVATE measured-wall column placement/four weathered hexagonal variants;not adopted. Same exact fixed source-backed large-lake location and source/biome/molten controls,diagnostic large-profile chance100percent unchanged. Actual unchanged cave field/rock/lake/three joined vaults with candidate opaque forms and matching collision;native two-way full360degree dry shore/parent return and independent opaque/molten geometry-off/exactreturn. Original main environment/test-only lamp;clock frozen for pixels. Not reference-art/FPS/global/all-user completion."
