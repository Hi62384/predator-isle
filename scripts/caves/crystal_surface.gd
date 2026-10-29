extends RefCounted
## Cave-only adapters reuse host rock and authored mineral optics. No new
## texture IDs,unverified downloads or light nodes. Rare fictional emission
## stays separate from ordinary mineral optics and cave ambient shelter.
static var _materials:Dictionary={}
func supports_weighted_blend()->bool:return true
func validation_errors(material:Dictionary,features:Dictionary)->Array[String]:
	var result:Array[String]=[]
	var shelter=material.get("ambient_shelter",.08)
	if not (shelter is float or shelter is int) or not is_finite(float(shelter)) or float(shelter)<0 or float(shelter)>1:result.append("Invalid finite Crystal ambient_shelter")
	for setting:Array in [[material,"mineral_strength",0.0,1.0],[features,"density",0.0,1.0],[features,"giant_chance",0.0,1.0],[features,"maximum_height",1.0,40.0],[features,"geode_frequency",0.0,1.0],[features,"ravine_frequency",0.0,1.0],[features,"large_lake_frequency",0.0,1.0]]:
		var value=setting[0].get(setting[1],setting[2])
		if not (value is float or value is int) or not is_finite(float(value)) or float(value)<setting[2] or float(value)>setting[3]:result.append("Invalid finite Crystal setting "+setting[1])
	if material.has("localized_veins") and not material.localized_veins is bool:result.append("Crystal material localized_veins must be boolean")
	var ridge=features.get("floor_ridge_height",.65)
	if not (ridge is float or ridge is int) or not is_finite(float(ridge)) or float(ridge)<0 or float(ridge)>1:result.append("Invalid finite Crystal floor_ridge_height")
	for name:String in ["chamber_growth","selective_transmission","mesh_lods","geode_lining","spanning_crystals","crystal_debris","localized_veins","corridor_growth","lake_chambers","precise_shores","luminous_minerals","shallow_chambers","floor_ridges"]:
		if features.has(name) and not features[name] is bool:result.append("Crystal switch must be boolean: "+name)
	var spanning_chance=features.get("spanning_chance",.15)
	for setting:Array in [[features,"luminous_region_chance",.005,1.0],[features,"luminous_form_chance",.12,1.0],[material,"luminous_strength",0.0,.05]]:
		var value=setting[0].get(setting[1],setting[2])
		if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0 or float(value)>setting[3]:result.append("Invalid finite Crystal setting "+setting[1])
	if not (spanning_chance is float or spanning_chance is int) or not is_finite(float(spanning_chance)) or float(spanning_chance)<0 or float(spanning_chance)>1:result.append("Invalid finite Crystal setting spanning_chance")
	for setting:Array in [[features,"debris_chance"],[material,"sediment_strength"]]:
		var amount=setting[0].get(setting[1],0.0)
		if not (amount is float or amount is int) or not is_finite(float(amount)) or float(amount)<0 or float(amount)>1:result.append("Invalid finite Crystal setting "+setting[1])
	if float(features.get("geode_frequency",.15))+float(features.get("ravine_frequency",.08))>1.0:result.append("Geode and ravine room frequencies must sum to at most1")
	return result
