using Godot;
using System;
using S=PredatorIsle.Terrain.StructureGeometryAccess;

namespace PredatorIsle.Terrain;

/// <summary>A blind, sealed summit recess above the canonical ground and water.</summary>
public partial class InsectVentGeometry : RefCounted
{
    public double admitted_depth(GodotObject builder,Vector3 anchor,double width,double height,double phase,double requested)
    {
        if(requested<=0)return 0;var center=anchor+new Vector3((float)(width*.16*Math.Sin(2+phase)),(float)height,(float)(width*.12));double floor=center.Y-requested;
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++){var p=center+new Vector3((float)(x*width*.12),0,(float)(z*width*.12));if(Math.Max(S.Height(builder,new Vector2(p.X,p.Z)),builder.Call("get_water_surface_height",p.X,p.Z).AsDouble())>floor-2)return 0;}return requested;
    }
    public void emit(GodotObject g,Vector3[] outer,double depth,Color color)
    {
        if(outer.Length<3||depth<=0)throw new ArgumentException("A summit recess requires at least three rim points and positive depth.");
        var center=Vector3.Zero;foreach(var p in outer)center+=p/outer.Length;var inner=new Vector3[outer.Length];var bottom=new Vector3[outer.Length];
        for(int i=0;i<outer.Length;i++){inner[i]=center+(outer[i]-center)*.62f;bottom[i]=center+(outer[i]-center)*.46f-Vector3.Up*(float)depth;}
        var floor=center-Vector3.Up*(float)depth;for(int i=0;i<outer.Length;i++){int j=(i+1)%outer.Length;S.Quad(g,outer[i],outer[j],inner[j],inner[i],color);S.Quad(g,inner[i],inner[j],bottom[j],bottom[i],color);S.Triangle(g,bottom[i],bottom[j],floor,color);}
    }
}
