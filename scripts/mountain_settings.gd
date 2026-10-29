@tool
extends Resource
## Mountain terrain only; immutable worker snapshot. Metres, not arbitrary noise amplitude.
@export_group("Geological Regions")
@export_range(8000,40000,500) var region_metres:float=16000
@export_range(600,3200,50) var mountain_height:float=1800
@export_range(.3,2,.05) var belt_width:float=1
@export_range(0,1,.05) var ruggedness:float=.65
@export_range(0,1,.05) var highland_frequency:float=.25
@export_range(0,1,.05) var glacial_frequency:float=.25
@export_group("Ridges and Valleys")
@export_range(.5,3,.1) var ridge_scale:float=1.8
@export_range(400,2400,50) var ridge_width:float=1250
@export_range(.5,2,.05) var ridge_sharpness:float=1.1
@export_range(0,1,.05) var secondary_strength:float=.65
@export_range(0,1,.05) var branching:float=.65
@export_range(1800,7000,100) var peak_spacing:float=3400
@export_range(200,1800,50) var valley_width:float=650
@export_range(0,1,.05) var valley_depth:float=.8
@export_range(0,1,.05) var glacial_influence:float=.85
@export_range(0,1,.05) var basin_frequency:float=.4
@export_group("Rock Faces and Deposits")
@export_range(0,1,.05) var cliff_frequency:float=.6
@export_range(256,900,16) var cliff_width:float=420
@export_range(0,1,.05) var erosion:float=.6
@export_range(0,1,.05) var gully_strength:float=.5
@export_range(160,900,20) var erosion_scale:float=360
@export_range(0,1,.05) var weathering:float=.5
@export_range(0,1,.05) var scree_coverage:float=.75
@export_range(200,1000,20) var talus_size:float=500
@export_group("Water")
@export_range(0,1,.05) var river_frequency:float=.65
@export_range(12,100,2) var river_width:float=34
@export_range(0,1,.05) var lake_frequency:float=.4
@export_group("Materials")
@export_range(0,1,.05) var rock_exposure:float=.85
@export_range(0,1,.05) var geology_variation:float=.6
@export_range(0,1,.05) var soil_coverage:float=.55
@export_range(0,1,.05) var alpine_coverage:float=.65
@export_range(0,1,.05) var wetness:float=.6
@export_range(.5,16,.25) var rock_metres:float=5
@export_range(.5,6,.25) var ground_metres:float=2
@export_range(0,2,.05) var normal_strength:float=.8
@export_range(0,1,.05) var macro_normal_strength:float=.38
@export_range(0,1,.05) var meso_normal_strength:float=.45
@export_range(.2,1.3,.05) var albedo_gain:float=.45
@export_range(0,1,.05) var path_coverage:float=.1
@export_group("Performance")
@export_range(128,512,64) var far_mesh_metres:float=256
@export_range(2,3,1) var material_quality:int=3
func uniforms()->Dictionary:
	return {"mountain_rock_exposure":rock_exposure,"mountain_geology_variation":geology_variation,"mountain_soil":soil_coverage,"mountain_alpine":alpine_coverage,"mountain_wetness":wetness,"mountain_rock_metres":rock_metres,"mountain_ground_metres":ground_metres,"mountain_normal_strength":normal_strength,"mountain_macro_strength":macro_normal_strength,"mountain_meso_strength":meso_normal_strength,"mountain_gain":albedo_gain,"mountain_paths":path_coverage,"mountain_quality":material_quality,"mountain_scree_cover":scree_coverage}
