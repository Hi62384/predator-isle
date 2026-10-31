using Godot;
using System;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Editable biome controls copied into private worker snapshots.</summary>
[Tool, GlobalClass]
public partial class SwampSettings : Resource
{
    // Swamp terrain and local water only. Restart after editing worker settings.
    [ExportGroup("Regional Geography")]
    [Export(PropertyHint.Range,"4000,30000,500")]
    public double region_metres { get; set; } = 9000;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double floodplain_frequency { get; set; } = .3;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double basin_frequency { get; set; } = .22;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double island_density { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double raised_frequency { get; set; } = .4;
    [Export(PropertyHint.Range,".2,3,.1")]
    public double terrain_relief { get; set; } = 1.2;
    [ExportGroup("Hydrology")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double water_coverage { get; set; } = .55;
    [Export(PropertyHint.Range,".2,6,.1")]
    public double depth_variation { get; set; } = 2;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double channel_frequency { get; set; } = .8;
    [Export(PropertyHint.Range,"24,240,4")]
    public double channel_width { get; set; } = 90;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double pool_frequency { get; set; } = .6;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double water_table_influence { get; set; } = .85;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double floodplain_connectivity { get; set; } = .8;
    [ExportGroup("Lowland Landforms")]
    [Export(PropertyHint.Range,"0,2,.1")]
    public double hummock_amplitude { get; set; } = .7;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double hollow_frequency { get; set; } = .6;
    [Export(PropertyHint.Range,".5,5,.1")]
    public double island_height { get; set; } = 2.4;
    [Export(PropertyHint.Range,"0,3,.1")]
    public double levee_height { get; set; } = 1.3;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double erosion_intensity { get; set; } = .4;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double sediment_deposition { get; set; } = .7;
    [ExportGroup("Ground Materials")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double mud_coverage { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double peat_coverage { get; set; } = .7;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double organic_coverage { get; set; } = .8;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double sediment_coverage { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double wetness_intensity { get; set; } = .9;
    [Export(PropertyHint.Range,"0,.3,.01")]
    public double macro_variation { get; set; } = .12;
    [Export(PropertyHint.Range,".2,3,.1")]
    public double shoreline_width { get; set; } = 1.2;
    [Export(PropertyHint.Range,".5,8,.25")]
    public double ground_metres { get; set; } = 2;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .65;
    [Export(PropertyHint.Range,".3,1.3,.05")]
    public double albedo_gain { get; set; } = .9;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double exposed_season { get; set; } = .35;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double path_coverage { get; set; } = .15;
    [ExportGroup("Water and Performance")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double water_opacity { get; set; } = .88;
    [Export(PropertyHint.Range,"0,.08,.005")]
    public double ripple_strength { get; set; } = .015;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double flood_stage { get; set; } = 0;
    [Export(PropertyHint.Range,"2,3,1")]
    public int material_quality { get; set; } = 3;
    // Local wetland interiors only; never changes canonical water coordinates.
    [Export(PropertyHint.Range,"128,512,64")]
    public double far_mesh_metres { get; set; } = 256;
    public D uniforms() => new()
    {
        ["swamp_mud"] = mud_coverage,
        ["swamp_peat"] = peat_coverage,
        ["swamp_organic"] = organic_coverage,
        ["swamp_sediment"] = sediment_coverage,
        ["swamp_wetness"] = wetness_intensity,
        ["swamp_macro"] = macro_variation,
        ["swamp_shore_width"] = shoreline_width,
        ["swamp_metres"] = ground_metres,
        ["swamp_normal_strength"] = normal_strength,
        ["swamp_gain"] = albedo_gain,
        ["swamp_exposed_season"] = exposed_season,
        ["swamp_paths"] = path_coverage,
        ["swamp_quality"] = material_quality,
    };
}
