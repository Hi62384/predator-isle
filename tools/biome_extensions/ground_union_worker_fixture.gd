extends RefCounted
const CONTROLLER="res://scripts/chunk_terrain.gd"
static func controller_script()->GDScript:
	var original:String=FileAccess.get_file_as_string(CONTROLLER).replace("\r\n","\n");var begin:int=original.find("func _dispatch_jobs()");var end:int=original.find("\nfunc _collect_jobs()",begin);assert(begin>0 and end>begin)
	var dispatch:String=original.substr(begin,end-begin);var call:String='preload("res://scripts/lod_biome_extension_structures.gd").new()';assert(dispatch.count(call)==1)
	# Inherit the actual controller/type;copy ONLY the actual dispatch method,
	# replacing one generator constructor. Same builder,workers,batching,
	# context/global bounds,collision preparation,streaming and material path.
	var script:=GDScript.new();script.source_code='extends "res://scripts/chunk_terrain.gd"\nvar _study_structure_script:Script\n'+dispatch.replace(call,"_study_structure_script.new()")+"\n";assert(script.reload()==OK);return script
static func configure(node:Node,enabled:bool)->void:
	node.set_script(controller_script())
	node.set("_study_structure_script",preload("res://tools/biome_extensions/conduit_ground_union_candidate.gd").script_for() if enabled else load("res://scripts/lod_biome_extension_structures.gd"))
	assert(node is ChunkTerrain and node.get("_study_structure_script")!=null)
