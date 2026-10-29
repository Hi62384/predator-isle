@tool
extends Resource
## Coastal overlay: does not compete for inland biome ownership.
@export_group("Coastal geography")
@export_range(0,1,.05) var coverage:float=.72
@export_range(2000,20000,500) var region_metres:float=6500
@export_range(400,2000,50) var influence_width:float=1100
@export_range(0,1,.05) var headlands:float=.7
@export_range(600,5000,100) var bay_scale:float=1800
@export_range(0,1,.05) var inlet_frequency:float=.5
@export_range(0,1,.05) var ruggedness:float=.65
@export_group("Sea cliffs and offshore rock")
@export_range(0,1,.05) var cliff_frequency:float=.75
@export_range(80,450,10) var cliff_height:float=260
@export_range(64,300,8) var cliff_width:float=120
@export_range(0,1,.05) var erosion:float=.65
@export_range(0,1,.05) var stack_frequency:float=.22
@export_range(64,200,8) var stack_size:float=100
@export_group("Platforms and pools")
@export_range(0,1,.05) var platform_frequency:float=.7
@export_range(64,400,16) var platform_width:float=200
@export_range(.2,3,.1) var platform_relief:float=.8
@export_range(0,1,.05) var pool_frequency:float=.55
@export_range(12,48,2) var pool_size:float=26
@export_range(.2,2,.1) var pool_depth:float=.8
@export_group("Materials")
@export_range(0,1,.05) var wetness:float=.85
@export_range(0,1,.05) var shingle:float=.75
@export_range(.2,1,.05) var albedo_gain:float=.6
@export_range(1,12,.25) var rock_metres:float=5
@export_range(0,2,.05) var normal_strength:float=.8
@export_range(0,1,.05) var macro_strength:float=.5
@export_range(0,1,.05) var salt_exposure:float=.35
@export_group("Performance")
@export_range(64,128,32) var far_mesh_metres:float=128
@export_range(2,3,1) var material_quality:int=3
func uniforms()->Dictionary:
	return {"coast_wetness":wetness,"coast_shingle":shingle,"coast_gain":albedo_gain,"coast_rock_metres":rock_metres,"coast_normal_strength":normal_strength,"coast_macro_strength":macro_strength,"coast_salt":salt_exposure,"coast_quality":material_quality}
