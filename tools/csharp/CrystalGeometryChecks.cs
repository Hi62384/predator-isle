using Godot;
using System;
using System.Linq;
using PredatorIsle.Caves;

namespace PredatorIsle.Checks;
internal static class CrystalGeometryChecks
{
    internal static void Run(Action<bool,string> require)
    {
        var script=GD.Load<GDScript>("res://scripts/caves/crystal_geometry.gd");using var original=script.New().AsGodotObject();using var current=new CrystalCaveGeometry();
        for(int habit=0;habit<6;habit++)foreach(bool broken in new[]{false,true})
        {
            var expected=original.Call("prototype",habit,broken).AsGodotArray();var actual=current.prototype(habit,broken);require(expected.Count==actual.Count,"Crystal prototype mesh schema differs");
            foreach(int slot in new[]{(int)Mesh.ArrayType.Vertex,(int)Mesh.ArrayType.Normal})
            {
                var a=expected[slot].AsVector3Array();var b=actual[slot].AsVector3Array();require(a.Length==b.Length,"Crystal prototype topology differs");
                for(int i=0;i<a.Length;i++)for(int component=0;component<3;component++)require(a[i][component]==b[i][component]||Math.Abs(a[i][component])<1e-9&&Math.Abs((double)a[i][component]-b[i][component])<=1e-12,"Crystal prototype exceeds near-zero native-math rounding allowance");
            }
            require(GD.VarToBytes(expected[(int)Mesh.ArrayType.TexUV]).SequenceEqual(GD.VarToBytes(actual[(int)Mesh.ArrayType.TexUV])),"Crystal prototype physical thickness/growth controls differ");
        }
        for(int family=-1;family<8;family++)foreach(double age in new[]{-1.0,0.0,.5,1.0})require(GD.VarToBytes(script.Call("tint",family,age)).SequenceEqual(GD.VarToBytes(current.tint(family,age))),"Mineral tint controls differ");
        require(current.templates.Count==12&&original.Get("templates").AsGodotDictionary().Count==12,"Crystal prototype cache metadata differs");
        var emitterScript=GD.Load<GDScript>("res://scripts/biome_extension_structures.gd");
        foreach(var center in new[]{new Vector3(0,0,-2),new Vector3(0,0,2)})foreach(bool degenerate in new[]{false,true})
        {
            using var expectedEmitter=emitterScript.New().AsGodotObject();using var actualEmitter=emitterScript.New().AsGodotObject();
            foreach(var emitter in new[]{expectedEmitter,actualEmitter}){emitter.Set("_skip_degenerate",true);emitter.Set("origin",new Vector3(7,9,-13));}
            var a=Vector3.Zero;var b=Vector3.Right;var c=degenerate?Vector3.Right:new Vector3(1,1,0);var d=degenerate?Vector3.Right:Vector3.Up;
            original.Call("quad",expectedEmitter,a,b,c,d,center);current.quad(actualEmitter,a,b,c,d,center);
            foreach(string property in new[]{"vertices","normals","colors","uvs"})require(GD.VarToBytes(expectedEmitter.Get(property)).SequenceEqual(GD.VarToBytes(actualEmitter.Get(property))),"Crystal wall-attachment winding/degenerate emission differs: "+property);
        }
    }
}
