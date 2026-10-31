using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class JunglePlacementChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/jungle_placement.gd");using var native=new JunglePlacement();using var builder=GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();var terrain=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);
        foreach(var item in terrain.GetPropertyList()){string name=item["name"].AsString();if(name.EndsWith("_coverage",StringComparison.Ordinal))terrain.Set(name,name=="jungle_coverage"?100:0);}terrain.Set("beaches_enabled",false);terrain.Set("rocky_coast_enabled",false);builder.Set("settings",terrain);builder.Set("world_seed",73921);builder.Set("water_level",0.0);builder.Call("_configure_noise");
        bool positive=false;var focus=new Vector2(-7000,3000);
        for(int i=0;i<100;i++)
        {
            double x=i*137.25-7000,z=i*-91.5+3000;var expected=original.Call("habitat",builder,x,z);var actual=native.habitat(builder,x,z);
            if(expected.AsGodotDictionary().ContainsKey("downhill_direction")&&!GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)))
            {
                var a=expected.AsGodotDictionary()["downhill_direction"].AsVector2();var b=actual["downhill_direction"].AsVector2();GD.Print($"Placement direction diagnostic ({x:R},{z:R}): original=({a.X:R},{a.Y:R}) bits=({BitConverter.SingleToInt32Bits(a.X)},{BitConverter.SingleToInt32Bits(a.Y)}); native=({b.X:R},{b.Y:R}) bits=({BitConverter.SingleToInt32Bits(b.X)},{BitConverter.SingleToInt32Bits(b.Y)})");
            }
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Jungle placement habitat differs: "+MigrationComparison.FirstDifference(expected,actual));if(!positive&&actual["canopy"].AsDouble()>.01){focus=new Vector2((float)x,(float)z);positive=true;}
        }
        require(positive,"Jungle placement fixture did not reach suitable canopy habitat");int candidates=0;
        foreach(double spacing in new[]{0.0,24.0,100.0})foreach(long maximum in new[]{0L,3L,300L})foreach(long offset in new[]{-1L,17L,1000000000L})
        {
            var bounds=new Rect2(focus-new Vector2(128,128),new Vector2(256,256));var expected=original.Call("candidates",builder,bounds,spacing,maximum,offset);var actual=native.candidates(builder,bounds,spacing,maximum,offset);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Jungle bounded candidate page differs: "+MigrationComparison.FirstDifference(expected,actual));require(actual["cells_probed"].AsInt64()<=512&&actual["candidates"].AsGodotArray().Count<=256,"Jungle placement page exceeded original bounds");candidates+=actual["candidates"].AsGodotArray().Count;
        }
        foreach(var bounds in new[]{new Rect2(focus,Vector2.Zero),new Rect2(focus,new Vector2(-10,-10))})require(GD.VarToBytes(original.Call("candidates",builder,bounds)).SequenceEqual(GD.VarToBytes(native.candidates(builder,bounds))),"Jungle empty/reversed rectangle differs");
        require(candidates>0,"Jungle placement fixture did not emit actual candidate data");
        var config=builder.Get("_jungle").AsGodotObject().Get("settings").As<Resource>();config.Set("canopy_density",0);var emptyBounds=new Rect2(focus,new Vector2(256,256));var disabled=native.candidates(builder,emptyBounds,24,128,0);require(disabled["candidates"].AsGodotArray().Count==0&&GD.VarToBytes(original.Call("candidates",builder,emptyBounds,24,128,0)).SequenceEqual(GD.VarToBytes(disabled)),"Jungle canopy-off page differs");
        builder.Set("water_level",100000.0);require(GD.VarToBytes(original.Call("habitat",builder,focus.X,focus.Y)).SequenceEqual(GD.VarToBytes(native.habitat(builder,focus.X,focus.Y))),"Jungle underwater habitat differs");
    }
}
