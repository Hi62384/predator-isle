using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;

namespace PredatorIsle.Checks;
internal static class QuarryRoadChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var config=GD.Load<Resource>("res://config/biomes/quarry_settings.tres");using var host=new RefCounted();int admitted=0;
        foreach(long seed in new[]{-17L,17L,73921L})
        {
            using var original=GD.Load<GDScript>("res://scripts/quarry_sampler.gd").New().AsGodotObject();using var native=new QuarrySampler();original.Call("configure",config,seed,host,0);native.configure(config,seed,host,0);int walked=0;
            for(int z=-8;z<=8;z++)for(int x=-8;x<=8;x++)
            {
                var cell=new Vector2I(x,z);double span=3200*config.Get("feature_scale").AsDouble();var descriptor=native.descriptor(cell,span);var expected=original.Call("ramp_plan",descriptor).AsGodotDictionary();var actual=native.ramp_plan(descriptor);
                require(expected.Count==actual.Count,"Quarry ramp admission differs");var normalized=actual.Duplicate();
                foreach(string field in new[]{"low","high"})if(expected.ContainsKey(field)){Equal(expected[field].AsDouble(),actual[field].AsDouble(),"Quarry ramp endpoint height");normalized[field]=expected[field];}
                require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(normalized)),"Quarry ramp descriptor differs: "+MigrationComparison.FirstDifference(expected,normalized));
                if(actual.Count==0)continue;admitted++;if(walked++>=2)continue;
                int turns=actual["turns"].AsInt32();double radius=descriptor["radius"].AsDouble(),yaw=descriptor["angle"].AsDouble();float yaw32=(float)yaw,sine=(float)Math.Sin(yaw32),cosine=(float)Math.Cos(yaw32);var center=descriptor["position"].AsVector2();
                for(int i=0;i<=turns*64;i++)
                {
                    double t=(double)i/(turns*64),angle=(t*turns-Math.Floor(t*turns))*Math.Tau-Math.PI,multiplier=1+.08*Math.Sin(angle*3+yaw)+.05*Math.Sin(angle*7+.4);var direction=new Vector2((float)Math.Cos(angle),(float)Math.Sin(angle));double stretch=new Vector2(direction.X,(float)((double)direction.Y*1.25)).Length();var local=direction*(float)(.22+1.08*t)*(float)radius*(float)multiplier/(float)stretch;var p=center+new Vector2(local.X*cosine-local.Y*sine,local.X*sine+local.Y*cosine);
                    Equal(original.Call("sample",p.X,p.Y,true).AsDouble(),native.sample(p.X,p.Y,true),"Quarry complete spiral road height");
                }
            }
            // The normal road fixture tests the ramp centerline. Extreme
            // regional coordinates must also agree before the 8,192-node FIFO
            // cache fills; a tiny 2D rotation discrepancy changes road heights.
            foreach(int site in new[]{0,127,840,4095,8199})
            {
                var cell=new Vector2I(site,-site);
                var p=(Vector2)cell*16;
                var descriptor=native.nearby(p,3200*config.Get("feature_scale").AsDouble());
                var qExpected=original.Call("local",p,descriptor).AsVector2();
                var qActual=native.local(p,descriptor);
                require(qExpected==qActual,
                    $"Quarry coordinate rotation disagrees: seed={seed} cell={cell} reference={qExpected} native={qActual}");
                // Sample each of the six regional visual structures before
                // checking the final mixed and excavated canonical node.
                for(int region=0;region<6;region++)
                {
                    var left=original.Call("evaluate",p,region).AsFloat64Array();
                    var right=native.evaluate(p,region);
                    for(int slot=0;slot<5;slot++)
                        Equal(left[slot],right[slot],
                            $"Quarry region probe {region} seed={seed} cell={cell} slot={slot}");
                }
                var expected=original.Call("_node",cell).AsFloat64Array();
                var current=native._node(cell);
                for(int slot=0;slot<5;slot++)
                    Equal(expected[slot],current[slot],
                        $"Quarry far-node probe seed={seed} cell={cell} slot={slot}");
            }
            require(native.RampPlanCount<=256,"Quarry ramp cache exceeded original limit");
        }
        require(admitted>0,"Quarry road fixtures did not admit any physical ramps");
        void Equal(double a,double b,string scope)=>require(Math.Abs(a-b)<=1e-12&&(float)a==(float)b,$"{scope}: {a:R} / {b:R}");
    }
}
