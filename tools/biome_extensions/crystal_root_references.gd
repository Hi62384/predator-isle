extends RefCounted
const ROOT="res://tools/biome_extensions/artifacts/revisions/experiment_earth_crystal_trial_5000e91a1dfb/sources/"
static func script_for(accepted:bool)->GDScript:
	var path:String=ROOT+("tools/biome_extensions/artifacts/earth_crystal_trial_source.txt.txt" if accepted else "scripts/biome_extension_structures.gd.txt")
	var source:String=FileAccess.get_file_as_string(path).replace("\r\n","\n");var start:int=source.find("func prism(");var end:int=source.find("\nfunc mound(",start);assert(start>0 and end>start)
	var script:=GDScript.new();script.source_code='extends "res://scripts/lod_biome_extension_structures.gd"\n'+source.substr(start,end-start)+"\n";assert(script.reload()==OK);return script
