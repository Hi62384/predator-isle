using Godot;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Sedimentary terrain controls, retaining the saved resource property names.</summary>
[Tool,GlobalClass]
public partial class BadlandsSettings : Resource
{
    [ExportGroup("Geological Provinces")]
    [Export(PropertyHint.Range,"3000,20000,500")]public double region_metres {get;set;}=7000;
    [Export(PropertyHint.Range,"0,1,0.05")]public double painted_frequency {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double rugged_frequency {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double clay_frequency {get;set;}=.7;
    [Export(PropertyHint.Range,"0,1,0.05")]public double basin_frequency {get;set;}=.4;
    [ExportGroup("Relief and Erosion")]
    [Export(PropertyHint.Range,"0.2,2,0.05")]public double relief {get;set;}=1;
    [Export(PropertyHint.Range,"0,1,0.05")]public double rounded_hill_strength {get;set;}=.75;
    [Export(PropertyHint.Range,"0.1,1,0.05")]public double erosion {get;set;}=.85;
    [Export(PropertyHint.Range,"0.3,2,0.05")]public double ridge_sharpness {get;set;}=1;
    [Export(PropertyHint.Range,"1000,4000,100")]public double drainage_spacing {get;set;}=1400;
    [Export(PropertyHint.Range,"0,1,0.05")]public double secondary_gullies {get;set;}=.75;
    [Export(PropertyHint.Range,"30,160,5")]public double wash_width {get;set;}=65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double ledges {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double remnants {get;set;}=.5;
    [Export(PropertyHint.Range,"20,100,5")]public double remnant_height {get;set;}=65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double fans {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double fan_shape_strength {get;set;}=1;
    [Export(PropertyHint.Range,"0,0.08,0.005")]public double fan_gradient {get;set;}=.025;
    [Export(PropertyHint.Range,"0,0.15,0.01")]public double pool_frequency {get;set;}=.03;
    [ExportGroup("Sedimentary Materials")]
    [Export(PropertyHint.Range,"40,180,5")]public double strata_metres {get;set;}=84;
    [Export(PropertyHint.Range,"0,0.35,0.01")]public double thickness_variation {get;set;}=.16;
    [Export]public Vector2 strata_dip {get;set;}=new(.018f,.012f);
    [Export(PropertyHint.Range,"0,2,0.05")]public double fold_strength {get;set;}=1;
    [Export(PropertyHint.Range,"0,1,0.05")]public double strata_strength {get;set;}=.75;
    [Export(PropertyHint.Range,"0,1,0.05")]public double lamina_strength {get;set;}=.18;
    [Export(PropertyHint.Range,"0,1,0.05")]public double regional_color_strength {get;set;}=.85;
    [Export(PropertyHint.Range,"0,1,0.05")]public double weathering {get;set;}=.4;
    [Export(PropertyHint.Range,"0,1,0.05")]public double gravel {get;set;}=.65;
    [Export(PropertyHint.Range,"0.5,6,0.25")]public double ground_metres {get;set;}=2;
    [Export(PropertyHint.Range,"2,16,0.25")]public double rock_metres {get;set;}=6;
    [Export(PropertyHint.Range,"0,2,0.05")]public double normal_strength {get;set;}=.75;
    [Export(PropertyHint.Range,"0.2,1.2,0.05")]public double albedo_gain {get;set;}=.55;
    [ExportGroup("Performance")]
    [Export(PropertyHint.Range,"64,256,32")]public double far_mesh_metres {get;set;}=256;
    [Export(PropertyHint.Range,"64,256,32")]public double dissected_mesh_metres {get;set;}=64;
    [Export(PropertyHint.Range,"8,64,8")]public double remnant_mesh_metres {get;set;}=16;
    [Export(PropertyHint.Range,"2,3")]public long material_quality {get;set;}=3;
    public D uniforms()=>new()
    {
        ["badlands_strata_metres"]=strata_metres,["badlands_thickness_variation"]=thickness_variation,
        ["badlands_strata_dip"]=strata_dip,["badlands_fold_strength"]=fold_strength,["badlands_strata_strength"]=strata_strength,
        ["badlands_lamina_strength"]=lamina_strength,["badlands_regional_strength"]=regional_color_strength,
        ["badlands_weathering"]=weathering,["badlands_gravel"]=gravel,["badlands_ground_metres"]=ground_metres,
        ["badlands_rock_metres"]=rock_metres,["badlands_normal_strength"]=normal_strength,
        ["badlands_gain"]=albedo_gain,["badlands_quality"]=material_quality
    };
}
