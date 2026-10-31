using Godot;
using System;
using System.Linq;
using PredatorIsle.Terrain;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle;

/// <summary>Existing opt-in export probe; inactive unless the user supplies smoke-test.</summary>
public partial class RuntimeSmoke : Node
{
    public double elapsed {get;set;}
    public int ready_frames {get;set;}
    public override void _Ready(){DisplayServer.WindowSetMode(DisplayServer.WindowMode.Windowed);DisplayServer.WindowSetSize(new Vector2I(1280,720));GetTree().Root.Size=new Vector2I(1280,720);}
    public override async void _Process(double delta)
    {
        elapsed+=delta;var terrain=GetParent<ChunkTerrain>();
        if(elapsed>120){GD.PushError("RUNTIME_SMOKE_TIMEOUT: no complete streamed partition");GetTree().Quit(2);SetProcess(false);return;}
        if(terrain.committed_revision!=terrain.partition_revision||terrain._active_chunks.Count==0)return;ready_frames++;var args=OS.GetCmdlineUserArgs();bool debug=args.Contains("extension-debug-smoke");
        if(debug&&ready_frames>=20&&ready_frames<25)
        {
            int index=ready_frames-20;terrain.set_debug_view(149+index);string[] names={"Extension ownership","Extension regional identity","Extension feature intensity","Extension wetness","Extension geometric normals"};
            if(terrain.get_debug_view_name()!=names[index]||terrain._terrain_material.GetShaderParameter("debug_view").AsInt32()!=260+index){GD.PushError("RUNTIME_SMOKE_DEBUG: extension HUD or shader mode mismatch");GetTree().Quit(3);SetProcess(false);return;}
        }
        if(debug&&ready_frames==25)terrain.set_debug_view(0);if(ready_frames<30)return;SetProcess(false);await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        string failure="";var settings=terrain._settings_snapshot;double N(string key)=>settings.Get(key).AsDouble();bool B(string key)=>settings.Get(key).AsBool();
        void Array(string name,int layers,string message){var texture=terrain._terrain_material.GetShaderParameter(name).AsGodotObject() as Texture2DArray;if(texture is null||texture.GetLayers()!=layers)failure=message+name;}
        void Bank(string name,int layers,string message){Array(name+"_colors",layers,message);Array(name+"_normals",layers,message);}
        Array("palette_color",9,"Missing nine-layer Grass palette: ");Array("palette_normal",9,"Missing nine-layer Grass palette: ");
        var point=terrain.target!.GlobalPosition;if(point.Y<terrain.get_height_at(point)+1)failure="Camera started below terrain";
        if(N("forest_coverage")>0)Bank("forest",2,"Forest CC0 array missing: ");
        if(N("tropical_coverage")>0)foreach(var bank in new[]{("savanna",8),("jungle",7),("swamp",3),("mountain",3)})Bank(bank.Item1,bank.Item2,"Tropical shared PBR array missing: ");
        if(N("badlands_coverage")>0)foreach(var bank in new[]{("savanna",8),("jungle",7),("mountain",3)})Bank(bank.Item1,bank.Item2,"Badlands shared PBR array missing: ");
        if(B("beaches_enabled"))Bank("beach",4,"Beach CC0 array missing: ");
        if(N("mountain_coverage")>0||B("rocky_coast_enabled")||B("beaches_enabled"))Bank("mountain",3,"Mountain CC0 array missing: ");
        if(N("savanna_coverage")>0||N("mountain_coverage")>0||B("rocky_coast_enabled"))Bank("savanna",8,"Savanna CC0 array missing: ");
        if(N("swamp_coverage")>0)Bank("swamp",3,"Swamp CC0 array missing: ");
        if(N("jungle_coverage")>0||N("forest_coverage")>0||N("swamp_coverage")>0||N("mountain_coverage")>0||B("rocky_coast_enabled"))Bank("jungle",7,"Jungle CC0 array missing: ");
        var report=new D{["elapsed_s"]=elapsed,["loaded_chunks"]=terrain.get_loaded_chunk_count(),["revision"]=terrain.committed_revision,["feature"]=terrain.jungle_preview_feature,["position"]=point.ToString(),["ground_height"]=terrain.get_height_at(point),["biome"]=terrain.get_biome_name_at(point),["failure"]=failure,["exported"]=!OS.HasFeature("editor"),["engine"]=Engine.GetVersionInfo()["string"]};
        foreach(string key in new[]{"jungle","forest","savanna","mountain","coast","beach","tropical","badlands","swamp"})report[key+"_preview"]=terrain.Get(key+"_preview");report["extension_preview"]=terrain.extension_preview;report["extension_debug_smoke"]=debug;
        foreach(string key in new[]{"badlands","tropical","beach","coast"})if(terrain.Get(key+"_preview").AsBool())report["feature"]=terrain.Get(key+"_preview_feature");
        int waterTiles=0;foreach(var n in terrain._active_chunks.Values){var water=((MeshInstance3D)n.AsGodotObject()).GetNodeOrNull<MeshInstance3D>("SwampWater");if(water?.Mesh is not null)waterTiles++;}
        report["swamp_water_tiles"]=waterTiles;report["local_water_level"]=terrain._sampler.get_water_surface_height(point.X,point.Z);
        foreach(string key in new[]{"mountain","swamp","forest","savanna","jungle"})if(terrain.Get(key+"_preview").AsBool())report["feature"]=terrain.Get(key+"_preview_feature");
        string output=args.FirstOrDefault(a=>a.StartsWith("smoke-output=",StringComparison.Ordinal))?[13..]??"";
        if(output.Length>0)
        {
            using var file=FileAccess.Open(output+".json",FileAccess.ModeFlags.Write);if(file is null)failure="Cannot write requested smoke result";else file.StoreString(Json.Stringify(report,"\t"));
            using var pixels=GetViewport().GetTexture().GetImage();if(pixels is null||pixels.SavePng(output+".png")!=Error.Ok)failure="Cannot save rendered smoke capture";
        }
        GD.Print("RUNTIME_SMOKE_",failure.Length==0?"PASS":"FAIL",": ",Json.Stringify(report));if(failure.Length>0)GD.PushError(failure);GetTree().Quit(failure.Length==0?0:1);
    }
}
