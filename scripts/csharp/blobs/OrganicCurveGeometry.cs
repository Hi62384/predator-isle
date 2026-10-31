using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Catmull-Rom swept-radius anatomy and monotone radius profiles used by the implicit tissue field.</summary>
public partial class OrganicCurveGeometry : RefCounted
{
    private static Variant Get(D d,string name,Variant fallback)=>d.TryGetValue(name,out var v)?v:fallback;
    private static double L(double a,double b,double t)=>a+(b-a)*t;
    public Vector3 vector(Variant value)=>vector(value,Vector3.Zero);
    public Vector3 vector(Variant value,Vector3 fallback)
    {
        if(value.VariantType==Variant.Type.Vector3)return value.AsVector3();
        if(value.VariantType==Variant.Type.Array){var a=value.AsGodotArray();if(a.Count>=3)return new Vector3((float)a[0].AsDouble(),(float)a[1].AsDouble(),(float)a[2].AsDouble());}
        if(value.VariantType==Variant.Type.PackedFloat32Array){var a=value.AsFloat32Array();if(a.Length>=3)return new Vector3(a[0],a[1],a[2]);}
        if(value.VariantType==Variant.Type.PackedFloat64Array){var a=value.AsFloat64Array();if(a.Length>=3)return new Vector3((float)a[0],(float)a[1],(float)a[2]);}
        return fallback;
    }
    public D sample(D node)=>sample(node,3,false);
    public D sample(D node,int subdivisions)=>sample(node,subdivisions,false);
    public D sample(D node,int subdivisions,bool smoothRadius)
    {
        var source=Get(node,"points",new A()).AsGodotArray();var positions=new List<Vector3>();var radii=new List<float>();
        if(source.Count<2)return new D{["points"]=System.Array.Empty<Vector3>(),["radii"]=System.Array.Empty<float>()};
        var sourceRadii=Get(node,"radii",new A()).AsGodotArray();double baseRadius=Math.Max(Get(node,"radius",.16).AsDouble(),.005);var shape=Get(node,"shape",new D()).AsGodotDictionary();
        double taper=Get(shape,"taper",0.0).AsDouble(),swelling=Get(shape,"swelling",.06).AsDouble(),twist=Get(shape,"twist",0.0).AsDouble();int steps=Math.Max(subdivisions,1);
        for(int i=0;i<source.Count-1;i++)
        {
            var a=vector(source[Math.Max(i-1,0)]);var b=vector(source[i]);var c=vector(source[i+1]);var d=vector(source[Math.Min(i+2,source.Count-1)]);
            double rb=i<sourceRadii.Count?sourceRadii[i].AsDouble():baseRadius,rc=i+1<sourceRadii.Count?sourceRadii[i+1].AsDouble():baseRadius;
            for(int j=0;j<steps;j++)
            {
                double t=(double)j/steps,t2=t*t,t3=t2*t;var p=(2*b+(-a+c)*(float)t+(2*a-5*b+4*c-d)*(float)t2+(-a+3*b-3*c+d)*(float)t3)*.5f;
                double along=(i+t)/(source.Count-1),radius=L(rb,rc,t)*(1-taper*along);radius*=1+swelling*Math.Sin(along*Math.Tau*2.7);
                if(Math.Abs(twist)>.0001)
                {
                    var tangent=(c-b).Normalized();var axis=tangent.Cross(Vector3.Up);if(axis.LengthSquared()<.01)axis=tangent.Cross(Vector3.Right);axis=axis.Normalized();
                    p+=axis.Rotated(tangent,(float)(along*Math.Tau*2))*(float)Math.Sin(along*Math.PI)*(float)radius*(float)twist;
                }
                positions.Add(p);radii.Add((float)Math.Max(radius,.004));
            }
        }
        positions.Add(vector(source[^1]));radii.Add((float)Math.Max((sourceRadii.Count>0?sourceRadii[^1].AsDouble():baseRadius)*(1-taper),.004));
        return new D{["points"]=positions.ToArray(),["radii"]=smoothRadius?smooth_radii(node,positions.Count,.06):radii.ToArray()};
    }
    public Transform3D attachment_frame(Vector3 point,Vector3 normal)=>attachment_frame(point,normal,Vector3.Up);
    public Transform3D attachment_frame(Vector3 point,Vector3 normal,Vector3 up)
    {
        var outward=normal.Normalized();if(outward.LengthSquared()<.1)outward=Vector3.Forward;var x=up.Cross(outward).Normalized();if(x.LengthSquared()<.1)x=Vector3.Right.Cross(outward).Normalized();var y=outward.Cross(x).Normalized();return new Transform3D(new Basis(x,y,outward),point);
    }
    public float[] smooth_radii(D node,int sampleCount)=>smooth_radii(node,sampleCount,0);
    public float[] smooth_radii(D node,int sampleCount,double defaultSwelling)
    {
        int count=Get(node,"points",new A()).AsGodotArray().Count;if(count<2)throw new ArgumentException("Radius interpolation requires at least two authored curve knots.");
        var source=Get(node,"radii",new A()).AsGodotArray();var values=new float[count];var slopes=new float[count];var output=new float[sampleCount];double baseRadius=Math.Max(Get(node,"radius",.16).AsDouble(),.004);
        for(int i=0;i<count;i++)values[i]=(float)Math.Max(i<source.Count?source[i].AsDouble():baseRadius,.004);
        for(int i=0;i<count;i++)
        {
            if(i==0)slopes[i]=values[1]-values[0];else if(i==count-1)slopes[i]=values[^1]-values[^2];
            else{double before=(double)values[i]-values[i-1],after=(double)values[i+1]-values[i];slopes[i]=(float)(before*after>0?2*before*after/(before+after):0);}
        }
        var shape=Get(node,"shape",new D()).AsGodotDictionary();double taper=Get(shape,"taper",0.0).AsDouble(),swelling=Get(shape,"swelling",defaultSwelling).AsDouble();
        for(int i=0;i<sampleCount;i++)
        {
            double along=(double)i/Math.Max(sampleCount-1,1),f=along*(count-1);int segment=Math.Min((int)Math.Floor(f),count-2);double t=f-segment,t2=t*t,t3=t2*t,a=values[segment],b=values[segment+1];
            double radius=(2*t3-3*t2+1)*a+(t3-2*t2+t)*slopes[segment]+(-2*t3+3*t2)*b+(t3-t2)*slopes[segment+1];radius=Math.Clamp(radius,Math.Min(a,b),Math.Max(a,b));radius*=(1-taper*along)*(1+swelling*Math.Sin(along*Math.Tau*2.7)*Math.Sin(along*Math.PI));output[i]=(float)Math.Max(radius,.004);
        }
        return output;
    }
    public double profile_value(A values,double t)
    {if(values.Count==0)return 1;if(values.Count==1)return Math.Clamp(values[0].AsDouble(),.1,4);double f=Math.Clamp(t,0,1)*(values.Count-1);int i=Math.Min((int)Math.Floor(f),values.Count-2);double q=f-i;q=q*q*(3-2*q);return Math.Clamp(L(values[i].AsDouble(),values[i+1].AsDouble(),q),.1,4);}
}
