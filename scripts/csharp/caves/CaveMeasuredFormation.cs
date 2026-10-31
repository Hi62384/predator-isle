using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Attaches opaque prototypes to measured rock while retaining exposed airspace and route clearance.</summary>
public partial class CaveMeasuredFormation : RefCounted
{
    private readonly CaveFormations Shapes=new();
    private static double Sample(GodotObject field,Vector3 point)=>field is CaveField native?native.sample(point):field.Call("sample",point).AsDouble();
    private static D Failure(string reason)=>new(){["valid"]=false,["reason"]=reason};
    public D fit(GodotObject field,Vector3[] points,Vector3 root,Vector3 axis,double width,double height,double phase)
    {
        if(!root.IsFinite()||!axis.IsFinite()||Math.Abs((double)axis.Length()-1)>.001||width<.1||height<.35||points.Length==0||points.Length%3!=0)return Failure("size_or_basis");
        var tangent=(Math.Abs(axis.Y)<.9?Vector3.Up:Vector3.Right).Cross(axis).Normalized().Rotated(axis,(float)phase);var across=tangent.Cross(axis).Normalized();var basis=new Basis(tangent,axis,across);if(basis.Determinant()<0)basis=new Basis(tangent,axis,-across);
        var vertices=new Vector3[points.Length];var contacts=new Dictionary<Vector2,Vector3>();var low=Vector3.Inf;var high=-Vector3.Inf;
        for(int i=0;i<points.Length;i++)
        {
            var q=points[i];var p=root+basis*new Vector3((float)(q.X*width),(float)(q.Y*height),(float)(q.Z*width));
            if(q.Y<.001)
            {
                var id=new Vector2(q.X,q.Z);
                if(!contacts.TryGetValue(id,out var foot))
                {
                    var back=p-axis*(float)(2+width);var front=p+axis*(float)(2+width);if(Sample(field,back)<0||Sample(field,front)>=0)return Failure("whole_foot_bracket");
                    foot=Shapes.boundary(field,back,front)-axis*1.25f;if(Sample(field,foot)<.15)return Failure("whole_foot_burial");contacts[id]=foot;
                }
                p=foot;
            }
            else if(Sample(field,p)>-Math.Min(.5,height*.2))return Failure("exposed_airspace");
            vertices[i]=p;low=low.Min(p);high=high.Max(p);
        }
        var bounds=new Aabb(low,high-low);if(Shapes.@protected(field,bounds.GetCenter(),new Vector2(bounds.Size.X,bounds.Size.Z).Length()*.5,low.Y,high.Y))return Failure("protected_route");
        var normals=new Vector3[vertices.Length];
        for(int i=0;i<vertices.Length;i+=3)
        {
            var cross=(vertices[i+2]-vertices[i]).Cross(vertices[i+1]-vertices[i]);if(cross.LengthSquared()<.0000000001)return Failure("collapsed_facet");for(int j=0;j<3;j++)normals[i+j]=cross.Normalized();
            foreach(var pair in new[]{new Vector2I(0,1),new Vector2I(1,2),new Vector2I(2,0)})
            {
                if(points[i+pair.X].Y<.001||points[i+pair.Y].Y<.001)continue;var a=vertices[i+pair.X];var b=vertices[i+pair.Y];int count=(int)Math.Ceiling(a.DistanceTo(b)/2.0);
                for(int station=1;station<count;station++)if(Sample(field,a.Lerp(b,(float)((double)station/count)))>-.15)return Failure("edge_airspace");
            }
        }
        return new D {["valid"]=true,["vertices"]=vertices,["normals"]=normals,["attachments"]=contacts.Values.ToArray(),["bounds"]=bounds};
    }
}
