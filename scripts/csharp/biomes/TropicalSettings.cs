using Godot;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Terrain and water controls; workers receive private resource snapshots.</summary>
[Tool,GlobalClass]
public partial class TropicalSettings : Resource
{
    [ExportGroup("Regional Geography")]
    [Export(PropertyHint.Range,"5000,30000,500")]public double region_metres {get;set;}=12000;
    [Export(PropertyHint.Range,"0,1,0.05")]public double lowland_frequency {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double hill_frequency {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double highland_frequency {get;set;}=.45;
    [Export(PropertyHint.Range,"0,1,0.05")]public double mountain_frequency {get;set;}=.22;
    [Export(PropertyHint.Range,"0,1,0.05")]public double rocky_frequency {get;set;}=.35;
    [ExportGroup("Landforms and Weathering")]
    [Export(PropertyHint.Range,"20,400,10")]public double hill_height {get;set;}=180;
    [Export(PropertyHint.Range,"500,4000,100")]public double hill_width {get;set;}=1800;
    [Export(PropertyHint.Range,"300,1600,50")]public double mountain_height {get;set;}=1000;
    [Export(PropertyHint.Range,"0,1,0.05")]public double ridge_strength {get;set;}=.75;
    [Export(PropertyHint.Range,"0,1,0.05")]public double valley_depth {get;set;}=.85;
    [Export(PropertyHint.Range,"0,1,0.05")]public double erosion {get;set;}=.55;
    [Export(PropertyHint.Range,"0,1,0.05")]public double gullies {get;set;}=.45;
    [Export(PropertyHint.Range,"0,1,0.05")]public double weathering {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double plateau_frequency {get;set;}=.3;
    [ExportGroup("Freshwater")]
    [Export(PropertyHint.Range,"0,1,0.05")]public double river_frequency {get;set;}=.8;
    [Export(PropertyHint.Range,"0,1,0.05")]public double stream_frequency {get;set;}=.45;
    [Export(PropertyHint.Range,"0,1,0.05")]public double lake_frequency {get;set;}=.4;
    [Export(PropertyHint.Range,"0,1,0.05")]public double basin_frequency {get;set;}=.45;
    [Export(PropertyHint.Range,"24,120,2")]public double river_width {get;set;}=45;
    [Export(PropertyHint.Range,"200,1400,50")]public double valley_width {get;set;}=650;
    [Export(PropertyHint.Range,"0,1,0.01")]public double waterfall_frequency {get;set;}=.12;
    [Export(PropertyHint.Range,"10,70,2")]public double waterfall_drop {get;set;}=30;
    [ExportGroup("Surface Materials")]
    [Export(PropertyHint.Range,"0,1,0.05")]public double lush_cover {get;set;}=.8;
    [Export(PropertyHint.Range,"0,1,0.05")]public double red_soil {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double rock_exposure {get;set;}=.7;
    [Export(PropertyHint.Range,"0,1,0.05")]public double wetness {get;set;}=.65;
    [Export(PropertyHint.Range,"0,1,0.05")]public double weathered_rock {get;set;}=.5;
    [Export(PropertyHint.Range,"0,1,0.05")]public double macro_variation {get;set;}=.16;
    [Export(PropertyHint.Range,"0,1,0.05")]public double dirt_patches {get;set;}=.4;
    [Export(PropertyHint.Range,"0,1,0.05")]public double paths {get;set;}=.3;
    [Export(PropertyHint.Range,"0.5,6,0.25")]public double ground_metres {get;set;}=2;
    [Export(PropertyHint.Range,"2,16,0.25")]public double rock_metres {get;set;}=6;
    [Export(PropertyHint.Range,"0,2,0.05")]public double normal_strength {get;set;}=.8;
    [Export(PropertyHint.Range,"0.2,1.2,0.05")]public double albedo_gain {get;set;}=.7;
    [ExportGroup("Performance")]
    [Export(PropertyHint.Range,"128,512,64")]public double far_mesh_metres {get;set;}=256;
    /// <summary>Near/mid main-river spacing; LOD4 doubles it. Zero disables refinement.</summary>
    [Export(PropertyHint.Range,"0,64,8")]public double river_detail_metres {get;set;}=32;
    [Export(PropertyHint.Range,"2,4,1")]public long river_detail_max_lod {get;set;}=4;
    [Export(PropertyHint.Range,"2,3,1")]public long material_quality {get;set;}=3;
    public D uniforms()=>new()
    {
        ["tropical_lush"]=lush_cover,["tropical_red_soil"]=red_soil,["tropical_rock_exposure"]=rock_exposure,
        ["tropical_wetness"]=wetness,["tropical_weathering"]=weathered_rock,["tropical_macro"]=macro_variation,
        ["tropical_patches"]=dirt_patches,["tropical_paths"]=paths,["tropical_ground_metres"]=ground_metres,
        ["tropical_rock_metres"]=rock_metres,["tropical_normal_strength"]=normal_strength,
        ["tropical_gain"]=albedo_gain,["tropical_quality"]=material_quality
    };
}
