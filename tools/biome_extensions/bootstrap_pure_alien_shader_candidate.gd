extends SceneTree
## Must NOT refer to ChunkTerrain or preload its script before cache takeover.
func _initialize()->void:
	var path:String="res://shaders/terrain_biomes.gdshader"
	assert(not ResourceLoader.has_cached(path),"Original master must not be loaded before this private bootstrap")
	var original:String=FileAccess.get_file_as_string(path)
	var start:int=original.find("void fragment() {");var shading:int=original.find(" if(coast_control.x>.999)",start);var guard:int=original.rfind(" // Overlay blending must not restore physical lighting")
	assert(start>0 and shading>start and guard>shading)
	var shader:=Shader.new();shader.code=original.substr(0,shading)+FileAccess.get_file_as_string("res://tools/biome_extensions/pure_alien_fragment_candidate.gdshaderinc")+original.substr(guard)
	shader.take_over_path(path)
	assert(ResourceLoader.get_cached_ref(path)==shader)
	root.set_meta("private_bootstrap_shader",shader)
	print("PURE_SHADER_REGISTERED_BEFORE_CHUNK_SCRIPT")
	set_script(load("res://tools/biome_extensions/render_preloaded_pure_alien_candidate.gd"))
	call_deferred("run")
