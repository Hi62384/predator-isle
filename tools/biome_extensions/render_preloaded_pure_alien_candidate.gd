extends "res://tools/biome_extensions/render_pure_alien_shader_candidate.gd"
func output_basename()->String:return "render_preloaded_pure_alien_candidate"
func prepare_shader()->void:
	for path:String in ["res://tools/biome_extensions/render_preloaded_pure_alien_candidate.gd","res://tools/biome_extensions/render_pure_alien_shader_candidate.gd","res://tools/biome_extensions/bootstrap_pure_alien_shader_candidate.gd","res://tools/biome_extensions/pure_alien_fragment_candidate.gdshaderinc"]:hashes[path]=FileAccess.get_sha256(path)
	var cached:Resource=ResourceLoader.get_cached_ref("res://shaders/terrain_biomes.gdshader")
	assert(cached!=null and root.get_meta("private_bootstrap_shader")==cached,"Actual loaded terrain material must reuse this bootstrap's private shader")
	assert(load("res://materials/terrain.tres").shader==cached)
	private_shader_override=true
