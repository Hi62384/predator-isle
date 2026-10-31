using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class MagmaTubeChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/caves/magma_tubes.gd");using var current=new MagmaCaveTubes();int admitted=0;
        foreach(int seed in new[]{-17,17,73921})foreach(double frequency in new[]{0.0,.5,1.0})foreach(double fissure in new[]{0.0,1.0})foreach(double surface in new[]{0.0,100.0,500.0})
        {
            var nodes=new A {new D {["id"]="a",["point"]=new Vector3(0,-30,0),["level"]=0,["chamber_radius"]=18.0,["chamber_height"]=18.0},new D {["id"]="b",["point"]=new Vector3(32,-30,0),["level"]=0,["chamber_radius"]=18.0,["chamber_height"]=18.0}};
            var edge=new D {["from"]="a",["to"]="b",["points"]=new[]{new Vector3(0,-30,0),new Vector3(32,-30,0)},["entrance"]=false,["half_width"]=4.0,["headroom"]=8.0};
            var candidate=new D {["id"]="hot",["biome_id"]="magma",["reach_m"]=1000.0,["transition_m"]=100.0,["distances"]=new D {["a"]=0.0,["b"]=32.0}};
            var region=new D {["valid"]=true,["nodes"]=nodes,["edges"]=new A {edge},["cave_biome_regions"]=new D {["fallback"]="default",["candidates"]=new A {candidate}}};var config=new D {["tube_frequency"]=frequency,["fissure_frequency"]=fissure};var height=Callable.From<double,double,double>((x,z)=>surface);
            var expected=original.Call("decorate",region,height,seed,config,400.0,10.0);var actual=current.decorate(region,height,seed,config,400,10);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Cooled tube geometry differs: "+MigrationComparison.FirstDifference(expected,actual));
            if(actual["edges"].AsGodotArray()[0].AsGodotDictionary().ContainsKey("magma_tube_profile"))admitted++;
            require(!edge.ContainsKey("magma_tube_profile")&&edge["half_width"].AsDouble()==4&&edge["headroom"].AsDouble()==8,"Cooled tube mutated its original solved route");
        }
        require(admitted>0,"Cooled tube fixture never admitted an enlargement");
    }
}
