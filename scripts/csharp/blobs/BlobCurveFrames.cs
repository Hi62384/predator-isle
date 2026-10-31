using Godot;
using System;

namespace PredatorIsle.Blobs;

/// <summary>Bounded Hermite centerlines and parallel-transport frames shared by geometry and deformation.</summary>
public partial class BlobCurveFrames : RefCounted
{
    public Vector3 point(Vector3[] points,double t)
    {
        if(points.Length<2)throw new ArgumentException("An anatomical curve needs at least two points.",nameof(points));
        double u=Math.Clamp(t,0,1)*(points.Length-1);int i=Math.Min((int)u,points.Length-2);double f=u-i;
        var a=points[Math.Max(i-1,0)];var b=points[i];var c=points[i+1];var d=points[Math.Min(i+2,points.Length-1)];double length=b.DistanceTo(c);
        var m0=((c-a)*.5f).LimitLength((float)(length*.75));var m1=((d-b)*.5f).LimitLength((float)(length*.75));
        return b*(float)(2*f*f*f-3*f*f+1)+m0*(float)(f*f*f-2*f*f+f)+c*(float)(-2*f*f*f+3*f*f)+m1*(float)(f*f*f-f*f);
    }
    public Vector3 tangent(Vector3[] points,double t)=>(point(points,Math.Min(1,t+.001))-point(points,Math.Max(0,t-.001))).Normalized();
    public Vector3[] normals(Vector3[] points)=>normals(points,Vector3.Right);
    public Vector3[] normals(Vector3[] points,Vector3 seed)
    {
        var result=new Vector3[points.Length];var normal=seed;
        for(int i=0;i<points.Length;i++)
        {
            var axis=tangent(points,(double)i/(points.Length-1));normal-=axis*normal.Dot(axis);
            if(normal.LengthSquared()<.01)normal=axis.Cross(Math.Abs(axis.Y)<.9?Vector3.Up:Vector3.Right);
            normal=normal.Normalized();result[i]=normal;
        }
        return result;
    }
    public Basis frame(Vector3[] points,Vector3[] axes,double t)
    {
        if(points.Length<2||axes.Length<points.Length)throw new ArgumentException("Curve frame arrays must cover the complete centerline.");
        double u=Math.Clamp(t,0,1)*(points.Length-1);int i=Math.Min((int)u,points.Length-2);var axis=tangent(points,t);
        var n=axes[i].Lerp(axes[i+1],(float)(u-i));n=(n-axis*n.Dot(axis)).Normalized();
        if(n.LengthSquared()<.01)n=axis.Cross(Math.Abs(axis.Y)<.9?Vector3.Up:Vector3.Right).Normalized();
        return new Basis(n,axis.Cross(n).Normalized(),axis);
    }
}
