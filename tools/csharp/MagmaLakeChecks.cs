using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class MagmaLakeChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/caves/magma_lake_chambers.gd");using var current=new MagmaLakeChambers();using var heat=new CaveHeatFixture();int admitted=0;
        foreach(double chance in new[]{0.0,1.0})foreach(double surface in new[]{-80.0,100.0})foreach(int sourceMode in new[]{0,1,2})
        {
            heat.heat=sourceMode==1?0:1;heat.source_id=sourceMode==2?"wrong-source":"fixture-heat";
            var point=new Vector3(300,-100,300);var poolCenter=point+Vector3.Right*14;
            var room=new D {["id"]="room",["point"]=point,["level"]=0,["chamber_radius"]=18.0,["chamber_height"]=18.0};
            var bed=new D {["id"]="room:bed",["point"]=poolCenter-Vector3.Up*3,["level"]=0,["chamber_radius"]=3.4,["chamber_height"]=4.5};
            var pool=new D {["id"]="room:seepage",["fluid_kind"]="magma",["center"]=poolCenter,["radius"]=4.0,["water_radius"]=3.2,["water_y"]=-100.4,["bed_y"]=-103.0,["depth"]=3.0,["bed"]=bed,["bed_lobes"]=new A(),["thermal_source"]="fixture-heat"};
            var candidate=new D {["id"]="hot",["biome_id"]="magma",["reach_m"]=1000.0,["transition_m"]=100.0,["distances"]=new D {["room"]=0.0}};
            var region=new D {["id"]=Vector2I.Zero,["valid"]=true,["nodes"]=new A {room},["edges"]=new A(),["pools"]=new A {pool},["cave_biome_regions"]=new D {["fallback"]="default",["candidates"]=new A {candidate}}};var settings=new D {["large_lake_chambers"]=true,["large_lake_chance"]=chance};var height=Callable.From<double,double,double>((x,z)=>surface);var before=GD.VarToBytes(region);
            var expected=original.Call("prepare",region,height,17,settings,400.0,10.0,heat);var actual=current.prepare(region,height,17,settings,400,10,heat);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Source-backed lake chamber differs: "+MigrationComparison.FirstDifference(expected,actual));
            require(before.SequenceEqual(GD.VarToBytes(region)),"Lake chamber mutated its immutable source descriptor");
            if(actual["pools"].AsGodotArray()[0].AsGodotDictionary().ContainsKey("magma_large_lake"))admitted++;
        }
        require(admitted>0,"Large magma lake fixture did not admit a measured dry bank");
    }
}
