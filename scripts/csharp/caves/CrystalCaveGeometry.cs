using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Bounded quartz, amethyst, gypsum, smoky quartz, fluorite and calcite cave prototypes.</summary>
public partial class CrystalCaveGeometry : RefCounted
{
    public D templates {get;}=new();private readonly Dictionary<int,A> _templates=new();
    // The remaining GDScript feature provider also uses this winding helper
    // for attached veins and wall lining, outside the cached prototypes.
    public void quad(GodotObject builder,Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 center)
    {
        if((c-a).Cross(b-a).Dot((a+b+c+d)*.25f-center)<0)builder.Call("quad",a,d,c,b,Colors.White);
        else builder.Call("quad",a,b,c,d,Colors.White);
    }
    public A prototype(int habit,bool broken)
    {
        int key=habit*2+(broken?1:0);if(_templates.TryGetValue(key,out var cached))return cached;var vertices=new List<Vector3>();var normals=new List<Vector3>();
        if(habit==5)
        {
            var bottom=new[]{new Vector3(-1,0,-.75f),new Vector3(1,0,-.75f),new Vector3(1.5f,0,.75f),new Vector3(-.5f,0,.75f)};var shift=new Vector3(.45f,1,.22f);var center=(bottom[0]+bottom[2]+shift)*.5f;
            for(int i=0;i<4;i++){int j=(i+1)%4;OutwardQuad(bottom[i],bottom[j],bottom[j]+shift,bottom[i]+shift,center);}OutwardQuad(bottom[0],bottom[1],bottom[2],bottom[3],center);OutwardQuad(bottom[0]+shift,bottom[1]+shift,bottom[2]+shift,bottom[3]+shift,center);
        }
        else
        {
            int sides=habit<2||habit==3?6:4;var rings=new Vector3[3][];
            for(int level=0;level<3;level++)
            {
                double t=new[]{0.0,.76,1.0}[level],radius=level<2||broken||habit==4?1:.04;var ring=new Vector3[sides];
                for(int i=0;i<sides;i++){double angle=i*Math.Tau/sides;ring[i]=new Vector3((float)(Math.Cos(angle)*radius),(float)t,(float)(Math.Sin(angle)*radius*(habit==2?.14:1)));}rings[level]=ring;
            }
            for(int level=0;level<2;level++)for(int i=0;i<sides;i++){int j=(i+1)%sides;Quad(rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]);}
            for(int i=0;i<sides;i++)Triangle(rings[2][i],rings[2][(i+1)%sides],Vector3.Up);
            for(int i=0;i<sides;i++){double a=i*Math.Tau/sides,c=(i+1)*Math.Tau/sides;Triangle(Vector3.Zero,new Vector3((float)Math.Cos(c),0,(float)(Math.Sin(c)*(habit==2?.14:1))),new Vector3((float)Math.Cos(a),0,(float)(Math.Sin(a)*(habit==2?.14:1))));}
        }
        var uv=new Vector2[vertices.Count];for(int i=0;i<uv.Length;i++)uv[i]=new Vector2((float)(habit+Math.Clamp((double)vertices[i].Y,0,1)*.25),(float)(habit==5?1.5:2*(habit==2?.14:1)));
        var result=new A();result.Resize((int)Mesh.ArrayType.Max);result[(int)Mesh.ArrayType.Vertex]=vertices.ToArray();result[(int)Mesh.ArrayType.Normal]=normals.ToArray();result[(int)Mesh.ArrayType.TexUV]=uv;_templates[key]=result;templates[key]=result;return result;
        void Triangle(Vector3 a,Vector3 b,Vector3 c)
        {var cross=(c-a).Cross(b-a);if(cross.LengthSquared()<.00000001)return;var n=cross.Normalized();vertices.Add(a);vertices.Add(b);vertices.Add(c);normals.Add(n);normals.Add(n);normals.Add(n);}
        void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d){Triangle(a,b,c);Triangle(a,c,d);}
        void OutwardQuad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 center){if((c-a).Cross(b-a).Dot((a+b+c+d)*.25f-center)<0)Quad(a,d,c,b);else Quad(a,b,c,d);}
    }
    public Color tint(int family,double age)
    {
        var colors=new[]{new Color(.79f,.84f,.83f),new Color(.39f,.24f,.53f),new Color(.86f,.86f,.77f),new Color(.37f,.31f,.26f),new Color(.48f,.65f,.58f),new Color(.82f,.71f,.52f)};
        return colors[Math.Clamp(family,0,5)].Lerp(new Color(.38f,.35f,.30f),(float)(age*.18));
    }
}
