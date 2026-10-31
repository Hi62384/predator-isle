using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

namespace PredatorIsle.Checks;
internal static class BadlandsFanChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var original=GD.Load<GDScript>("res://scripts/badlands_fan_geometry.gd");using var current=new BadlandsFanGeometry();bool positive=false;
        foreach(long seed in new[]{-17L,17L,73921L})
        {
            using var host=(RefCounted)GD.Load<GDScript>("res://scripts/terrain_mesh_builder.gd").New().AsGodotObject();
            var settings=GD.Load<Resource>("res://config/world/terrain_settings.tres").DuplicateDeep(Resource.DeepDuplicateMode.All);settings.Set("badlands_coverage",100.0);
            host.Set("settings",settings);host.Set("world_seed",seed);host.Call("_configure_noise");var sampler=host.Get("_badlands").AsGodotObject();
            for(int i=-8;i<=8;i++)foreach(int side in new[]{-1,1})
            {
                var tree=sampler.Call("_tree",i,i%5,side).AsGodotDictionary();Compare(tree);
            }
        }
        foreach(float length in new[]{0f,.0005f,.001f,.002f,32f,100000f})Compare(new D{["root"]=Vector3.Zero,["edges"]=new A{new A{Vector3.Zero,new Vector3(length,0,0)}}});
        require(positive,"Badlands fan probes did not exercise positive deposition");
        void Compare(D tree)
        {
            var a=tree.Duplicate(true);var b=tree.Duplicate(true);a.Remove("fan_frame");b.Remove("fan_frame");
            var expected=original.Call("frame",a).AsFloat64Array();var actual=current.frame(b);
            require(GD.VarToBytes(expected).SequenceEqual(GD.VarToBytes(actual)),"Badlands fan frame differs");
            require(GD.VarToBytes(a).SequenceEqual(GD.VarToBytes(b)),"Badlands fan cache mutation/schema differs");
            require(GD.VarToBytes(current.frame(b)).SequenceEqual(GD.VarToBytes(actual)),"Badlands cached frame changed");
            if(actual.Length==0)return;
            var root=new Vector2((float)actual[0],(float)actual[1]);var axis=new Vector2((float)actual[2],(float)actual[3]);var normal=new Vector2(-axis.Y,axis.X);
            foreach(double span in new[]{0.0,16,200,1400,100000})foreach(double t in new[]{-.1,0,.1,.5,1,1.1,1.22,1.3})foreach(float across in new[]{-400f,-80,0,80,400})
            {
                var p=root+axis*(float)(Math.Min(span,Math.Max(32,actual[4]*.85))*(1-t))+normal*across;
                double old=original.Call("mask",p,a,span).AsDouble(),now=current.mask(p,b,span);
                require(Math.Abs(old-now)<=1e-12&&(float)old==(float)now,$"Badlands fan mask differs: {old:R}/{now:R}");positive|=now>.1;
            }
        }
    }
}
