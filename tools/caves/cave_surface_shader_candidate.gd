extends RefCounted
## PRIVATE alternate terrain shader for decoded replacement vertices only.
## The original parent terrain shader/source and packed vertex layout stay
## untouched. Fail closed if its exact decode boundaries are not recognized.
const LAYOUT=[ ["geology_control",3],["jungle_control",3],["forest_control",3],["forest_ecology",3],["forest_geology",2],["savanna_control",3],["savanna_geology",3],["savanna_water",3],["savanna_surface",3],["swamp_control",3],["swamp_hydro",3],["swamp_land",3],["swamp_ecology",3],["mountain_control",3],["mountain_geology",3],["mountain_shape",3],["mountain_wet",1],["terrain_surface",2],["coast_control",3],["coast_sediment",1],["beach_control",2],["tropical_control",3],["badlands_control",2],["swamp_water_level",1],["UV.y",1],["COLOR",4] ]
const BEGIN:String="\n geology_control=CUSTOM0.xyz;"
const END:String="\n}\n// Shared jittered junctions"
static func load_texels()->String:
	var code:String="\n int surface_base=VERTEX_ID*17;\n"
	for i in range(17):code+=" vec4 surface_p%d=texelFetch(cave_surface_payload,ivec2((surface_base+%d)%%1024,(surface_base+%d)/1024),0);\n"%[i,i,i]
	return code
static func component(index:int)->String:return "surface_p%d[%d]"%[index/4,index%4]
static func uniforms()->String:return "\nuniform sampler2D cave_surface_payload:filter_nearest,repeat_disable;\n"
static func code(original:String)->String:
	if original.count(BEGIN)!=1 or original.count(END)!=1:return ""
	var begin:int=original.find(BEGIN);var end:int=original.find(END,begin)
	if end<=begin:return ""
	var replacement:String=load_texels();var offset:int=0
	for item:Array in LAYOUT:
		var arguments:Array[String]=[]
		for i in range(item[1]):arguments.append(component(offset));offset+=1
		replacement+=" "+item[0]+"="+("vec%d("%item[1] if item[1]>1 else "")+",".join(arguments)+(");\n" if item[1]>1 else ";\n")
	assert(offset==67)
	replacement+=" UV.x=swamp_water_level;forest_local_position=VERTEX;forest_origin=MODEL_MATRIX[3].xyz;\n"
	return original.substr(0,begin).replace("void vertex() {",uniforms()+"\nvoid vertex() {")+replacement+original.substr(end)
