using Godot;
using System;

namespace PredatorIsle.Terrain;

[Tool,GlobalClass]
public partial class TerrainRingSettings : Resource
{
    [ExportGroup("World-aligned terrain rings")]
    [Export(PropertyHint.Range,"16,64,16")] public double base_patch_metres{get;set;}=16;
    [Export(PropertyHint.Range,"0,8,1")] public int outer_rings{get;set;}=6;
    [Export(PropertyHint.Enum,"Low,Medium,High,Ultra")] public int profile{get;set;}=1;
    [ExportToolButton("Apply selected profile")]
    public Callable ApplySelectedProfile=>Callable.From(()=>{apply_profile(profile);EmitChanged();});
    [Export(PropertyHint.Range,"0.5,2,0.5")] public double nearby_vertex_metres{get;set;}=1;
    [ExportGroup("Worker and memory limits")]
    [Export(PropertyHint.Range,"1,16,1")] public int maximum_workers{get;set;}=4;
    [Export(PropertyHint.Range,"0.25,5,0.25")] public double upload_budget_ms{get;set;}=1.5;
    [Export(PropertyHint.Range,"16,1024,16")] public int cache_mebibytes{get;set;}=128;
    [Export] public bool adaptive_budgets{get;set;}=true;
    [ExportGroup("Surface quality")]
    [Export(PropertyHint.Range,"0,3,1")] public int shader_detail_quality{get;set;}=1;
    [Export] public bool selective_geometry_refinement{get;set;}=true;
    [Export] public bool filtered_distant_heights{get;set;}=true;
    // CPU is the supported generation backend. This is explicit rather than a nonfunctional GPU toggle.
    [Export(PropertyHint.Enum,"CPU")] public int generation_backend{get;set;}
    public int subdivisions()=>checked((int)Math.Round(base_patch_metres/nearby_vertex_metres,MidpointRounding.AwayFromZero));
    public Godot.Collections.Array<string> validation_errors()
    {
        var errors=new Godot.Collections.Array<string>();if(!double.IsFinite(base_patch_metres)||base_patch_metres<16||base_patch_metres>64||base_patch_metres%16!=0)errors.Add("Terrain patch width must be 16, 32, 48 or 64 metres.");if(nearby_vertex_metres is not (.5 or 1 or 2))errors.Add("Nearby vertex spacing must be 0.5, 1 or 2 metres.");if(outer_rings<0||outer_rings>8)errors.Add("Outer ring count must be between zero and eight.");if(profile<0||profile>3||shader_detail_quality<0||shader_detail_quality>3)errors.Add("Terrain and shader quality must be between Low and Ultra.");if(generation_backend!=0)errors.Add("Only deterministic CPU generation is currently supported.");if(maximum_workers<1||maximum_workers>16)errors.Add("Worker limit must be between one and sixteen.");if(!double.IsFinite(upload_budget_ms)||upload_budget_ms<.25||upload_budget_ms>5)errors.Add("Upload budget must be between 0.25 and 5 milliseconds.");if(cache_mebibytes<16||cache_mebibytes>1024)errors.Add("Cache budget must be between 16 and 1024 MiB.");return errors;
    }
    public void apply_profile(int selected)
    {
        profile=Math.Clamp(selected,0,3);int capacity=Math.Max(1,(System.Environment.ProcessorCount-2)/2);base_patch_metres=16;nearby_vertex_metres=profile==0?2:profile==3?.5:1;outer_rings=profile==0?5:profile==3?7:6;maximum_workers=Math.Min(capacity,profile==0?1:profile==1?4:8);upload_budget_ms=profile==0?.75:profile==1?1.5:profile==2?2:3;cache_mebibytes=profile==0?48:profile==1?128:profile==2?256:384;shader_detail_quality=profile;selective_geometry_refinement=profile>0;
    }
}