func source(original:String,slot:int,entry:bool)->String:
	if slot<0 or slot>3 or original.contains("varying float cave_crystal_weight;"):return ""
	var rock:bool=original.contains("varying vec3 cave_position;")
	if not rock and not (entry and original.contains("varying vec3 forest_local_position;")):return ""
	var code:String=original;var declaration:int=code.find(";",code.find("render_mode "))
	if declaration<0:return ""
	code=code.insert(declaration+1,"\n#include \"res://shaders/cave_crystal_surface.gdshaderinc\"\nuniform float cave_crystal_mineral_strength=.65;\nvarying float cave_crystal_weight;\n")
	var pattern:=RegEx.new();pattern.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{");var found:Array[RegExMatch]=pattern.search_all(code)
	if found.size()!=1:return ""
	code=code.insert(found[0].get_end(),"\n cave_crystal_weight="+["UV.x","UV.y","UV2.x","UV2.y"][slot]+";\n");var final:int=code.rfind("}")
	if final<0:return ""
	var p:String="cave_position" if rock else "(forest_local_position+mod(forest_origin,vec3(3840.0)))";var amount:String="cave_biome_control(cave_crystal_weight,"+str(slot)+")" if original.contains("float cave_biome_control(") else "clamp(cave_crystal_weight,0.0,1.0)"
	if entry:amount+="*smoothstep(1.0,10.0,cave_entry_depth)"
	code=code.insert(final,"\n float crystal_amount="+amount+";if(crystal_amount>.00001){float crystal_vein=cave_crystal_vein("+p+");float crystal_replace=crystal_amount*cave_crystal_mineral_strength*(.10+.70*crystal_vein);vec3 crystal_rock=ALBEDO;vec3 crystal_min=vec3(.67,.66,.59)*mix(.65,1.0,crystal_vein);ALBEDO=mix(crystal_rock,crystal_min,crystal_replace);ROUGHNESS=mix(ROUGHNESS,.27,crystal_replace);SPECULAR=mix(SPECULAR,.40,crystal_replace);EMISSION*=1.0-crystal_replace;}\n")
	if rock:
		code=code.insert(code.find("varying float cave_crystal_weight;"),"uniform float cave_crystal_sediment_strength=0.0;\n")
		code=code.insert(code.rfind("}"),"\n if(cave_crystal_sediment_strength>.00001){vec3 crystal_floor_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);float crystal_sediment=crystal_amount*cave_crystal_sediment_strength*smoothstep(.65,.94,crystal_floor_normal.y)*smoothstep(.4,.7,ROUGHNESS)*cave_crystal_sediment(cave_position);if(crystal_sediment>.00001){ALBEDO=mix(ALBEDO,vec3(.52,.49,.42),crystal_sediment);ROUGHNESS=mix(ROUGHNESS,.83,crystal_sediment);SPECULAR=mix(SPECULAR,.22,crystal_sediment);}}\n")
	return code
func bind(material:ShaderMaterial,configuration:Dictionary)->void:
	material.set_shader_parameter("cave_crystal_mineral_strength",clampf(float(configuration.get("mineral_strength",.65)),0,1));material.set_shader_parameter("cave_crystal_sediment_strength",clampf(float(configuration.get("sediment_strength",0)),0,1))
	material.set_shader_parameter("cave_crystal_localized_veins",bool(configuration.get("localized_veins",true)))
func feature_material(kind:String,configuration:Dictionary,common:bool)->ShaderMaterial:
	if kind not in ["mineral_opaque","mineral_clear","mineral_grains","mineral_bed"]:return null
	var key:String=kind+str(configuration)+str(common)
	if _materials.has(key):return _materials[key]
	var shader:Shader=load("res://shaders/cave_crystal_feature.gdshader")
	if kind=="mineral_clear":
		shader=shader.duplicate();shader.code=shader.code.replace("varying vec3 crystal_position;","uniform sampler2D cave_crystal_scene:hint_screen_texture,filter_linear_mipmap,repeat_disable;\nvarying vec3 crystal_position;")
		shader.code=shader.code.replace("// SELECTIVE_NEAR_TRANSMISSION","vec3 n=normalize(NORMAL),incident=-normalize(VIEW);float incidence=max(dot(-incident,n),0.0);float fresnel=f0+(1.0-f0)*pow(1.0-incidence,5.0);vec3 through=mineral_throughput(kind,UV.y,incidence,COLOR.rgb)*(1.0-fresnel);vec3 ray=refract(incident,n,1.0/mineral_ior(kind));vec2 shift=ray.xy/max(abs(ray.z),.35)*.004*clamp(UV.y/4.0,.05,1.0);vec3 behind=textureLod(cave_crystal_scene,clamp(SCREEN_UV+shift,vec2(.002),vec2(.998)),kind==2?1.5:0.5).rgb;ALBEDO*=1.0-dot(through,vec3(.3,.5,.2));EMISSION=behind*through;")
	var result:=ShaderMaterial.new();result.shader=shader;result.set_shader_parameter("cave_common_projection",common);result.set_shader_parameter("cave_crystal_bed",kind=="mineral_bed")
	result.set_shader_parameter("cave_crystal_luminous_strength",configuration.get("luminous_strength",0.0))
	result.set_shader_parameter("cave_crystal_ambient_shelter",configuration.get("ambient_shelter",.08))
	if _materials.size()>=8:_materials.erase(_materials.keys()[0])
	_materials[key]=result;return result
