extends RefCounted
const MIXED:int=-1
const ZERO_BASE:int=-2
const GRASS_BASE:int=-3
const COAST_BASE:int=-4
static func body(source:String,marker:String)->String:
	var start:int=source.find(marker);assert(start>=0,marker)
	start=source.find("{",start)+1;var end:int=start;var depth:int=1
	while depth>0:
		if source[end]=="{":depth+=1
		elif source[end]=="}":depth-=1
		end+=1
	return source.substr(start,end-start-1)
static func source_for(original:String,mask:int,base:int)->String:
	var source:String=preload("res://tools/biome_extensions/unreachable_shader_blocks_candidate.gd").compact(original,mask)
	if base==MIXED:return source
	var start:int=source.find("\n if(",source.find("vec3 cache_jungle_color="))
	var end:int=source.find("\n if(extension_payload_enabled){\n",start)
	assert(start>=0 and end>start)
	var replacement:String=""
	if base==COAST_BASE:replacement="\n"+body(source,"if(coast_control.x>.999)")+"\n"
	elif base==ZERO_BASE:replacement="\n"+body(source,"else if(dot(extension_weights_a,vec4(1))+dot(extension_weights_b,vec4(1))>.999)")+"\n"
	elif base==GRASS_BASE:replacement="\n"+body(source,"}else{\n float broad=")+"\n"
	else:
		var index:int=0
		while (1<<index)!=base:index+=1;assert(index<7)
		assert((mask & base)!=0)
		replacement="\n"+body(source,"if("+preload("res://scripts/terrain_shader_variants.gd").CONTROLS[index]+">.999)")+"\n"
	if base==GRASS_BASE or base>0:
		# The proven inland base can still receive partial overlays. Preserve
		# BOTH original overlay fast paths, including their .999 thresholds.
		replacement="\n if(coast_control.x>.999){"+body(original,"if(coast_control.x>.999)")+"}else if(dot(extension_weights_a,vec4(1))+dot(extension_weights_b,vec4(1))>.999){"+body(original,"else if(dot(extension_weights_a,vec4(1))+dot(extension_weights_b,vec4(1))>.999)")+"}else{"+replacement+"}\n"
	return "// PROVEN_PURE_BASE_%d\n"%base+source.substr(0,start)+replacement+source.substr(end)
