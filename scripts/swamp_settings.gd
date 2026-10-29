@tool
extends Resource
## Swamp terrain and local water only. Restart after editing worker settings.
@export_group("Regional Geography")
@export_range(4000,30000,500) var region_metres:float=9000
@export_range(0,1,.05) var floodplain_frequency:float=.3
@export_range(0,1,.05) var basin_frequency:float=.22
@export_range(0,1,.05) var island_density:float=.65
@export_range(0,1,.05) var raised_frequency:float=.4
@export_range(.2,3,.1) var terrain_relief:float=1.2
@export_group("Hydrology")
@export_range(0,1,.05) var water_coverage:float=.55
@export_range(.2,6,.1) var depth_variation:float=2
@export_range(0,1,.05) var channel_frequency:float=.8
@export_range(24,240,4) var channel_width:float=90
@export_range(0,1,.05) var pool_frequency:float=.6
@export_range(0,1,.05) var water_table_influence:float=.85
@export_range(0,1,.05) var floodplain_connectivity:float=.8
@export_group("Lowland Landforms")
@export_range(0,2,.1) var hummock_amplitude:float=.7
@export_range(0,1,.05) var hollow_frequency:float=.6
@export_range(.5,5,.1) var island_height:float=2.4
@export_range(0,3,.1) var levee_height:float=1.3
@export_range(0,1,.05) var erosion_intensity:float=.4
@export_range(0,1,.05) var sediment_deposition:float=.7
@export_group("Ground Materials")
@export_range(0,1,.05) var mud_coverage:float=.8
@export_range(0,1,.05) var peat_coverage:float=.7
@export_range(0,1,.05) var organic_coverage:float=.8
@export_range(0,1,.05) var sediment_coverage:float=.65
@export_range(0,1,.05) var wetness_intensity:float=.9
@export_range(0,.3,.01) var macro_variation:float=.12
@export_range(.2,3,.1) var shoreline_width:float=1.2
@export_range(.5,8,.25) var ground_metres:float=2
@export_range(0,2,.05) var normal_strength:float=.65
@export_range(.3,1.3,.05) var albedo_gain:float=.9
@export_range(0,1,.05) var exposed_season:float=.35
@export_range(0,1,.05) var path_coverage:float=.15
@export_group("Water and Performance")
@export_range(0,1,.05) var water_opacity:float=.88
@export_range(0,.08,.005) var ripple_strength:float=.015
@export_range(0,1,.05) var flood_stage:float=0
@export_range(2,3,1) var material_quality:int=3
## Local wetland interiors only; never changes canonical water coordinates.
@export_range(128,512,64) var far_mesh_metres:float=256
func uniforms()->Dictionary:
	return {"swamp_mud":mud_coverage,"swamp_peat":peat_coverage,"swamp_organic":organic_coverage,"swamp_sediment":sediment_coverage,"swamp_wetness":wetness_intensity,"swamp_macro":macro_variation,"swamp_shore_width":shoreline_width,"swamp_metres":ground_metres,"swamp_normal_strength":normal_strength,"swamp_gain":albedo_gain,"swamp_exposed_season":exposed_season,"swamp_paths":path_coverage,"swamp_quality":material_quality}

