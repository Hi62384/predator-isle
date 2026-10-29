extends RefCounted
const SOURCE="res://tools/biome_extensions/artifacts/revisions/experiment_check_insect_mound_profiles_d805abcd1a4f/sources/scripts/biome_extension_structures.gd.txt"
static func original()->GDScript:
	var text:String=FileAccess.get_file_as_string(SOURCE).replace("\r\n","\n");var start:int=text.find("func mound(");var end:int=text.find("\nfunc _conduit_config_values",start);assert(start>0 and end>start);var script:=GDScript.new();script.source_code='extends "res://scripts/lod_biome_extension_structures.gd"\n'+text.substr(start,end-start)+"\n";assert(script.reload()==OK);return script
