extends "res://tools/biome_extensions/render_alien_memory_baseline.gd"
func output_basename()->String:return "characterize_early_full_shader_2560" if OS.get_cmdline_user_args().has("characterize") else "render_early_full_shader_warmup"
func report_metadata()->Dictionary:
	if not OS.get_cmdline_user_args().has("characterize"):return {}
	return {"characterization_only":true,"runner_memory_limit_mib":2560,"passes_2048_memory_gate":false,"production_optimization_adopted":false,"warning":"Original 2048MiB gate remains failed. This separately named run only characterizes compilation/full-scene behavior under a predeclared larger diagnostic bound; it cannot justify a memory/startup success claim."}
func prepare_shader()->void:
	for path:String in ["res://tools/biome_extensions/bootstrap_full_shader_warmup.gd","res://tools/biome_extensions/render_early_full_shader_warmup.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var shader:Shader=root.get_meta("early_full_shader");assert(ResourceLoader.get_cached_ref("res://shaders/terrain_biomes.gdshader")==shader)
	assert(shader.code==FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader"),"Unmodified complete production source, no specialization")
	assert(load("res://materials/terrain.tres").shader==shader)
func capture(key:String,kind:String,focus:Vector3,offset:Vector3,debug:int=0)->void:
	await super.capture(key,kind,focus,offset,debug)
	records[-1]["early_full_shader_warmup_seconds"]=root.get_meta("early_full_shader_seconds")
	records[-1]["private_load_order_only"]=true
