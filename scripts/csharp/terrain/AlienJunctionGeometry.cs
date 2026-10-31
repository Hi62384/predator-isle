using Godot;
using System;
using S=PredatorIsle.Terrain.StructureGeometryAccess;

namespace PredatorIsle.Terrain;

public partial class AlienJunctionGeometry : RefCounted
{
    public bool longitudinal_ribs {get;set;}=true;
    public bool surface_guide_enabled {get;set;}=true;
    public void emit(GodotObject g,GodotObject builder,Vector2 point,Godot.Collections.Array<Vector2> directions,double width,double height,double phase)
    {
        int first=S.Vertices(g).Count;double ground=S.Height(builder,point);var tint=new Color(.34f,.28f,.26f);var origin=S.Origin(g);var footings=S.Footings(g);var uvs=S.UVs(g);var sampler=builder.Get("_extras").AsGodotArray()[7].AsGodotObject();
        for(int blade=0;blade<directions.Count;blade++)
        {
            var axis=directions[blade].Normalized();var side=new Vector2(-axis.Y,axis.X);double scale=blade==0?1:.68;var rings=new Vector3[25][];
            for(int row=0;row<=24;row++)
            {
                double t=row/24.0,length=width*scale*(.035+.965*Math.Pow(1-t,1.1)),thickness=width*scale*(.025+.16*Math.Pow(1-t,.65));var center=point+axis*(float)width*(float)scale*.6f*(float)Math.Sin(t*Math.PI*.65)+side*(float)width*.07f*(float)Math.Sin(t*Math.PI+phase)*(float)t;var ring=new Vector3[20];
                for(int i=0;i<20;i++)
                {
                    double angle=i*Math.Tau/20,rib=longitudinal_ribs?1+(.115*Math.Sin(angle*5+phase+t*.7)+.035*Math.Sin(angle*11-phase-t*1.3))*S.Smooth(0,.15,t):1+.09*Math.Sin(t*Math.Tau*6+phase+Math.Sin(angle)*.8)*S.Smooth(0,.15,t);
                    var q=center+axis*(float)Math.Cos(angle)*(float)length*(float)rib+side*(float)Math.Sin(angle)*(float)thickness*(float)rib;var v=new Vector3(q.X,(float)(ground+height*scale*t),q.Y);
                    if(row==0){v.Y=(float)S.Footing(g,builder,q);footings[v-origin]=0.0;}uvs[v-origin]=S.Controls(sampler,q);ring[i]=v;
                }
                rings[row]=ring;
            }
            for(int row=0;row<24;row++)for(int i=0;i<20;i++){int j=(i+1)%20;S.Quad(g,rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],tint);}
            var bottom=Vector3.Zero;var top=Vector3.Zero;for(int i=0;i<20;i++){bottom+=rings[0][i]/20;top+=rings[^1][i]/20;}var controls=S.Controls(sampler,point);uvs[bottom-origin]=controls;uvs[top-origin]=controls;
            for(int i=0;i<20;i++){int j=(i+1)%20;S.Triangle(g,rings[0][j],rings[0][i],bottom,tint);S.Triangle(g,rings[^1][i],rings[^1][j],top,tint);}
        }
        root_strut(g,builder,point,directions[0].Normalized(),width,height,phase,ground,tint);S.SmoothRange(g,first,.15);footings.Clear();uvs.Clear();
    }
    public void root_strut(GodotObject g,GodotObject builder,Vector2 point,Vector2 axis,double width,double height,double phase,double ground,Color tint)
    {
        var side=new Vector2(-axis.Y,axis.X);double shoulder=.65;var a2=point+axis*(float)width*.6f*(float)Math.Sin(shoulder*Math.PI*.65)+side*(float)width*.07f*(float)Math.Sin(shoulder*Math.PI+phase)*(float)shoulder;var b2=point+axis*(float)width*3.6f;
        var a=new Vector3(a2.X,(float)(ground+height*shoulder),a2.Y);var b=new Vector3(b2.X,(float)(surface_guide_enabled?S.Height(builder,b2)-8:S.Footing(g,builder,b2)),b2.Y);var control=new Vector3((float)(point.X+axis.X*width*3),(float)(ground+height*1.02),(float)(point.Y+axis.Y*width*3));var rings=new Vector3[33][];var origin=S.Origin(g);var footings=S.Footings(g);var uvs=S.UVs(g);var sampler=builder.Get("_extras").AsGodotArray()[7].AsGodotObject();
        for(int row=0;row<=32;row++)
        {
            double t=row/32.0,u=1-t;var center=a*(float)u*(float)u+control*2*(float)u*(float)t+b*(float)t*(float)t;var tangent=((control-a)*(float)u+(b-control)*(float)t).Normalized();var lateral=new Vector3(side.X,0,side.Y);var upright=lateral.Cross(tangent).Normalized();double radius=width*(.07+.025*Math.Sin(t*Math.PI))*(1+.045*Math.Sin(t*Math.Tau*8+phase));var ring=new Vector3[16];
            for(int i=0;i<16;i++)
            {double angle=i*Math.Tau/16;var v=center+lateral*(float)Math.Cos(angle)*(float)radius+upright*(float)Math.Sin(angle)*(float)radius*1.2f;if(row==32){v.Y=(float)Math.Min(v.Y,S.Footing(g,builder,new Vector2(v.X,v.Z)));footings[v-origin]=0.0;}uvs[v-origin]=S.Controls(sampler,new Vector2(v.X,v.Z));ring[i]=v;}rings[row]=ring;
        }
        for(int row=0;row<32;row++)for(int i=0;i<16;i++){int j=(i+1)%16;S.Quad(g,rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],tint);}
        var end=Vector3.Zero;foreach(var v in rings[^1])end+=v/16;foreach(var center in new[]{a,end})uvs[center-origin]=S.Controls(sampler,new Vector2(center.X,center.Z));
        for(int i=0;i<16;i++){int j=(i+1)%16;S.Triangle(g,rings[0][j],rings[0][i],a,tint);S.Triangle(g,rings[^1][i],rings[^1][j],end,tint);}
    }
}
