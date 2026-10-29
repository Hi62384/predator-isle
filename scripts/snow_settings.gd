@tool
class_name SnowSettings
extends Resource
## Static, world-space Snow baseline. Restart terrain after editing.
@export_group("Regional Terrain")
@export_range(4000,24000,500) var region_metres:float=10000.0
@export_range(0,1,0.05) var plains_frequency:float=0.18
@export_range(0,1,0.05) var alpine_frequency:float=0.20
@export_range(0,1,0.05) var glacial_frequency:float=0.17
@export_range(0,1,0.05) var tundra_frequency:float=0.16
@export_range(300,1800,25) var mountain_height:float=1100.0
@export_range(0,1,0.05) var ruggedness:float=0.65
@export_group("Accumulation")
@export_range(0,8,0.1) var snow_depth:float=1.6
@export_range(300,3000,50) var accumulation_metres:float=900.0
@export_range(0,2,0.05) var slope_influence:float=1.0
@export_range(0,1,0.05) var wind_exposure:float=0.7
@export_range(0,2,0.05) var sheltered_accumulation:float=1.0
@export_range(0,1,0.05) var rock_exposure:float=0.65
@export_group("Wind and Drifts")
@export_range(-180,180,1) var wind_degrees:float=28.0
@export_range(0,1,0.05) var wind_variation:float=0.5
@export_range(0,1,0.05) var drift_frequency:float=0.55
@export_range(0,16,0.25) var drift_height:float=4.0
@export_range(120,1000,10) var drift_length:float=420.0
@export_range(40,300,5) var drift_width:float=105.0
@export_group("Glaciers")
@export_range(6000,20000,500) var glacier_length:float=12000.0
@export_range(400,2400,50) var glacier_width:float=1100.0
@export_range(0,1,0.05) var crevasse_amount:float=0.55
@export_range(0,1,0.05) var exposed_ice:float=0.65
@export_range(0,1,0.05) var glacier_snow_coverage:float=0.65
@export_group("Frozen Water")
@export_range(0,1,0.02) var lake_ice_coverage:float=0.82
@export_range(0,1,0.02) var river_ice_coverage:float=0.72
@export_range(0,1,0.05) var snow_on_ice:float=0.55
@export_range(0,1,0.05) var coastal_ice:float=0.35
@export_group("Materials")
@export_range(0.15,1,0.01) var albedo_gain:float=0.45
@export_range(0,2,0.05) var powder_strength:float=1.0
@export_range(0,1,0.05) var compacted_coverage:float=0.55
@export_range(0,0.3,0.01) var color_variation:float=0.06
@export_range(0.12,0.75,0.01) var ice_roughness:float=0.27
@export_range(0,2,0.05) var macro_strength:float=0.25
## Fine powder/crust source-map multiplier; the other bands are independent.
@export_range(0,2,0.05) var normal_strength:float=0.8
## Zero disables every Snow material normal overlay, but not geometric normals.
@export_range(0,2,.05) var master_normal_strength:float=1.0
@export_subgroup("Surface Scales and Normals")
@export_range(.2,12,.1) var powder_metres:float=3.0
@export_range(.5,24,.1) var crust_metres:float=5.0
@export_range(.5,24,.1) var ground_metres:float=3.8
@export_range(1,40,.5) var rock_metres:float=9.0
@export_range(1,60,.5) var ice_metres:float=12.0
@export_range(5,150,1) var wind_texture_metres:float=35.0
@export_range(0,2,.05) var crust_normal_strength:float=.8
@export_range(0,2,.05) var rock_normal_strength:float=.7
@export_range(0,2,.05) var ice_normal_strength:float=.7
@export_range(0,2,.05) var ground_normal_strength:float=.45
@export_group("Performance")
## Bound distant pure-Snow triangle edges. Zero disables this optional refinement.
@export_range(0,1024,128) var far_mesh_metres:float=512.0
## Exact Hermite derivatives on dry pure-Snow interiors; fixed 32 m fallback elsewhere.
@export var fast_normal_sampling:bool=true
## Same shading source, compiled without unrelated biome branches on certified Snow tiles.
@export var specialize_pure_snow_shader:bool=true
func uniforms()->Dictionary:
	return {"snow_master_strength":master_normal_strength,"snow_ground_strength":ground_normal_strength,"snow_powder_metres":powder_metres,"snow_crust_metres":crust_metres,"snow_ground_metres":ground_metres,"snow_rock_metres":rock_metres,"snow_crust_strength":crust_normal_strength,"snow_rock_strength":rock_normal_strength,"snow_ice_strength":ice_normal_strength,"snow_albedo_gain":albedo_gain,"snow_powder_strength":powder_strength,"snow_compacted_coverage":compacted_coverage,"snow_ice_metres":ice_metres,"snow_wind_metres":wind_texture_metres,"snow_color_variation":color_variation,"snow_ice_roughness":ice_roughness,"snow_macro_strength":macro_strength,"snow_normal_strength":normal_strength,"snow_slope_influence":slope_influence,"snow_exposed_ice":exposed_ice,"snow_glacier_snow":glacier_snow_coverage,"snow_ice_snow":snow_on_ice,"snow_wind_angle":deg_to_rad(wind_degrees),"snow_wind_variation":wind_variation}
