@tool
extends Resource
## Terrain/material settings only. No vegetation systems are created.
@export_group("Geographic Regions")
@export_range(4000,40000,500) var region_metres:float=11000
@export_range(0,1,.05) var deciduous_frequency:float=.22
@export_range(0,1,.05) var conifer_frequency:float=.18
@export_range(0,1,.05) var mixed_frequency:float=.16
@export_range(0,1,.05) var old_growth_frequency:float=.10
@export_range(0,1,.05) var lowland_frequency:float=.35
@export_range(0,1,.05) var hill_frequency:float=.65
@export_range(0,1,.05) var mountain_frequency:float=.18
@export_range(0,1,.05) var ruggedness:float=.55
@export_range(200,1400,25) var mountain_height:float=760
@export_range(700,8000,100) var valley_scale:float=2400
@export_range(0,1,.05) var erosion_strength:float=.55
@export_range(10,200,5) var ravine_depth:float=70
@export_group("Water Terrain - Existing Sea-level Renderer")
@export_range(0,1,.05) var river_influence:float=1
@export_range(12,160,2) var river_width:float=65
@export_range(100,1500,25) var river_valley_width:float=450
@export_range(0,1,.05) var stream_density:float=.45
@export_range(0,1,.05) var lake_frequency:float=.3
@export_group("Forest Floor")
@export_range(.1,1.5,.01) var albedo_gain:float=.72
@export_range(0,1,.05) var leaf_coverage:float=.85
@export_range(0,1,.05) var needle_coverage:float=.9
@export_range(0,1,.05) var soil_exposure:float=.4
@export_range(0,1,.05) var moss_coverage:float=.55
@export_range(0,1,.05) var wetness:float=.5
@export_range(0,1,.05) var rock_exposure:float=.65
@export_range(0,1,.05) var clearing_frequency:float=.18
@export_range(0,.3,.01) var macro_variation:float=.12
@export_range(.5,10,.25) var litter_metres:float=3
@export_range(.5,12,.25) var soil_metres:float=3.5
@export_range(.5,12,.25) var moss_metres:float=3
@export_range(2,40,.25) var rock_metres:float=10
@export_range(0,2,.05) var normal_strength:float=.85
@export_range(0,2,.05) var rock_normal_strength:float=.8
@export_group("Woodland Trails")
@export_range(0,1,.05) var path_coverage:float=.55
@export_range(.5,8,.1) var path_width:float=2.8
@export_range(.3,5,.1) var path_falloff:float=1.4
@export_range(150,1500,25) var path_spacing:float=650
@export_group("Distant Geometry")
## Maximum target spacing for extra far-region detail; 128 is the slower quality option.
@export_range(0,512,32) var far_mesh_metres:float=256
func uniforms()->Dictionary:
	return {"forest_gain":albedo_gain,"forest_leaves":leaf_coverage,"forest_needles":needle_coverage,"forest_soil":soil_exposure,"forest_moss":moss_coverage,"forest_wetness":wetness,"forest_rock":rock_exposure,"forest_macro":macro_variation,"forest_litter_metres":litter_metres,"forest_soil_metres":soil_metres,"forest_moss_metres":moss_metres,"forest_rock_metres":rock_metres,"forest_normal_strength":normal_strength,"forest_rock_normal":rock_normal_strength,"forest_path_coverage":path_coverage,"forest_path_width":path_width,"forest_path_falloff":path_falloff,"forest_path_spacing":path_spacing}
