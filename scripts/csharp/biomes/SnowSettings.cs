using Godot;
namespace PredatorIsle.Biomes;
[Tool, GlobalClass]
public partial class SnowSettings : Resource
{
    [ExportGroup("Regional Terrain")]
    [Export(PropertyHint.Range,"4000,24000,500")]
    public double region_metres {get;set;}=10000.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double plains_frequency {get;set;}=0.18;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double alpine_frequency {get;set;}=0.20;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double glacial_frequency {get;set;}=0.17;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double tundra_frequency {get;set;}=0.16;
    [Export(PropertyHint.Range,"300,1800,25")]
    public double mountain_height {get;set;}=1100.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double ruggedness {get;set;}=0.65;
    [ExportGroup("Accumulation")]
    [Export(PropertyHint.Range,"0,8,0.1")]
    public double snow_depth {get;set;}=1.6;
    [Export(PropertyHint.Range,"300,3000,50")]
    public double accumulation_metres {get;set;}=900.0;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double slope_influence {get;set;}=1.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double wind_exposure {get;set;}=0.7;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double sheltered_accumulation {get;set;}=1.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double rock_exposure {get;set;}=0.65;
    [ExportGroup("Wind and Drifts")]
    [Export(PropertyHint.Range,"-180,180,1")]
    public double wind_degrees {get;set;}=28.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double wind_variation {get;set;}=0.5;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double drift_frequency {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,16,0.25")]
    public double drift_height {get;set;}=4.0;
    [Export(PropertyHint.Range,"120,1000,10")]
    public double drift_length {get;set;}=420.0;
    [Export(PropertyHint.Range,"40,300,5")]
    public double drift_width {get;set;}=105.0;
    [ExportGroup("Glaciers")]
    [Export(PropertyHint.Range,"6000,20000,500")]
    public double glacier_length {get;set;}=12000.0;
    [Export(PropertyHint.Range,"400,2400,50")]
    public double glacier_width {get;set;}=1100.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double crevasse_amount {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double exposed_ice {get;set;}=0.65;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double glacier_snow_coverage {get;set;}=0.65;
    [ExportGroup("Frozen Water")]
    [Export(PropertyHint.Range,"0,1,0.02")]
    public double lake_ice_coverage {get;set;}=0.82;
    [Export(PropertyHint.Range,"0,1,0.02")]
    public double river_ice_coverage {get;set;}=0.72;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double snow_on_ice {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double coastal_ice {get;set;}=0.35;
    [ExportGroup("Materials")]
    [Export(PropertyHint.Range,"0.15,1,0.01")]
    public double albedo_gain {get;set;}=0.45;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double powder_strength {get;set;}=1.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double compacted_coverage {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,0.3,0.01")]
    public double color_variation {get;set;}=0.06;
    [Export(PropertyHint.Range,"0.12,0.75,0.01")]
    public double ice_roughness {get;set;}=0.27;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double macro_strength {get;set;}=0.25;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double normal_strength {get;set;}=0.8;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double master_normal_strength {get;set;}=1.0;
    [ExportSubgroup("Surface Scales and Normals")]
    [Export(PropertyHint.Range,".2,12,.1")]
    public double powder_metres {get;set;}=3.0;
    [Export(PropertyHint.Range,".5,24,.1")]
    public double crust_metres {get;set;}=5.0;
    [Export(PropertyHint.Range,".5,24,.1")]
    public double ground_metres {get;set;}=3.8;
    [Export(PropertyHint.Range,"1,40,.5")]
    public double rock_metres {get;set;}=9.0;
    [Export(PropertyHint.Range,"1,60,.5")]
    public double ice_metres {get;set;}=12.0;
    [Export(PropertyHint.Range,"5,150,1")]
    public double wind_texture_metres {get;set;}=35.0;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double crust_normal_strength {get;set;}=.8;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double rock_normal_strength {get;set;}=.7;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double ice_normal_strength {get;set;}=.7;
    [Export(PropertyHint.Range,"0,2,.05")]
    public double ground_normal_strength {get;set;}=.45;
    [ExportGroup("Performance")]
    [Export(PropertyHint.Range,"0,1024,128")]
    public double far_mesh_metres {get;set;}=512.0;
    [Export]
    public bool fast_normal_sampling {get;set;}=true;
    [Export]
    public bool specialize_pure_snow_shader {get;set;}=true;
}
