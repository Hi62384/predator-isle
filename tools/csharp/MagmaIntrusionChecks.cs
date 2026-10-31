using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class MagmaIntrusionChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var script=GD.Load<GDScript>("res://scripts/caves/magma_intrusions.gd");
        using(var original=script.New().AsGodotObject())using(var current=new MagmaIntrusions())
            for(int kind=0;kind<4;kind++)require(GD.VarToBytes(original.Call("prototype",kind)).SequenceEqual(GD.VarToBytes(current.prototype(kind))),"Cooled intrusion prototype differs");
        int placed=0;
        foreach(int style in new[]{0,2,3,5})foreach(int seed in new[]{17,73921})foreach(var key in new[]{Vector3I.Zero,new Vector3I(-1,-1,1)})foreach(int limit in new[]{0,8})
        {
            var center=(Vector3)key*64+new Vector3(32,16,32);var room=new D {["id"]="room",["point"]=center,["level"]=0,["chamber_radius"]=26.0,["chamber_height"]=28.0};
            var candidate=new D {["id"]="hot",["biome_id"]="magma",["reach_m"]=1000.0,["transition_m"]=100.0,["distances"]=new D {["room"]=0.0}};var assignment=new D {["fallback"]="default",["candidates"]=new A {candidate}};
            using var field=new CaveField();require(field.compile(new A {new D {["valid"]=true,["nodes"]=new A {room},["edges"]=new A(),["cross_section_style"]=style}},Callable.From<double,double,double>((x,z)=>200),new A(),assignment),"Cooled intrusion room fixture not admitted");
            var rooms=new D {["room"]=room};var settings=new D {["intrusion_frequency"]=1.0,["lava_drip_frequency"]=1.0};using var original=script.New().AsGodotObject();using var current=new MagmaIntrusions();
            var expected=original.Call("build",field,key,seed,rooms,1.0,limit,settings);var actual=current.build(field,key,seed,rooms,1,limit,settings);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Complete cooled intrusion payload differs: "+MigrationComparison.FirstDifference(expected,actual));
            var count=actual["placements"].AsGodotArray().Count;require(count<=limit,"Cooled intrusion exceeded its placement limit");placed+=count;
        }
        require(placed>0,"Cooled intrusion fixtures did not place a measured rock feature");
    }
}
