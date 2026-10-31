using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class CoastSamplerChecks
{
    internal static void Run(Action<bool,string> require)
    {
        foreach(string path in new[]{"res://tools/beach/check_invariants.gd","res://tools/rocky_coast/check_invariants.gd","res://tools/rocky_coast/find_previews.gd"})require(GD.Load<GDScript>(path).CanInstantiate(),"Existing coast tool adapter did not compile: "+path);
        var script=GD.Load<GDScript>("res://scripts/rocky_coast_sampler.gd");bool positive=false;
        foreach(long seed in new[]{-17L,17L,73921L})foreach(bool sand in new[]{false,true})foreach(double coverage in new[]{0.0,.5,1.0})
        {
            using var host=(RefCounted)GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();var terrain=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);terrain.Set("beaches_enabled",sand);terrain.Set("rocky_coast_enabled",true);terrain.Set("island_size",6000.0);var config=terrain.Get("rocky_coast").As<Resource>();config.Set("coverage",coverage);host.Set("settings",terrain);host.Set("world_seed",seed);host.Set("water_level",0.0);host.Call("_configure_noise");
            require(host.Get("_coast").AsGodotObject() is RockyCoastSampler,"Terrain builder did not create native Rocky Coast sampler");using var original=script.New().AsGodotObject();using var native=new RockyCoastSampler();original.Call("configure",config,seed,host);if(sand){var oldBeach=GD.Load<GDScript>("res://scripts/beach_sampler.gd").New().AsGodotObject();oldBeach.Call("configure",terrain.Get("beach"),original);original.Set("beach",oldBeach);}native.configure(config,seed,host);require(GD.VarToBytes(script.GetScriptConstantMap()["NAMES"]).SequenceEqual(GD.VarToBytes(native.NAMES)),"Coast preview names differ");Equal(original.Call("max_width").AsDouble(),native.max_width(),"Coast maximum support width");var random=new Random(73921);
            for(int i=0;i<240;i++)
            {
                double x=i<32?(i-16)*8:random.NextDouble()*40000-20000,z=i<32?(i-16)*-128:random.NextDouble()*40000-20000;var p=new Vector2((float)x,(float)z);double hint=host.Call("_island_mask",x,z).AsDouble()*3000;
                require(original.Call("may_affect",x,z,hint).AsBool()==native.may_affect(x,z,hint),"Coast early-admission differs");Equal(original.Call("sample",x,z,70.0,hint,i%3!=0).AsDouble(),native.sample(x,z,70,hint,i%3!=0),"Coast canonical height");var expected=original.Get("state").AsFloat64Array();require(expected.Length==native.state.Length,"Coast published schema differs");for(int channel=0;channel<expected.Length;channel++)Equal(expected[channel],native.state[channel],"Coast published control "+channel);positive|=native.state.Length>2&&native.state[2]>0;
                require(GD.VarToBytes(original.Call("region_weights",p)).SequenceEqual(GD.VarToBytes(native.region_weights(p))),"Coast regional weights differ");require(GD.VarToBytes(original.Call("coast_frame",p)).SequenceEqual(GD.VarToBytes(native.coast_frame(p))),"Coast measured shore frame differs");Equal(original.Call("inherited_river",p).AsDouble(),native.inherited_river(p),"Coast inherited river");double a=original.Call("inherited_river_distance",p).AsDouble(),b=native.inherited_river_distance(p);require(a==b,"Coast inherited river distance differs");
                if(i%30==0){var cell=new Vector2I(i/3-5,7-i/4);require(GD.VarToBytes(original.Call("_formation_sites",cell)).SequenceEqual(GD.VarToBytes(native._formation_sites(cell))),"Coast fixed-lattice formation descriptors differ");}
            }
            native.profile=true;native._raw_rock(new Vector2(317,-811));require(native.timings.ContainsKey("coastal_fields_us")&&native.timings["coastal_fields_us"].AsInt64()>=0,"Coast profiling hook missing");require(native.NodeCount<=8192&&native.PatchCount<=2048&&native.RegionCount<=2048&&native.FormationCount<=512,"Coast cache limits exceeded");
            var counts=native.cache_counts();require(counts["nodes"].AsInt32()==native.NodeCount&&counts["patches"].AsInt32()==native.PatchCount&&counts["regions"].AsInt32()==native.RegionCount&&counts["formations"].AsInt32()==native.FormationCount,"Coast diagnostic cache counts do not report real managed caches");
            native.clear_numeric_caches(false);require(native.NodeCount==0&&native.PatchCount==0&&native.RegionCount==counts["regions"].AsInt32()&&native.FormationCount==counts["formations"].AsInt32(),"Coast partial diagnostic cache reset changed unrelated caches");native.clear_numeric_caches();require(native.NodeCount==0&&native.PatchCount==0&&native.RegionCount==0&&native.FormationCount==0&&native.formation_cache_values().Count==0,"Coast full diagnostic cache reset failed");
            using var referenceBuilder=GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();referenceBuilder.Set("settings",terrain);referenceBuilder.Set("world_seed",seed);referenceBuilder.Set("water_level",0.0);referenceBuilder.Call("_configure_noise");using var referenceCoast=script.New().AsGodotObject();referenceCoast.Call("configure",config,seed,referenceBuilder);
            if(sand){var originalBeach=GD.Load<GDScript>("res://scripts/beach_sampler.gd").New().AsGodotObject();originalBeach.Call("configure",terrain.Get("beach"),referenceCoast);referenceCoast.Set("beach",originalBeach);}referenceBuilder.Set("_coast",referenceCoast);
            for(int i=0;i<80;i++)
            {
                double x=(i%16-8)*1003.25,z=(i/16-3)*907.5;Equal(referenceBuilder.Call("_get_height",x,z).AsDouble(),host.Call("_get_height",x,z).AsDouble(),"Whole terrain/coast height integration");require(GD.VarToBytes(referenceBuilder.Get("_last_coast")).SequenceEqual(GD.VarToBytes(host.Get("_last_coast"))),"Whole terrain/coast packed material controls differ");Equal(referenceBuilder.Get("_last_swamp_water").AsDouble(),host.Get("_last_swamp_water").AsDouble(),"Whole terrain/coast retained water integration");
            }
        }
        require(positive,"Coast fixtures did not exercise positive coastal influence");
        void Equal(double a,double b,string scope)=>require(Math.Abs(a-b)<=1e-12&&(float)a==(float)b,$"{scope}: {a:R} / {b:R}");
    }
}
