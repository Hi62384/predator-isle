using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class MagmaCascadeChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/caves/magma_cascades.gd");using var current=new MagmaCascades();using var source=new CaveHeatFixture {source_id="explicit_controlled_cascade_intrusion"};
        var room=new D {["id"]="A",["point"]=new Vector3(32,20,32),["level"]=0,["chamber_radius"]=26.0,["chamber_height"]=36.0};
        var pool=new D {["id"]="A:seepage",["center"]=new Vector3(32,20,50),["radius"]=5.0,["water_y"]=19.6,["bed_y"]=17.0,["depth"]=3.0,["fluid_kind"]="magma",["thermal_source"]=source.source_id,["source_heat"]=1.0,["bed"]=new D {["id"]="A:basin-bed",["point"]=new Vector3(32,17,50),["level"]=0,["chamber_radius"]=4.25,["chamber_height"]=4.5}};
        var edge=new D {["from"]="A",["to"]="B",["points"]=new[]{new Vector3(-16,20,32),new Vector3(96,20,32)},["half_width"]=4.0,["headroom"]=8.0,["entrance"]=false};
        var candidate=new D {["id"]="A/magma",["biome_id"]="magma",["distances"]=new D {["A"]=0.0,["B"]=112.0},["reach_m"]=350.0,["transition_m"]=32.0};
        var assignment=new D {["fallback"]="default",["candidates"]=new A {candidate}};
        var region=new D {["id"]=Vector2I.Zero,["valid"]=true,["nodes"]=new A {room},["edges"]=new A {edge},["geology"]=0,["pools"]=new A {pool},["cave_biome_regions"]=assignment};
        var settings=new D {["molten_cascades"]=true,["molten_cascade_chance"]=1.0};var height=Callable.From<double,double,double>((x,z)=>200);D? first=null;var before=GD.VarToBytes(region);
        for(int seed=0;seed<16;seed++)
        {
            var expected=original.Call("prepare",region,height,seed,settings,400.0,10.0,source);var actual=current.prepare(region,height,seed,settings,400,10,source);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Measured molten cascade differs: "+MigrationComparison.FirstDifference(expected,actual));
            if(first==null&&actual["pools"].AsGodotArray()[0].AsGodotDictionary().ContainsKey("molten_cascade"))first=actual;
        }
        require(first!=null,"Controlled source/chance-one cascade fixture did not admit a supported film and free fall");
        require(before.SequenceEqual(GD.VarToBytes(region)),"Molten cascade changed its original excavation descriptor");
        var stripped=first!.Duplicate(true);stripped["pools"].AsGodotArray()[0].AsGodotDictionary().Remove("molten_cascade");require(before.SequenceEqual(GD.VarToBytes(stripped)),"Molten cascade added unrelated geometry");
        using var field=new CaveField();require(field.compile(new A {first},height,new A(),first["cave_biome_regions"].AsGodotDictionary()),"Molten cascade volume fixture did not compile");
        var cascade=first["pools"].AsGodotArray()[0].AsGodotDictionary()["molten_cascade"].AsGodotDictionary();var points=cascade["vertices"].AsVector3Array();require(points.Length==288,"Molten cascade changed its bounded triangle count");
        foreach(var point in points)
        {
            require(field.sample(point)<-.03,"Molten cascade vertex left measured cave air");
            require(original.Call("backing_distance",field,point,field.normal(point)).AsDouble()==current.backing_distance(field,point,field.normal(point)),"Molten film solid backing differs");
        }
        using var basins=new CaveSeepageBasins();foreach(var key in new[]{Vector3I.Zero,new Vector3I(1,0,0)})
        {
            var patch=basins.water_cell(new A {first},field,key,"magma");var expected=original.Call("append_to",patch,new A {first},key);var actual=current.append_to(patch,new A {first},key);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Dedicated molten cascade batch append differs");
        }
        foreach(int mode in new[]{0,1,2})
        {
            source.heat=mode==1?0:1;source.source_id=mode==2?"wrong-source":"explicit_controlled_cascade_intrusion";var controls=settings.Duplicate();if(mode==0)controls["molten_cascades"]=false;
            require(before.SequenceEqual(GD.VarToBytes(current.prepare(region,height,17,controls,400,10,source))),"Disabled/cold/wrong-source molten cascade was admitted");
        }
    }
}
