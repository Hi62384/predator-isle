using Godot;
using System;
using System.Collections.Generic;
using S=PredatorIsle.Terrain.StructureGeometryAccess;

namespace PredatorIsle.Terrain;

/// <summary>Unequal construction ribs on the existing mound mesh; exact feet and summit stay fixed.</summary>
public partial class InsectMoundProfiles : RefCounted
{
    public Godot.Collections.Array<Vector4> coefficients(int sides,double phase)
    {
        var result=new Godot.Collections.Array<Vector4>();
        for(int side=0;side<sides;side++)
        {
            double angle=side*Math.Tau/sides,buttress=0,groove=0,upper=0,strongest=0,termination=.7;
            for(int rib=0;rib<11;rib++)
            {
                double seed=.5+.5*Math.Sin(rib*18.713+phase*2.341),center=(rib+.24*Math.Sin(rib*7.31+phase))*Math.Tau/11+phase*.17,delta=Mathf.Wrap(angle-center,-Math.PI,Math.PI),width=.10+.10*seed,crest=Math.Exp(-delta*delta/(width*width));buttress+=crest*(.16+.22*seed);upper+=crest*(.05+.14*(1-seed));double gap=Mathf.Wrap(angle-center-width*1.65,-Math.PI,Math.PI);groove+=Math.Exp(-gap*gap/.0036)*(.05+.08*seed);if(crest>strongest){strongest=crest;termination=.38+.55*seed;}
            }
            result.Add(new Vector4((float)buttress,(float)upper,(float)groove,(float)termination));
        }
        return result;
    }
    public Vector3[] sculpt(Vector3[] positions,Vector3 origin,Vector3 anchor,double width,double height,int archetype,double phase)
    {
        if(archetype==3)return positions;var rows=coefficients(42,phase);var moved=new Vector3[positions.Length];var memo=new Dictionary<Vector3,Vector3>();
        for(int i=0;i<positions.Length;i++)
        {
            var point=positions[i];if(memo.TryGetValue(point,out var cached)){moved[i]=cached;continue;}var p=point+origin-anchor;double t=p.Y/height;var output=point;
            if(t>0&&t<.99999)
            {
                var lean=new Vector2((float)(width*.16*Math.Sin(t*2+phase)*t),(float)(width*.12*t*t));double ellipse=archetype==2?.22:1;var radial=new Vector2((float)((double)p.X-lean.X),(float)((p.Z-(double)lean.Y)/ellipse));double angle=radial.Angle();int side=(int)Mathf.PosMod((long)Math.Round(angle*42/Math.Tau,MidpointRounding.AwayFromZero),42);var c=rows[side];
                double factor=.91+c.X*(1-S.Smooth(.12,c.W,t))+c.Y*(1-S.Smooth(Math.Max(.2,c.W-.2),.96,t))-c.Z*(.3+.7*S.Smooth(.1,.5,t));factor+=.012*Math.Sin(angle*19+t*7+phase)+.008*Math.Sin(angle*31-t*11-phase);if(archetype==4)factor-=.12*S.Smooth(.15,.8,t)*(.5+.5*Math.Sin(angle*3+phase));if(archetype==2)factor=S.Lerp(1,factor,.55);
                double radius=width*Math.Pow(Math.Max(.015,1-t),.65)*Math.Clamp(factor,.72,1.42);var target=new Vector3((float)(Math.Cos(angle)*radius+lean.X),p.Y,(float)(Math.Sin(angle)*radius*ellipse+lean.Y));double influence=.55*S.Smooth(0,.12,t)*(1-S.Smooth(.88,1,t));output=(point+origin).Lerp(target+anchor,(float)influence)-origin;
            }
            memo[point]=output;moved[i]=output;
        }
        return moved;
    }
    public void apply(GodotObject generator,int first,Vector3 anchor,double width,double height,int archetype,double phase)
    {
        var vertices=S.Vertices(generator);var normals=S.Normals(generator);int end=first+24*42*6;var shell=sculpt(vertices.GetRange(first,end-first).ToArray(),S.Origin(generator),anchor,width,height,archetype,phase);for(int i=0;i<shell.Length;i++)vertices[first+i]=shell[i];var sums=new Dictionary<Vector3,Vector3>();
        for(int i=first;i<vertices.Count;i+=3){var n=(vertices[i+2]-vertices[i]).Cross(vertices[i+1]-vertices[i]).Normalized();for(int j=0;j<3;j++){normals[i+j]=n;sums[vertices[i+j]]=sums.GetValueOrDefault(vertices[i+j])+n;}}
        for(int i=first;i<vertices.Count;i++){var n=sums[vertices[i]].Normalized();if(n.Dot(normals[i])>.15)normals[i]=n;}S.Commit(generator,vertices,normals);
    }
}
