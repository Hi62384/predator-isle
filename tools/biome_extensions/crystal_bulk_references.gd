extends RefCounted
const ROOT="res://tools/biome_extensions/artifacts/revisions/experiment_crystal_bulk_trial_68828270bd88/sources/"
static func script_for(accepted:bool)->GDScript:
	var old:String=FileAccess.get_file_as_string(ROOT+"scripts/biome_extension_structures.gd.txt").replace("\r\n","\n");var start:int=old.find("func prism(");var end:int=old.find("\nfunc mound(",start);assert(start>0 and end>start);var method:String=old.substr(start,end-start)
	if accepted:
		var private_source:String=FileAccess.get_file_as_string(ROOT+"tools/biome_extensions/crystal_bulk_candidate.gd.txt").replace("\r\n","\n");var body_start:int=private_source.find("\tvar thickness:");assert(body_start>0)
		var line_end:int=method.find("\n");method=method.insert(line_end+1,"\tvar begin:int=vertices.size()\n")+"\n"+private_source.substr(body_start)
	var script:=GDScript.new();script.source_code='extends "res://scripts/lod_biome_extension_structures.gd"\n'+method+"\n";assert(script.reload()==OK);return script
