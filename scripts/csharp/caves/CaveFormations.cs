using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Measured geological growth attached to solid cave boundaries and excluded from protected passages.</summary>
public partial class CaveFormations : RefCounted
{
    private readonly List<Vector3> _vertices=new(),_normals=new();private readonly List<Color> _colors=new();
    internal List<Vector3> VertexBuffer=>_vertices;
    internal List<Vector3> NormalBuffer=>_normals;
    internal List<Color> ColorBuffer=>_colors;
    public Vector3[] vertices {get=>_vertices.ToArray();set{_vertices.Clear();_vertices.AddRange(value);}}
    public Vector3[] normals {get=>_normals.ToArray();set{_normals.Clear();_normals.AddRange(value);}}
    public Color[] colors {get=>_colors.ToArray();set{_colors.Clear();_colors.AddRange(value);}}
    public Vector3 origin {get;set;}
    private static double Sample(GodotObject field,Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
    public double random(Vector3I cell,long seed_id,long salt){long h=unchecked(cell.X*374761393L+cell.Y*668265263L+cell.Z*1442695041L+seed_id*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return(double)(h^(h>>16))/2147483647.0;}
    public Vector3 boundary(GodotObject field,Vector3 a,Vector3 b)
    {bool positive=Sample(field,a)>=0;for(int i=0;i<16;i++){var mid=(a+b)*.5f;if((Sample(field,mid)>=0)==positive)a=mid;else b=mid;}return(a+b)*.5f;}
    public Vector3 ceiling_at(GodotObject field,Vector3 floor_point)
    {
        var previous=floor_point+new Vector3(0,.1f,0);if(Sample(field,previous)>=0)return Vector3.Inf;
        for(int step=1;step<=64;step++){var point=floor_point+new Vector3(0,step*2,0);if(Sample(field,point)>=0)return boundary(field,previous,point);previous=point;}return Vector3.Inf;
    }
    public bool @protected(GodotObject field,Vector3 point,double radius,double low,double high)
    {
        if(field.HasMethod("protected_shore")&&field.Call("protected_shore",point,radius,low,high).AsBool())return true;
        var native=field as CaveField;var first=field.Call("bin_cell",new Vector3((float)(point.X-radius),(float)(low-1),(float)(point.Z-radius))).AsVector3I();var last=field.Call("bin_cell",new Vector3((float)(point.X+radius),(float)(high+1),(float)(point.Z+radius))).AsVector3I();var visited=new HashSet<int>();
        var bins=native==null?field.Get("bins").AsGodotDictionary():null;var kinds=native==null?field.Get("kinds").AsByteArray():null;var begins=native==null?field.Get("begins").AsVector3Array():null;var ends=native==null?field.Get("ends").AsVector3Array():null;var dimensions=native==null?field.Get("dimensions").AsVector2Array():null;
        for(int z=first.Z;z<=last.Z;z++)for(int y=first.Y;y<=last.Y;y++)for(int x=first.X;x<=last.X;x++)
        {
            var key=new Vector3I(x,y,z);IEnumerable<int> features=native!=null?(native.Bins.TryGetValue(key,out var found)?found:System.Array.Empty<int>()):(bins!.ContainsKey(key)?bins[key].AsInt32Array():System.Array.Empty<int>());
            foreach(int feature in features)
            {
                if(visited.Contains(feature)||(native!=null?native.Kinds[feature]:kinds![feature])==2)continue;visited.Add(feature);var a=native!=null?native.Begins[feature]:begins![feature];var b=native!=null?native.Ends[feature]:ends![feature];var size=native!=null?native.Dimensions[feature]:dimensions![feature];var ab=new Vector2(b.X-a.X,b.Z-a.Z);var q=new Vector2(point.X-a.X,point.Z-a.Z);double t=Math.Clamp(q.Dot(ab)/Math.Max(ab.LengthSquared(),.000001),0,1),floor=a.Y+((double)b.Y-a.Y)*t;
                if((q-ab*(float)t).Length()<size.X+radius+1&&high>floor-.5&&low<floor+size.Y+.5)return true;
            }
        }
        return false;
    }
    public void triangle(Vector3 a,Vector3 b,Vector3 c,Vector3 outward,Color color)
    {
        var cross=(c-a).Cross(b-a);if(cross.LengthSquared()<.0000000001)return;if(cross.Dot(outward)<0){(b,c)=(c,b);cross=-cross;}var normal=cross.Normalized();
        foreach(var p in new[]{a,b,c}){_vertices.Add(p-origin);_normals.Add(normal);_colors.Add(color);}
    }
    public Vector3[] contacts(GodotObject field,Vector3 root,double radius,double up,double phase,double height)
    {
        var result=new Vector3[14];
        for(int i=0;i<14;i++)
        {
            double angle=i*Math.Tau/14,flute=1+.075*Math.Sin(angle*5+phase)+.04*Math.Sin(angle*9-phase);var p=root+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*(float)radius*(float)flute;var a=p-new Vector3(0,(float)(up*1.25),0);var b=p+new Vector3(0,(float)(up*1.25),0);
            if(Sample(field,a)<0||Sample(field,b)>=0)return System.Array.Empty<Vector3>();var contact=boundary(field,a,b);if(Math.Abs((double)contact.Y-root.Y)>Math.Min(.9,height*.2))return System.Array.Empty<Vector3>();result[i]=contact-new Vector3(0,(float)(up*.35),0);
        }
        return result;
    }
    public void growth(Vector3 root,double radius,double height,double up,double phase,Vector3[] foot)=>growth(root,radius,height,up,phase,foot,false,false);
    public void growth(Vector3 root,double radius,double height,double up,double phase,Vector3[] foot,bool flowing)=>growth(root,radius,height,up,phase,foot,flowing,false);
    public void growth(Vector3 root,double radius,double height,double up,double phase,Vector3[] foot,bool flowing,bool breakdown)
    {
        int rings=breakdown?5:12;var tint=breakdown?new Color(.38f,.35f,.30f,.5f):new Color(.73f,.67f,.54f,1);Vector3[] previous=System.Array.Empty<Vector3>();
        for(int j=0;j<=rings;j++)
        {
            double t=(double)j/rings,profile=Math.Pow(Math.Max(0,1-t),.68)*(1+.12*Math.Sin(t*Math.Tau*2+phase)*Math.Sin(Math.PI*t));var ring=new Vector3[14];
            if(flowing)profile=Math.Pow(Math.Max(0,1-t),.30)*(1+.085*Math.Sin(t*Math.Tau*4+phase)*Math.Sin(Math.PI*t));if(breakdown)profile=Math.Pow(Math.Max(0,1-t),.28)*(1+.19*Math.Sin(t*Math.PI*3+phase)*Math.Sin(Math.PI*t));
            for(int i=0;i<14;i++)
            {
                double angle=i*Math.Tau/14,flute=1+.075*Math.Sin(angle*5+phase)+.04*Math.Sin(angle*9-phase),r=radius*profile*flute;var bend=new Vector2((float)Math.Sin(phase),(float)Math.Cos(phase))*(float)height*.025f*(float)t*(float)t;
                var point=root+new Vector3((float)(Math.Cos(angle)*r+bend.X),(float)(up*(height*t-.35)),(float)(Math.Sin(angle)*r+bend.Y));point.Y=(float)(point.Y+(foot[i].Y-(root.Y-up*.35))*Math.Pow(1-t,2));ring[i]=point;
            }
            if(j>0)for(int i=0;i<14;i++){int n=(i+1)%14;var outward=new Vector3((float)Math.Cos((i+.5)*Math.Tau/14),0,(float)Math.Sin((i+.5)*Math.Tau/14));triangle(previous[i],ring[i],ring[n],outward,tint);triangle(previous[i],ring[n],previous[n],outward,tint);}
            else for(int i=0;i<14;i++)triangle(root-new Vector3(0,(float)(up*.35),0),ring[i],ring[(i+1)%14],new Vector3(0,(float)-up,0),tint);previous=ring;
        }
    }
    public void column(Vector3 floor_point,Vector3 ceiling,double radius,double phase,Vector3[] foot,Vector3[] crown)
    {
        Vector3[] previous=System.Array.Empty<Vector3>();double height=(double)ceiling.Y-floor_point.Y;var tint=new Color(.73f,.67f,.54f,1);
        for(int j=0;j<21;j++)
        {
            double t=(double)j/20,profile=.34+.66*Math.Pow(Math.Abs(2*t-1),1.6);var ring=new Vector3[14];
            for(int i=0;i<14;i++)
            {
                double angle=i*Math.Tau/14,flute=1+.075*Math.Sin(angle*5+phase)+.04*Math.Sin(angle*9-phase),r=radius*profile*flute;var bend=new Vector2((float)Math.Sin(phase),(float)Math.Cos(phase))*(float)height*.012f*(float)Math.Sin(Math.PI*t);
                var point=floor_point+new Vector3((float)(Math.Cos(angle)*r+bend.X),(float)(height*t),(float)(Math.Sin(angle)*r+bend.Y));point.Y=(float)(point.Y+((double)foot[i].Y-floor_point.Y)*Math.Pow(1-t,3)+((double)crown[i].Y-ceiling.Y)*Math.Pow(t,3));ring[i]=point;
            }
            if(j>0)for(int i=0;i<14;i++){int n=(i+1)%14;var outward=new Vector3((float)Math.Cos((i+.5)*Math.Tau/14),0,(float)Math.Sin((i+.5)*Math.Tau/14));triangle(previous[i],ring[i],ring[n],outward,tint);triangle(previous[i],ring[n],previous[n],outward,tint);}previous=ring;
        }
    }
    private A Arrays(){var arrays=new A();if(_vertices.Count>0){arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices;arrays[(int)Mesh.ArrayType.Normal]=normals;arrays[(int)Mesh.ArrayType.Color]=colors;}return arrays;}
    public D build(GodotObject field,Vector3I key,long seed_id,int geology)=>build(field,key,seed_id,geology,1);
    public D build(GodotObject field,Vector3I key,long seed_id,int geology,double density)
    {
        _vertices.Clear();_normals.Clear();_colors.Clear();origin=(Vector3)key*64;var placements=new A();var statistics=new D {["candidates"]=0,["floors"]=0,["ceilings"]=0,["owned"]=0,["protected"]=0};
        if(density<=0||field==null||geology is not(0 or 2 or 3 or 5))return new D {["arrays"]=new A(),["placements"]=placements};if(geology==5)density*=.3;
        for(int z=0;z<4;z++)for(int x=0;x<4;x++)
        {
            var cell=new Vector3I(key.X*4+x,key.Y,key.Z*4+z);if(random(cell,seed_id,1)>Math.Clamp(density*.72,0,1))continue;Increment("candidates");
            var p=new Vector3((float)((cell.X+.25+random(cell,seed_id,2)*.5)*16),origin.Y,(float)((cell.Z+.25+random(cell,seed_id,3)*.5)*16));var previous=p;previous.Y-=2;double previousValue=Sample(field,previous);
            for(int station=0;station<34;station++)
            {
                p.Y=origin.Y+station*2;double value=Sample(field,p);
                if(previousValue>=0&&value<0)
                {
                    var floorPoint=boundary(field,previous,p);var ceiling=ceiling_at(field,floorPoint);Increment("floors");if(ceiling.IsFinite())Increment("ceilings");
                    if(ceiling.IsFinite()&&floorPoint.Y>=origin.Y-.0001&&floorPoint.Y<origin.Y+64-.0001&&(double)ceiling.Y-floorPoint.Y>3&&field.Get("height").AsCallable().Call(floorPoint.X,floorPoint.Z).AsDouble()-floorPoint.Y>8)
                    {
                        Increment("owned");double radius=.45+random(cell,seed_id,5)*1.9,height=Math.Min(1.2+random(cell,seed_id,6)*7.5,((double)ceiling.Y-floorPoint.Y)*.55),up=random(cell,seed_id,7)<.6?1:-1;var root=up>0?floorPoint:ceiling;double tip=root.Y+up*height,phase=random(cell,seed_id,8)*Math.Tau;bool joined=random(cell,seed_id,9)<.10&&(double)ceiling.Y-floorPoint.Y<32&&(double)ceiling.Y-floorPoint.Y>6;
                        if(field.HasMethod("biome_weights_at")&&random(cell,seed_id,55001)<field.Call("biome_weights_at",root,new A {"magma"}).AsVector4().X){previous=p;previousValue=value;continue;}
                        bool flowing=geology is 0 or 2&&random(cell,seed_id,10)<.16,breakdown=geology==3;
                        if(flowing||breakdown){joined=false;root=floorPoint;up=1;radius=(breakdown?2.0:1.4)+random(cell,seed_id,11)*(breakdown?2.2:1.9);height=(breakdown?1.0:.5)+random(cell,seed_id,12)*(breakdown?2.5:1.6);tip=root.Y+height;}
                        if(joined){root=floorPoint;up=1;height=(double)ceiling.Y-floorPoint.Y;tip=ceiling.Y;}double extent=radius*1.15+height*.025;
                        if(!@protected(field,root,extent,Math.Min(root.Y,tip)-.9,Math.Max(root.Y,tip)+.9)&&placements.Count<48)
                        {
                            var foot=contacts(field,root,radius,up,phase,height);if(foot.Length==0){previous=p;previousValue=value;continue;}var attachments=new A {foot};
                            if(joined){var crown=contacts(field,ceiling,radius,-1,phase,height);if(crown.Length==0){previous=p;previousValue=value;continue;}column(floorPoint,ceiling,radius,phase,foot,crown);attachments.Add(crown);}else growth(root,radius,height,up,phase,foot,flowing,breakdown);
                            placements.Add(new D {["root"]=root,["radius"]=extent,["height"]=height,["up"]=up,["kind"]=joined?"column":flowing?"flowstone":breakdown?"breakdown":up>0?"stalagmite":"stalactite",["owner"]=key,["attachments"]=attachments});
                        }
                        else Increment("protected");
                    }
                }
                previous=p;previousValue=value;
            }
        }
        return new D {["arrays"]=Arrays(),["placements"]=placements,["statistics"]=statistics};
        void Increment(string name)=>statistics[name]=statistics[name].AsInt64()+1;
    }
    public A join(A basis,A extra)
    {
        if(extra.Count==0)return basis;if(basis.Count==0)return extra;var result=basis.Duplicate();
        foreach(int slot in new[]{(int)Mesh.ArrayType.Vertex,(int)Mesh.ArrayType.Normal})result[slot]=basis[slot].AsVector3Array().Concat(extra[slot].AsVector3Array()).ToArray();result[(int)Mesh.ArrayType.Color]=basis[(int)Mesh.ArrayType.Color].AsColorArray().Concat(extra[(int)Mesh.ArrayType.Color].AsColorArray()).ToArray();return result;
    }
}
