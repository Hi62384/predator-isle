using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class BiomeExtensionSampler : RefCounted
{
    public Resource settings {get;set;}=null!;
    public long seed_value {get;set;}
    public long family {get;set;}
    public double[] state {get;set;}=new double[5];
    protected WeakRef? Host;
    private readonly Dictionary<Vector2I,double[]> _nodes=new();
    private readonly List<Vector2I> _ring=new();private int _cursor;
    private readonly Dictionary<Vector3I,D> _descriptors=new();
    private readonly FastNoiseLite _macro=new(),_meso=new(),_regions=new();
    private readonly Terrain.TerrainParameterSnapshot numericSettings=new();
    protected double P(string key)=>numericSettings[key];
    protected static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    protected static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    public virtual void configure(Resource config,long seed_id,RefCounted host,long family_id)
    {
        settings=config;numericSettings.Capture(config);seed_value=seed_id;family=family_id;Host?.Dispose();Host=GodotObject.WeakRef(host);
        var noises=new[]{_macro,_meso,_regions};var offsets=new[]{41011,41039,41077};var frequencies=new[]{1.0/2300,1.0/230,1.0/Math.Max(P("region_metres"),1000)};
        for(int i=0;i<3;i++){var n=noises[i];n.Seed=unchecked((int)(seed_id+offsets[i]+family*1009));n.Frequency=(float)frequencies[i];n.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;n.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;n.FractalOctaves=i<2?2:1;n.FractalGain=.32f;}
        _nodes.Clear();_descriptors.Clear();_ring.Clear();_cursor=0;
    }
    public double random(long x,long z,long salt){long h=unchecked(x*374761393+z*668265263+seed_value*69069+(salt+family*301)*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (double)(h^(h>>16))/2147483647.0;}
    public D descriptor(Vector2I cell,double span)
    {
        var key=new Vector3I(cell.X,cell.Y,(int)Math.Round(span,MidpointRounding.AwayFromZero));if(_descriptors.TryGetValue(key,out var found))return found;
        var p=((Vector2)cell+new Vector2((float)(.25+random(cell.X,cell.Y,1)*.5),(float)(.25+random(cell.X,cell.Y,2)*.5)))*(float)span;
        var result=new D {["id"]=FormattableString.Invariant($"{family}:{cell.X}:{cell.Y}"),["position"]=p,["radius"]=span*(.2+.18*random(cell.X,cell.Y,3)),["age"]=random(cell.X,cell.Y,4),["kind"]=Math.Min(5,(int)(random(cell.X,cell.Y,5)*6)),["angle"]=random(cell.X,cell.Y,6)*Math.Tau,["chance"]=random(cell.X,cell.Y,7)};
        if(_descriptors.Count>=512)_descriptors.Clear();_descriptors[key]=result;return result;
    }
    public D nearby(Vector2 p,double span)
    {
        var cell=new Vector2I((int)Math.Floor(p.X/span),(int)Math.Floor(p.Y/span));var best=new D();double distance=double.PositiveInfinity;
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++){var d=descriptor(cell+new Vector2I(x,z),span);double score=p.DistanceSquaredTo(d["position"].AsVector2());if(score<distance){distance=score;best=d;}}return best;
    }
    public Vector2 local(Vector2 p,D d)
    {
        var q=p-d["position"].AsVector2();float angle=(float)-d["angle"].AsDouble();
        // Match the engine's float-angle/double-trig/float-result path.
        // MathF trig differs by one ULP at some far descriptor angles.
        float sine=(float)Math.Sin(angle),cosine=(float)Math.Cos(angle);
        return new Vector2(q.X*cosine-q.Y*sine,q.X*sine+q.Y*cosine);
    }
    public Vector2 segment(Vector2 p,Vector2 a,Vector2 b){var ab=b-a;double t=Math.Clamp((p-a).Dot(ab)/Math.Max(ab.LengthSquared(),.001),0,1);return new Vector2(p.DistanceTo(a+ab*(float)t),(float)t);}
    public double noise(Vector2 p)=>_meso.GetNoise2Dv(p);
    public double macro(Vector2 p)=>_macro.GetNoise2Dv(p);
    public double region(Vector2 p)=>Math.Clamp((_regions.GetNoise2Dv(p)*.8+.5)*5,0,4.99999);
    public double sample(double x,double z)=>sample(x,z,true);
    public virtual double sample(double x,double z,bool publish)
    {
        var p=new Vector2((float)x,(float)z)/16;var cell=new Vector2I((int)Math.Floor(p.X),(int)Math.Floor(p.Y));var f=p-(Vector2)cell;
        if(f==Vector2.Zero){var value=_node(cell);if(publish)state=(double[])value.Clone();return value[0];}
        f=new Vector2((float)Smooth(0,1,f.X),(float)Smooth(0,1,f.Y));var a=_node(cell);var b=_node(cell+Vector2I.Right);var c=_node(cell+Vector2I.Down);var d=_node(cell+Vector2I.One);
        double h=Lerp(Lerp(a[0],b[0],f.X),Lerp(c[0],d[0],f.X),f.Y);if(publish){state=new double[5];state[0]=h;for(int i=1;i<5;i++)state[i]=Lerp(Lerp(a[i],b[i],f.X),Lerp(c[i],d[i],f.X),f.Y);}return h;
    }
    protected bool HasCachedNode(Vector2I cell)=>_nodes.ContainsKey(cell);
    public virtual double[] _node(Vector2I cell)
    {
        if(_nodes.TryGetValue(cell,out var found))return found;var p=(Vector2)cell*16;double r=region(p);int id=(int)Math.Floor(r);double f=Smooth(.25,.75,r-Math.Floor(r));var a=evaluate(p,id);var b=f>0?evaluate(p,Math.Min(id+1,5)):a;var value=new double[5];
        for(int i=0;i<5;i++)value[i]=Lerp(a[i],b[i],f);double relief=P("relief");value[0]*=relief;value[1]*=relief;value[3]=r/5;
        if(_ring.Count<8192)_ring.Add(cell);else{_nodes.Remove(_ring[_cursor]);_ring[_cursor]=cell;_cursor=(_cursor+1)%8192;}_nodes[cell]=value;return value;
    }
    public virtual double[] evaluate(Vector2 p,int id)=>new double[5];
    public virtual D describe(Vector2 p){sample(p.X,p.Y);return new D {["family"]=family,["height"]=state[0],["water_level"]=state[1],["wetness"]=state[2],["region"]=state[3]*5,["feature"]=state[4],["caves_supported"]=settings.Get("caves_enabled").AsBool()&&family is 1 or 2 or 6 or 7,["cave_placement"]="Finite dry-site portals only, not arbitrary heightfield excavation"};}
    internal int NodeCount=>_nodes.Count;
    internal int DescriptorCount=>_descriptors.Count;
}
