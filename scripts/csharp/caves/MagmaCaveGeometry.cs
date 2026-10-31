using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Caves;
/// <summary>Opaque weathered basalt columns, volcanic blocks and obsidian wedges.</summary>
public partial class MagmaCaveGeometry : RefCounted
{
    private readonly Dictionary<int,Vector3[]> _templates=new();
    public Godot.Collections.Dictionary templates {get;}=new();
    public Vector3[] prototype(int kind)=>prototype(kind,0);
    public Vector3[] prototype(int kind,int variant)
    {
        variant=kind==0?(variant%4+4)%4:0;int key=kind*4+variant;if(_templates.TryGetValue(key,out var cached))return cached;
        var vertices=new List<Vector3>();var center=new Vector3(0,.5f,0);
        if(kind==0)
        {
            Vector3[] previous=System.Array.Empty<Vector3>();var radii=new[]{1.0,.97,1.01,.94,.89};
            for(int ring=0;ring<5;ring++)
            {
                var points=new Vector3[6];double y=ring*.25,radius=radii[ring];
                for(int side=0;side<6;side++)
                {
                    double angle=side*Math.Tau/6,r=radius*(1+.035*Math.Sin(angle*2+variant*.73)),top=ring==4?.97+.03*Math.Cos(angle*2+variant*.7):y;var bend=new Vector2((float)Math.Sin(y*3+variant),(float)Math.Cos(y*3+variant))*.025f*(float)y;
                    points[side]=new Vector3((float)(Math.Cos(angle)*r+bend.X),(float)top,(float)(Math.Sin(angle)*r+bend.Y));
                }
                for(int side=0;side<6;side++)
                {
                    int next=(side+1)%6;if(ring>0)Quad(previous[side],points[side],points[next],previous[next]);if(ring==0)Triangle(Vector3.Zero,points[next],points[side]);if(ring==4)Triangle(Vector3.Up*.97f,points[side],points[next]);
                }
                previous=points;
            }
        }
        else
        {
            var basis=new[]{new Vector3(-1,0,-.7f),new Vector3(1,0,-.7f),new Vector3(1,0,.7f),new Vector3(-1,0,.7f)};var tops=new Vector3[4];var heights=new[]{.3,1.0,.7,.2};
            for(int i=0;i<4;i++)tops[i]=basis[i]*.8f+new Vector3(.12f,(float)(kind==1?1:heights[i]),.08f);
            for(int i=0;i<4;i++){int j=(i+1)%4;Quad(basis[i],tops[i],tops[j],basis[j]);}Quad(basis[0],basis[1],basis[2],basis[3]);Quad(tops[0],tops[3],tops[2],tops[1]);
        }
        var result=vertices.ToArray();_templates[key]=result;templates[key]=result;return result;
        void Triangle(Vector3 a,Vector3 b,Vector3 c){if((c-a).Cross(b-a).LengthSquared()<.00000001)return;vertices.Add(a);vertices.Add(b);vertices.Add(c);}
        void Quad(Vector3 a,Vector3 c,Vector3 d,Vector3 e)
        {
            if((d-a).Cross(c-a).Dot((a+c+d+e)*.25f-center)<0){Triangle(a,e,d);Triangle(a,d,c);}else{Triangle(a,c,d);Triangle(a,d,e);}
        }
    }
}
