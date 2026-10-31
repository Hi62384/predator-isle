using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Checks;
internal static class CaveEntryGuardChecks
{
    internal static void Run(Action<bool,string> require)
    {
        using var hive = new CaveHiveEntryGuard(); using var insect = new CaveInsectEntryGuard();
        using var oldHive = GD.Load<GDScript>("res://scripts/caves/hive_entry_guard.gd").New().AsGodotObject();
        using var oldInsect = GD.Load<GDScript>("res://scripts/caves/insect_entry_guard.gd").New().AsGodotObject();
        foreach (string family in new[] {"alien_infected","insect_colony"})
        {
            var settings=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);
            foreach(string name in new[] {"grass","forest","savanna","swamp","jungle","mountain","tropical","badlands","quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"}) settings.Set(name+"_coverage",name==family?100:0);
            settings.Set("beaches_enabled",false); settings.Set("rocky_coast_enabled",false);
            using var builder=GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject(); builder.Set("settings",settings); builder.Set("world_seed",17); builder.Call("_configure_noise");
            hive.configure(builder); insect.configure(builder); oldHive.Call("configure",builder); oldInsect.Call("configure",builder);
            require(builder.Get("_extras").AsGodotArray()[family=="insect_colony"?6:7].VariantType!=Variant.Type.Nil,"Entrance guard fixture did not enable its structure sampler");
            var caves=GD.Load<Resource>("res://config/caves/cave_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All); caves.Set("insect_networks",true); caves.Set("hive_networks",true);
            using var graph=new CaveNetwork();graph.configure(Callable.From<double,double,double>((x,z)=>100),Callable.From<double,double,double>((x,z)=>-1000),17,400);graph.activity=1;
            using var nativeColony=new CaveColonyNetwork();using var referenceColony=GD.Load<GDScript>("res://scripts/caves/colony_network.gd").New().AsGodotObject();
            nativeColony.configure(builder,caves,graph);referenceColony.Call("configure",builder,caves,graph);
            for(int i=0;i<8;i++)
            {
                var cell=new Vector2I(i-4,i%3-1);var originalContext=referenceColony.Call("context",cell);var currentContext=nativeColony.Call("context",cell);
                require(GD.VarToBytes(originalContext).SequenceEqual(GD.VarToBytes(currentContext)),"Cave family context differs: "+MigrationComparison.FirstDifference(originalContext,currentContext));
            }
            var baseRegion=graph.region(Vector2I.Zero);require(baseRegion["valid"].AsBool(),"Cave family graph fixture not admitted");
            var description=family=="insect_colony"?new D {["family"]=6,["colony_id"]="fixture-colony",["surface_center"]=Vector2.Zero}:new D {["family"]=7,["hive_id"]="fixture-hive",["surface_center"]=Vector2.Zero,["hive_region"]=2.5};
            var expectedRegion=referenceColony.Call("decorate",baseRegion.Duplicate(true),description);var actualRegion=nativeColony.Call("decorate",baseRegion.Duplicate(true),description);
            require(GD.VarToBytes(expectedRegion).SequenceEqual(GD.VarToBytes(actualRegion)),"Cave family chambers, lobes or secondary routes differ: "+MigrationComparison.FirstDifference(expectedRegion,actualRegion));
            require(actualRegion.AsGodotDictionary()["cave_family"].AsInt32()==(family=="insect_colony"?6:7),"Cave family fixture did not run its decorator");
            require(graph.half_width==4&&graph.headroom==8,"Secondary family passage leaked temporary route dimensions");
            for(int i=0;i<24;i++)
            {
                var point=new Vector3((i-12)*1741.125f,50,(i%7-3)*2197.75f); double radius=i%2==0?4:8;
                require(oldHive.Call("clear_point",point,radius).AsBool()==hive.clear_point(point,radius),"Hive point clearance differs");
                var p=new Vector2(point.X,point.Z); var expected=oldInsect.Call("roots_near",p,radius); var actual=insect.roots_near(p,radius);
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Insect mound descriptors differ: "+MigrationComparison.FirstDifference(expected,actual));
                require(oldInsect.Call("clear_mounds",point,radius).AsBool()==insect.clear_mounds(point,radius),"Insect mound clearance differs");
                var edge=new D {["points"]=new[] {point,point+new Vector3(16,-2,8)},["half_width"]=radius};
                require(oldHive.Call("clear_access",edge).AsBool()==hive.clear_access(edge),"Hive dry approach clearance differs");
                require(oldInsect.Call("clear_access",edge).AsBool()==insect.clear_access(edge),"Insect dry approach clearance differs");
            }
            require(!hive.clear_point(Vector3.Inf,4)&&!insect.clear_mounds(Vector3.Inf,4)&&!insect.clear_mounds(Vector3.Zero,-1)&&!insect.clear_mounds(Vector3.Zero,double.NaN),"Entrance guard accepted invalid geometry");
            var finiteCell=new Vector2I(3,-2); var finitePoint=new Vector3(200,0,-100);
            var sites=new A {new D {["position"]=new Vector2(200,-100),["half"]=300.0}};
            insect._finite[finiteCell]=sites; oldInsect.Get("_finite").AsGodotDictionary()[finiteCell]=sites;
            require(!insect.clear_finite(finitePoint,4)&&!oldInsect.Call("clear_finite",finitePoint,4).AsBool(),"Finite structure reservation did not block the aperture");
            require(insect._roots.Count<=32&&insect._finite.Count<=64&&hive._finite.Count<=64,"Entrance guard caches exceeded their bounds");
        }
    }
}
