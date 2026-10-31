using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class RockyCoastSettings : Resource
{
    // Coastal overlay: does not compete for inland biome ownership.
    [ExportGroup("Coastal geography")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double coverage { get; set; } = .72;
    [Export(PropertyHint.Range,"2000,20000,500")]
    public double region_metres { get; set; } = 6500;
    [Export(PropertyHint.Range,"400,2000,50")]
    public double influence_width { get; set; } = 1100;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double headlands { get; set; } = .7;
    [Export(PropertyHint.Range,"600,5000,100")]
    public double bay_scale { get; set; } = 1800;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double inlet_frequency { get; set; } = .5;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ruggedness { get; set; } = .65;
    [ExportGroup("Sea cliffs and offshore rock")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double cliff_frequency { get; set; } = .75;
    [Export(PropertyHint.Range,"80,450,10")]
    public double cliff_height { get; set; } = 260;
    [Export(PropertyHint.Range,"64,300,8")]
    public double cliff_width { get; set; } = 120;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double erosion { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double stack_frequency { get; set; } = .22;
    [Export(PropertyHint.Range,"64,200,8")]
    public double stack_size { get; set; } = 100;
    [ExportGroup("Platforms and pools")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double platform_frequency { get; set; } = .7;
    [Export(PropertyHint.Range,"64,400,16")]
    public double platform_width { get; set; } = 200;
    [Export(PropertyHint.Range,".2,3,.1")]
    public double platform_relief { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double pool_frequency { get; set; } = .55;
    [Export(PropertyHint.Range,"12,48,2")]
    public double pool_size { get; set; } = 26;
    [Export(PropertyHint.Range,".2,2,.1")]
    public double pool_depth { get; set; } = .8;
    [ExportGroup("Materials")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double wetness { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double shingle { get; set; } = .75;
    [Export(PropertyHint.Range,".2,1,.05")]
    public double albedo_gain { get; set; } = .6;
    [Export(PropertyHint.Range,"1,12,.25")]
    public double rock_metres { get; set; } = 5;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double macro_strength { get; set; } = .5;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double salt_exposure { get; set; } = .35;
    [ExportGroup("Performance")]
    [Export(PropertyHint.Range,"64,128,32")]
    public double far_mesh_metres { get; set; } = 128;
    [Export(PropertyHint.Range,"2,3,1")]
    public int material_quality { get; set; } = 3;
    public D uniforms() => new()
    {
        ["coast_wetness"] = wetness,
        ["coast_shingle"] = shingle,
        ["coast_gain"] = albedo_gain,
        ["coast_rock_metres"] = rock_metres,
        ["coast_normal_strength"] = normal_strength,
        ["coast_macro_strength"] = macro_strength,
        ["coast_salt"] = salt_exposure,
        ["coast_quality"] = material_quality,
    };
}
