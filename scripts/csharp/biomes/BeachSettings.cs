using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class BeachSettings : Resource
{
    // Sandy coast overlay. All distances are world metres; sea elevation is inherited.
    [ExportGroup("Beach geography")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double coverage { get; set; } = .58;
    [Export(PropertyHint.Range,"60,600,10")]
    public double beach_width { get; set; } = 240;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double width_variation { get; set; } = .7;
    [Export(PropertyHint.Range,".005,.08,.005")]
    public double beach_slope { get; set; } = .025;
    [Export(PropertyHint.Range,"0,3,.1")]
    public double berm_height { get; set; } = .9;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double shoreline_irregularity { get; set; } = .6;
    [ExportGroup("Dune belts")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double dune_frequency { get; set; } = .85;
    [Export(PropertyHint.Range,"5,120,5")]
    public double foredune_height { get; set; } = 48;
    [Export(PropertyHint.Range,"100,500,10")]
    public double foredune_width { get; set; } = 220;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double secondary_dunes { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double backdune_relief { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double asymmetry { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double crest_irregularity { get; set; } = .5;
    [ExportGroup("Wind and erosion")]
    [Export(PropertyHint.Range,"-180,180,5")]
    public double wind_degrees { get; set; } = -35;
    [Export(PropertyHint.Range,"0,90,5")]
    public double wind_variation { get; set; } = 25;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double blowouts { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double storm_erosion { get; set; } = .6;
    [ExportGroup("Depositional coast")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double barrier_frequency { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double spit_frequency { get; set; } = .75;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lagoon_frequency { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double tidal_flat_frequency { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double sandbar_frequency { get; set; } = .8;
    [ExportGroup("Sand materials")]
    [Export(PropertyHint.Range,".2,1,.05")]
    public double albedo_gain { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double wetness { get; set; } = .9;
    [Export(PropertyHint.Range,".5,4,.25")]
    public double sand_metres { get; set; } = 1.5;
    [Export(PropertyHint.Range,"0,1.5,.05")]
    public double normal_strength { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ripple_strength { get; set; } = .35;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double coarse_sediment { get; set; } = .4;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double macro_strength { get; set; } = .3;
    [Export(PropertyHint.Range,"1,6,.25")]
    public double intertidal_height { get; set; } = 2.5;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double swash { get; set; } = .5;
    public D uniforms() => new()
    {
        ["beach_gain"] = albedo_gain,
        ["beach_wetness"] = wetness,
        ["beach_metres"] = sand_metres,
        ["beach_normal_strength"] = normal_strength,
        ["beach_ripples"] = ripple_strength,
        ["beach_coarse"] = coarse_sediment,
        ["beach_macro"] = macro_strength,
        ["beach_intertidal"] = intertidal_height,
        ["beach_swash"] = swash,
        ["beach_wind"] = (wind_degrees * Math.PI / 180.0),
        ["beach_wind_variation"] = (wind_variation * Math.PI / 180.0),
    };
}
