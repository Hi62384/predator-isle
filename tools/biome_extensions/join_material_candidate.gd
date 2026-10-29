extends RefCounted
## Private material-only study; never registered in production scene materials.
## The geometric apron already extends below every supported ground chord.
func terrain_shader()->Shader:
	var source:String=FileAccess.get_file_as_string("res://shaders/terrain_biomes.gdshader")
	var extension:String=FileAccess.get_file_as_string("res://shaders/biome_extensions.gdshaderinc")
	var token:String="  color=mix(color,bio*.55,clamp(coverage,0.0,1.0));rough=tissue_rough;"
	assert(extension.count(token)==1,"Exact current tissue response before private substitution")
	extension=extension.replace(token,token+"\n  if(family==7){float attached=smoothstep(.02,.10,feature);color=mix(color,bio*.55,attached);gradient*=1.0-attached;coverage=mix(coverage,1.0,attached);}")
	var include_token:String='#include "res://shaders/biome_extensions.gdshaderinc"'
	assert(source.count(include_token)==1,"One original production extension include")
	var shader:=Shader.new();shader.code=source.replace(include_token,extension);return shader
