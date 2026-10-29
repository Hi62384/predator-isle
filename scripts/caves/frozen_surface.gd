extends RefCounted
## Main-thread source/material adapter;does not replace the terrain renderer.
const INCLUDE:String="\n#include \"res://shaders/cave_frozen_surface.gdshaderinc\"\nuniform vec4 cave_frozen_water_sources[8];\nuniform int cave_frozen_water_source_count=0;\nvarying float cave_frozen_weight;\nvarying vec3 cave_frozen_texture_position;\n"
static var _feature_materials:Dictionary={}
func supports_weighted_blend()->bool:return true
func validation_errors(material:Dictionary,features:Dictionary)->Array[String]:
	var result:Array[String]=[]
	for setting:Array in [[material,"texture_metres",.5,20.0],[material,"normal_strength",0.0,2.0],[features,"density",0.0,1.0],[features,"curtain_chance",0.0,1.0],[features,"lake_radius_multiplier",1.0,3.0],[features,"lake_radius_minimum",3.0,12.0],[features,"lake_radius_maximum",3.0,12.0]]:
		if not setting[0].has(setting[1]):continue
		var value=setting[0][setting[1]]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)<setting[2] or float(value)>setting[3]:result.append("Invalid finite Frozen setting "+setting[1])
	for name:String in ["lake_ice","large_lakes","smooth_normals"]:
		if features.has(name) and not features[name] is bool:result.append("Frozen switch must be boolean: "+name)
	var low=features.get("lake_radius_minimum",8);var high=features.get("lake_radius_maximum",12)
	if (low is int or low is float) and (high is int or high is float) and float(high)<float(low):result.append("Frozen lake radius bounds must be ordered")
	return result
func feature_material(kind:String,configuration:Dictionary,common:bool)->ShaderMaterial:
	if kind not in ["ice","thin_ice"]:return null
	var key:String=kind+str(configuration)+str(common)
	if _feature_materials.has(key):return _feature_materials[key]
	var shader:Shader=load("res://shaders/cave_frozen_feature.gdshader")
	if kind=="thin_ice":
		shader=shader.duplicate();shader.code=shader.code.replace("specular_schlick_ggx;","specular_schlick_ggx,depth_prepass_alpha;");var final:int=shader.code.rfind("}");shader.code=shader.code.insert(final,"\n ALPHA=.82;\n")
	var result:=ShaderMaterial.new();result.shader=shader;bind(result,configuration);result.set_shader_parameter("cave_common_projection",common)
	if _feature_materials.size()>=8:_feature_materials.erase(_feature_materials.keys()[0])
	_feature_materials[key]=result;return result
func source(original:String,slot:int,entry:bool)->String:
	if slot<0 or slot>3 or original.contains("varying float cave_frozen_weight;"):return ""
	var rock:bool=original.contains("varying vec3 cave_position;")
	if not rock and not (entry and original.contains("varying vec3 forest_local_position;")):return ""
	var code:String=original;var header:int=code.find("render_mode ");var declaration:int=code.find(";",header)
	if header<0 or declaration<0:return ""
	code=code.insert(declaration+1,INCLUDE);var pattern:=RegEx.new();pattern.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{");var found:Array[RegExMatch]=pattern.search_all(code)
	if found.size()!=1:return ""
	code=code.insert(found[0].get_end(),"\n cave_frozen_weight="+["UV.x","UV.y","UV2.x","UV2.y"][slot]+";\n cave_frozen_texture_position=VERTEX+mod(MODEL_MATRIX[3].xyz,vec3(max(cave_frozen_texture_metres,.5)));\n");var final:int=code.rfind("}")
	if final<0:return ""
	var p:String="cave_position" if rock else "(forest_local_position+mod(forest_origin,vec3(3840.0)))";var normal:String="normalize(cave_normal)" if rock else "normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz)";var amount:String="clamp(cave_frozen_weight,0.0,1.0)"+("*smoothstep(1.0,10.0,cave_entry_depth)" if entry else "")
	if original.contains("float cave_biome_control("):amount=amount.replace("clamp(cave_frozen_weight,0.0,1.0)","cave_biome_control(cave_frozen_weight,"+str(slot)+")")
	var world:String="cave_world" if rock else "(forest_local_position+forest_origin)"
	var blend:String="\n vec3 frozen_p="+p+",frozen_n="+normal+";vec3 frozen_dx=dFdx(frozen_p),frozen_dy=dFdy(frozen_p);float frozen_amount="+amount+";if(frozen_amount>.00001){float frozen_moisture=0.0;for(int i=0;i<8;i++){if(i>=cave_frozen_water_source_count)break;vec4 water=cave_frozen_water_sources[i];frozen_moisture=max(frozen_moisture,1.0-smoothstep(water.w+10.0,water.w+72.0,length("+world+"-water.xyz)));}float frozen_crust=(.12+.86*frozen_moisture)*mix(.45,1.0,smoothstep(.25,.8,abs(frozen_n.y)));frozen_amount*=frozen_crust;vec3 frozen_base,frozen_mapped;float frozen_rough;cave_frozen_sample(frozen_p,frozen_n,frozen_dx,frozen_dy,frozen_base,frozen_rough,frozen_mapped);vec3 frozen_previous=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);ALBEDO=mix(ALBEDO,frozen_base,frozen_amount);ROUGHNESS=mix(ROUGHNESS,frozen_rough,frozen_amount);SPECULAR=mix(SPECULAR,.28,frozen_amount);NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(frozen_previous,frozen_mapped,frozen_amount)),0.0)).xyz);EMISSION*=1.0-frozen_amount;}\n"
	blend=blend.replace("cave_frozen_sample(frozen_p,frozen_n,","cave_frozen_sample(frozen_p,cave_frozen_texture_position,frozen_n,")
	return code.insert(final,blend)
func bind_context(material:ShaderMaterial,context:Dictionary)->void:
	var sources:=PackedVector4Array();var pools:Array=preload("res://scripts/caves/material_palette.gd").water_sources(context.get("pools",[]))
	for i in range(8):
		var pool:Dictionary=pools[i] if i<pools.size() else {};sources.append(Vector4(pool.center.x,pool.water_y,pool.center.z,pool.radius) if not pool.is_empty() else Vector4.ZERO)
	material.set_shader_parameter("cave_frozen_water_sources",sources);material.set_shader_parameter("cave_frozen_water_source_count",mini(8,pools.size()))
func bind(material:ShaderMaterial,configuration:Dictionary)->void:
	material.set_shader_parameter("cave_frozen_colors",load("res://materials/cave_frozen_colors.tres"));material.set_shader_parameter("cave_frozen_normals",load("res://materials/cave_frozen_normals.tres"));material.set_shader_parameter("cave_frozen_texture_metres",clampf(float(configuration.get("texture_metres",6)),.5,20));material.set_shader_parameter("cave_frozen_normal_strength",clampf(float(configuration.get("normal_strength",.35)),0,2))
