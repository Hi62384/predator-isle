@tool
extends Resource
## Terrain only. Season is a material state, never a height input.
@export_group("Regional Geography")
@export_range(4000,40000,500) var region_metres:float=12000
@export_range(0,1,.05) var plains_frequency:float=.3
@export_range(0,1,.05) var rolling_frequency:float=.2
@export_range(0,1,.05) var rocky_frequency:float=.15
@export_range(0,1,.05) var highland_frequency:float=.12
@export_range(0,1,.05) var basin_frequency:float=.14
@export_range(150,1400,25) var mountain_height:float=740
@export_range(0,1,.05) var ridge_intensity:float=.65
@export_group("Weathered Bedrock")
@export_range(0,1,.05) var kopje_frequency:float=.4
@export_range(100,450,10) var kopje_size:float=240
@export_range(0,1,.05) var kopje_ruggedness:float=.6
@export_range(0,1,.05) var bedrock_exposure:float=.8
@export_group("Drainage and Basins")
@export_range(0,1,.05) var drainage_strength:float=.8
@export_range(0,1,.05) var erosion_intensity:float=.6
@export_range(0,1,.05) var gully_frequency:float=.45
@export_range(100,1400,25) var valley_width:float=500
@export_range(0,1,.05) var perennial_frequency:float=.25
@export_range(0,1,.05) var seasonal_channel_frequency:float=.75
@export_range(0,1,.05) var basin_water_coverage:float=.2
@export_group("Season and Ground")
## 0 dry, 1 wet. Appearance only: geography and water beds stay canonical.
@export_range(0,1,.05) var season:float=.18
@export_range(.2,1.5,.01) var albedo_gain:float=.85
@export_range(0,1,.05) var dry_ground_coverage:float=.85
@export_range(0,1,.05) var green_ground_coverage:float=.75
@export_range(0,1,.05) var red_soil_exposure:float=.6
@export_range(0,1,.05) var gravel_coverage:float=.55
@export_range(0,1,.05) var rocky_soil:float=.65
@export_range(0,1,.05) var dirt_patch_frequency:float=.4
@export_range(0,.25,.01) var macro_variation:float=.1
@export_range(.5,12,.25) var ground_metres:float=3
@export_range(2,40,.25) var rock_metres:float=9
@export_range(0,2,.05) var normal_strength:float=.8
@export_range(0,2,.05) var rock_normal_strength:float=.8
@export_range(0,1,.05) var rock_macro_strength:float=.4
@export_range(.2,1.2,.05) var rock_albedo_gain:float=.65
@export_group("Worn Trails")
@export_range(0,1,.05) var path_frequency:float=.25
@export_range(.5,6,.25) var path_width:float=2.5
@export_range(250,2000,50) var path_spacing:float=1000
@export_group("Performance")
## 2 or 3 active materials, not all palette layers per pixel.
@export_range(2,3,1) var material_quality:int=3
## Extra far geometry only in certified Savanna interiors; 0 disables it.
@export_range(0,512,32) var far_mesh_metres:float=256
func uniforms()->Dictionary:
	return {"savanna_season":season,"savanna_gain":albedo_gain,"savanna_dry_cover":dry_ground_coverage,"savanna_green_cover":green_ground_coverage,"savanna_red_soil":red_soil_exposure,"savanna_gravel":gravel_coverage,"savanna_rocky_soil":rocky_soil,"savanna_patch":dirt_patch_frequency,"savanna_macro":macro_variation,"savanna_ground_metres":ground_metres,"savanna_rock_metres":rock_metres,"savanna_normal_strength":normal_strength,"savanna_rock_normal":rock_normal_strength,"savanna_path_frequency":path_frequency,"savanna_path_width":path_width,"savanna_path_spacing":path_spacing,"savanna_quality":material_quality,"savanna_bedrock":bedrock_exposure,"savanna_rock_macro":rock_macro_strength,"savanna_rock_gain":rock_albedo_gain}
