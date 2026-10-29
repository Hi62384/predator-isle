@tool
class_name JungleSettings
extends Resource
## Static worker snapshot; restart the scene after editing.
@export_group("Regional Geography")
@export_range(4000,40000,500) var region_metres:float=14000
@export_range(0,1,.05) var lowland_frequency:float=.25
@export_range(0,1,.05) var mountain_frequency:float=.18
@export_range(0,1,.05) var plateau_frequency:float=.10
@export_range(0,1,.05) var hill_density:float=.65
@export_range(0,1,.05) var ruggedness:float=.6
@export_range(200,1400,25) var mountain_height:float=780
@export_group("Erosion")
@export_range(0,1,.05) var erosion_strength:float=.65
@export_range(20,250,5) var valley_depth:float=110
@export_range(0,1,.05) var tributary_density:float=.65
@export_range(0,1,.05) var gully_frequency:float=.6
@export_group("Hydrology")
## Corridor influence on the shared world river network (0 disables it).
@export_range(0,1,.05) var river_frequency:float=1.0
@export_range(0,1,.05) var stream_density:float=.6
@export_range(150,1500,25) var river_valley_width:float=620
@export_range(8,160,2) var river_width:float=90
@export_range(0,1,.05) var lake_frequency:float=.3
@export_range(0,1,.05) var floodplain_influence:float=.7
@export_group("Materials")
@export_range(.1,1,.01) var albedo_gain:float=.9
## Living ground cover color; mud and rock retain independent colors.
@export var green_tint:Color=Color(.22,.56,.075,1)
@export_range(0,1,.01) var green_coverage:float=.96
@export_range(0,1,.05) var organic_soil:float=.65
@export_range(0,1,.05) var leaf_litter:float=.75
@export_range(0,1,.05) var mud_coverage:float=.55
@export_range(0,1,.05) var moss_coverage:float=.65
@export_range(0,1,.05) var rock_exposure:float=.65
@export_range(0,1,.05) var wetness_variation:float=.65
@export_range(0,.3,.01) var macro_variation:float=.12
@export_range(.3,12,.1) var ground_metres:float=3.0
@export_range(2,60,.5) var rock_metres:float=12.0
@export_range(0,2,.05) var normal_strength:float=.9
@export_range(0,2,.05) var rock_normal_strength:float=.8
@export_group("Distant Geometry")
## Preserve regional relief/river corridors without changing view distance. 0 uses legacy mesh density.
@export_range(0,512,32) var far_mesh_metres:float=128
@export_group("Vegetation Hooks - No Renderer Installed")
@export_range(0,1,.05) var canopy_density:float=.8
@export_range(0,.15,.01) var emergent_frequency:float=.04
@export_range(0,1,.05) var understory_density:float=.55
@export_range(0,1,.05) var ground_cover_density:float=.7
@export_range(0,.6,.02) var clearing_frequency:float=.12
func uniforms()->Dictionary:
	return {"jungle_green_tint":Vector3(green_tint.srgb_to_linear().r,green_tint.srgb_to_linear().g,green_tint.srgb_to_linear().b),"jungle_green_coverage":green_coverage,"jungle_albedo_gain":albedo_gain,"jungle_organic":organic_soil,"jungle_litter":leaf_litter,"jungle_mud":mud_coverage,"jungle_moss":moss_coverage,"jungle_rock":rock_exposure,"jungle_macro":macro_variation,"jungle_ground_metres":ground_metres,"jungle_rock_metres":rock_metres,"jungle_normal_strength":normal_strength,"jungle_rock_normal":rock_normal_strength,"jungle_canopy":canopy_density,"jungle_clearing":clearing_frequency}
