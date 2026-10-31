using Godot;
namespace PredatorIsle.Biomes;
[Tool, GlobalClass]
public partial class DesertSettings : Resource
{
    [ExportGroup("Regions")]
    [Export(PropertyHint.Range,"3000,24000,250")]
    public double region_size {get;set;}=8000.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double sandy_frequency {get;set;}=0.30;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double rocky_frequency {get;set;}=0.20;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double ruggedness {get;set;}=0.65;
    [ExportGroup("Mesh Budget")]
    [Export(PropertyHint.Range,"0,512,32")]
    public double far_mesh_metres {get;set;}=512.0;
    [ExportGroup("Dunes")]
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dune_occurrence {get;set;}=1.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dune_frequency {get;set;}=0.82;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dune_relief_strength {get=>dune_frequency;set=>dune_frequency=value;}
    [Export(PropertyHint.Range,"0,180,1")]
    public double dune_max_height {get;set;}=85.0;
    [Export]
    public Vector2 dune_width_range {get;set;}=new Vector2(360.0f, 850.0f);
    [Export(PropertyHint.Range,"0.5,3,0.05")]
    public double dune_spacing {get;set;}=1.25;
    [Export(PropertyHint.Range,"0.55,0.82,0.01")]
    public double dune_asymmetry {get;set;}=0.76;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double slip_face_sharpness {get;set;}=0.78;
    [Export(PropertyHint.Range,"-180,180,1")]
    public double wind_direction_degrees {get;set;}=24.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double wind_variation {get;set;}=0.65;
    [ExportGroup("Sandstone")]
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double canyon_occurrence {get;set;}=1.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double rock_exposure {get;set;}=0.8;
    [Export(PropertyHint.Range,"100,900,10")]
    public double highland_height {get;set;}=430.0;
    [Export(PropertyHint.Range,"12,48,1")]
    public double sedimentary_bed_height {get;set;}=24.0;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double fracture_strength {get;set;}=0.6;
    [Export(PropertyHint.Range,"0,60,1")]
    public double rock_relief_metres {get;set;}=24.0;
    [Export]
    public bool fast_normal_sampling {get;set;}=true;
    [Export(PropertyHint.Range,"0,1,0.05")]
    public double wind_shelter_strength {get;set;}=0.65;
    [Export(PropertyHint.Range,"0,400,5")]
    public double canyon_depth {get;set;}=240.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double canyon_frequency {get;set;}=0.65;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double canyon_incision_strength {get=>canyon_frequency;set=>canyon_frequency=value;}
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double erosion_intensity {get;set;}=0.65;
    [ExportGroup("Basins")]
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dry_lake_occurrence {get;set;}=1.0;
    [Export(PropertyHint.Range,"600,5000,100")]
    public double basin_size {get;set;}=2400.0;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dry_lake_frequency {get;set;}=0.7;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double dry_lake_floor_strength {get=>dry_lake_frequency;set=>dry_lake_frequency=value;}
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double salt_coverage {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double sediment_variation {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,0.06,0.002")]
    public double oasis_frequency {get;set;}=0.018;
    [ExportGroup("Materials")]
    [Export(PropertyHint.Range,"0.2,1.0,0.01")]
    public double albedo_gain {get;set;}=0.55;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double sand_color_variation {get;set;}=0.45;
    [Export(PropertyHint.Range,"0,1.5,0.05")]
    public double ripple_strength {get;set;}=0.32;
    [Export(PropertyHint.Range,"0.08,0.8,0.01")]
    public double ripple_wavelength {get;set;}=0.24;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double gravel_coverage {get;set;}=0.6;
    [Export(PropertyHint.Range,"0,1,0.01")]
    public double weathering {get;set;}=0.65;
    [Export(PropertyHint.Range,"0,1.5,0.05")]
    public double macro_detail_intensity {get;set;}=0.65;
    [Export(PropertyHint.Range,"0,2,0.05")]
    public double broad_rock_relief {get;set;}=0.65;
    [Export(PropertyHint.Range,"0.2,3,0.05")]
    public double micro_normal_strength {get;set;}=0.65;
}
