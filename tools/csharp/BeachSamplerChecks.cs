using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class BeachSamplerChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var script=GD.Load<GDScript>("res://scripts/beach_sampler.gd");
        foreach(long seed in new[]{-17L,17L,73921L})
        {
            using var host=(RefCounted)GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();var terrain=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);terrain.Set("beaches_enabled",true);terrain.Set("rocky_coast_enabled",true);terrain.Set("island_size",6000.0);host.Set("settings",terrain);host.Set("world_seed",seed);host.Set("water_level",0.0);host.Call("_configure_noise");var coast=host.Get("_coast").As<RefCounted>();var config=terrain.Get("beach").As<Resource>();
            using var original=script.New().AsGodotObject();using var native=new BeachSampler();original.Call("configure",config,coast);native.configure(config,coast);require(GD.VarToBytes(script.GetScriptConstantMap()["NAMES"]).SequenceEqual(GD.VarToBytes(native.NAMES)),"Beach preview names differ");var random=new Random(73921);
            foreach(double coverage in new[]{0.0,.5,1.0})
            {
                config.Set("coverage",coverage);
                for(int i=0;i<160;i++)
                {
                    var p=new Vector2((float)(random.NextDouble()*40000-20000),(float)(random.NextDouble()*40000-20000));Equal(original.Call("wind_angle",p).AsDouble(),native.wind_angle(p),"Beach wind direction");Equal(original.Call("shore_distance",p).AsDouble(),native.shore_distance(p),"Beach polynomial shore carrier");
                    var weights=new float[16];weights[i%16]=1;double angle=i*.37;var frame=new Vector3(0,(float)Math.Cos(angle),(float)Math.Sin(angle));double a=random.NextDouble()*2-1,b=random.NextDouble()*2-1,c=random.NextDouble()*2-1,river=i%3==0?double.PositiveInfinity:i*17.5;
                    var expected=original.Call("evaluate",p,frame,weights,a,b,c,river).AsFloat64Array();var actual=native.evaluate(p,frame,weights,a,b,c,river);require(expected.Length==actual.Length,"Beach control schema differs");for(int channel=0;channel<actual.Length;channel++)Equal(expected[channel],actual[channel],$"Beach region {i%16} channel {channel}");
                }
            }
            for(int i=0;i<4100;i++){var cell=new Vector2I(i,-i);Equal(original.Call("_shore_node",cell).AsDouble(),native._shore_node(cell),"Beach node-cache eviction");}
            require(native.ShoreNodeCount<=4096&&native.ShorePatchCount<=2048,"Beach shore caches exceed original bounds");
            require(coast.Get("beach").AsGodotObject() is BeachSampler,"Production Rocky Coast did not create the native Beach sampler");
            using var referenceCoast=GD.Load<GDScript>("res://scripts/rocky_coast_sampler.gd").New().AsGodotObject();referenceCoast.Call("configure",terrain.Get("rocky_coast"),seed,host);using var referenceBeach=script.New().AsGodotObject();referenceBeach.Call("configure",config,referenceCoast);referenceCoast.Set("beach",referenceBeach);bool positive=false;
            for(int i=0;i<200;i++)
            {
                double x=(i%20-10)*1003.25,z=(i/20-5)*907.5,hint=host.Call("_island_mask",x,z).AsDouble()*3000;bool publish=i%3!=0;
                Equal(referenceCoast.Call("sample",x,z,70.0,hint,publish).AsDouble(),coast.Call("sample",x,z,70.0,hint,publish).AsDouble(),"Complete Rocky Coast/Beach terrain height");
                var expectedState=referenceCoast.Get("state").AsFloat64Array();var actualState=coast.Get("state").AsFloat64Array();require(expectedState.Length==actualState.Length,"Coast/Beach material control schema differs");for(int channel=0;channel<actualState.Length;channel++)Equal(expectedState[channel],actualState[channel],"Coast/Beach published control "+channel);positive|=actualState.Length>2&&actualState[2]>0;
            }
            require(positive,"Coast/Beach integration fixture did not exercise positive coastal influence");
        }
        void Equal(double a,double b,string scope)=>require(Math.Abs(a-b)<=1e-12&&(float)a==(float)b,$"{scope}: {a:R} / {b:R}");
    }
}
