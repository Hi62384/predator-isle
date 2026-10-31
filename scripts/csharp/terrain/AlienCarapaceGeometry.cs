using Godot;
using System;
using S=PredatorIsle.Terrain.StructureGeometryAccess;

namespace PredatorIsle.Terrain;

public partial class AlienCarapaceGeometry : RefCounted
{
    public void emit(GodotObject g,GodotObject builder,Vector2 point,Vector2 axis,double width,double height,double phase)=>emit(g,builder,point,axis,width,height,phase,2);
    public void emit(GodotObject g,GodotObject builder,Vector2 point,Vector2 axis,double width,double height,double phase,int habit)
    {
        int first=S.Vertices(g).Count;var side=new Vector2(-axis.Y,axis.X);var tint=habit==5?new Color(.74f,.72f,.66f):new Color(.25f,.26f,.27f);var controls=new Vector2(habit,1);var origin=S.Origin(g);var footings=S.Footings(g);var uvs=S.UVs(g);
        double[] scales={.8,1,.88},rises={.72,1,.83};
        for(int plate=0;plate<3;plate++)
        {
            double scale=scales[plate];var center=point+axis*(plate-1)*(float)width*.55f+side*(float)width*.07f*(float)Math.Sin(phase+plate*2.1);double baseline=S.Height(builder,center),length=width*.95*scale,breadth=width*.32*scale,rise=height*rises[plate];var rings=new Vector3[25][];
            for(int row=0;row<=24;row++)
            {
                double t=row/24.0,core=Math.Max(.015,1-t),radius=core+.045*Math.Sin(Math.Clamp(t/.4,0,1)*Math.PI);var ring=new Vector3[40];
                for(int i=0;i<40;i++)
                {
                    double angle=i*Math.Tau/40,edge=1+.035*Math.Sin(angle*5+phase+plate*.7)+.02*Math.Cos(angle*9-phase),along=Math.Sign(Math.Cos(angle))*Math.Pow(Math.Abs(Math.Cos(angle)),.8)*length*radius*edge,across=Math.Sin(angle)*breadth*radius*edge;var q=center+axis*(float)along+side*(float)across;
                    double keel=Math.Max(0,1-Math.Abs(across)/Math.Max(breadth*.4,1))*rise*.3*(1-core*core),arch=Math.Sqrt(Math.Max(0,1-core*core)),growth=rise*.15*Math.Pow(.5+.5*Math.Cos(along/Math.Max(length,1)*Math.PI*5+Math.Sin(across/Math.Max(breadth,1)*2+phase)),4)*(1-core*core),deck=rise*(.72+.28*arch)+keel+growth-rise*.25*(along/Math.Max(length,1))+rise*.08*Math.Sin(angle*3+phase)*core*core;
                    var v=new Vector3(q.X,(float)(baseline+deck*S.Smooth(0,.38,t)),q.Y);if(row==0){v.Y=(float)S.Footing(g,builder,q);footings[v-origin]=0.0;}uvs[v-origin]=controls;ring[i]=v;
                }
                rings[row]=ring;
            }
            for(int row=0;row<24;row++)for(int i=0;i<40;i++){int j=(i+1)%40;S.Quad(g,rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],tint);}
            var bottom=Vector3.Zero;var top=Vector3.Zero;for(int i=0;i<40;i++){bottom+=rings[0][i]/40;top+=rings[^1][i]/40;}uvs[bottom-origin]=controls;uvs[top-origin]=controls;
            for(int i=0;i<40;i++){int j=(i+1)%40;S.Triangle(g,rings[0][j],rings[0][i],bottom,tint);S.Triangle(g,rings[^1][i],rings[^1][j],top,tint);}
        }
        S.SmoothRange(g,first,.7);footings.Clear();uvs.Clear();
    }
}
