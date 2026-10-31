using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>CPU counterpart of the tissue shader, retaining independent triangle orientation references.</summary>
public partial class BlobDeformationOracle : RefCounted
{
    private readonly BlobCurveFrames Frames=new();
    private sealed record Chain(Vector3[] Rest,Vector3[] Posed,Vector3[] RestAxes,Vector3[] Axes);
    private Chain[] Capture(Node3D actor,BlobSurfaceCirculation solver)
    {
        var contacts=(BlobAppendageContacts)actor.Get("contacts").AsGodotObject();var origin=actor.GlobalPosition+Vector3.Up*(float)solver.height;
        return contacts.chains.Select(value=>{var c=value.AsGodotDictionary();var rest=c["rest"].AsVector3Array();var local=c["points"].AsVector3Array().Select(p=>p-origin).ToArray();return new Chain(rest,local,Frames.normals(rest),Frames.normals(local,c["frame_seed"].AsVector3()));}).ToArray();
    }
    private Basis Matrix(Chain[] chains,int id,int other,double t,bool sheet)
    {
        var c=chains[id];return sheet?sheet_basis(c.Posed,chains[other].Posed,t)*sheet_basis(c.Rest,chains[other].Rest,t).Transposed():Frames.frame(c.Posed,c.Axes,t)*Frames.frame(c.Rest,c.RestAxes,t).Transposed();
    }
    private static Vector3 BodyNormal(Vector3 normal,Vector3 radii,BlobSurfaceCirculation solver)
    {
        var n=new Vector3(normal.X,normal.Y*radii.Y,normal.Z*radii.Z).Rotated(Vector3.Right,(float)(solver.roll_safe?-solver.circulation:0));return solver.pose_frame*new Vector3(n.X,n.Y/radii.Y,n.Z/radii.Z);
    }
    public D mesh_pose(D mesh,Node3D actor)
    {
        var solver=(BlobSurfaceCirculation)actor.Get("solver").AsGodotObject();var radii=actor.Get("anatomy").AsGodotDictionary()["dna"].AsGodotDictionary()["core_radii"].AsVector3();var chains=Capture(actor,solver);var rest=mesh["vertices"].AsVector3Array();var sourceNormals=mesh["normals"].AsVector3Array();var binds=mesh["binds"].AsFloat32Array();var cb=mesh["chain_binds"].AsFloat32Array();var anchors=mesh["anchors"].AsFloat32Array();var indices=mesh["indices"].AsInt32Array();var vertices=new Vector3[rest.Length];var normals=new Vector3[rest.Length];var references=new Vector3[indices.Length/3];
        for(int i=0;i<rest.Length;i++)
        {
            int offset=i*4,id=(int)cb[offset]-1,other=(int)cb[offset+2]-1;double t=cb[offset+1],u=cb[offset+3];
            if(binds[offset+2]<-.5&&id>=0){var a=Frames.point(chains[id].Posed,t);var b=Frames.point(chains[other].Posed,t);var n=(b-a).Cross(Frames.tangent(chains[id].Posed,t)+Frames.tangent(chains[other].Posed,t)).Normalized();vertices[i]=a.Lerp(b,(float)u)+n*(float)(anchors[offset]-(double)anchors[offset+1]*4*u*(1-u));normals[i]=(Matrix(chains,id,other,t,true)*sourceNormals[i]).Normalized();}
            else if(id>=0){var c=chains[id];var frame=Frames.frame(c.Posed,c.Axes,t);vertices[i]=Frames.point(c.Posed,t)+frame*new Vector3(anchors[offset],anchors[offset+1],anchors[offset+2]);normals[i]=(frame*Frames.frame(c.Rest,c.RestAxes,t).Transposed()*sourceNormals[i]).Normalized();}
            else{vertices[i]=solver.map_point(rest[i]);normals[i]=BodyNormal(sourceNormals[i],radii,solver).Normalized();}
        }
        var matrices=new Dictionary<Vector2I,Basis>();for(int i=0;i<indices.Length;i+=3){int a=indices[i],b=indices[i+1],c=indices[i+2],id=(int)cb[a*4]-1;var normal=-(rest[b]-rest[a]).Cross(rest[c]-rest[a]).Normalized();if(id<0)normal=BodyNormal(normal,radii,solver);else{double t=cb[a*4+1];var key=new Vector2I(id,(int)(t*1000000));if(!matrices.TryGetValue(key,out var matrix)){matrix=Matrix(chains,id,(int)cb[a*4+2]-1,t,binds[a*4+2]<-.5);matrices[key]=matrix;}normal=matrix*normal;}references[i/3]=normal.Normalized();}
        return new D{["vertices"]=vertices,["normals"]=normals,["reference_faces"]=references};
    }
    public int confirmed_inversions(D mesh,D pose,Node3D actor,int[] suspects)
    {
        var solver=(BlobSurfaceCirculation)actor.Get("solver").AsGodotObject();var chains=Capture(actor,solver);var rest=mesh["vertices"].AsVector3Array();var posed=pose["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var cb=mesh["chain_binds"].AsFloat32Array();var binds=mesh["binds"].AsFloat32Array();int count=0;
        foreach(int face in suspects){int a=indices[face*3],b=indices[face*3+1],c=indices[face*3+2],id=(int)cb[a*4]-1;var normal=-(rest[b]-rest[a]).Cross(rest[c]-rest[a]).Normalized();var current=(posed[b]-posed[a]).Cross(posed[c]-posed[a]);if(id<0)normal=solver.map_normal((rest[a]+rest[b]+rest[c])/3,normal);else{double t=((double)cb[a*4+1]+cb[b*4+1]+cb[c*4+1])/3;normal=Matrix(chains,id,(int)cb[a*4+2]-1,t,binds[a*4+2]<-.5)*normal;}if(current.Dot(normal)>1e-10)count++;}return count;
    }
    public Basis sheet_basis(Vector3[] a,Vector3[] b,double t)
    {
        var x=(Frames.point(b,t)-Frames.point(a,t)).Normalized();var y=Frames.tangent(a,t)+Frames.tangent(b,t);y=(y-x*x.Dot(y)).Normalized();return new Basis(x,y,x.Cross(y).Normalized());
    }
}
