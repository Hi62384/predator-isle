using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class ShallowChamberChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var reference=GD.Load<GDScript>("res://scripts/caves/shallow_chambers.gd");var crystalReference=GD.Load<GDScript>("res://scripts/caves/crystal_shallow.gd");using var native=new ShallowCaveChambers();using var crystal=new CrystalShallowChambers();bool positive=false,crystalPositive=false;
        var region=new D {["valid"]=true,["id"]=Vector2I.Zero,["nodes"]=new A {new D {["id"]="A",["point"]=new Vector3(-32,20,0),["level"]=-1,["chamber_radius"]=10.0,["chamber_height"]=12.0},new D {["id"]="B",["point"]=new Vector3(64,20,0),["level"]=0,["chamber_radius"]=20.0,["chamber_height"]=16.0}},["edges"]=new A {new D {["from"]="A",["to"]="B",["points"]=new[]{new Vector3(-32,20,0),new Vector3(0,20,0),new Vector3(32,20,0),new Vector3(64,20,0)},["half_width"]=4.0,["headroom"]=8.0,["entrance"]=true}},["pockets"]=new A(),["pocket_passages"]=new A(),["cave_biome_regions"]=new D {["fallback"]="default",["candidates"]=new A {new D {["id"]="B/crystal",["biome_id"]="crystal",["anchor"]="B",["distances"]=new D {["A"]=96.0,["B"]=0.0},["reach_m"]=1000.0,["transition_m"]=32.0}}}};
        foreach(double surface in new[]{40.0,52.0,100.0})foreach(int family in new[]{0,6,7})foreach(bool enabled in new[]{false,true})
        {
            region["cave_family"]=family;var before=GD.VarToBytes(region);var height=Callable.From<double,double,double>((x,z)=>surface);
            var expected=reference.Call("prepare",region,height,enabled,400.0,10.0);var actual=native.prepare(region,height,enabled,400,10);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Shared shallow chamber descriptor differs: "+MigrationComparison.FirstDifference(expected,actual));positive|=actual["pockets"].AsGodotArray().Count>0;
            var expectedCrystal=crystalReference.Call("prepare",region,height,enabled,400.0,10.0);var actualCrystal=crystal.prepare(region,height,enabled,400,10);
            require(GD.VarToBytes(expectedCrystal).SequenceEqual(GD.VarToBytes(actualCrystal)),"Crystal shallow reach/topology differs: "+MigrationComparison.FirstDifference(expectedCrystal,actualCrystal));crystalPositive|=actualCrystal["pockets"].AsGodotArray().Count>0;
            require(before.SequenceEqual(GD.VarToBytes(region)),"Shallow chamber changed original graph");
            require(GD.VarToBytes(region["nodes"]).SequenceEqual(GD.VarToBytes(actual["nodes"]))&&GD.VarToBytes(region["edges"]).SequenceEqual(GD.VarToBytes(actual["edges"])),"Shallow chamber changed retained nodes/routes");
        }
        require(positive&&crystalPositive,"Shallow fixtures did not admit shared and Crystal side chambers");
        var flat=Callable.From<double,double,double>((x,z)=>52);using var originalField=new CaveField();using var damagedField=new CaveField();
        var damaged=region.Duplicate(true);damaged["pockets"].AsGodotArray().Add(new D {["id"]="bad-floor",["point"]=new Vector3(0,16,0),["level"]=0,["chamber_radius"]=18.0,["chamber_height"]=12.0});
        region["cave_family"]=0;damaged["cave_family"]=0;
        require(originalField.compile(new A {region},flat)&&damagedField.compile(new A {damaged},flat),"Shallow floor protection fixtures did not compile");
        var start=new Vector3(0,20,0);var join=new Vector3(20,20,0);var end=new Vector3(30,20,0);
        bool expectedSafe=reference.Call("retained_floors_safe",region,originalField,damagedField,start,join,end).AsBool();bool actualSafe=native.retained_floors_safe(region,originalField,damagedField,start,join,end);
        require(!expectedSafe&&!actualSafe,"Shallow floor guard accepted a branch that removes the existing walking floor");
    }
}
