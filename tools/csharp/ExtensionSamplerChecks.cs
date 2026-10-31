using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;
using A=Godot.Collections.Array;

namespace PredatorIsle.Checks;
internal static class ExtensionSamplerChecks
{
    internal static void Run(Action<bool,string> require)
    {
        QuarryRoadChecks.Run(require);
        AlienSamplerChecks.Run(require);
        using var host=(RefCounted)GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();
        foreach(int family in new[]{0,1,2,3,4,5,6,7})foreach(long seed in new[]{-17L,17L,73921L})
        {
            string name=family==0?"quarry":family==1?"wise_mountains":family==2?"volcanic":family==3?"spore_forest":family==4?"radiation_wasteland":family==5?"crystal_wastes":family==6?"insect_colony":"alien_infected";var config=GD.Load<Resource>($"res://config/biomes/{name}_settings.tres");using var original=GD.Load<GDScript>($"res://scripts/{name}_sampler.gd").New().AsGodotObject();using BiomeExtensionSampler native=family==0?new QuarrySampler():family==1?new WiseMountainsSampler():family==2?new VolcanicSampler():family==3?new SporeForestSampler():family==4?new RadiationWastelandSampler():family==5?new CrystalWastesSampler():family==6?new InsectColonySampler():new AlienInfectedSampler();
            if(family is 1 or 4){host.Set("settings",GD.Load<Resource>("res://config/world/terrain_settings.tres"));host.Set("world_seed",seed);host.Call("_configure_noise");}
            original.Call("configure",config,seed,host,family);native.configure(config,seed,host,family);var random=new Random(73921);
            var originalNames=GD.Load<GDScript>($"res://scripts/{name}_sampler.gd").GetScriptConstantMap()["NAMES"];
            require(GD.VarToBytes(originalNames).SequenceEqual(GD.VarToBytes(native.Get("NAMES"))),"Extension preview region-name interface differs");
            for(int i=0;i<400;i++)
            {
                double x=i<20?(i-10)*16:random.NextDouble()*40000-20000,z=i<20?(i-10)*-256:random.NextDouble()*40000-20000;bool publish=i%3!=0;
                double expected=original.Call("sample",x,z,publish).AsDouble(),actual=native.sample(x,z,publish);Equal(expected,actual,$"{name} sample seed={seed} ({x:R},{z:R})");
                var oldState=original.Get("state").AsFloat64Array();for(int slot=0;slot<5;slot++)Equal(oldState[slot],native.state[slot],$"{name} published state {slot}");
                var p=new Vector2((float)x,(float)z);for(int id=0;id<6;id++){var a=original.Call("evaluate",p,id).AsFloat64Array();var b=native.evaluate(p,id);for(int slot=0;slot<5;slot++)Equal(a[slot],b[slot],$"{name} direct region {id} state {slot}");}
                if(i%20==0)
                {
                    var cell=new Vector2I(i-160,32-i);var a=original.Call("descriptor",cell,1700.5);var b=native.descriptor(cell,1700.5);require(GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b)),"Extension finite descriptor differs: "+MigrationComparison.FirstDifference(a,b));
                    if(native is InsectColonySampler insect)require(GD.VarToBytes(original.Call("satellites",a)).SequenceEqual(GD.VarToBytes(insect.satellites(b))),"Insect satellite sites differ");
                    if(native is VolcanicSampler volcanic)require(GD.VarToBytes(original.Call("active_lava_descriptor",p)).SequenceEqual(GD.VarToBytes(volcanic.active_lava_descriptor(p))),"Volcanic retained lava-source eligibility differs");
                    if(native is WiseMountainsSampler wise)require(GD.VarToBytes(original.Call("tributary",p)).SequenceEqual(GD.VarToBytes(wise.tributary(p))),"Wise Mountains tributary geometry differs");
                    if(native is SporeForestSampler spore)
                    {
                        require(GD.VarToBytes(original.Call("ecology",p)).SequenceEqual(GD.VarToBytes(spore.ecology(p))),"Spore colony union field differs");
                        var expectedDescription=original.Call("describe",p);var description=spore.describe(p);
                        foreach(string field in new[]{"height","water_level","wetness","region","feature"})
                        {
                            var value=expectedDescription.AsGodotDictionary()[field];require(value.VariantType==description[field].VariantType,"Spore description scalar type differs");Equal(value.AsDouble(),description[field].AsDouble(),"Spore description "+field);description[field]=value;
                        }
                        require(GD.VarToBytes(expectedDescription).SequenceEqual(GD.VarToBytes(description)),"Spore colony description differs: "+MigrationComparison.FirstDifference(expectedDescription,description));
                    }
                    if(native is RadiationWastelandSampler radiation)
                    {
                        require(GD.VarToBytes(original.Call("source_field",p)).SequenceEqual(GD.VarToBytes(radiation.source_field(p))),"Radiation contamination/source descriptor differs: "+MigrationComparison.FirstDifference(original.Call("source_field",p),radiation.source_field(p)));
                        require(GD.VarToBytes(original.Call("drainage",p)).SequenceEqual(GD.VarToBytes(radiation.drainage(p))),"Radiation outlet-connected drainage differs");
                        var expectedDescription=original.Call("describe",p);var description=radiation.describe(p);
                        require(GD.VarToBytes(expectedDescription).SequenceEqual(GD.VarToBytes(description)),"Radiation physical-damage description differs: "+MigrationComparison.FirstDifference(expectedDescription,description));
                    }
                }
            }
            for(int i=0;i<8200;i++)
            {
                var cell=new Vector2I(i,-i);var expected=original.Call("_node",cell).AsFloat64Array();var actual=native._node(cell);
                for(int slot=0;slot<5;slot++)Equal(expected[slot],actual[slot],$"Extension FIFO {name} seed={seed} cell={cell} slot={slot}");
            }
            require(native.NodeCount<=8192&&native.DescriptorCount<=512,"Extension sampler cache exceeded its original bound");
            if(native is WiseMountainsSampler mountains)
            {
                int admitted=0;double spacing=4000/Math.Max(host.Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),.01);
                for(int index=-4;index<=4;index++)
                {
                    double x=index*4096+Math.Sin(index*1.7+seed)*180,outlet=host.Call("_grass_river_center",x,0,spacing).AsDouble(),side=mountains.random(index,0,921)>.5?1:-1;var p=new Vector2((float)x,(float)(outlet+side*500));var actual=mountains.tributary(p);
                    require(GD.VarToBytes(original.Call("tributary",p)).SequenceEqual(GD.VarToBytes(actual)),"Wise Mountains positive tributary differs");if(actual.Y>0)admitted++;
                }
                require(admitted>0,"Wise Mountains fixture did not exercise a positive connected tributary");
            }
            if(native is SporeForestSampler fungus)
            {
                var p=new Vector2(39,-827);fungus.ecology(p);original.Call("ecology",p);original.Call("configure",config,seed+1,host,family);fungus.configure(config,seed+1,host,family);
                require(GD.VarToBytes(original.Call("ecology",p)).SequenceEqual(GD.VarToBytes(fungus.ecology(p))),"Spore ecology cache retained previous-seed values after configure");
            }
        }
        foreach(int family in new[]{0,1,2,3,4,5,6,7})
        {
            string name=family==0?"quarry":family==1?"wise_mountains":family==2?"volcanic":family==3?"spore_forest":family==4?"radiation_wasteland":family==5?"crystal_wastes":family==6?"insect_colony":"alien_infected";var settings=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);
            foreach(var item in settings.GetPropertyList()){string key=item["name"].AsString();if(key.EndsWith("_coverage",StringComparison.Ordinal))settings.Set(key,key==name+"_coverage"?100:0);}
            settings.Set("beaches_enabled",false);settings.Set("rocky_coast_enabled",false);
            using var originalBuilder=MigrationComparison.CreateReferenceTerrainBuilder();using var currentBuilder=new PredatorIsle.Terrain.TerrainMeshBuilder();
            foreach(var builder in new[]{originalBuilder,currentBuilder}){builder.Set("settings",settings);builder.Set("world_seed",73921);builder.Set("water_level",0.0);builder.Call("_configure_noise");}
            using var old=GD.Load<GDScript>($"res://scripts/{name}_sampler.gd").New().AsGodotObject();old.Call("configure",settings.Get(name),73921,originalBuilder,family);originalBuilder.Get("_extras").AsGodotArray()[family]=Variant.From(old);
            require(currentBuilder.Get("_extras").AsGodotArray()[family].AsGodotObject() is BiomeExtensionSampler,"Actual terrain builder did not create native extension sampler");
            for(int i=0;i<100;i++)
            {
                double x=i*137.25-7000,z=i*-91.5+3000;Equal(originalBuilder.Call("_get_height",x,z).AsDouble(),currentBuilder.Call("_get_height",x,z).AsDouble(),"Complete extension terrain/water integration");
                require(GD.VarToBytes(originalBuilder.Get("_last_extras")).SequenceEqual(GD.VarToBytes(currentBuilder.Get("_last_extras"))),"Extension packed material controls differ");
            }
        }
        void Equal(double a,double b,string scope)=>require(Math.Abs(a-b)<=1e-12&&(float)a==(float)b,$"{scope}: {a:R} / {b:R}");
    }
}
