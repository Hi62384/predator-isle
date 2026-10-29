@tool
extends Resource
## Sedimentary terrain only. No hydraulic simulation or independent rock objects.
@export_group("Geological Provinces")
@export_range(3000,20000,500) var region_metres:float=7000
@export_range(0,1,.05) var painted_frequency:float=.65
@export_range(0,1,.05) var rugged_frequency:float=.65
@export_range(0,1,.05) var clay_frequency:float=.7
@export_range(0,1,.05) var basin_frequency:float=.4
@export_group("Relief and Erosion")
@export_range(.2,2,.05) var relief:float=1
## Province-specific painted/clay hill rhythms; zero restores the prior mass profile.
@export_range(0,1,.05) var rounded_hill_strength:float=.75
@export_range(.1,1,.05) var erosion:float=.85
@export_range(.3,2,.05) var ridge_sharpness:float=1
@export_range(1000,4000,100) var drainage_spacing:float=1400
@export_range(0,1,.05) var secondary_gullies:float=.75
@export_range(30,160,5) var wash_width:float=65
@export_range(0,1,.05) var ledges:float=.65
@export_range(0,1,.05) var remnants:float=.5
@export_range(20,100,5) var remnant_height:float=65
@export_range(0,1,.05) var fans:float=.65
## Finite flaring aprons aligned with feeder valleys; zero restores the old
## symmetric fan footprint and floor blending exactly.
@export_range(0,1,.05) var fan_shape_strength:float=1
## Depositional rise toward the actual feeder throat, in metres per horizontal
## metre. Zero preserves the previous apron heights exactly. Wash floors are
## protected independently; overlapping fans use a bounded weighted mean.
@export_range(0,.08,.005) var fan_gradient:float=.025
@export_range(0,.15,.01) var pool_frequency:float=.03
@export_group("Sedimentary Materials")
@export_range(40,180,5) var strata_metres:float=84
## Bed reference scale; the unequal five-unit sequence spans 1.75 times this.
@export_range(0,.35,.01) var thickness_variation:float=.16
## Metres of bed elevation change per horizontal metre; not camera-dependent.
@export var strata_dip:Vector2=Vector2(.018,.012)
@export_range(0,2,.05) var fold_strength:float=1
@export_range(0,1,.05) var strata_strength:float=.75
## Subordinate fine sediment beds on exposed faces; filtered before subpixel scale.
@export_range(0,1,.05) var lamina_strength:float=.18
## Regional mineral palette on flat clay/pale provinces, independent of band contrast.
@export_range(0,1,.05) var regional_color_strength:float=.85
@export_range(0,1,.05) var weathering:float=.4
@export_range(0,1,.05) var gravel:float=.65
@export_range(.5,6,.25) var ground_metres:float=2
@export_range(2,16,.25) var rock_metres:float=6
@export_range(0,2,.05) var normal_strength:float=.75
@export_range(.2,1.2,.05) var albedo_gain:float=.55
@export_group("Performance")
@export_range(64,256,32) var far_mesh_metres:float=256
## Local refinement for dissected ridges/caprock only; calm regions keep baseline density.
@export_range(64,256,32) var dissected_mesh_metres:float=64
## Compact caprock needs finer sampling only in its own geological province.
@export_range(8,64,8) var remnant_mesh_metres:float=16
@export_range(2,3) var material_quality:int=3
func uniforms()->Dictionary:
	return {"badlands_strata_metres":strata_metres,"badlands_thickness_variation":thickness_variation,"badlands_strata_dip":strata_dip,"badlands_fold_strength":fold_strength,"badlands_strata_strength":strata_strength,"badlands_lamina_strength":lamina_strength,"badlands_regional_strength":regional_color_strength,"badlands_weathering":weathering,"badlands_gravel":gravel,"badlands_ground_metres":ground_metres,"badlands_rock_metres":rock_metres,"badlands_normal_strength":normal_strength,"badlands_gain":albedo_gain,"badlands_quality":material_quality}
