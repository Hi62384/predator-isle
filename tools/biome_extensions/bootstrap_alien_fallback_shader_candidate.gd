extends SceneTree
## A different explicit domain from the rejected full-owner specialization:
## Alien plus its ORIGINAL Grass fallback, no other owners/coasts. Private only.
func _initialize()->void:
	var path:String="res://shaders/terrain_biomes.gdshader";assert(not ResourceLoader.has_cached(path))
	var source:String=FileAccess.get_file_as_string(path)
	for control:String in ["coast_control.x","badlands_control.x","tropical_control.x","mountain_control.z","swamp_control.z","savanna_control.z","forest_control.z","jungle_control.z"]:
		for threshold:String in [".999",".001"]:
			var condition:String="if("+control+">"+threshold+")"
			assert(source.count(condition)>0,"Expected original owner branch "+condition)
			source=source.replace(condition,"if(false)")
	assert(source.count("for(int i=0;i<8;i++){")==2)
	source=source.replace("for(int i=0;i<8;i++){","for(int i=7;i<8;i++){")
	var shader:=Shader.new();shader.code="// PRIVATE_EXPLICIT_ALIEN_GRASS_FALLBACK\n"+source;shader.take_over_path(path);root.set_meta("private_fallback_shader",shader)
	assert(ResourceLoader.get_cached_ref(path)==shader)
	set_script(load("res://tools/biome_extensions/render_alien_fallback_shader_candidate.gd"));call_deferred("run")
