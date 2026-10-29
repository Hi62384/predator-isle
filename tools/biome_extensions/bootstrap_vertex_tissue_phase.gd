extends SceneTree
## Hold unspecialized master/shell variants before their materials are loaded.
func _initialize()->void:
	var candidate=load("res://tools/biome_extensions/biological_vertex_phase_candidate.gd")
	var sampling:String=candidate.sampler(FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
	var extensions:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	var sampling_marker:String='#include "res://shaders/biological_sampling.gdshaderinc"'
	assert(extensions.count(sampling_marker)==1)
	extensions=extensions.replace(sampling_marker,sampling.trim_prefix(candidate.DECLARATION))
	var held:Array=[]
	for path:String in ["res://shaders/terrain_biomes.gdshader","res://shaders/biome_structures.gdshader"]:
		assert(not ResourceLoader.has_cached(path),"No original shader may be eagerly loaded")
		var source:String=FileAccess.get_file_as_string(path)
		if path.ends_with("terrain_biomes.gdshader"):
			var marker:String='#include "res://shaders/biome_extensions.gdshaderinc"'
			assert(source.count(marker)==1)
			source=candidate.terrain(source).replace(marker,extensions)
		else:source=candidate.shell(source).replace(sampling_marker,sampling)
		var shader:=Shader.new();shader.code=source;shader.take_over_path(path);held.append(shader)
		assert(ResourceLoader.get_cached_ref(path)==shader)
	root.set_meta("private_vertex_phase_shaders",held)
	set_script(load("res://tools/biome_extensions/render_vertex_tissue_phase.gd"));call_deferred("run")
