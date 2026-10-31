using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Rendering;

[Tool, GlobalClass]
public partial class GroundMaterialSettings : Resource
{
    [ExportGroup("Landscape")]
    [Export(PropertyHint.Range,"80,2000,10")]
    public double region_size_metres { get; set; } = 620.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double macro_color_strength { get; set; } = 0.4;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double grass_variation_strength { get; set; } = 0.7;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double moisture_darkening { get; set; } = 0.28;
    [ExportGroup("Bare Ground")]
    [Export(PropertyHint.Range,"5,200,1")]
    public double patch_size_metres { get; set; } = 48.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dirt_coverage { get; set; } = 0.24;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dirt_cutoff { get; set; } = 0.62;
    [Export(PropertyHint.Range,"0.02,0.5,0.01")]
    public double patch_softness { get; set; } = 0.22;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_coverage { get; set; } = 0.3;
    [Export(PropertyHint.Range,"40,600,5")]
    public double wear_size_metres { get; set; } = 180.0;
    [Export(PropertyHint.Range,"0.5,12,0.25")]
    public double wear_width_metres { get; set; } = 3.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double erosion_strength { get; set; } = 0.28;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double ridge_soil_strength { get; set; } = 0.18;
    [ExportGroup("Path Surface")]
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_sand_mix { get; set; } = 0.38;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_gravel_mix { get; set; } = 0.18;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_dry_earth_mix { get; set; } = 0.28;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_mud_mix { get; set; } = 0.24;
    [Export(PropertyHint.Range,"0,3,0.05")]
    public double path_normal_strength { get; set; } = 1.0;
    [Export(PropertyHint.Range,"0.4,8,0.1")]
    public double path_texture_metres { get; set; } = 2.0;
    [ExportGroup("Path Shape")]
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_wander_strength { get; set; } = 0.82;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double path_edge_noise_strength { get; set; } = 0.48;
    [Export(PropertyHint.Range,"0.5,40,0.5")]
    public double path_edge_noise_metres { get; set; } = 7.0;
    [Export(PropertyHint.Range,"0.05,8,0.05")]
    public double path_edge_softness_metres { get; set; } = 1.4;
    [ExportGroup("Near Ground")]
    [Export(PropertyHint.Range,"0.4,4,0.05")]
    public double grass_texture_metres { get; set; } = 1.1;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double grass_normal_strength { get; set; } = 0.75;
    [ExportGroup("Shore")]
    [Export(PropertyHint.Range,"1,40,0.5")]
    public double shoreline_width_metres { get; set; } = 7.0;
    [Export(PropertyHint.Range,"1,100,1")]
    public double damp_margin_metres { get; set; } = 24.0;
    [ExportGroup("Debug")]
    [Export(PropertyHint.Enum,"Off,Grass,Dirt,Wear,Shore,Moisture,Macro,Dryness,Regional Type,Grass Family Weights,Bare Patches,Erosion,Ridge Soil,Meso")]
    public int debug_mode { get; set; } = 0;
    public D uniforms() => new()
    {
        ["ground_region_size"] = Math.Max(region_size_metres, 80.0),
        ["ground_macro_strength"] = macro_color_strength,
        ["ground_grass_variation"] = grass_variation_strength,
        ["ground_moisture_darkening"] = moisture_darkening,
        ["ground_patch_size"] = Math.Max(patch_size_metres, 5.0),
        ["ground_dirt_coverage"] = dirt_coverage,
        ["ground_dirt_cutoff"] = dirt_cutoff,
        ["ground_patch_softness"] = Math.Max(patch_softness, 0.02),
        ["ground_path_coverage"] = path_coverage,
        ["ground_wear_size"] = Math.Max(wear_size_metres, 40.0),
        ["ground_wear_width"] = Math.Max(wear_width_metres, 0.5),
        ["path_sand_mix"] = path_sand_mix,
        ["path_gravel_mix"] = path_gravel_mix,
        ["path_dry_earth_mix"] = path_dry_earth_mix,
        ["path_mud_mix"] = path_mud_mix,
        ["path_normal_strength"] = path_normal_strength,
        ["path_texture_metres"] = Math.Max(path_texture_metres,0.4),
        ["path_wander_strength"] = path_wander_strength,
        ["path_edge_noise_strength"] = path_edge_noise_strength,
        ["path_edge_noise_metres"] = Math.Max(path_edge_noise_metres,0.5),
        ["path_edge_softness_metres"] = Math.Max(path_edge_softness_metres,0.05),
        ["ground_erosion_strength"] = erosion_strength,
        ["ground_ridge_strength"] = ridge_soil_strength,
        ["ground_grass_metres"] = Math.Max(grass_texture_metres,0.4),
        ["ground_normal_strength"] = grass_normal_strength,
        ["ground_shore_width"] = Math.Max(shoreline_width_metres, 1.0),
        ["ground_damp_width"] = Math.Max(damp_margin_metres, shoreline_width_metres + 1.0),
        ["ground_debug"] = debug_mode,
    };
}
