extends "res://tools/biome_extensions/render_alien_memory_baseline.gd"
var domain_tiles:int=0
var domain_vertices:int=0
func output_basename()->String:return "render_alien_fallback_shader_candidate"
func prepare_shader()->void:
	for path:String in ["res://tools/biome_extensions/bootstrap_alien_fallback_shader_candidate.gd","res://tools/biome_extensions/render_alien_fallback_shader_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	assert(ResourceLoader.get_cached_ref("res://shaders/terrain_biomes.gdshader")==root.get_meta("private_fallback_shader"))
	assert(load("res://materials/terrain.tres").shader==root.get_meta("private_fallback_shader"))
	private_shader_override=true
func report_metadata()->Dictionary:
	return {"production_registration":false,"explicit_grass_fallback_retained":true,"current_full_master_pixel_equivalence_proven":false,"domain_tiles_checked":domain_tiles,"domain_vertices_checked":domain_vertices,"warning":"Private domain-limited shader-preparation experiment only. Original Grass fallback remains, unlike the separately rejected all-full-Alien specialization. Native full-master pixel equivalence is still required before any adoption."}
func settle()->bool:
	var result:bool=await super.settle()
	if not result:return false
	assert(not terrain._settings_snapshot.rocky_coast_enabled and not terrain._settings_snapshot.beaches_enabled)
	for owner:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:
		if owner!="alien_infected":assert(terrain._settings_snapshot.get(owner+"_coverage")==0,"No unsupported configured owners")
	assert(terrain._active_chunks.size()>0)
	for node:MeshInstance3D in terrain._active_chunks.values():
		var material:ShaderMaterial=node.mesh.surface_get_material(0);var mask:int=int(material.get_shader_parameter("extension_active_mask"))
		assert((mask & 127)==0,"Other extension fields require the original full shader")
		var arrays:Array=node.mesh.surface_get_arrays(0);var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		assert(colors.size()==arrays[Mesh.ARRAY_VERTEX].size())
		for color:Color in colors:assert(color==Color(0,0,0,0),"Legacy owner channels must be zero; Grass fallback is the original default branch")
		domain_tiles+=1;domain_vertices+=colors.size()
	return true
