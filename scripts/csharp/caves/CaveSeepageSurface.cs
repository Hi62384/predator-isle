using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Bounded connected water patches clipped against actual carved air and a measured solid bed.</summary>
public partial class CaveSeepageSurface : RefCounted
{
    private static double N(D d,string key) => d[key].AsDouble();
    private static Vector3[] Path(D d) => d.ContainsKey("stream_points")?d["stream_points"].AsVector3Array():System.Array.Empty<Vector3>();
    private static double Sample(GodotObject field,Vector3 p) => field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
    private static double Smooth(double a,double b,double x) {double t=Math.Clamp((x-a)/(b-a),0,1); return t*t*(3-2*t);}
    private static D Failure(string reason) => new() {["valid"]=false,["reason"]=reason};
    public Vector3 water_point(D pool,Vector2 p) => WaterPoint(pool,p,Path(pool));
    private static Vector3 WaterPoint(D pool,Vector2 p,Vector3[] path)
    {
        double surface=N(pool,"water_y"),best=double.PositiveInfinity,progress=1;
        for(int i=0;i<path.Length-1;i++)
        {
            var a=new Vector2(path[i].X,path[i].Z); var b=new Vector2(path[i+1].X,path[i+1].Z); var ab=b-a;
            double t=Math.Clamp((p-a).Dot(ab)/Math.Max(ab.LengthSquared(),.000001),0,1),distance=p.DistanceSquaredTo(a+ab*(float)t);
            if(distance<best){best=distance;progress=(i+t)/(path.Length-1);}
        }
        var center=pool["center"].AsVector3();
        if(path.Length>0) surface+=.10*(1-progress)*Smooth(N(pool,"radius"),N(pool,"radius")+2,p.DistanceTo(new Vector2(center.X,center.Z)));
        return new Vector3(p.X,(float)surface,p.Y);
    }
    private static List<Vector3> Clip(Vector3[] points,float[] values,int a,int b,int c,CaveField local,GodotObject field)
    {
        var indices=new[]{a,b,c}; var result=new List<Vector3>(4);
        for(int i=0;i<3;i++)
        {
            int previous=indices[(i+2)%3],current=indices[i]; var pa=points[previous]; var pb=points[current];
            bool insideA=values[previous]+.035<0,insideB=values[current]+.035<0;
            if(insideA!=insideB)
            {
                var low=pa;var high=pb;
                for(int iteration=0;iteration<10;iteration++) {var mid=(low+high)*.5f;bool inside=Math.Max(local.sample(mid),Sample(field,mid))<-.035;if(inside==insideA) low=mid;else high=mid;}
                result.Add(insideA?low:high);
            }
            if(insideB) result.Add(pb);
        }
        return result;
    }
    public D build(D pool,GodotObject field) => build(pool,field,0);
    public D build(D pool,GodotObject field,int style)
    {
        using var local=new CaveField {maximum_depth=field.Get("maximum_depth").AsDouble(),minimum_roof=field.Get("minimum_roof").AsDouble()};
        var nodes=new A {pool["bed"]}; if(pool.ContainsKey("bed_lobes")) nodes.AddRange(pool["bed_lobes"].AsGodotArray());
        var edges=pool.ContainsKey("stream_edges")?pool["stream_edges"].AsGodotArray():new A();
        if(!local.compile(new A {new D {["valid"]=true,["nodes"]=nodes,["edges"]=edges,["cross_section_style"]=style}},field.Get("height").AsCallable())) return Failure("Invalid local seepage bed");
        var center=pool["center"].AsVector3();double radius=N(pool,"radius"); var low=new Vector2((float)(center.X-radius-1),(float)(center.Z-radius-1));var high=low+Vector2.One*(float)(radius+1)*2;var path=Path(pool);
        foreach(var point in path) {low=low.Min(new Vector2(point.X,point.Z)-Vector2.One*2.5f);high=high.Max(new Vector2(point.X,point.Z)+Vector2.One*2.5f);}
        var first=new Vector2I((int)Math.Floor(low.X/.5),(int)Math.Floor(low.Y/.5));var last=new Vector2I((int)Math.Ceiling(high.X/.5),(int)Math.Ceiling(high.Y/.5));
        long wide=(long)last.X-first.X+1,tall=(long)last.Y-first.Y+1;
        if(wide<2||tall<2||wide>8192||tall>8192||wide*tall>8192) return Failure("Seepage surface exceeds bounded sampling domain");
        int width=(int)wide,height=(int)tall;var positions=new Vector3[width*height];var samples=new float[positions.Length];
        for(int z=0;z<height;z++) for(int x=0;x<width;x++) {var p=WaterPoint(pool,(Vector2)(first+new Vector2I(x,z))*.5f,path);int index=x+z*width;positions[index]=p;samples[index]=(float)Math.Max(local.sample(p),Sample(field,p));}
        var vertices=new List<Vector3>();var normals=new List<Vector3>();var colors=new List<Color>();var uv=new List<Vector2>();var uv2=new List<Vector2>();var measured=new Dictionary<Vector3,(double Bed,double Flow,double Along,double Angle)>();
        for(int z=0;z<height-1;z++) for(int x=0;x<width-1;x++)
        {
            int a=x+z*width,b=a+1,c=a+width,d=c+1;
            foreach(var indices in new[]{new Vector3I(a,b,c),new Vector3I(c,b,d)})
            {
                var clipped=Clip(positions,samples,indices.X,indices.Y,indices.Z,local,field);
                for(int triangle=1;triangle<clipped.Count-1;triangle++)
                {
                    var trianglePoints=new[]{clipped[0],clipped[triangle],clipped[triangle+1]};
                    if((trianglePoints[2]-trianglePoints[0]).Cross(trianglePoints[1]-trianglePoints[0]).LengthSquared()<.000000000001) continue;
                    foreach(var point in trianglePoints)
                    {
                        if(vertices.Count>=30000) return Failure("Seepage surface exceeds vertex bound");
                        if(!measured.TryGetValue(point,out var payload))
                        {
                            var bottom=new Vector3(point.X,(float)(N(pool,"bed_y")-2),point.Z);var top=point;double air=Sample(field,top),bed=Sample(field,bottom);
                            if(air>=-.01||bed<=0) return Failure("Seepage vertex has no measured air/solid bed at"+Variant.From(point).AsString()+" air="+air.ToString("F6",System.Globalization.CultureInfo.InvariantCulture)+" bed="+bed.ToString("F6",System.Globalization.CultureInfo.InvariantCulture));
                            for(int iteration=0;iteration<14;iteration++) {var mid=(bottom+top)*.5f;if(Sample(field,mid)>=0) bottom=mid;else top=mid;}
                            double flow=0,along=0,angle=0,closest=double.PositiveInfinity;
                            for(int i=0;i<path.Length-1;i++)
                            {
                                var p0=new Vector2(path[i].X,path[i].Z);var p1=new Vector2(path[i+1].X,path[i+1].Z);var ab=p1-p0;var q=new Vector2(point.X,point.Z);
                                double t=Math.Clamp((q-p0).Dot(ab)/Math.Max(ab.LengthSquared(),.000001),0,1),distance=q.DistanceSquaredTo(p0+ab*(float)t);
                                if(distance<closest) {closest=distance;angle=((double)ab.Angle()%Math.Tau+Math.Tau)%Math.Tau;along=(i+t)*path[0].DistanceTo(path[^1])/Math.Max(1,path.Length-1);flow=Smooth(radius*.7,radius+1,q.DistanceTo(new Vector2(center.X,center.Z)));}
                            }
                            payload=(((double)bottom.Y+top.Y)*.5,flow,along,angle);measured[point]=payload;
                        }
                        vertices.Add(point);normals.Add(Vector3.Up);colors.Add(new Color(.08f,0,1,(float)payload.Flow));uv.Add(new Vector2((float)payload.Bed,(float)payload.Along));uv2.Add(new Vector2((float)payload.Angle,-1));
                    }
                }
            }
        }
        var arrays=new A();if(vertices.Count>0){arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices.ToArray();arrays[(int)Mesh.ArrayType.Normal]=normals.ToArray();arrays[(int)Mesh.ArrayType.Color]=colors.ToArray();arrays[(int)Mesh.ArrayType.TexUV]=uv.ToArray();arrays[(int)Mesh.ArrayType.TexUV2]=uv2.ToArray();}
        return new D {["valid"]=true,["arrays"]=arrays,["sample_count"]=width*height,["measured_vertices"]=measured.Count};
    }
}
