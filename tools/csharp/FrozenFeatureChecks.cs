using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class FrozenFeatureChecks
{
    internal static D Fixture()
    {
        var room=new D {["id"]="A",["point"]=new Vector3(32,20,32),["level"]=0,["chamber_radius"]=26.0,["chamber_height"]=36.0};
        var pool=new D {["id"]="A:seepage",["center"]=new Vector3(32,20,50),["radius"]=5.0,["water_y"]=19.6,["bed_y"]=17.0,["depth"]=3.0,["bed"]=new D {["id"]="A:basin-bed",["point"]=new Vector3(32,17,50),["level"]=0,["chamber_radius"]=4.25,["chamber_height"]=4.5}};
        var edge=new D {["from"]="A",["to"]="B",["points"]=new[]{new Vector3(-16,20,32),new Vector3(96,20,32)},["half_width"]=4.0,["headroom"]=8.0,["entrance"]=false};
        var candidate=new D {["id"]="A/frozen",["biome_id"]="frozen",["distances"]=new D {["A"]=0.0,["B"]=112.0},["reach_m"]=350.0,["transition_m"]=32.0};var assignment=new D {["fallback"]="default",["candidates"]=new A {candidate}};
        return new D {["id"]=Vector2I.Zero,["valid"]=true,["nodes"]=new A {room},["edges"]=new A {edge},["geology"]=0,["pools"]=new A {pool},["cave_biome_regions"]=assignment};
    }
    internal static void Run(Action<bool,string> require)
    {
        var script=GD.Load<GDScript>("res://scripts/caves/frozen_features.gd");using var original=script.New().AsGodotObject();using var current=new FrozenCaveFeatures();using var basins=new CaveSeepageBasins();var region=Fixture();var height=Callable.From<double,double,double>((x,z)=>150);var kinds=new HashSet<string>();
        using var savedProvider=GD.Load<Resource>("res://config/caves/biomes/frozen_cave_definition.tres").Get("feature_provider").As<Script>().Call("new").AsGodotObject();require(savedProvider is FrozenCaveFeatures,"Saved Frozen definition did not create the C# feature provider");
        foreach(bool large in new[]{false,true})foreach(double surface in new[]{25.0,150.0,1000.0})
        {
            var controls=new D {["large_lakes"]=large};var sample=Callable.From<double,double,double>((x,z)=>surface);var expected=original.Call("decorate_region",region,sample,17,controls,400.0,10.0);var actual=current.decorate_region(region,sample,17,controls,400,10);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Expanded Frozen basin descriptor differs: "+MigrationComparison.FirstDifference(expected,actual));
        }
        using var field=new PortalCaveField();require(field.compile(new A {region},height,new A(),region["cave_biome_regions"].AsGodotDictionary()),"Frozen feature chamber fixture did not compile");
        foreach(int seed in new[]{17,73921})foreach(bool smooth in new[]{false,true})foreach(bool ice in new[]{false,true})foreach(var key in new[]{Vector3I.Zero,new Vector3I(1,0,0),new Vector3I(-1,0,0)})
        {
            var controls=new D {["density"]=1.0,["curtain_chance"]=1.0,["lake_ice"]=ice,["smooth_normals"]=smooth};var water=basins.water_cell(new A {region},field,key);var expected=original.Call("build",field,key,seed,new A {region},controls,water);var actual=current.build(field,key,seed,new A {region},controls,water);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Complete Frozen feature payload differs: "+MigrationComparison.FirstDifference(expected,actual));
            require(field.include_surface_air&&field.opening_rock_cover==0,"Frozen provider retained a temporary extraction mode");
            foreach(var item in actual["placements"].AsGodotArray()){var placement=item.AsGodotDictionary();kinds.Add(placement["kind"].AsString());require(placement["owner"].AsVector3I()==key,"Frozen feature was assigned to the wrong half-open cell");}
        }
        require(kinds.Contains("frozen_water")&&kinds.Contains("frozen_waterfall")&&kinds.Contains("ice_shore_apron")&&(kinds.Contains("icicle")||kinds.Contains("ice_column")),"Frozen fixtures did not exercise real ice growth, wall sheet, retained pool and supported shore apron");
        var hotRegion=region.Duplicate(true);hotRegion["cave_thermal_sources"]=new A {new D {["id"]="controlled-hot-zone",["point"]=new Vector3(32,36,32),["radius"]=64.0,["height"]=64.0,["heat"]=1.0}};
        using var hotField=new PortalCaveField();require(hotField.compile(new A {hotRegion},height,new A(),region["cave_biome_regions"].AsGodotDictionary())&&hotField.thermal_sources.Count>0,"Frozen hot-exclusion fixture did not register its thermal source");var hotControls=new D {["density"]=1.0,["curtain_chance"]=1.0};var hotWater=basins.water_cell(new A {hotRegion},hotField,Vector3I.Zero);
        var expectedHot=original.Call("build",hotField,Vector3I.Zero,73921,new A {hotRegion},hotControls,hotWater);var actualHot=current.build(hotField,Vector3I.Zero,73921,new A {hotRegion},hotControls,hotWater);
        require(GD.VarToBytes(expectedHot).SequenceEqual(GD.VarToBytes(actualHot)),"Frozen hot-zone exclusion differs");
    }
}
