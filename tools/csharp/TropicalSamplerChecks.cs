using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class TropicalSamplerChecks
{
    internal static void Run(Action<bool,string> require)
    {
        SettingsChecks(require);
        var script=GD.Load<GDScript>("res://scripts/tropical_sampler.gd");
        bool channel=false,stream=false,lake=false,fall=false,ridge=false;
        foreach(long seed in new[]{-17L,17L,73921L})
        {
            using var host=(RefCounted)GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();
            var terrain=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);
            foreach(string biome in new[]{"grass","forest","savanna","swamp","jungle","mountain","badlands","quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"})terrain.Set(biome+"_coverage",0.0);
            terrain.Set("tropical_coverage",100.0);
            terrain.Set("beaches_enabled",false);terrain.Set("rocky_coast_enabled",false);
            terrain.Set("island_size",60000.0);terrain.Set("island_position_jitter",0.0);terrain.Set("island_size_variation",0.0);terrain.Set("island_coast_irregularity",0.0);
            host.Set("settings",terrain);host.Set("world_seed",seed);host.Set("water_level",0.0);host.Call("_configure_noise");
            var config=terrain.Get("tropical").As<Resource>();
            using var original=script.New().AsGodotObject();using var native=new TropicalSampler();
            original.Call("configure",config,seed,host);native.configure(config,seed,host);
            require(GD.VarToBytes(script.GetScriptConstantMap()["NAMES"]).SequenceEqual(GD.VarToBytes(native.NAMES)),"Tropical public region names differ");
            require(native.STEP==script.GetScriptConstantMap()["STEP"].AsDouble()&&native.CHANNELS==16,"Tropical public lattice constants differ");
            var random=new Random(73921);
            for(int i=0;i<500;i++)
            {
                double x=i<32?(i-16)*16:random.NextDouble()*400000-200000,z=i<32?(i-16)*-512:random.NextDouble()*400000-200000;
                Probe(new Vector2((float)x,(float)z));
                Equal(original.Call("sample",x+.125,z-.25,false).AsDouble(),native.sample(x+.125,z-.25,false),"Unpublished tropical height");
                Compare(original.Get("state").AsFloat64Array(),native.state,"Unpublished state preservation");
                Equal(original.Call("water_potential",x).AsDouble(),native.water_potential(x),"Catchment water potential");
                Equal(original.Call("_structural_center",x,i%7-3).AsDouble(),native._structural_center(x,i%7-3),"Broad drainage center");
                require(original.Call("_carrier",x,i%7-3).AsVector3()==native._carrier(x,i%7-3),"Fractional drainage carrier differs");
            }
            // Descriptor-centered probes require actual rivers, tributaries and cascades.
            config.Set("river_frequency",1.0);config.Set("stream_frequency",1.0);config.Set("waterfall_frequency",1.0);config.Set("lake_frequency",1.0);config.Set("basin_frequency",1.0);
            original.Call("configure",config,seed,host);native.configure(config,seed,host);
            for(int lane=-3;lane<=3;lane++)for(int segment=-10;segment<=10;segment++)
            {
                double r=native.random(segment,lane,131);Equal(original.Call("cascade_height",segment,lane,r).AsDouble(),native.cascade_height(segment,lane,r),"Cascade admission/drop");fall|=native.cascade_height(segment,lane,r)>0;
                foreach(double t in new[]{0.0,.4,.5,.55,1.0})
                {
                    var p=native.cascade_point(segment,lane,t);require(original.Call("cascade_point",segment,lane,t).AsVector2()==p,"Cascade descriptor point differs");
                    Equal(original.Call("cascade_rise",t).AsDouble(),native.cascade_rise(t),"Cascade rock step");Probe(p);
                }
                double x=Math.Round((segment+.25+native.random(segment,lane,151)*.5)*6000/16,MidpointRounding.AwayFromZero)*16;
                Probe(new Vector2((float)x,native._carrier(x,lane).X));
            }
            native.profile=true;native._raw(new Vector2(317,-811));require(native.timings.ContainsKey("raw_us"),"Tropical profiling hook missing");
            for(int i=0;i<16400;i++)native._node(new Vector2I(i,-i));
            var counts=native.cache_counts();foreach(string key in new[]{"nodes","regions","carriers","structural_nodes","cascades"})require(counts[key].AsInt32()<=(key=="nodes"?16384:key=="cascades"?512:2048),"Tropical cache bound exceeded: "+key);
            native.configure(config,seed+1,host);foreach(Variant count in native.cache_counts().Values)require(count.AsInt32()==0,"Tropical configure did not clear caches");
            using var reference=(RefCounted)GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();reference.Set("settings",terrain);reference.Set("world_seed",seed);reference.Set("water_level",0.0);reference.Call("_configure_noise");
            using var referenceSampler=script.New().AsGodotObject();referenceSampler.Call("configure",config,seed,reference);reference.Set("_tropical",referenceSampler);
            host.Call("_configure_noise");require(host.Get("_tropical").AsGodotObject() is TropicalSampler,"Terrain builder did not create native Tropical sampler");
            using var detail=new TropicalRiverDetail();var originalDetail=GD.Load<GDScript>("res://scripts/tropical_river_detail.gd");
            bool positiveDetail=false;
            for(int lod=0;lod<=6;lod++)for(int i=0;i<30;i++)
            {
                var bounds=new Rect2(new Vector2((i-15)*257,(i%7-3)*521),new Vector2(i==0?100000:256, i==0?100000:256));
                double expected=originalDetail.Call("spacing",host,bounds,lod).AsDouble(),actual=detail.spacing(host,bounds,lod);
                require(expected==actual,"Tropical river density hint differs");positiveDetail|=actual>0;
            }
            require(positiveDetail,"Tropical river detail fixtures had no positive density hints");
            foreach(string key in new[]{"river_detail_metres","river_frequency","grass_river_frequency","water_enabled"})
            {
                var owner=key is "grass_river_frequency" or "water_enabled"?terrain:config;var prior=owner.Get(key);owner.Set(key,key=="water_enabled"?Variant.From(false):Variant.From(0.0));
                require(detail.spacing(host,new Rect2(-128,-128,256,256),3)==0,"Tropical density opt-out ignored: "+key);owner.Set(key,prior);
            }
            for(int i=0;i<100;i++)
            {
                double x=(i%20-10)*1003.25,z=(i/20-3)*907.5;
                Equal(reference.Call("_get_height",x,z).AsDouble(),host.Call("_get_height",x,z).AsDouble(),"Whole terrain tropical height");
                require(GD.VarToBytes(reference.Get("_last_tropical")).SequenceEqual(GD.VarToBytes(host.Get("_last_tropical"))),"Whole terrain tropical material controls differ");
                Equal(reference.Get("_last_swamp_water").AsDouble(),host.Get("_last_swamp_water").AsDouble(),"Whole terrain tropical water");
                require(host.Get("_last_tropical").AsVector3().X>.99,"Whole terrain fixture is not actually Tropical");
            }
            foreach(string path in new[]{"res://tools/tropical/find_previews.gd","res://tools/tropical/check_river_detail.gd","res://tools/tropical/check_cascades.gd"})require(GD.Load<GDScript>(path).CanInstantiate(),"Existing tropical adapter did not compile: "+path);
            void Probe(Vector2 p)
            {
                require(GD.VarToBytes(original.Call("region_weights",p)).SequenceEqual(GD.VarToBytes(native.region_weights(p))),"Tropical regional weights differ");
                Equal(original.Call("sample",p.X,p.Y,true).AsDouble(),native.sample(p.X,p.Y,true),"Published tropical height at "+p);
                Compare(original.Get("state").AsFloat64Array(),native.state,"Tropical published channels at "+p);
                channel|=native.state[13]>.1;stream|=native.state[12]>.1;lake|=native.state[9]>.1;ridge|=native.state[7]>.1;
            }
        }
        require(channel&&stream&&lake&&fall&&ridge,$"Tropical positive fixtures incomplete: channel={channel}, stream={stream}, lake={lake}, cascade={fall}, ridge={ridge}");
        void Compare(double[] a,double[] b,string scope){require(a.Length==b.Length,scope+" length");for(int i=0;i<a.Length;i++)Equal(a[i],b[i],scope+" channel "+i);}
        void Equal(double a,double b,string scope)=>require(Math.Abs(a-b)<=1e-12&&(float)a==(float)b,$"{scope}: {a:R} / {b:R}");
    }
    private static void SettingsChecks(Action<bool,string> require)
    {
        using var original=GD.Load<GDScript>("res://scripts/tropical_settings.gd").New().AsGodotObject();using var current=new TropicalSettings();
        var exported=original.GetPropertyList().Where(p=>(p["usage"].AsInt64()&(long)PropertyUsageFlags.ScriptVariable)!=0&&p["name"].AsString()!="script").ToArray();
        var nativeProperties=current.GetPropertyList();
        foreach(var property in exported)
        {
            string name=property["name"].AsString();require(GD.VarToBytes(original.Get(name)).SequenceEqual(GD.VarToBytes(current.Get(name))),"Tropical resource default differs: "+name);
            var match=nativeProperties.FirstOrDefault(p=>p["name"].AsString()==name);require(match!=null,"Missing native tropical inspector property: "+name);
            if(match==null)continue;
            require(property["type"].AsInt64()==match["type"].AsInt64()&&property["hint"].AsInt64()==match["hint"].AsInt64(),"Tropical inspector property type/hint differs: "+name);
            var oldRange=property["hint_string"].AsString().Split(',');var newRange=match["hint_string"].AsString().Split(',');
            require(oldRange.Length==newRange.Length&&oldRange.Zip(newRange,(a,b)=>double.Parse(a,System.Globalization.CultureInfo.InvariantCulture)==double.Parse(b,System.Globalization.CultureInfo.InvariantCulture)).All(s=>s),"Tropical inspector range differs: "+name);
            Variant altered=property["type"].AsInt32()==(int)Variant.Type.Int?Variant.From(2L):Variant.From(.375);
            original.Set(name,altered);current.Set(name,altered);
        }
        require(exported.Length==39,"Unexpected tropical exported property inventory");
        require(GD.VarToBytes(original.Call("uniforms")).SequenceEqual(GD.VarToBytes(current.uniforms())),"Tropical shader uniforms differ");
        using var duplicate=(TropicalSettings)current.DuplicateDeep(Resource.DeepDuplicateMode.All);duplicate.hill_height=999;require(current.hill_height==.375,"Tropical resource duplicate is not independent");
        require(GD.Load<Resource>("res://config/biomes/tropical_settings.tres") is TropicalSettings,"Saved Tropical settings did not instantiate native resource");
    }
}
