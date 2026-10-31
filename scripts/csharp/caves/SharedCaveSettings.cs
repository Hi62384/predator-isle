using Godot;
using System;

namespace PredatorIsle.Caves;
[Tool,GlobalClass]
public partial class SharedCaveSettings : Resource
{
    [ExportGroup("Shared Cave Foundation")]
    [Export]public bool enabled {get;set;}
    [Export(PropertyHint.Range,"350,450,1")]public double maximum_depth_metres {get;set;}=400;
    [Export(PropertyHint.Range,"0,1,0.01")]public double regional_activity {get;set;}=.85;
    [Export(PropertyHint.Range,"8,24,0.5")]public double minimum_rock_cover_metres {get;set;}=10;
    [Export(PropertyHint.Range,"6,16,0.5")]public double main_route_width_metres {get;set;}=8;
    [Export(PropertyHint.Range,"6,16,0.5")]public double main_route_height_metres {get;set;}=8;
    [Export(PropertyHint.Range,"0.1,0.25,0.01")]public double maximum_route_grade {get;set;}=.2;
    [ExportGroup("Graph-Aware Cave Biomes")]
    [Export]public Resource? biome_regions {get;set;}=GD.Load<Resource>("res://config/caves/cave_biome_regions.tres");
    [ExportGroup("Default Geology")]
    [Export]public bool chamber_variety {get;set;}=true;
    [Export]public bool geological_morphology {get;set;}=true;
    [Export(PropertyHint.Range,"0,1,0.01")]public double seepage_density {get;set;}=.15;
    [Export(PropertyHint.Range,"0,1,0.05")]public double formation_density {get;set;}=.75;
    [ExportGroup("Supported Surface Interiors")]
    [Export]public bool insect_networks {get;set;}=true;
    [Export]public bool hive_networks {get;set;}=true;
    [Export]public bool specialize_insect_palette {get;set;}=true;
    [ExportGroup("Sparse Streaming")]
    [Export]public bool retain_deep_surface_cut {get;set;}=true;
    [Export]public bool indexed_entry_payload {get;set;}=true;
    [Export]public bool seal_stream_frontiers {get;set;}=true;
    [Export]public bool common_vertex_projection {get;set;}=true;
    [Export(PropertyHint.Range,"96,256,32")]public double visible_radius_metres {get;set;}=160;
    [Export(PropertyHint.Range,"128,384,32")]public double preload_radius_metres {get;set;}=256;
    [Export(PropertyHint.Range,"32,256,16")]public long resident_cell_limit {get;set;}=128;
    [Export(PropertyHint.Range,"4,32,1")]public long pending_job_limit {get;set;}=12;
    public Godot.Collections.Array<string> validation_errors()
    {
        var errors=new Godot.Collections.Array<string>();
        if(biome_regions==null||!biome_regions.HasMethod("validation_errors"))errors.Add("Cave biome registry is required");
        else foreach(var error in biome_regions.Call("validation_errors").AsGodotArray())errors.Add(error.AsString());
        foreach(double value in new[]{maximum_depth_metres,regional_activity,minimum_rock_cover_metres,main_route_width_metres,main_route_height_metres,maximum_route_grade,visible_radius_metres,preload_radius_metres,formation_density,seepage_density})
            if(!double.IsFinite(value)){errors.Add("Cave settings must be finite");return errors;}
        if(maximum_depth_metres<350||maximum_depth_metres>450)errors.Add("Maximum cave depth must be350–450m below the actual local surface");
        if(regional_activity<0||regional_activity>1)errors.Add("Regional activity must be0–1");
        if(formation_density<0||formation_density>1)errors.Add("Formation density must be0–1");
        if(seepage_density<0||seepage_density>1)errors.Add("Seepage density must be0–1");
        if(minimum_rock_cover_metres<8)errors.Add("Closed routes require at least8m rock cover");
        if(main_route_width_metres<6||main_route_height_metres<6)errors.Add("Main routes require at least6m width/headroom");
        if(maximum_route_grade<.1||maximum_route_grade>.25)errors.Add("Protected main route grade must remain10–25percent");
        if(visible_radius_metres<96||preload_radius_metres<visible_radius_metres)errors.Add("Preload radius must cover the complete visible cave radius");
        if(resident_cell_limit<32||resident_cell_limit>256||pending_job_limit<4||pending_job_limit>32)errors.Add("Sparse cave cache/queue bounds exceeded");
        return errors;
    }
}
