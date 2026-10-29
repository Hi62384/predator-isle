extends RefCounted
const ROOT="res://tools/biome_extensions/artifacts/revisions/experiment_ground_union_trial_4da5146ad6b0/sources/"
const BEFORE_BASE=ROOT+"scripts/biome_extension_structures.gd.txt"
const BEFORE_LOD=ROOT+"scripts/lod_biome_extension_structures.gd.txt"
const ACCEPTED=ROOT+"tools/biome_extensions/artifacts/ground_union_candidate_frozen_source.txt.txt"
static func section(code:String,first:String,next:String="")->String:
	var begin:int=code.find(first);var end:int=code.find(next,begin) if not next.is_empty() else code.length();assert(begin>=0 and end>begin);return code.substr(begin,end-begin)
static func before()->GDScript:
	# Freeze the COMPLETE original near/far arithmetic,not a fresh production
	# class with a guessed switch. Inherit only unchanged support/emission/build
	# infrastructure. Disable reference memo rather than sharing new mesh keys.
	var base:String=FileAccess.get_file_as_string(BEFORE_BASE);var lod:String=FileAccess.get_file_as_string(BEFORE_LOD)
	var near:String=section(base,"func _conduit_uncached(","\nfunc can_place_carapace(").replace("func _conduit_uncached(","func _reference_near_conduit(")
	var dispatcher:String=section(lod,"func _conduit_uncached(","\nfunc footing_height(").replace("super._conduit_uncached(","_reference_near_conduit(")
	var far:String=section(lod,"func emit_far_conduit(")
	var script:=GDScript.new();script.source_code='extends "res://scripts/lod_biome_extension_structures.gd"\nfunc _init()->void:conduit_cache_enabled=false\n'+dispatcher+"\n"+near+"\n"+far;assert(script.reload()==OK);return script
static func accepted()->GDScript:
	# Exact archived pre-registration private source,including its independent
	# near dispatch and finite-far/retained-contact paths. Do not regenerate it
	# from the newly edited production base or silently rebind old evidence.
	var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(ACCEPTED);assert(script.reload()==OK);return script
