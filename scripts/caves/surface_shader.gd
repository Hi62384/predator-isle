extends RefCounted
## Cave core: alternate terrain shader for decoded replacement vertices only.
## The original parent terrain shader/source and packed vertex layout stay
## untouched. Fail closed if its exact decode boundaries are not recognized.
const LAYOUT=[ ["geology_control",3],["jungle_control",3],["forest_control",3],["forest_ecology",3],["forest_geology",2],["savanna_control",3],["savanna_geology",3],["savanna_water",3],["savanna_surface",3],["swamp_control",3],["swamp_hydro",3],["swamp_land",3],["swamp_ecology",3],["mountain_control",3],["mountain_geology",3],["mountain_shape",3],["mountain_wet",1],["terrain_surface",2],["coast_control",3],["coast_sediment",1],["beach_control",2],["tropical_control",3],["badlands_control",2],["swamp_water_level",1],["UV.y",1],["COLOR",4] ]
const BEGIN:String="\n geology_control=CUSTOM0.xyz;"
const END:String="\n}\n// Shared jittered junctions"
const Extensions=preload("res://shaders/biome_extensions.gdshaderinc")
const VertexProjection=preload("res://scripts/caves/vertex_projection.gd")
static func load_texels()->String:
	var code:String="\n int surface_base=VERTEX_ID*17;\n"
	for i in range(17):code+=" vec4 surface_p%d=texelFetch(cave_surface_payload,ivec2((surface_base+%d)%%1024,(surface_base+%d)/1024),0);\n"%[i,i,i]
	return code
static func component(index:int)->String:return "surface_p%d[%d]"%[index/4,index%4]
static func uniforms(parent_space:bool=false,entry_transition:bool=false,hive_entry:bool=false)->String:
	var result:String="\nuniform sampler2D cave_surface_payload:filter_nearest,repeat_disable;\n"
	if parent_space:result+="uniform vec3 cave_parent_offset=vec3(0);\nuniform vec3 cave_parent_origin=vec3(0);\n"
	if entry_transition:
		result+="varying float cave_entry_depth;\n"
		if not hive_entry:result+="#include \"res://shaders/cave_entry_rock.gdshaderinc\"\n"
		else:result+="uniform bool cave_hive_entry_material=true;\n"
	return result
static func code(original:String,parent_space:bool=false,entry_transition:bool=false,hive_entry:bool=false,common_projection:bool=false)->String:
	if original.count(BEGIN)!=1 or original.count(END)!=1:return ""
	var begin:int=original.find(BEGIN);var end:int=original.find(END,begin)
	if end<=begin:return ""
	var replacement:String=load_texels();var offset:int=0
	for item:Array in LAYOUT:
		var arguments:Array[String]=[]
		for i in range(item[1]):arguments.append(component(offset));offset+=1
		replacement+=" "+item[0]+"="+("vec%d("%item[1] if item[1]>1 else "")+",".join(arguments)+(");\n" if item[1]>1 else ";\n")
	assert(offset==67)
	replacement+=" UV.x=swamp_water_level;forest_local_position=VERTEX"+("+cave_parent_offset" if parent_space else "")+";forest_origin="+("cave_parent_origin" if parent_space else "MODEL_MATRIX[3].xyz")+";\n"
	if entry_transition:replacement+=" cave_entry_depth=surface_p16.w;\n"
	var result:String=original.substr(0,begin).replace("void vertex() {",uniforms(parent_space,entry_transition,hive_entry)+"\nvoid vertex() {")+replacement+original.substr(end)
	if hive_entry and entry_transition:
		# Reuse the terrain's ONE existing biological sample. A second nested
		# sample in the portal blend duplicated the driver's large tissue IR
		# and exceeded the live memory budget. This cave-only expansion keeps
		# all ordinary shaders/includes untouched and works as a saved resource
		# in exports,without FileAccess reads of shader source at runtime.
		var biology:String=Extensions.code
		var coverage:String="float coverage=family==3?feature*patch*(1.0-rock*.65):.65+feature*.35;"
		var pigment:String="color=mix(color,bio*.55,clamp(coverage,0.0,1.0));rough=tissue_rough;"
		var relief:String="if(abs(denominator)>.000001)gradient-=clamp((r1*dFdx(height)+r2*dFdy(height))/denominator,vec3(-.25),vec3(.25))*extension_normals[family]*fine;"
		var include:String="#include \"res://shaders/biome_extensions.gdshaderinc\""
		if biology.count(coverage)!=1 or biology.count(pigment)!=1 or biology.count(relief)!=1 or result.count(include)!=1:return ""
		biology=biology.replace(coverage,coverage+"\n float cave_hive_amount=family==7 && cave_hive_entry_material?smoothstep(1.0,10.0,cave_entry_depth):0.0;coverage=mix(coverage,1.0,cave_hive_amount);")
		biology=biology.replace(pigment,"color=mix(color,bio*mix(.55,.5,cave_hive_amount),clamp(coverage,0.0,1.0));rough=tissue_rough;")
		biology=biology.replace(relief,"vec3 cave_hive_gradient=vec3(0);if(abs(denominator)>.000001)cave_hive_gradient=-clamp((r1*dFdx(height)+r2*dFdy(height))/denominator,vec3(-.25),vec3(.25))*extension_normals[family]*fine;gradient+=cave_hive_gradient;gradient=mix(gradient,cave_hive_gradient,cave_hive_amount);")
		result=result.replace(include,biology)
	if entry_transition:
		var final:int=result.rfind("\n}")
		if final<0:return ""
		var blend:String='''
 if(debug_view==0 && ground_debug==0 && cliff_normal_debug==0){
  float entry_amount=smoothstep(1.0,10.0,cave_entry_depth);
  if(entry_amount>.0001){
   vec3 entry_base,entry_mapped;float entry_rough;
   vec3 entry_position=forest_local_position+mod(forest_origin,vec3(3840.0));
   shade_cave_entry(entry_position,n,dFdx(entry_position),dFdy(entry_position),entry_base,entry_rough,entry_mapped);
   vec3 entry_previous=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0)).xyz);
   ALBEDO=mix(ALBEDO,entry_base,entry_amount);ROUGHNESS=mix(ROUGHNESS,entry_rough,entry_amount);SPECULAR=mix(SPECULAR,.2,entry_amount);EMISSION*=1.0-entry_amount;
   AO=mix(AO,.08,entry_amount);AO_LIGHT_AFFECT=0.0;
   NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(entry_previous,entry_mapped,entry_amount)),0)).xyz);
  }
 }
'''
		if hive_entry:blend='''
 if(debug_view==0 && ground_debug==0 && cliff_normal_debug==0){
  float entry_amount=smoothstep(1.0,10.0,cave_entry_depth);
  AO=mix(AO,.08,entry_amount);AO_LIGHT_AFFECT=0.0;EMISSION*=1.0-entry_amount;
 }
'''
		result=result.substr(0,final)+blend+result.substr(final)
	return VertexProjection.source(result) if common_projection else result
