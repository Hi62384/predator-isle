using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>A finite sediment apron attached to the existing drainage trunk.</summary>
public partial class BadlandsFanGeometry : RefCounted
{
    public double[] frame(D tree)
    {
        if(tree.ContainsKey("fan_frame"))return tree["fan_frame"].AsFloat64Array();
        var root=tree["root"].AsVector3();var junction=tree["edges"].AsGodotArray()[0].AsGodotArray()[1].AsVector3();
        var axis=new Vector2((float)((double)junction.X-root.X),(float)((double)junction.Z-root.Z));double length=axis.Length();
        if(length<=.001)return System.Array.Empty<double>();
        axis/=(float)length;
        double[] result={root.X,root.Z,axis.X,axis.Y,length};tree[new StringName("fan_frame")]=result;return result;
    }
    public double mask(Vector2 p,D tree,double span)
    {
        var basis=frame(tree);if(basis.Length==0)return 0;
        var axis=new Vector2((float)basis[2],(float)basis[3]);var relative=p-new Vector2((float)basis[0],(float)basis[1]);
        double reach=Math.Min(span,Math.Max(32,basis[4]*.85)),t=1-relative.Dot(axis)/Math.Max(reach,1);
        if(t<=0||t>=1.22)return 0;
        double width=18+(320-18)*Math.Clamp(t,0,1),across=Math.Abs(relative.Cross(axis));
        return Smooth(0,.18,t)*(1-Smooth(1,1.22,t))*(1-Smooth(.25,1,across/width));
    }
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
}
