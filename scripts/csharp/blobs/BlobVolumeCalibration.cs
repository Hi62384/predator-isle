using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Measures the actual closed tissue shell across circulation and strain states.</summary>
public partial class BlobVolumeCalibration : RefCounted
{
    public int SAMPLES {get;}=32;
    private static bool Cancelled(RefCounted? job)=>job is not null&&job.Call("is_cancelled").AsBool();
    public float[] calibrate(D data)=>calibrate(data,null);
    public float[] calibrate(D data,RefCounted? job)
    {
        using var solver=new BlobSurfaceCirculation();var dna=data["dna"].AsGodotDictionary().Duplicate(true);dna.Remove("volume_curve");dna.Remove("strain_volume_curve");var mesh=data["body"].AsGodotDictionary();solver.configure(dna,data["rig"].AsGodotDictionary(),mesh);
        var restVertices=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var binds=mesh["binds"].AsFloat32Array();double rest=_volume(restVertices,indices);var curve=new float[SAMPLES];var vertices=new Vector3[restVertices.Length];
        for(int sample=0;sample<SAMPLES;sample++)
        {
            if(Cancelled(job))return System.Array.Empty<float>();solver.circulation=Math.Tau*sample/SAMPLES;solver._update_groups(0);
            for(int i=0;i<vertices.Length;i++)vertices[i]=solver.map_bound(restVertices[i],(int)binds[i*4]-1,binds[i*4+1]);double deformed=_volume(vertices,indices);curve[sample]=(float)Math.Pow(rest/Math.Max(deformed,rest*.12),1.0/3);
        }
        data["dna"].AsGodotDictionary()["strain_volume_curve"]=calibrate_strain(data,job);return curve;
    }
    public float[] calibrate_strain(D data)=>calibrate_strain(data,null);
    public float[] calibrate_strain(D data,RefCounted? job)
    {
        using var solver=new BlobSurfaceCirculation();var dna=data["dna"].AsGodotDictionary().Duplicate(true);dna.Remove("volume_curve");dna.Remove("strain_volume_curve");var mesh=data["body"].AsGodotDictionary();solver.configure(dna,data["rig"].AsGodotDictionary(),mesh);
        var rest=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var binds=mesh["binds"].AsFloat32Array();var vertices=new Vector3[rest.Length];var curve=new float[8];double baseline=0;
        for(int corner=0;corner<8;corner++)
        {
            if(Cancelled(job))return System.Array.Empty<float>();solver.strain=new Vector3((corner&1)!=0?.22f:0,(corner&2)!=0?.22f:0,(corner&4)!=0?.22f:0);solver._update_groups(0);
            for(int i=0;i<vertices.Length;i++)vertices[i]=solver.map_bound(rest[i],(int)binds[i*4]-1,binds[i*4+1]);double measured=_volume(vertices,indices);if(corner==0)baseline=measured;curve[corner]=(float)Math.Pow(baseline/Math.Max(measured,baseline*.12),1.0/3);
        }
        return curve;
    }
    public double _volume(Vector3[] vertices,int[] indices)
    {double value=0;for(int i=0;i<indices.Length;i+=3)value+=vertices[indices[i]].Dot(vertices[indices[i+1]].Cross(vertices[indices[i+2]]))/6.0;return Math.Abs(value);}
}
