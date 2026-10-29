extends RefCounted
## Raw barycentric weights survive until the fragment. Generic color layers
## can use conditional amounts,but partially covered biome materials must each
## evaluate from the SAME original host and then mix their complete targets.
## Single-biome source is unchanged. No duplicate original PBR evaluation.
const OUTPUTS:Array=["ALBEDO","NORMAL","EMISSION","ROUGHNESS","SPECULAR","METALLIC","AO","AO_LIGHT_AFFECT"]
static func control(weights:Vector4,slot:int,count:int)->float:
	var later:float=0
	for i in range(slot+1,count):later+=weights[i]
	return clampf(weights[slot]/maxf(1-later,.000001),0,1)
static func source(original:String,count:int,independent_targets:bool=false)->String:
	if count<=1:return original
	if count>4 or original.contains("varying vec4 cave_biome_raw_weights;"):return ""
	var declaration:int=original.find(";",original.find("render_mode "))
	if declaration<0:return ""
	var header:String="\nvarying vec4 cave_biome_raw_weights;\nfloat cave_biome_control(float own,int slot){float later=0.0;for(int i=0;i<4;i++){if(i>slot&&i<"+str(count)+")later+=cave_biome_raw_weights[i];}return clamp(own/max(1.0-later,.000001),0.0,1.0);}\n"
	if independent_targets:header="\nvarying vec4 cave_biome_raw_weights;\nfloat cave_biome_control(float own,int slot){return 1.0;}\n"
	var code:String=original.insert(declaration+1,header);var pattern:=RegEx.new();pattern.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{");var found:Array[RegExMatch]=pattern.search_all(code)
	if found.size()!=1:return ""
	return code.insert(found[0].get_end(),"\n cave_biome_raw_weights=vec4(UV,UV2);\n")
static func begin(count:int)->String:
	var expression:String="1.0"
	for i in range(count):expression+="-cave_biome_raw_weights["+str(i)+"]"
	var code:String="\nfloat cave_mix_default=max(0.0,"+expression+");\n"
	for name:String in OUTPUTS:
		var type:String="vec3" if name in ["ALBEDO","NORMAL","EMISSION"] else "float";code+=type+" cave_mix_base_"+name+"="+name+";"+type+" cave_mix_sum_"+name+"="+name+"*cave_mix_default;\n"
	return code
static func restore()->String:
	var code:String="\n"
	for name:String in OUTPUTS:code+=name+"=cave_mix_base_"+name+";"
	return code+"\n"
static func accumulate(slot:int)->String:
	var code:String="\n"
	for name:String in OUTPUTS:code+="cave_mix_sum_"+name+"+="+name+"*cave_biome_raw_weights["+str(slot)+"];"
	return code+"\n"
static func finish()->String:
	var code:String="\n"
	for name:String in OUTPUTS:code+=name+"="+("normalize(cave_mix_sum_NORMAL)" if name=="NORMAL" else "cave_mix_sum_"+name)+";"
	return code+"\n"
