using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class MagmaFeatureChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var script=GD.Load<GDScript>("res://scripts/caves/magma_features.gd");using var original=script.New().AsGodotObject();using var current=new MagmaCaveFeatures();using var heat=new CaveHeatFixture();int placed=0,molten=0;
        using var savedProvider=GD.Load<Resource>("res://config/caves/biomes/magma_cave_definition.tres").Get("feature_provider").As<Script>().Call("new").AsGodotObject();require(savedProvider is MagmaCaveFeatures,"Saved Magma definition did not create the C# feature provider");
        foreach(int seed in new[]{17,73921})foreach(bool varied in new[]{false,true})foreach(bool heated in new[]{false,true})
        {
            var room=new D {["id"]="A",["point"]=new Vector3(32,20,32),["level"]=0,["chamber_radius"]=26.0,["chamber_height"]=36.0};
            var pool=new D {["id"]="A:seepage",["center"]=new Vector3(32,20,50),["radius"]=5.0,["water_y"]=19.6,["bed_y"]=17.0,["depth"]=3.0,["bed"]=new D {["id"]="A:basin-bed",["point"]=new Vector3(32,17,50),["level"]=0,["chamber_radius"]=4.25,["chamber_height"]=4.5}};
            var edge=new D {["from"]="A",["to"]="B",["points"]=new[]{new Vector3(-16,20,32),new Vector3(96,20,32)},["half_width"]=4.0,["headroom"]=8.0,["entrance"]=false};
            var candidate=new D {["id"]="A/magma",["biome_id"]="magma",["distances"]=new D {["A"]=0.0,["B"]=112.0},["reach_m"]=350.0,["transition_m"]=32.0};var assignment=new D {["fallback"]="default",["candidates"]=new A {candidate}};
            var region=new D {["id"]=Vector2I.Zero,["valid"]=true,["nodes"]=new A {room},["edges"]=new A {edge},["geology"]=0,["pools"]=new A {pool},["cave_biome_regions"]=assignment};
            var configuration=new D {["chamber_variety"]=varied,["cooled_deposits"]=true,["density"]=1.0,["cooled_intrusions"]=true,["intrusion_frequency"]=1.0,["lava_drip_frequency"]=1.0,["active_pool_chance"]=1.0,["large_lake_chambers"]=false,["molten_cascades"]=false};var height=Callable.From<double,double,double>((x,z)=>200);heat.heat=heated?1:0;
            var expectedRegion=original.Call("decorate_region_with_context",region,height,seed,configuration,400.0,10.0,heat);var actualRegion=current.decorate_region_with_context(region,height,seed,configuration,400,10,heat);
            require(GD.VarToBytes(expectedRegion).SequenceEqual(GD.VarToBytes(actualRegion)),"Combined magma chamber/pool/deposit descriptor differs: "+MigrationComparison.FirstDifference(expectedRegion,actualRegion));
            using var field=new PortalCaveField();require(field.compile(new A {actualRegion},height,new A(),assignment),"Combined magma feature fixture did not compile");
            foreach(var key in new[]{Vector3I.Zero,new Vector3I(1,0,0)})
            {
                var expected=original.Call("build",field,key,seed,new A {actualRegion},configuration,new D());var actual=current.build(field,key,seed,new A {actualRegion},configuration,new D());
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Complete magma feature payload differs: "+MigrationComparison.FirstDifference(expected,actual));
                require(field.include_surface_air&&field.opening_rock_cover==0,"Magma feature provider retained a temporary extraction mode");
                placed+=actual["placements"].AsGodotArray().Count;
                foreach(var batch in actual["batches"].AsGodotArray())if(batch.AsGodotDictionary()["kind"].AsString()=="molten_volcanic")molten++;
            }
            var off=configuration.Duplicate();off["density"]=0.0;require(GD.VarToBytes(original.Call("build",field,Vector3I.Zero,seed,new A {actualRegion},off,new D())).SequenceEqual(GD.VarToBytes(current.build(field,Vector3I.Zero,seed,new A {actualRegion},off,new D()))),"Disabled magma feature provider differs");
        }
        require(placed>0&&molten>0,"Combined magma fixtures did not create both cooled rock and a witnessed molten batch");
    }
}
