@tool
extends Resource
## Terrain/water only. Each worker reads a private settings snapshot.
@export_group("Regional Geography")
@export_range(5000,30000,500) var region_metres:float=12000
@export_range(0,1,.05) var lowland_frequency:float=.65
@export_range(0,1,.05) var hill_frequency:float=.65
@export_range(0,1,.05) var highland_frequency:float=.45
@export_range(0,1,.05) var mountain_frequency:float=.22
@export_range(0,1,.05) var rocky_frequency:float=.35
@export_group("Landforms and Weathering")
@export_range(20,400,10) var hill_height:float=180
@export_range(500,4000,100) var hill_width:float=1800
@export_range(300,1600,50) var mountain_height:float=1000
@export_range(0,1,.05) var ridge_strength:float=.75
@export_range(0,1,.05) var valley_depth:float=.85
@export_range(0,1,.05) var erosion:float=.55
@export_range(0,1,.05) var gullies:float=.45
@export_range(0,1,.05) var weathering:float=.65
@export_range(0,1,.05) var plateau_frequency:float=.3
@export_group("Freshwater")
@export_range(0,1,.05) var river_frequency:float=.8
@export_range(0,1,.05) var stream_frequency:float=.45
@export_range(0,1,.05) var lake_frequency:float=.4
@export_range(0,1,.05) var basin_frequency:float=.45
@export_range(24,120,2) var river_width:float=45
@export_range(200,1400,50) var valley_width:float=650
## Rare rocky tributary steps use the existing terrain-feature foam renderer.
## Zero restores the pre-cascade terrain, water and payload fields exactly.
@export_range(0,1,.01) var waterfall_frequency:float=.12
@export_range(10,70,2) var waterfall_drop:float=30
@export_group("Surface Materials")
@export_range(0,1,.05) var lush_cover:float=.8
@export_range(0,1,.05) var red_soil:float=.65
@export_range(0,1,.05) var rock_exposure:float=.7
@export_range(0,1,.05) var wetness:float=.65
@export_range(0,1,.05) var weathered_rock:float=.5
@export_range(0,1,.05) var macro_variation:float=.16
@export_range(0,1,.05) var dirt_patches:float=.4
@export_range(0,1,.05) var paths:float=.3
@export_range(.5,6,.25) var ground_metres:float=2
@export_range(2,16,.25) var rock_metres:float=6
@export_range(0,2,.05) var normal_strength:float=.8
@export_range(.2,1.2,.05) var albedo_gain:float=.7
@export_group("Performance")
@export_range(128,512,64) var far_mesh_metres:float=256
## Near/mid main-river spacing; LOD4 uses twice this spacing. Zero restores
## the original LOD policy. All refinement remains capped at128 grid points.
## Does not change canonical heights, water, river routes or distant landforms.
@export_range(0,64,8) var river_detail_metres:float=32
@export_range(2,4,1) var river_detail_max_lod:int=4
@export_range(2,3,1) var material_quality:int=3
func uniforms()->Dictionary:
	return {"tropical_lush":lush_cover,"tropical_red_soil":red_soil,"tropical_rock_exposure":rock_exposure,"tropical_wetness":wetness,"tropical_weathering":weathered_rock,"tropical_macro":macro_variation,"tropical_patches":dirt_patches,"tropical_paths":paths,"tropical_ground_metres":ground_metres,"tropical_rock_metres":rock_metres,"tropical_normal_strength":normal_strength,"tropical_gain":albedo_gain,"tropical_quality":material_quality}
