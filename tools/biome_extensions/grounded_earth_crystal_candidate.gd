extends RefCounted
static func script_for()->GDScript:
	var base:String=FileAccess.get_file_as_string("res://scripts/biome_extension_structures.gd").replace("\r\n","\n")
	var start:int=base.find("func prism(");var end:int=base.find("\nfunc _conduit_config_values",start)
	assert(start>0 and end>start)
	var methods:String=base.substr(start,end-start)
	var old:String="v.y=minf(v.y,builder._get_height(v.x,v.z)-8)"
	assert(methods.count(old)==2)
	methods=methods.replace(old,"v.y=minf(v.y,footing_height(builder,Vector2(v.x,v.z)))")
	var script:=GDScript.new();script.source_code='extends "res://scripts/lod_biome_extension_structures.gd"\n'+methods+"\n"
	assert(script.reload()==OK);return script
