extends RefCounted
## Reuses eight distinct existing photographed PBR image pairs. This creates
## only array descriptors,not resampled/recolored replacement bitmap assets.
const COLORS="res://materials/cave_colors.tres"
const NORMALS="res://materials/cave_normals.tres"
const INSECT_COLORS="res://materials/cave_insect_colors.tres"
const INSECT_NORMALS="res://materials/cave_insect_normals.tres"
const RECORDS=[
	["Rock051","res://data/mountain_material_sources.json","massive rock","mountain_color_massive_rock","mountain_normal_Rock051"],
	["Rock042L","res://data/savanna_material_sources.json","weathered bedrock appearance","savanna_color_weathered_kopje_bedrock","savanna_normal_Rock042L"],
	["Rock055","res://data/savanna_material_sources.json","layered bedrock appearance","savanna_color_warm_layered_bedrock","savanna_normal_Rock055"],
	["Rock030","res://data/jungle_material_sources.json","granular rock","jungle_color_Rock030","jungle_normal_Rock030"],
	["Ground108","res://data/mountain_material_sources.json","talus floor","mountain_color_coarse_talus","mountain_normal_Ground108"],
	["Gravel020","res://data/jungle_material_sources.json","gravel floor","jungle_color_Gravel020","jungle_normal_Gravel020"],
	["Gravel040","res://data/mountain_material_sources.json","slate-like gravel floor","mountain_color_angular_scree","mountain_normal_Gravel040"],
	["Ground026","res://data/savanna_material_sources.json","clay floor","savanna_color_clay_hardpan","savanna_normal_Ground026"]]
static func paths(style:int,specialize_insect:bool=true)->Dictionary:
	var compact:bool=style==6 and specialize_insect;return {"colors":INSECT_COLORS if compact else COLORS,"normals":INSECT_NORMALS if compact else NORMALS,"compact":compact}
static func bind(material:ShaderMaterial,style:int,pools:Array=[],specialize_insect:bool=true)->void:
	var bank:Dictionary=paths(style,specialize_insect);material.set_shader_parameter("cave_rock_colors",load(bank.colors));material.set_shader_parameter("cave_rock_normals",load(bank.normals));material.set_shader_parameter("cave_compact_palette",bank.compact);material.set_shader_parameter("geological_style",style)
	var positions:=PackedVector4Array()
	for index in range(4):
		var pool:Dictionary=pools[index] if index<pools.size() else {};positions.append(Vector4(pool.center.x,pool.water_y,pool.center.z,pool.radius) if not pool.is_empty() else Vector4.ZERO)
	material.set_shader_parameter("cave_pool_positions",positions);material.set_shader_parameter("cave_pool_count",mini(4,pools.size()))
