extends "res://tools/biome_extensions/render_alien_memory_baseline.gd"
func output_basename()->String:return "render_vertex_tissue_phase"
func prepare_shader()->void:
	for path:String in ["res://tools/biome_extensions/bootstrap_vertex_tissue_phase.gd","res://tools/biome_extensions/render_vertex_tissue_phase.gd","res://tools/biome_extensions/biological_vertex_phase_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var held:Array=root.get_meta("private_vertex_phase_shaders")
	assert(held.size()==2)
	assert(load("res://materials/terrain.tres").shader==held[0])
	assert(ResourceLoader.get_cached_ref("res://shaders/biome_structures.gdshader")==held[1])
	private_shader_override=true
func report_metadata()->Dictionary:
	return {"production_registration":false,"full_master_owner_logic_retained":true,"period_metres":30,"physical_texture_metres":[2.5,2.0,1.5],"warning":"Private vertex-phase correction only; full source and geometry are retained, not owner-specialized. One full-scene resource gate is necessary but not sufficient for adoption."}
