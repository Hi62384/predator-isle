using Godot;
using System;
using S=PredatorIsle.Terrain.StructureGeometryAccess;

namespace PredatorIsle.Terrain;

/// <summary>Closed membrane volume attached to the admitted blade and buried far root.</summary>
public partial class AlienMembraneGeometry : RefCounted
{
    public bool surface_guide_enabled {get;set;}=true;
    public void emit(GodotObject g,GodotObject builder,Vector2 point,Vector2 axis,double width,double height,double phase)
    {
        int first=S.Vertices(g).Count;axis=axis.Normalized();var side=new Vector2(-axis.Y,axis.X);double ground=S.Height(builder,point),shoulder=.65;var a2=point+axis*(float)width*.6f*(float)Math.Sin(shoulder*Math.PI*.65)+side*(float)width*.07f*(float)Math.Sin(shoulder*Math.PI+phase)*(float)shoulder;var b2=point+axis*(float)width*3.6f;
        var a=new Vector3(a2.X,(float)(ground+height*shoulder),a2.Y);var b=new Vector3(b2.X,(float)(surface_guide_enabled?S.Height(builder,b2)-8:S.Footing(g,builder,b2)),b2.Y);var control=new Vector3((float)(point.X+axis.X*width*3),(float)(ground+height*1.02),(float)(point.Y+axis.Y*width*3));
        var faces=new Vector3[2][];var origin=S.Origin(g);var uvs=S.UVs(g);var footings=S.Footings(g);var sampler=builder.Get("_extras").AsGodotArray()[7].AsGodotObject();double[] offsets={.28,.55,.81},curves={.08,-.11,.06},spread={.1,.13,.07},strength={.045,-.035,.055};
        for(int faceIndex=0;faceIndex<2;faceIndex++)
        {
            int face=faceIndex==0?-1:1;var vertices=new Vector3[33*13];int index=0;
            for(int column=0;column<=32;column++)
            {
                double u=column/32.0;var center=a*(float)(1-u)*(float)(1-u)+control*2*(float)(1-u)*(float)u+b*(float)u*(float)u;double floor=S.Height(builder,new Vector2(center.X,center.Z)),bottom=Math.Min(center.Y-width*.025,Math.Max(S.Lerp(a.Y-height*.3,b.Y-width*.1,u)+height*.16*Math.Sin(u*Math.PI),floor+12));
                for(int row=0;row<=12;row++)
                {
                    double v=row/12.0,envelope=Math.Sin(u*Math.PI)*Math.Sin(v*Math.PI),billow=width*.11*envelope*(.7+.3*Math.Sin(phase+u*7+v*4)),fold=0;
                    for(int rib=0;rib<3;rib++){double offset=offsets[rib]+(v-.5)*(v-.5)*curves[rib],q=Math.Abs(u-offset)/spread[rib];fold+=Math.Pow(Math.Max(0,1-q*q),3)*strength[rib]*width*Math.Sin(v*Math.PI);}
                    double thickness=width*.035*(.8+.2*Math.Sin(v*Math.PI));var p=new Vector3((float)(center.X+side.X*(billow+fold+face*thickness)),(float)S.Lerp(bottom,center.Y,v),(float)(center.Z+side.Y*(billow+fold+face*thickness)));
                    if(column==32){p.Y=(float)(S.Footing(g,builder,new Vector2(p.X,p.Z))-width*.1*(1-v));footings[p-origin]=0.0;}var data=S.Controls(sampler,new Vector2(p.X,p.Z));uvs[p-origin]=new Vector2(3,data.Y);vertices[index++]=p;
                }
            }
            faces[faceIndex]=vertices;
        }
        var negative=faces[0];var positive=faces[1];var tint=new Color(.34f,.28f,.26f);
        for(int column=0;column<32;column++)
        {
            for(int row=0;row<12;row++){int i=column*13+row,j=i+13;S.Quad(g,negative[i],negative[j],negative[j+1],negative[i+1],tint);S.Quad(g,positive[i],positive[i+1],positive[j+1],positive[j],tint);}
            int lower=column*13,next=lower+13,upper=lower+12,nextUpper=next+12;S.Quad(g,positive[lower],positive[next],negative[next],negative[lower],tint);S.Quad(g,positive[upper],negative[upper],negative[nextUpper],positive[nextUpper],tint);
        }
        for(int row=0;row<12;row++){S.Quad(g,positive[row],negative[row],negative[row+1],positive[row+1],tint);int i=32*13+row;S.Quad(g,positive[i],positive[i+1],negative[i+1],negative[i],tint);}
        S.SmoothRange(g,first,.3);footings.Clear();uvs.Clear();
    }
}
