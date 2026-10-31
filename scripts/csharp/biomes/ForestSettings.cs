using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class ForestSettings : Resource
{
    // Terrain/material settings only. No vegetation systems are created.
    [ExportGroup("Geographic Regions")]
    [Export(PropertyHint.Range,"4000,40000,500")]
    public double region_metres { get; set; } = 11000;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double deciduous_frequency { get; set; } = .22;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double conifer_frequency { get; set; } = .18;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double mixed_frequency { get; set; } = .16;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double old_growth_frequency { get; set; } = .10;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lowland_frequency { get; set; } = .35;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double hill_frequency { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double mountain_frequency { get; set; } = .18;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ruggedness { get; set; } = .55;
    [Export(PropertyHint.Range,"200,1400,25")]
    public double mountain_height { get; set; } = 760;
    [Export(PropertyHint.Range,"700,8000,100")]
    public double valley_scale { get; set; } = 2400;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double erosion_strength { get; set; } = .55;
    [Export(PropertyHint.Range,"10,200,5")]
    public double ravine_depth { get; set; } = 70;
    [ExportGroup("Water Terrain - Existing Sea-level Renderer")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double river_influence { get; set; } = 1;
    [Export(PropertyHint.Range,"12,160,2")]
    public double river_width { get; set; } = 65;
    [Export(PropertyHint.Range,"100,1500,25")]
    public double river_valley_width { get; set; } = 450;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double stream_density { get; set; } = .45;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lake_frequency { get; set; } = .3;
    [ExportGroup("Forest Floor")]
    [Export(PropertyHint.Range,".1,1.5,.01")]
    public double albedo_gain { get; set; } = .72;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double leaf_coverage { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double needle_coverage { get; set; } = .9;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double soil_exposure { get; set; } = .4;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double moss_coverage { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double wetness { get; set; } = .5;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rock_exposure { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double clearing_frequency { get; set; } = .18;
    [Export(PropertyHint.Range,"0,.3,.01")]
    public double macro_variation { get; set; } = .12;
    [Export(PropertyHint.Range,".5,10,.25")]
    public double litter_metres { get; set; } = 3;
    [Export(PropertyHint.Range,".5,12,.25")]
    public double soil_metres { get; set; } = 3.5;
    [Export(PropertyHint.Range,".5,12,.25")]
    public double moss_metres { get; set; } = 3;
    [Export(PropertyHint.Range,"2,40,.25")]
    public double rock_metres { get; set; } = 10;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .85;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double rock_normal_strength { get; set; } = .8;
    [ExportGroup("Woodland Trails")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double path_coverage { get; set; } = .55;
    [Export(PropertyHint.Range,".5,8,.1")]
    public double path_width { get; set; } = 2.8;
    [Export(PropertyHint.Range,".3,5,.1")]
    public double path_falloff { get; set; } = 1.4;
    [Export(PropertyHint.Range,"150,1500,25")]
    public double path_spacing { get; set; } = 650;
    [ExportGroup("Distant Geometry")]
    // Maximum target spacing for extra far-region detail; 128 is the slower quality option.
    [Export(PropertyHint.Range,"0,512,32")]
    public double far_mesh_metres { get; set; } = 256;
    public D uniforms() => new()
    {
        ["forest_gain"] = albedo_gain,
        ["forest_leaves"] = leaf_coverage,
        ["forest_needles"] = needle_coverage,
        ["forest_soil"] = soil_exposure,
        ["forest_moss"] = moss_coverage,
        ["forest_wetness"] = wetness,
        ["forest_rock"] = rock_exposure,
        ["forest_macro"] = macro_variation,
        ["forest_litter_metres"] = litter_metres,
        ["forest_soil_metres"] = soil_metres,
        ["forest_moss_metres"] = moss_metres,
        ["forest_rock_metres"] = rock_metres,
        ["forest_normal_strength"] = normal_strength,
        ["forest_rock_normal"] = rock_normal_strength,
        ["forest_path_coverage"] = path_coverage,
        ["forest_path_width"] = path_width,
        ["forest_path_falloff"] = path_falloff,
        ["forest_path_spacing"] = path_spacing,
    };
}
