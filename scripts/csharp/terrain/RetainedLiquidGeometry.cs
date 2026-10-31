using Godot;
using System;
using System.Collections.Generic;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Shared canonical rim, water level and clipped footprint for existing finite surface pools.</summary>
public partial class RetainedLiquidGeometry : RefCounted
{
    private static double Height(GodotObject builder,double x,double z)=>builder.Call("_get_height",x,z).AsDouble();
    public D measure(GodotObject builder,Vector2 point,double radius)
    {
        if(!point.IsFinite()||!double.IsFinite(radius)||radius<=0)return new D {["retained"]=false};
        double center=Height(builder,point.X,point.Y),rim=double.PositiveInfinity;
        for(int index=0;index<32;index++)
        {
            var q=point+new Vector2((float)Math.Cos(index*Math.Tau/32),(float)Math.Sin(index*Math.Tau/32))*(float)radius;
            rim=Math.Min(rim,Height(builder,q.X,q.Y));
        }
        double level=Math.Min(center+Math.Max(2,(rim-center)*.35),rim-.5);
        return new D {["retained"]=double.IsFinite(center)&&double.IsFinite(rim)&&double.IsFinite(level)&&!(level<center+.5||level<builder.Get("water_level").AsDouble()+2),["surface_y"]=level,["bed_y"]=center,["rim_y"]=rim};
    }
    public Vector3[] clipped_polygon(GodotObject builder,Vector3 a,Vector3 b,Vector3 c,double level)
    {
        var polygon=new[]{a,b,c};var clipped=new List<Vector3>(6);
        for(int index=0;index<3;index++)
        {
            var p=polygon[index];var q=polygon[(index+1)%3];bool pInside=p.Y<level-.05,qInside=q.Y<level-.05;
            if(pInside)clipped.Add(new Vector3(p.X,(float)level,p.Z));
            if(pInside==qInside)continue;var inside=pInside?p:q;var outside=pInside?q:p;
            for(int iteration=0;iteration<12;iteration++) {var mid=(inside+outside)*.5f;if(Height(builder,mid.X,mid.Z)<level-.05)inside=mid;else outside=mid;}
            clipped.Add(new Vector3(inside.X,(float)level,inside.Z));
        }
        return clipped.ToArray();
    }
}
