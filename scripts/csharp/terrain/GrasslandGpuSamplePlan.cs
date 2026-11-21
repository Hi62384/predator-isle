using Godot;
using System;
using System.Collections.Generic;
using System.Threading;

namespace PredatorIsle.Terrain;

/// <summary>
/// Deduplicates the canonical coarse field corners before GPU generation. Interpolation
/// follows GrasslandField.sample's managed float vectors and double precision weights.
/// This avoids evaluating the same expensive raw corner for every nearby terrain vertex.
/// </summary>
internal sealed class GrasslandGpuSamplePlan
{
    private readonly record struct Query(int A,int B,int C,int D,int Exact,Vector2 Fraction);
    public Vector2[] RawPositions {get;}
    private readonly Query[] queries;
    private GrasslandGpuSamplePlan(Vector2[] positions,Query[] queries){RawPositions=positions;this.queries=queries;}

    public static GrasslandGpuSamplePlan? Create(ReadOnlySpan<Vector2> positions,double step,CancellationToken cancellation=default)
    {
        var raw=new List<Vector2>();var lookup=new Dictionary<Vector2,int>();var queries=new Query[positions.Length];
        bool valid=true;
        int Add(double x,double z)
        {
            // A shader accepts float coordinates. If conversion changes a canonical
            // coarse corner (e.g. a fractional spacing), use the CPU for this request.
            if((double)(float)x!=x||(double)(float)z!=z||!double.IsFinite(x)||!double.IsFinite(z)){valid=false;return 0;}
            var point=new Vector2((float)x,(float)z);
            if(lookup.TryGetValue(point,out int index))return index;
            index=raw.Count;lookup.Add(point,index);raw.Add(point);return index;
        }
        for(int i=0;i<positions.Length;i++)
        {
            if((i&127)==0)cancellation.ThrowIfCancellationRequested();
            var point=positions[i];var p=point/(float)step;
            int x=(int)Math.Floor(p.X),z=(int)Math.Floor(p.Y);var fraction=p-new Vector2(x,z);
            int a=Add(x*step,z*step);
            if(fraction.X<.000001&&fraction.Y<.000001){queries[i]=new(a,a,a,a,-1,fraction);continue;}
            int b=fraction.X==0?a:Add((x+1)*step,z*step);
            int c=fraction.Y==0?a:Add(x*step,(z+1)*step);
            int d=fraction.X==0?c:fraction.Y==0?b:Add((x+1)*step,(z+1)*step);
            int exact=Add(point.X,point.Y);
            queries[i]=new(a,b,c,d,exact,fraction);
        }
        return valid?new GrasslandGpuSamplePlan(raw.ToArray(),queries):null;
    }

    public float[] Interpolate(float[] raw)
    {
        if(raw.Length!=RawPositions.Length*9)throw new ArgumentException("Invalid GPU raw grassland payload.",nameof(raw));
        var result=new float[queries.Length*8];
        static double L(double a,double b,double t)=>a+(b-a)*t;
        Vector3 Value(int at)=>new(raw[at*9],raw[at*9+1],raw[at*9+2]);
        Vector2 Surface(int at)=>new(raw[at*9+3],raw[at*9+4]);
        Vector3 Geology(int at)=>new(raw[at*9+5],raw[at*9+6],raw[at*9+7]);
        for(int i=0;i<queries.Length;i++)
        {
            var q=queries[i];Vector3 value,geology;Vector2 surface;
            if(q.Exact<0){value=Value(q.A);surface=Surface(q.A);geology=Geology(q.A);}
            else
            {
                var f=q.Fraction;
                value=Value(q.A).Lerp(Value(q.B),f.X).Lerp(Value(q.C).Lerp(Value(q.D),f.X),f.Y);
                surface=Surface(q.A).Lerp(Surface(q.B),f.X).Lerp(Surface(q.C).Lerp(Surface(q.D),f.X),f.Y);
                geology=Geology(q.A).Lerp(Geology(q.B),f.X).Lerp(Geology(q.C).Lerp(Geology(q.D),f.X),f.Y);
                double detail=L(L(raw[q.A*9+8],raw[q.B*9+8],f.X),L(raw[q.C*9+8],raw[q.D*9+8],f.X),f.Y);
                if(detail>.001)
                {
                    value=value.Lerp(Value(q.Exact),(float)detail);
                    surface=surface.Lerp(Surface(q.Exact),(float)detail);
                    geology=geology.Lerp(Geology(q.Exact),(float)detail);
                }
            }
            int offset=i*8;
            result[offset]=value.X;result[offset+1]=value.Y;result[offset+2]=value.Z;
            result[offset+3]=surface.X;result[offset+4]=surface.Y;
            result[offset+5]=geology.X;result[offset+6]=geology.Y;result[offset+7]=geology.Z;
        }
        return result;
    }
}
