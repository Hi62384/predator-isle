using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class MountainSettings : Resource
{
    // Mountain terrain only; immutable worker snapshot. Metres, not arbitrary noise amplitude.
    [ExportGroup("Geological Regions")]
    [Export(PropertyHint.Range,"8000,40000,500")]
    public double region_metres { get; set; } = 16000;
    [Export(PropertyHint.Range,"600,3200,50")]
    public double mountain_height { get; set; } = 1800;
    [Export(PropertyHint.Range,".3,2,.05")]
    public double belt_width { get; set; } = 1;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ruggedness { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double highland_frequency { get; set; } = .25;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double glacial_frequency { get; set; } = .25;
    [ExportGroup("Ridges and Valleys")]
    [Export(PropertyHint.Range,".5,3,.1")]
    public double ridge_scale { get; set; } = 1.8;
    [Export(PropertyHint.Range,"400,2400,50")]
    public double ridge_width { get; set; } = 1250;
    [Export(PropertyHint.Range,".5,2,.05")]
    public double ridge_sharpness { get; set; } = 1.1;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double secondary_strength { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double branching { get; set; } = .65;
    [Export(PropertyHint.Range,"1800,7000,100")]
    public double peak_spacing { get; set; } = 3400;
    [Export(PropertyHint.Range,"200,1800,50")]
    public double valley_width { get; set; } = 650;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double valley_depth { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double glacial_influence { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double basin_frequency { get; set; } = .4;
    [ExportGroup("Rock Faces and Deposits")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double cliff_frequency { get; set; } = .6;
    [Export(PropertyHint.Range,"256,900,16")]
    public double cliff_width { get; set; } = 420;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double erosion { get; set; } = .6;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double gully_strength { get; set; } = .5;
    [Export(PropertyHint.Range,"160,900,20")]
    public double erosion_scale { get; set; } = 360;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double weathering { get; set; } = .5;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double scree_coverage { get; set; } = .75;
    [Export(PropertyHint.Range,"200,1000,20")]
    public double talus_size { get; set; } = 500;
    [ExportGroup("Water")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double river_frequency { get; set; } = .65;
    [Export(PropertyHint.Range,"12,100,2")]
    public double river_width { get; set; } = 34;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lake_frequency { get; set; } = .4;
    [ExportGroup("Materials")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rock_exposure { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double geology_variation { get; set; } = .6;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double soil_coverage { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double alpine_coverage { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double wetness { get; set; } = .6;
    [Export(PropertyHint.Range,".5,16,.25")]
    public double rock_metres { get; set; } = 5;
    [Export(PropertyHint.Range,".5,6,.25")]
    public double ground_metres { get; set; } = 2;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double macro_normal_strength { get; set; } = .38;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double meso_normal_strength { get; set; } = .45;
    [Export(PropertyHint.Range,".2,1.3,.05")]
    public double albedo_gain { get; set; } = .45;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double path_coverage { get; set; } = .1;
    [ExportGroup("Performance")]
    [Export(PropertyHint.Range,"128,512,64")]
    public double far_mesh_metres { get; set; } = 256;
    [Export(PropertyHint.Range,"2,3,1")]
    public int material_quality { get; set; } = 3;
    public D uniforms() => new()
    {
        ["mountain_rock_exposure"] = rock_exposure,
        ["mountain_geology_variation"] = geology_variation,
        ["mountain_soil"] = soil_coverage,
        ["mountain_alpine"] = alpine_coverage,
        ["mountain_wetness"] = wetness,
        ["mountain_rock_metres"] = rock_metres,
        ["mountain_ground_metres"] = ground_metres,
        ["mountain_normal_strength"] = normal_strength,
        ["mountain_macro_strength"] = macro_normal_strength,
        ["mountain_meso_strength"] = meso_normal_strength,
        ["mountain_gain"] = albedo_gain,
        ["mountain_paths"] = path_coverage,
        ["mountain_quality"] = material_quality,
        ["mountain_scree_cover"] = scree_coverage,
    };
}
