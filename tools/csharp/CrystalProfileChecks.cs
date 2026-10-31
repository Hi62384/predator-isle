using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CrystalProfileChecks
{
    internal static D Fixture()
    {
        var a=new D {["id"]="A",["point"]=new Vector3(32,20,32),["level"]=1,["chamber_radius"]=26.0,["chamber_height"]=46.0};var b=new D {["id"]="B",["point"]=new Vector3(-32,20,32),["level"]=1,["chamber_radius"]=8.0,["chamber_height"]=8.0};
        return new D {["valid"]=true,["id"]=Vector2I.Zero,["nodes"]=new A {a,b},["edges"]=new A {new D {["from"]="A",["to"]="B",["points"]=new[]{a["point"].AsVector3(),b["point"].AsVector3()},["half_width"]=4.0,["headroom"]=8.0,["entrance"]=false}},["pockets"]=new A(),["pocket_passages"]=new A(),["cave_biome_regions"]=new D {["fallback"]="default",["candidates"]=new A {new D {["id"]="A/crystal",["biome_id"]="crystal",["anchor"]="A",["point"]=a["point"],["reach_m"]=350.0,["extent_m"]=700.0,["transition_m"]=48.0,["distances"]=new D {["A"]=0.0,["B"]=64.0},["connected_growth"]=true}},["edges"]=new A {new D {["from"]="A",["to"]="B",["length"]=64.0}}}};
    }
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/caves/crystal_profiles.gd");using var native=new CrystalConnectedProfiles();int geodes=0,ravines=0,lakes=0;
        foreach(int seed in new[]{73921,17,92881}.Concat(Enumerable.Range(1000,33)))
        {
            foreach(int style in new[]{0,1,2})foreach(double surface in new[]{45.0,200.0})
            {
                var region=Fixture();var before=GD.VarToBytes(region);var controls=new D {["geode_frequency"]=style==0?1.0:0.0,["ravine_frequency"]=style==1?1.0:0.0,["large_lake_frequency"]=0.0};var height=Callable.From<double,double,double>((x,z)=>surface);
                var expected=original.Call("decorate",region,height,seed,controls,400.0,10.0);var actual=native.decorate(region,height,seed,controls,400,10);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Crystal connected chamber descriptor differs: "+MigrationComparison.FirstDifference(expected,actual));
                require(before.SequenceEqual(GD.VarToBytes(region)),"Crystal connected chamber mutated original graph");
                require(GD.VarToBytes(actual).SequenceEqual(GD.VarToBytes(native.decorate(actual,height,seed,controls,400,10))),"Crystal connected chamber is not idempotent");
                if(style==0)geodes+=actual["pockets"].AsGodotArray().Count;if(style==1)ravines+=actual["pockets"].AsGodotArray().Count;
                require(actual["pockets"].AsGodotArray().Count<=4,"Crystal connected chamber exceeds four-addition cap");
            }
            var wet=Fixture();wet["pools"]=new A {new D {["id"]="A:seepage",["center"]=new Vector3(32,20,50),["radius"]=5.0,["water_radius"]=4.0,["water_y"]=19.6,["bed_y"]=17.0,["depth"]=3.0,["bed"]=new D {["id"]="A:bed",["point"]=new Vector3(32,17,50),["level"]=1,["chamber_radius"]=4.25,["chamber_height"]=4.5},["bed_lobes"]=new A()}};
            // Give the complete enlarged shore real host air; the old narrow
            // fixture correctly rejects every seed under the current field.
            wet["nodes"].AsGodotArray()[0].AsGodotDictionary()["chamber_radius"]=48.0;
            var flat=Callable.From<double,double,double>((x,z)=>200);var lakeControls=new D {["geode_frequency"]=0.0,["ravine_frequency"]=0.0,["large_lake_frequency"]=1.0};var expectedWet=original.Call("decorate",wet,flat,seed,lakeControls,400.0,10.0);var actualWet=native.decorate(wet,flat,seed,lakeControls,400,10);
            require(GD.VarToBytes(expectedWet).SequenceEqual(GD.VarToBytes(actualWet)),"Crystal retained lake growth differs: "+MigrationComparison.FirstDifference(expectedWet,actualWet));if(actualWet["pools"].AsGodotArray()[0].AsGodotDictionary().ContainsKey("crystal_large_lake"))lakes++;
        }
        require(geodes>30&&ravines>30&&lakes>0,$"Crystal profile fixture did not exercise geodes, ravines and measured retained lake banks: {geodes}/{ravines}/{lakes}");
        var originalLake=GD.Load<GDScript>("res://scripts/caves/crystal_lake_chambers.gd");using var nativeLake=new CrystalLakeChambers();int bankChambers=0;
        foreach(double surface in new[]{35.0,200.0})foreach(bool enabled in new[]{false,true})foreach(bool precise in new[]{false,true})foreach(int mode in new[]{0,1,2})
        {
            var wet=Fixture();var parent=wet["nodes"].AsGodotArray()[0].AsGodotDictionary();parent["point"]=new Vector3(300,20,300);wet["nodes"]=new A {parent};wet["edges"]=new A();
            var pool=new D {["id"]="A:seepage",["center"]=new Vector3(300,20,318),["radius"]=5.0,["water_radius"]=4.0,["water_y"]=19.6,["bed_y"]=17.0,["depth"]=3.0,["bed"]=new D {["id"]="A:bed",["point"]=new Vector3(300,17,318),["level"]=1,["chamber_radius"]=4.25,["chamber_height"]=4.5},["bed_lobes"]=new A()};wet["pools"]=new A {pool};
            if(mode==1)pool["stream_edges"]=new A {new D()};
            if(mode==2)wet["pools"].AsGodotArray().Add(new D {["id"]="higher-water",["center"]=new Vector3(304,21,318),["radius"]=5.0,["water_y"]=21.0});
            var controls=new D {["lake_chambers"]=enabled,["precise_shores"]=precise,["large_lake_frequency"]=1.0};var height=Callable.From<double,double,double>((x,z)=>surface);var before=GD.VarToBytes(wet);
            var expected=originalLake.Call("prepare",wet,height,17,controls,400.0,10.0);var actual=nativeLake.prepare(wet,height,17,controls,400,10);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Crystal bank chamber differs: "+MigrationComparison.FirstDifference(expected,actual));require(before.SequenceEqual(GD.VarToBytes(wet)),"Crystal bank chamber mutated source pools");
            if(actual["pools"].AsGodotArray()[0].AsGodotDictionary().ContainsKey("bank_lobes"))bankChambers++;
        }
        require(bankChambers>0,"Crystal lake fixture did not admit a real connected dry-bank chamber");
    }
}
