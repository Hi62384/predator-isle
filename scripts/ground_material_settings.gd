@tool
class_name GroundMaterialSettings
extends Resource

@export_group("Landscape")
@export_range(80,2000,10) var region_size_metres: float = 620.0
@export_range(0,1,0.01) var macro_color_strength: float = 0.4
@export_range(0,1,0.01) var grass_variation_strength: float = 0.7
@export_range(0,1,0.01) var moisture_darkening: float = 0.28
@export_group("Bare Ground")
@export_range(5,200,1) var patch_size_metres: float = 48.0
@export_range(0,1,0.01) var dirt_coverage: float = 0.24
@export_range(0,1,0.01) var dirt_cutoff: float = 0.62
@export_range(0.02,0.5,0.01) var patch_softness: float = 0.22
@export_range(0,1,0.01) var path_coverage: float = 0.3
@export_range(40,600,5) var wear_size_metres: float = 180.0
@export_range(0.5,12,0.25) var wear_width_metres: float = 3.0
@export_range(0,1,0.01) var erosion_strength: float = 0.28
@export_range(0,1,0.01) var ridge_soil_strength: float = 0.18
@export_group("Path Surface")
@export_range(0,1,0.01) var path_sand_mix: float = 0.38
@export_range(0,1,0.01) var path_gravel_mix: float = 0.18
@export_range(0,1,0.01) var path_dry_earth_mix: float = 0.28
@export_range(0,1,0.01) var path_mud_mix: float = 0.24
@export_range(0,3,0.05) var path_normal_strength: float = 1.0
@export_range(0.4,8,0.1) var path_texture_metres: float = 2.0
@export_group("Path Shape")
@export_range(0,1,0.01) var path_wander_strength: float = 0.82
@export_range(0,1,0.01) var path_edge_noise_strength: float = 0.48
@export_range(0.5,40,0.5) var path_edge_noise_metres: float = 7.0
@export_range(0.05,8,0.05) var path_edge_softness_metres: float = 1.4
@export_group("Near Ground")
@export_range(0.4,4,0.05) var grass_texture_metres: float = 1.1
@export_range(0,2,0.05) var grass_normal_strength: float = 0.75
@export_group("Shore")
@export_range(1,40,0.5) var shoreline_width_metres: float = 7.0
@export_range(1,100,1) var damp_margin_metres: float = 24.0
@export_group("Debug")
@export_enum("Off", "Grass", "Dirt", "Wear", "Shore", "Moisture", "Macro", "Dryness", "Regional Type", "Grass Family Weights", "Bare Patches", "Erosion", "Ridge Soil", "Meso") var debug_mode: int = 0

func uniforms() -> Dictionary:
	return {
		"ground_region_size": maxf(region_size_metres, 80.0),
		"ground_macro_strength": macro_color_strength,
		"ground_grass_variation": grass_variation_strength,
		"ground_moisture_darkening": moisture_darkening,
		"ground_patch_size": maxf(patch_size_metres, 5.0),
		"ground_dirt_coverage": dirt_coverage,
		"ground_dirt_cutoff": dirt_cutoff,
		"ground_patch_softness": maxf(patch_softness, 0.02),
		"ground_path_coverage": path_coverage,
		"ground_wear_size": maxf(wear_size_metres, 40.0),
		"ground_wear_width": maxf(wear_width_metres, 0.5),
		"path_sand_mix": path_sand_mix,
		"path_gravel_mix": path_gravel_mix,
		"path_dry_earth_mix": path_dry_earth_mix,
		"path_mud_mix": path_mud_mix,
		"path_normal_strength": path_normal_strength,
		"path_texture_metres": maxf(path_texture_metres,0.4),
		"path_wander_strength": path_wander_strength,
		"path_edge_noise_strength": path_edge_noise_strength,
		"path_edge_noise_metres": maxf(path_edge_noise_metres,0.5),
		"path_edge_softness_metres": maxf(path_edge_softness_metres,0.05),
		"ground_erosion_strength": erosion_strength,
		"ground_ridge_strength": ridge_soil_strength,
		"ground_grass_metres": maxf(grass_texture_metres,0.4),
		"ground_normal_strength": grass_normal_strength,
		"ground_shore_width": maxf(shoreline_width_metres, 1.0),
		"ground_damp_width": maxf(damp_margin_metres, shoreline_width_metres + 1.0),
		"ground_debug": debug_mode,
	}
