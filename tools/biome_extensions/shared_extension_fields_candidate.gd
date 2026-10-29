extends RefCounted
static func source_for(source:String)->String:
	var path:String="res://shaders/biome_extensions.gdshaderinc"
	var extensions:String=FileAccess.get_file_as_string(path)
	var common:String='float fracture=field(world_position.xz*.024+vec2(field(world_position.zy*.013),field(world_position.xy*.017))*3.0);\n float bedding=sin(world_position.y*.075+field(world_position.xz*.006)*9.0);\n float meso=field(world_position.xy*.12)+field(world_position.zy*.15);'
	assert(extensions.count(common)==1)
	var function:String="vec3 extension_shared_fields(){\n "+common+"\n return vec3(fracture,bedding,meso);\n}\n"
	extensions=extensions.replace(common,"float fracture=shared_fields.x,bedding=shared_fields.y,meso=shared_fields.z;")
	assert(extensions.count("float fine,out vec3 color")==1)
	extensions=extensions.replace("float fine,out vec3 color","float fine,vec3 shared_fields,out vec3 color")
	extensions=extensions.replace("void shade_extension(",function+"void shade_extension(")
	var marker:String=" if(extension_payload_enabled){\n  vec3 ec=";assert(source.count(marker)==1)
	source=source.replace(marker," if(extension_payload_enabled){\n  vec3 shared_extension_fields=extension_shared_fields();\n  vec3 ec=")
	var call:String="projection,fine,c,r,g,e)";assert(source.count(call)==1)
	source=source.replace(call,"projection,fine,shared_extension_fields,c,r,g,e)")
	return source.replace('#include "res://shaders/biome_extensions.gdshaderinc"',extensions)
