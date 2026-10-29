extends RefCounted
static var _feature_materials:Dictionary={}
static var _feature_textures:Dictionary={}
func supports_weighted_blend()->bool:return true
func validation_errors(material:Dictionary,features:Dictionary)->Array[String]:
	var errors:Array[String]=[]
	for pair:Array in [[material,"cooled_strength"],[features,"density"]]:
		var value=pair[0].get(pair[1],.65)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>1:errors.append("Magma "+pair[1]+" must be finite0–1")
	var chance=features.get("active_pool_chance",.14)
	if not (chance is float or chance is int) or not is_finite(float(chance)) or chance<0 or chance>1:errors.append("Magma active_pool_chance must be finite0–1")
	for id:String in ["chamber_growth","mesh_lods","source_heat","geological_intrusions","cooled_tubes","large_lake_chambers","cooled_deposits","cooled_intrusions","chamber_variety","molten_cascades"]:
		if features.has(id) and not features[id] is bool:errors.append("Magma "+id+" must be boolean")
	var lake_chance=features.get("large_lake_chance",.08)
	if not (lake_chance is float or lake_chance is int) or not is_finite(float(lake_chance)) or lake_chance<0 or lake_chance>1:errors.append("Magma large_lake_chance must be finite0–1")
	var energy=material.get("lava_light_energy",.9)
	if not (energy is float or energy is int) or not is_finite(float(energy)) or energy<0 or energy>2:errors.append("Magma lava_light_energy must be finite0–2")
	if material.has("lava_lighting") and not material.lava_lighting is bool:errors.append("Magma lava_lighting must be boolean")
	var deposits=features.get("deposit_height",.45)
	if not (deposits is float or deposits is int) or not is_finite(float(deposits)) or deposits<0 or deposits>.6:errors.append("Magma deposit_height must be finite0–0.6m")
	var cascade_chance=features.get("molten_cascade_chance",.06)
	if not (cascade_chance is float or cascade_chance is int) or not is_finite(float(cascade_chance)) or cascade_chance<0 or cascade_chance>1:errors.append("Magma molten_cascade_chance must be finite0–1")
	for specification:Array in [[material,"lava_emission_strength",1.9,4.0],[material,"lava_animation_speed",1.0,4.0],[material,"lava_crust_strength",1.0,1.0],[material,"lava_normal_strength",1.0,1.0],[features,"column_frequency",.75,1.0],[features,"obsidian_lens_chance",.12,1.0],[features,"tube_frequency",1.0,1.0],[features,"fissure_frequency",.12,1.0],[features,"intrusion_frequency",.55,1.0],[features,"lava_drip_frequency",.1,1.0]]:
		var value=specification[0].get(specification[1],specification[2])
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>specification[3]:errors.append("Magma "+str(specification[1])+" must be finite0–"+str(specification[3]))
	var quality=material.get("lava_detail_quality",1)
	if not quality is int or quality<0 or quality>2:errors.append("Magma lava_detail_quality must be integer0–2")
	return errors
func create_runtime_controller(configuration:Dictionary):
	if not configuration.get("lava_lighting",true) or float(configuration.get("lava_light_energy",.9))<=0:return null
	var controller=preload("res://scripts/caves/magma_lighting.gd").new();controller.configure(configuration);return controller
func source(original:String,slot:int,entry:bool)->String:
	if slot<0 or slot>3 or original.contains("varying float cave_magma_weight;"):return ""
	var rock:bool=original.contains("varying vec3 cave_position;")
	if not rock and not (entry and original.contains("varying vec3 forest_local_position;")):return ""
	var code:String=original;var declaration:int=code.find(";",code.find("render_mode "))
	if declaration<0:return ""
	code=code.insert(declaration+1,"\n#include \"res://shaders/cave_magma_surface.gdshaderinc\"\nuniform float cave_magma_cooled_strength=.85;\nvarying float cave_magma_weight;\n")
	var pattern:=RegEx.new();pattern.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{");var found:Array[RegExMatch]=pattern.search_all(code)
	if found.size()!=1:return ""
	code=code.insert(found[0].get_end(),"\n cave_magma_weight="+["UV.x","UV.y","UV2.x","UV2.y"][slot]+";\n")
	var amount:String="cave_biome_control(cave_magma_weight,"+str(slot)+")" if original.contains("float cave_biome_control(") else "clamp(cave_magma_weight,0.0,1.0)"
	if entry:amount+="*smoothstep(1.0,10.0,cave_entry_depth)"
	var position:String="cave_position" if rock else "forest_local_position"
	code=code.insert(code.rfind("}"),"\n float magma_cooled="+amount+"*cave_magma_cooled_strength;if(magma_cooled>.00001){magma_cooled_surface("+position+",magma_cooled,VERTEX,ALBEDO,NORMAL,ROUGHNESS,SPECULAR,EMISSION);}\n")
	return code
func bind(material:ShaderMaterial,configuration:Dictionary)->void:material.set_shader_parameter("cave_magma_cooled_strength",configuration.get("cooled_strength",.85))
func feature_material(kind:String,configuration:Dictionary,common:bool)->ShaderMaterial:
	if kind not in ["cooled_volcanic","molten_volcanic"]:return null
	var key:String=kind+str(common)+var_to_bytes(configuration).hex_encode()
	if _feature_materials.has(key):return _feature_materials[key]
	var material:=ShaderMaterial.new();material.shader=load("res://shaders/cave_magma_molten.gdshader" if kind=="molten_volcanic" else "res://shaders/cave_magma_cooled.gdshader")
	if kind=="cooled_volcanic":
		# Reuse the existing CC0 photographed massive-rock PBR input. This is
		# appearance detail,not a claim that Rock051 is geological basalt.
		if _feature_textures.is_empty():
			_feature_textures["volcanic_color"]=ImageTexture.create_from_image(load("res://materials/mountain_color_massive_rock.res"));_feature_textures["volcanic_normal"]=ImageTexture.create_from_image(load("res://materials/cave_normal_Rock051.res"))
		for parameter:String in _feature_textures:material.set_shader_parameter(parameter,_feature_textures[parameter])
	else:
		for parameter:String in ["lava_emission_strength","lava_animation_speed","lava_crust_strength","lava_normal_strength","lava_detail_quality"]:
			material.set_shader_parameter(parameter,configuration.get(parameter,{"lava_emission_strength":1.9,"lava_animation_speed":1.0,"lava_crust_strength":1.0,"lava_normal_strength":1.0,"lava_detail_quality":1}[parameter]))
	material.set_shader_parameter("cave_common_projection",common)
	while _feature_materials.size()>=16:_feature_materials.erase(_feature_materials.keys()[0])
	_feature_materials[key]=material;return material
