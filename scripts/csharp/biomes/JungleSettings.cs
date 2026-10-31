using Godot;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

[Tool, GlobalClass]
public partial class JungleSettings : Resource
{
    // Static worker snapshot; restart the scene after editing.
    [ExportGroup("Regional Geography")]
    [Export(PropertyHint.Range,"4000,40000,500")]
    public double region_metres { get; set; } = 14000;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lowland_frequency { get; set; } = .25;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double mountain_frequency { get; set; } = .18;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double plateau_frequency { get; set; } = .10;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double hill_density { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ruggedness { get; set; } = .6;
    [Export(PropertyHint.Range,"200,1400,25")]
    public double mountain_height { get; set; } = 780;
    [ExportGroup("Erosion")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double erosion_strength { get; set; } = .65;
    [Export(PropertyHint.Range,"20,250,5")]
    public double valley_depth { get; set; } = 110;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double tributary_density { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double gully_frequency { get; set; } = .6;
    [ExportGroup("Hydrology")]
    // Corridor influence on the shared world river network (0 disables it).
    [Export(PropertyHint.Range,"0,1,.05")]
    public double river_frequency { get; set; } = 1.0;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double stream_density { get; set; } = .6;
    [Export(PropertyHint.Range,"150,1500,25")]
    public double river_valley_width { get; set; } = 620;
    [Export(PropertyHint.Range,"8,160,2")]
    public double river_width { get; set; } = 90;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double lake_frequency { get; set; } = .3;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double floodplain_influence { get; set; } = .7;
    [ExportGroup("Materials")]
    [Export(PropertyHint.Range,".1,1,.01")]
    public double albedo_gain { get; set; } = .9;
    // Living ground cover color; mud and rock retain independent colors.
    [Export]
    public Color green_tint { get; set; } = new Color((float)(.22),(float)(.56),(float)(.075),(float)(1));
    [Export(PropertyHint.Range,"0,1,.01")]
    public double green_coverage { get; set; } = .96;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double organic_soil { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double leaf_litter { get; set; } = .75;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double mud_coverage { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double moss_coverage { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double rock_exposure { get; set; } = .65;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double wetness_variation { get; set; } = .65;
    [Export(PropertyHint.Range,"0,.3,.01")]
    public double macro_variation { get; set; } = .12;
    [Export(PropertyHint.Range,".3,12,.1")]
    public double ground_metres { get; set; } = 3.0;
    [Export(PropertyHint.Range,"2,60,.5")]
    public double rock_metres { get; set; } = 12.0;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double normal_strength { get; set; } = .9;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double rock_normal_strength { get; set; } = .8;
    [ExportGroup("Distant Geometry")]
    // Preserve regional relief/river corridors without changing view distance. 0 uses legacy mesh density.
    [Export(PropertyHint.Range,"0,512,32")]
    public double far_mesh_metres { get; set; } = 128;
    [ExportGroup("Vegetation Hooks - No Renderer Installed")]
    [Export(PropertyHint.Range,"0,1,.05")]
    public double canopy_density { get; set; } = .8;
    [Export(PropertyHint.Range,"0,.15,.01")]
    public double emergent_frequency { get; set; } = .04;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double understory_density { get; set; } = .55;
    [Export(PropertyHint.Range,"0,1,.05")]
    public double ground_cover_density { get; set; } = .7;
    [Export(PropertyHint.Range,"0,.6,.02")]
    public double clearing_frequency { get; set; } = .12;
    public D uniforms()
    {
        var linear = green_tint.SrgbToLinear();
        return new D
        {
            ["jungle_green_tint"] = new Vector3(linear.R, linear.G, linear.B),
            ["jungle_green_coverage"] = green_coverage,
            ["jungle_albedo_gain"] = albedo_gain,
            ["jungle_organic"] = organic_soil,
            ["jungle_litter"] = leaf_litter,
            ["jungle_mud"] = mud_coverage,
            ["jungle_moss"] = moss_coverage,
            ["jungle_rock"] = rock_exposure,
            ["jungle_macro"] = macro_variation,
            ["jungle_ground_metres"] = ground_metres,
            ["jungle_rock_metres"] = rock_metres,
            ["jungle_normal_strength"] = normal_strength,
            ["jungle_rock_normal"] = rock_normal_strength,
            ["jungle_canopy"] = canopy_density,
            ["jungle_clearing"] = clearing_frequency,
        };
    }
}
