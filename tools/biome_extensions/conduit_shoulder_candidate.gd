extends RefCounted
const SOURCE="res://scripts/lod_biome_extension_structures.gd"
const BASE="res://scripts/biome_extension_structures.gd"
static func source_for(source:String,enabled:bool=true)->String:
	if not enabled:return source
	# Near detail dispatches to the inherited base emitter. A far-only source
	# substitution silently leaves every near vertex unchanged. Override that
	# dispatch with the COMPLETE original near method before changing profiles.
	var base:String=FileAccess.get_file_as_string(BASE);var begin:int=base.find("func _conduit_uncached(");var end:int=base.find("\nfunc can_place_carapace(",begin);assert(begin>0 and end>begin)
	var near:String=base.substr(begin,end-begin).replace("func _conduit_uncached(","func _candidate_near_conduit(")
	var dispatch:String="super._conduit_uncached(builder,a,b,width,phase,color)";assert(source.count(dispatch)==1)
	source=source.replace(dispatch,"_candidate_near_conduit(builder,a,b,width,phase,color)")+"\n"+near+"\n"
	var marker:String="if conduit_aprons and conduit_shoulders:rise*=rise";assert(source.count(marker)==2)
	# Private first study only. Same crest,root footprint,buried margins,
	# protected approaches,row/cross sections and triangle topology.
	var code:String=source.replace(marker,"if conduit_aprons and conduit_shoulders:rise=lerpf(rise*rise,pow(rise,4),smoothstep(9,15,radius))")
	var key_marker:String='if detail>1 and not is_finite(context.get("floor",INF)):key="retained_contact_v1/"+key';assert(code.count(key_marker)==1)
	# A worker may compare both algorithms;never share differently shaped mesh
	# entries under the old memo identity. Existing8MiB/32-entry cap unchanged.
	return code.replace(key_marker,'key="private_quartic_shoulder_v1/"+key\n\t'+key_marker)
static func script_for(enabled:bool=true)->GDScript:
	var result:=GDScript.new();result.source_code=source_for(FileAccess.get_file_as_string(SOURCE),enabled);assert(result.reload()==OK);return result
