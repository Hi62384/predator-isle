using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;

namespace PredatorIsle.Checks;
internal static class CaveSettingsChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var reference=GD.Load<GDScript>("res://scripts/caves/cave_settings.gd");
        require(GD.Load<Resource>("res://config/caves/cave_settings.tres") is SharedCaveSettings,"Saved cave settings did not instantiate the C# resource");
        using var baseline=new SharedCaveSettings();using var original=reference.New().AsGodotObject();
        foreach(var property in baseline.GetPropertyList())
        {
            string name=property["name"].AsString();if((property["usage"].AsInt32()&(int)PropertyUsageFlags.ScriptVariable)==0||name=="biome_regions")continue;
            require(GD.VarToBytes(baseline.Get(name)).SequenceEqual(GD.VarToBytes(original.Get(name))),"Default shared cave setting differs: "+name);
        }
        foreach(string name in new[]{"maximum_depth_metres","regional_activity","minimum_rock_cover_metres","main_route_width_metres","main_route_height_metres","maximum_route_grade","visible_radius_metres","preload_radius_metres","formation_density","seepage_density"})
        foreach(double value in new[]{-1.0,0,.1,.25,.85,1,6,8,96,160,256,350,400,450,451,double.NaN,double.PositiveInfinity,double.NegativeInfinity})
        {
            using var current=new SharedCaveSettings();using var old=reference.New().AsGodotObject();current.Set(name,value);old.Set(name,value);
            require(GD.VarToBytes(old.Call("validation_errors")).SequenceEqual(GD.VarToBytes(current.validation_errors())),"Shared cave setting validation differs: "+name+"/"+value);
        }
        foreach(string name in new[]{"resident_cell_limit","pending_job_limit"})foreach(long value in new[]{-1L,0,3,4,12,31,32,128,256,257,long.MaxValue})
        {
            using var current=new SharedCaveSettings();using var old=reference.New().AsGodotObject();current.Set(name,value);old.Set(name,value);
            require(GD.VarToBytes(old.Call("validation_errors")).SequenceEqual(GD.VarToBytes(current.validation_errors())),"Shared cave queue/cache bound validation differs");
        }
        baseline.biome_regions=null;original.Set("biome_regions",default(Variant));
        require(GD.VarToBytes(original.Call("validation_errors")).SequenceEqual(GD.VarToBytes(baseline.validation_errors())),"Missing cave registry validation differs");
        baseline.biome_regions=GD.Load<Resource>("res://config/caves/cave_biome_regions.tres");using var clone=(SharedCaveSettings)baseline.DuplicateDeep(Resource.DeepDuplicateMode.All);
        require(clone.biome_regions!=baseline.biome_regions&&clone.validation_errors().Count==0,"Deeply copied shared cave settings did not retain an independent valid registry");
    }
}
