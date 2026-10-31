using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class SavannaSettings : Resource
{
    // Terrain only. Season is a material state, never a height input.
    [ExportGroup("Regional Geography")]
    [Export(PropertyHint.Range,"4000,40000,500")]
    public double region_metres { get; set; } = 12000;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double plains_frequency { get; set; } = .3;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rolling_frequency { get; set; } = .2;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rocky_frequency { get; set; } = .15;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double highland_frequency { get; set; } = .12;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double basin_frequency { get; set; } = .14;
    [Export(PropertyHint.Range,"150,1400,25")]
    public double mountain_height { get; set; } = 740;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ridge_intensity { get; set; } = .65;
    [ExportGroup("Weathered Bedrock")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double kopje_frequency { get; set; } = .4;
    [Export(PropertyHint.Range,"100,450,10")]
    public double kopje_size { get; set; } = 240;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double kopje_ruggedness { get; set; } = .6;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double bedrock_exposure { get; set; } = .8;
    [ExportGroup("Drainage and Basins")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double drainage_strength { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double erosion_intensity { get; set; } = .6;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double gully_frequency { get; set; } = .45;
    [Export(PropertyHint.Range,"100,1400,25")]
    public double valley_width { get; set; } = 500;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double perennial_frequency { get; set; } = .25;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double seasonal_channel_frequency { get; set; } = .75;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double basin_water_coverage { get; set; } = .2;
    [ExportGroup("Season and Ground")]
    // 0 dry, 1 wet. Appearance only: geography and water beds stay canonical.
    [Export(PropertyHint.Range,"0,1,.05")]
    public double season { get; set; } = .18;
    [Export(PropertyHint.Range,".2,1.5,.01")]
    public double albedo_gain { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double dry_ground_coverage { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double green_ground_coverage { get; set; } = .75;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double red_soil_exposure { get; set; } = .6;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double gravel_coverage { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rocky_soil { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double dirt_patch_frequency { get; set; } = .4;
    [Export(PropertyHint.Range,"0,.25,.01")]
    public double macro_variation { get; set; } = .1;
    [Export(PropertyHint.Range,".5,12,.25")]
    public double ground_metres { get; set; } = 3;
    [Export(PropertyHint.Range,"2,40,.25")]
    public double rock_metres { get; set; } = 9;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .8;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double rock_normal_strength { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rock_macro_strength { get; set; } = .4;
    [Export(PropertyHint.Range,".2,1.2,.05")]
    public double rock_albedo_gain { get; set; } = .65;
    [ExportGroup("Worn Trails")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double path_frequency { get; set; } = .25;
    [Export(PropertyHint.Range,".5,6,.25")]
    public double path_width { get; set; } = 2.5;
    [Export(PropertyHint.Range,"250,2000,50")]
    public double path_spacing { get; set; } = 1000;
    [ExportGroup("Performance")]
    // 2 or 3 active materials, not all palette layers per pixel.
    [Export(PropertyHint.Range,"2,3,1")]
    public int material_quality { get; set; } = 3;
    // Extra far geometry only in certified Savanna interiors; 0 disables it.
    [Export(PropertyHint.Range,"0,512,32")]
    public double far_mesh_metres { get; set; } = 256;
    public D uniforms() => new()
    {
        ["savanna_season"] = season,
        ["savanna_gain"] = albedo_gain,
        ["savanna_dry_cover"] = dry_ground_coverage,
        ["savanna_green_cover"] = green_ground_coverage,
        ["savanna_red_soil"] = red_soil_exposure,
        ["savanna_gravel"] = gravel_coverage,
        ["savanna_rocky_soil"] = rocky_soil,
        ["savanna_patch"] = dirt_patch_frequency,
        ["savanna_macro"] = macro_variation,
        ["savanna_ground_metres"] = ground_metres,
        ["savanna_rock_metres"] = rock_metres,
        ["savanna_normal_strength"] = normal_strength,
        ["savanna_rock_normal"] = rock_normal_strength,
        ["savanna_path_frequency"] = path_frequency,
        ["savanna_path_width"] = path_width,
        ["savanna_path_spacing"] = path_spacing,
        ["savanna_quality"] = material_quality,
        ["savanna_bedrock"] = bedrock_exposure,
        ["savanna_rock_macro"] = rock_macro_strength,
        ["savanna_rock_gain"] = rock_albedo_gain,
    };
}
