@tool
extends Resource
## Sandy coast overlay. All distances are world metres; sea elevation is inherited.
@export_group("Beach geography")
@export_range(0,1,.05) var coverage:float=.58
@export_range(60,600,10) var beach_width:float=240
@export_range(0,1,.05) var width_variation:float=.7
@export_range(.005,.08,.005) var beach_slope:float=.025
@export_range(0,3,.1) var berm_height:float=.9
@export_range(0,1,.05) var shoreline_irregularity:float=.6
@export_group("Dune belts")
@export_range(0,1,.05) var dune_frequency:float=.85
@export_range(5,120,5) var foredune_height:float=48
@export_range(100,500,10) var foredune_width:float=220
@export_range(0,1,.05) var secondary_dunes:float=.8
@export_range(0,1,.05) var backdune_relief:float=.55
@export_range(0,1,.05) var asymmetry:float=.65
@export_range(0,1,.05) var crest_irregularity:float=.5
@export_group("Wind and erosion")
@export_range(-180,180,5) var wind_degrees:float=-35
@export_range(0,90,5) var wind_variation:float=25
@export_range(0,1,.05) var blowouts:float=.65
@export_range(0,1,.05) var storm_erosion:float=.6
@export_group("Depositional coast")
@export_range(0,1,.05) var barrier_frequency:float=.8
@export_range(0,1,.05) var spit_frequency:float=.75
@export_range(0,1,.05) var lagoon_frequency:float=.8
@export_range(0,1,.05) var tidal_flat_frequency:float=.8
@export_range(0,1,.05) var sandbar_frequency:float=.8
@export_group("Sand materials")
@export_range(.2,1,.05) var albedo_gain:float=.65
@export_range(0,1,.05) var wetness:float=.9
@export_range(.5,4,.25) var sand_metres:float=1.5
@export_range(0,1.5,.05) var normal_strength:float=.55
@export_range(0,1,.05) var ripple_strength:float=.35
@export_range(0,1,.05) var coarse_sediment:float=.4
@export_range(0,1,.05) var macro_strength:float=.3
@export_range(1,6,.25) var intertidal_height:float=2.5
@export_range(0,1,.05) var swash:float=.5
func uniforms()->Dictionary:
	return {"beach_gain":albedo_gain,"beach_wetness":wetness,"beach_metres":sand_metres,"beach_normal_strength":normal_strength,"beach_ripples":ripple_strength,"beach_coarse":coarse_sediment,"beach_macro":macro_strength,"beach_intertidal":intertidal_height,"beach_swash":swash,"beach_wind":deg_to_rad(wind_degrees),"beach_wind_variation":deg_to_rad(wind_variation)}
