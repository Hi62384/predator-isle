using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveSeepageChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/caves/seepage_surface.gd");using var current=new CaveSeepageSurface();int visible=0;
        var originalBasins=GD.Load<GDScript>("res://scripts/caves/seepage_basins.gd");using var basins=new CaveSeepageBasins();int retained=0;
        foreach(int seed in new[]{-17,17,73921}) for(int geology=0;geology<8;geology++) foreach(double density in new[]{0.0,.15,1.0})
        {
            var rooms=new A();for(int i=0;i<8;i++) rooms.Add(new D {["id"]="room:"+i,["point"]=new Vector3(i*64,-i*20,i*-80),["level"]=i%3,["chamber_radius"]=26.0,["chamber_height"]=24.0});
            var region=new D {["id"]=new Vector2I(-3,8),["valid"]=true,["geology"]=geology,["nodes"]=rooms,["edges"]=new A()};
            foreach(bool soluble in new[]{false,true})
            {
                var expected=originalBasins.Call("make",region,seed,density,soluble);var actual=basins.make(region,seed,density,soluble);retained+=actual.Count;
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Retained basin placement differs: "+MigrationComparison.FirstDifference(expected,actual));
                require(actual.Count<=4,"Retained basin placement exceeded its regional bound");
            }
        }
        require(retained>0,"Basin placement fixtures did not retain any pool");
        foreach(var offset in new[]{Vector3.Zero,new Vector3(-128,0,64)})
        foreach(bool stream in new[]{false,true})
        for(int style=0;style<8;style++)
        {
            var center=offset+new Vector3(16,0,16);var bed=new D {["id"]="bed",["point"]=center-new Vector3(0,3,0),["level"]=0,["chamber_radius"]=3.4,["chamber_height"]=4.5};
            var pool=new D {["id"]="fixture-pool",["center"]=center,["radius"]=4.0,["water_radius"]=3.2,["water_y"]=-.4,["bed_y"]=-3.0,["bed"]=bed};var edges=new A();
            if(stream)
            {
                var path=Enumerable.Range(0,5).Select(i=>center+new Vector3(2+i,-2,i)).ToArray();pool["stream_points"]=path;
                edges.Add(new D {["points"]=path,["half_width"]=1.5,["headroom"]=4.5,["entrance"]=false});pool["stream_edges"]=edges;
            }
            using var field=new CaveField();require(field.compile(new A {new D {["valid"]=true,["nodes"]=new A {bed},["edges"]=edges,["cross_section_style"]=style}},Callable.From<double,double,double>((x,z)=>100)),"Seepage fixture field failed");
            for(int i=0;i<12;i++)
            {
                var p=new Vector2(center.X+i*.5f,center.Z-i*.25f);var expected=original.Call("water_point",pool,p);Variant actual=current.water_point(pool,p);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Retained water height differs");
            }
            var expectedPatch=original.Call("build",pool,field,style);var patch=current.build(pool,field,style);
            require(GD.VarToBytes(expectedPatch).SequenceEqual(GD.VarToBytes(patch)),"Measured seepage surface differs: "+MigrationComparison.FirstDifference(expectedPatch,patch));
            if(patch["valid"].AsBool()&&patch["arrays"].AsGodotArray().Count>0) visible++;
            require(GD.VarToBytes(originalBasins.Call("surface_outline",pool,field)).SequenceEqual(GD.VarToBytes(basins.surface_outline(pool,field))),"Measured retained pool outline differs");
            require(GD.VarToBytes(originalBasins.Call("water_arrays",pool,offset)).SequenceEqual(GD.VarToBytes(basins.water_arrays(pool,offset))),"Retained pool disk payload differs");
            var regions=new A {new D {["pools"]=new A {pool},["cross_section_style"]=style}};var cell=field.Call("cell",new Vector3(center.X,-.4f,center.Z)).AsVector3I();
            require(GD.VarToBytes(originalBasins.Call("water_cell",regions,field,cell)).SequenceEqual(GD.VarToBytes(basins.water_cell(regions,field,cell))),"Owned retained water cell payload differs");
            require(GD.VarToBytes(originalBasins.Call("water_cell",regions,field,cell,"magma")).SequenceEqual(GD.VarToBytes(basins.water_cell(regions,field,cell,"magma"))),"Fluid-kind filtering differs");
            var huge=pool.Duplicate(true);huge["radius"]=100000.0;
            require(!current.build(huge,field,style)["valid"].AsBool(),"Seepage accepted an unbounded sampling domain");
        }
        require(visible>0,"Seepage fixtures did not produce a visible retained pool");
    }
}
