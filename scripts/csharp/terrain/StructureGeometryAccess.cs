using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

internal interface IStructureGeometry
{
    List<Vector3> VertexBuffer {get;}
    List<Vector3> NormalBuffer {get;}
    Vector3 origin {get;}
    D _footing_vertices {get;}
    D _conduit_uvs {get;}
    double footing_height(GodotObject builder,Vector2 point);
    void triangle(Vector3 a,Vector3 b,Vector3 c,Color color);
    void quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Color color);
}

/// <summary>Native buffer access, with one import/export for retained GDScript emitters.</summary>
internal static class StructureGeometryAccess
{
    internal static Vector3 Origin(GodotObject g)=>g is IStructureGeometry n?n.origin:g.Get("origin").AsVector3();
    internal static D Footings(GodotObject g)=>g is IStructureGeometry n?n._footing_vertices:g.Get("_footing_vertices").AsGodotDictionary();
    internal static D UVs(GodotObject g)=>g is IStructureGeometry n?n._conduit_uvs:g.Get("_conduit_uvs").AsGodotDictionary();
    internal static double Footing(GodotObject g,GodotObject builder,Vector2 p)=>g is IStructureGeometry n?n.footing_height(builder,p):g.Call("footing_height",builder,p).AsDouble();
    internal static double Height(GodotObject builder,Vector2 p)=>builder.Call("_get_height",p.X,p.Y).AsDouble();
    internal static void Triangle(GodotObject g,Vector3 a,Vector3 b,Vector3 c,Color color){if(g is IStructureGeometry n)n.triangle(a,b,c,color);else g.Call("triangle",a,b,c,color);}
    internal static void Quad(GodotObject g,Vector3 a,Vector3 b,Vector3 c,Vector3 d,Color color){if(g is IStructureGeometry n)n.quad(a,b,c,d,color);else g.Call("quad",a,b,c,d,color);}
    internal static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    internal static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    internal static Vector2 Controls(GodotObject sampler,Vector2 p)
    {
        if(sampler is Biomes.AlienInfectedSampler native){native.sample(p.X,p.Y);return new((float)(native.state[3]*5),(float)native.state[4]);}
        sampler.Call("sample",p.X,p.Y);var state=sampler.Get("state").AsFloat64Array();return new((float)(state[3]*5),(float)state[4]);
    }
    internal static List<Vector3> Vertices(GodotObject g)=>g is IStructureGeometry n?n.VertexBuffer:new(g.Get("vertices").AsVector3Array());
    internal static List<Vector3> Normals(GodotObject g)=>g is IStructureGeometry n?n.NormalBuffer:new(g.Get("normals").AsVector3Array());
    internal static void Commit(GodotObject g,List<Vector3> vertices,List<Vector3> normals){if(g is IStructureGeometry)return;g.Set("vertices",vertices.ToArray());g.Set("normals",normals.ToArray());}
    internal static void SmoothRange(GodotObject g,int first,double threshold)
    {
        var vertices=Vertices(g);var normals=Normals(g);var sums=new Dictionary<Vector3,Vector3>();
        for(int i=first;i<vertices.Count;i++)sums[vertices[i]]=sums.GetValueOrDefault(vertices[i])+normals[i];
        for(int i=first;i<vertices.Count;i++){var n=sums[vertices[i]].Normalized();if(n.Dot(normals[i])>threshold)normals[i]=n;}Commit(g,vertices,normals);
    }
}
