using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Rejects posed anatomical curves that stretch edges, collapse faces or reverse their rest hemisphere.</summary>
public partial class BlobCurveGuard : RefCounted
{
    private readonly BlobCurveFrames Frames=new();
    public void prepare(D chain,D mesh)
    {
        var vertices=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var binds=mesh["chain_binds"].AsFloat32Array();var anchors=mesh["anchors"].AsFloat32Array();var rest=chain["rest"].AsVector3Array();
        var parameters=new float[vertices.Length];var offsets=new Vector3[vertices.Length];for(int i=0;i<vertices.Length;i++){parameters[i]=binds[i*4+1];offsets[i]=new Vector3(anchors[i*4],anchors[i*4+1],anchors[i*4+2]);}
        var edges=new HashSet<Vector2I>();var edgeIds=new List<int>();var lengths=new List<float>();int faces=indices.Length/3;
        var normals=new Vector3[faces];var areas=new float[faces];var faceParameters=new float[faces];var axes=Frames.normals(rest);
        for(int i=0;i<indices.Length;i+=3)
        {
            int a=indices[i],b=indices[i+1],c=indices[i+2];var n=(vertices[b]-vertices[a]).Cross(vertices[c]-vertices[a]);
            normals[i/3]=Frames.frame(rest,axes,parameters[a]).Transposed()*n;areas[i/3]=n.Length();faceParameters[i/3]=(float)(((double)parameters[a]+parameters[b]+parameters[c])/3);
            foreach(var edge in new[]{new Vector2I(a,b),new Vector2I(b,c),new Vector2I(c,a)})
            {var key=new Vector2I(Math.Min(edge.X,edge.Y),Math.Max(edge.X,edge.Y));if(!edges.Add(key))continue;edgeIds.Add(edge.X);edgeIds.Add(edge.Y);lengths.Add(vertices[edge.X].DistanceTo(vertices[edge.Y]));}
        }
        chain["qa"]=new D{["parameters"]=parameters,["offsets"]=offsets,["edges"]=edgeIds.ToArray(),["lengths"]=lengths.ToArray(),["normals"]=normals,["areas"]=areas,["face_parameters"]=faceParameters,["indices"]=indices};
    }
    public bool valid(D chain,Vector3[] points,Vector3 seed)
    {
        if(!chain.TryGetValue("qa",out var value))return true;var qa=value.AsGodotDictionary();var parameters=qa["parameters"].AsFloat32Array();var offsets=qa["offsets"].AsVector3Array();var edges=qa["edges"].AsInt32Array();var lengths=qa["lengths"].AsFloat32Array();var normals=qa["normals"].AsVector3Array();var areas=qa["areas"].AsFloat32Array();var indices=qa["indices"].AsInt32Array();
        var axes=Frames.normals(points,seed);var matrices=new Dictionary<double,Basis>();var centers=new Dictionary<double,Vector3>();var vertices=new Vector3[parameters.Length];
        for(int i=0;i<vertices.Length;i++)
        {
            double t=parameters[i];if(!matrices.TryGetValue(t,out var matrix)){matrix=Frames.frame(points,axes,t);matrices[t]=matrix;centers[t]=Frames.point(points,t);}var v=centers[t]+matrix*offsets[i];if(!v.IsFinite())return false;vertices[i]=v;
        }
        for(int i=0;i<lengths.Length;i++)if(vertices[edges[i*2]].DistanceTo(vertices[edges[i*2+1]])>2.2*(double)lengths[i])return false;
        for(int i=0;i<areas.Length;i++)
        {
            int a=indices[i*3],b=indices[i*3+1],c=indices[i*3+2];var current=(vertices[b]-vertices[a]).Cross(vertices[c]-vertices[a]);double ratio=current.Length()/Math.Max(areas[i],1e-10);
            if(ratio<.18||ratio>3.2)return false;var reference=matrices[parameters[a]]*normals[i];if(current.Dot(reference)<.3*current.Length()*reference.Length())return false;
        }
        return true;
    }
}
