using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

namespace PredatorIsle.Blobs;

/// <summary>Seats anatomical roots on the final extracted surface, using a local triangle grid.</summary>
public partial class BlobSurfaceAttachments : RefCounted
{
    public D mesh {get;set;}=new();
    public double cell {get;set;}=.5;
    private readonly Dictionary<Vector3I,List<int>> _buckets=new();
    private Vector3[] _vertices=System.Array.Empty<Vector3>(),_normals=System.Array.Empty<Vector3>();
    private int[] _indices=System.Array.Empty<int>(),_owners=System.Array.Empty<int>();
    private Color[] _colors=System.Array.Empty<Color>();
    private Vector2[] _uvs=System.Array.Empty<Vector2>();
    private readonly OrganicCurveGeometry Curves=new();
    private static Variant Get(D d,string key,Variant fallback)=>d.TryGetValue(key,out var v)?v:fallback;
    public void configure(D body,double size)
    {
        mesh=body;cell=Math.Max(.2,size*.35);_vertices=body["vertices"].AsVector3Array();_indices=body["indices"].AsInt32Array();_normals=body["normals"].AsVector3Array();_colors=body["colors"].AsColorArray();_uvs=body["uvs"].AsVector2Array();_owners=body["feature_ids"].AsInt32Array();_buckets.Clear();
        for(int triangle=0;triangle<_indices.Length;triangle+=3)
        {
            var a=_vertices[_indices[triangle]];var b=_vertices[_indices[triangle+1]];var c=_vertices[_indices[triangle+2]];var low=(Vector3I)(a.Min(b).Min(c)/(float)cell).Floor();var high=(Vector3I)(a.Max(b).Max(c)/(float)cell).Floor();
            for(int z=low.Z;z<=high.Z;z++)for(int y=low.Y;y<=high.Y;y++)for(int x=low.X;x<=high.X;x++){var key=new Vector3I(x,y,z);if(!_buckets.TryGetValue(key,out var bucket))_buckets[key]=bucket=new List<int>();bucket.Add(triangle);}
        }
    }
    public D nearest(Vector3 point)
    {
        var key=(Vector3I)(point/(float)cell).Floor();var candidates=new List<int>();var seen=new HashSet<int>();
        foreach(int radius in new[]{1,2,3,5})
        {
            for(int z=-radius;z<=radius;z++)for(int y=-radius;y<=radius;y++)for(int x=-radius;x<=radius;x++)if(_buckets.TryGetValue(key+new Vector3I(x,y,z),out var bucket))foreach(int triangle in bucket)if(seen.Add(triangle))candidates.Add(triangle);
            if(candidates.Count>8)break;
        }
        double best=double.PositiveInfinity;var result=new D();
        foreach(int triangle in candidates)
        {
            int ia=_indices[triangle],ib=_indices[triangle+1],ic=_indices[triangle+2];var a=_vertices[ia];var b=_vertices[ib];var c=_vertices[ic];var p=_closest_triangle(point,a,b,c);double distance=point.DistanceSquaredTo(p);if(distance>=best)continue;best=distance;
            var w=barycentric(p,a,b,c);var color=_colors[ia]*w.X+_colors[ib]*w.Y+_colors[ic]*w.Z;var normal=(_normals[ia]*w.X+_normals[ib]*w.Y+_normals[ic]*w.Z).Normalized();
            result=new D{["point"]=p,["normal"]=normal,["distance"]=Math.Sqrt(distance),["color"]=color,["tissue"]=(int)_uvs[ia].X,["owner"]=_owners[ia],["triangle"]=triangle,["weights"]=w};
        }
        return result;
    }
    public Vector3 barycentric(Vector3 p,Vector3 a,Vector3 b,Vector3 c)
    {
        var v0=b-a;var v1=c-a;var v2=p-a;double denominator=(double)v0.Dot(v0)*v1.Dot(v1)-(double)v0.Dot(v1)*v0.Dot(v1);if(Math.Abs(denominator)<.0000000001)return new Vector3(1,0,0);
        double y=((double)v1.Dot(v1)*v2.Dot(v0)-(double)v0.Dot(v1)*v2.Dot(v1))/denominator,z=((double)v0.Dot(v0)*v2.Dot(v1)-(double)v0.Dot(v1)*v2.Dot(v0))/denominator;return new Vector3((float)(1-y-z),(float)y,(float)z);
    }
    public D finalize(A features,double size)
    {
        int corrected=0;var failures=new Godot.Collections.Array<string>();
        foreach(var item in features)
        {
            var f=item.AsGodotDictionary();if(!f.ContainsKey("points")||Get(f,"sheet",false).AsBool()||Get(f,"fused_path",false).AsBool())continue;
            var parent=features[Math.Max(f["parent"].AsInt32(),0)].AsGodotDictionary();string type=f["feature_type"].AsString();var points=f["points"].AsGodotArray();
            if(parent.ContainsKey("points")&&(type is "gripping_digit" or "sensory_bulb"))
            {var parentPoints=parent["points"].AsGodotArray();var delta=parentPoints[^1].AsVector3()-points[0].AsVector3();for(int i=0;i<points.Count;i++)points[i]=points[i].AsVector3()+delta;f["center"]=points[0];f["terminal_parent"]=parent["id"];continue;}
            if(parent.ContainsKey("points")&&(type is "vine_branch" or "attachment_fiber"))
            {
                var curve=Curves.sample(new D{["points"]=_arrays(parent["points"].AsGodotArray()),["radii"]=parent["radii_profile"]},7)["points"].AsVector3Array();var nearest=curve[0];double best=double.PositiveInfinity,along=0;
                for(int i=0;i<curve.Length;i++){double distance=curve[i].DistanceSquaredTo(points[0].AsVector3());if(distance<best){best=distance;nearest=curve[i];along=(double)i/(curve.Length-1);}}
                var delta=nearest-points[0].AsVector3();for(int i=0;i<points.Count;i++)points[i]=points[i].AsVector3()+delta*(float)(1-(double)i/points.Count);f["center"]=points[0];f["parent_along"]=along;continue;
            }
            if(type is "vascular_trunk" or "vascular_branch" or "capillary" or "anatomical_fold" or "eyelid" or "face_transition")continue;
            var seat=nearest(points[0].AsVector3());if(seat.Count==0){failures.Add("No supporting surface for feature "+f["id"].AsInt64());continue;}
            double burial=f["radii"].AsVector3().X*.65;var root=seat["point"].AsVector3()-seat["normal"].AsVector3()*(float)f["radii"].AsVector3().X*.65f;var displacement=root-points[0].AsVector3();
            if(displacement.Length()>size*1.3){failures.Add("Feature "+f["id"].AsInt64()+" is outside its parent surface");continue;}
            for(int i=0;i<points.Count;i++){double t=(double)i/Math.Max(points.Count-1,1);points[i]=points[i].AsVector3()+displacement*(float)(1-t)*(float)(1-t);}
            f["center"]=points[0];f["surface_attachment"]=new D{["point"]=seat["point"],["normal"]=seat["normal"],["triangle"]=seat["triangle"],["burial"]=burial};f["root_color"]=seat["color"];f["root_tissue"]=seat["tissue"];corrected++;
        }
        return new D{["corrected_roots"]=corrected,["failures"]=failures};
    }
    public A _arrays(A points){var result=new A();foreach(var item in points){var p=item.AsVector3();result.Add(new A{p.X,p.Y,p.Z});}return result;}
    public Vector3 _closest_triangle(Vector3 p,Vector3 a,Vector3 b,Vector3 c)
    {
        var ab=b-a;var ac=c-a;var ap=p-a;double d1=ab.Dot(ap),d2=ac.Dot(ap);if(d1<=0&&d2<=0)return a;var bp=p-b;double d3=ab.Dot(bp),d4=ac.Dot(bp);if(d3>=0&&d4<=d3)return b;
        double vc=d1*d4-d3*d2;if(vc<=0&&d1>=0&&d3<=0)return a+ab*(float)(d1/(d1-d3));var cp=p-c;double d5=ab.Dot(cp),d6=ac.Dot(cp);if(d6>=0&&d5<=d6)return c;
        double vb=d5*d2-d1*d6;if(vb<=0&&d2>=0&&d6<=0)return a+ac*(float)(d2/(d2-d6));double va=d3*d6-d5*d4;if(va<=0&&d4-d3>=0&&d5-d6>=0)return b+(c-b)*(float)((d4-d3)/((d4-d3)+(d5-d6)));
        double denominator=1/(va+vb+vc);return a+ab*(float)vb*(float)denominator+ac*(float)vc*(float)denominator;
    }
}
