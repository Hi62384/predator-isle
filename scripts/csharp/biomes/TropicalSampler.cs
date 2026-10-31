using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

namespace PredatorIsle.Biomes;
public partial class TropicalSampler : RefCounted
{
    public double STEP {get;}=16;
    public int CHANNELS {get;}=16;
    public A NAMES {get;}=new() {"Coastal lowland","Lush plain","Rolling hills","Rugged hills","Rocky highland","Mountain belt","River valley","Humid basin","Lake country","Ancient volcanic highland","Limestone highland","Plateau country","Ravine country","Coastal bluff","Uplifted terrace","Weathered escarpment"};
    public Resource settings {get;set;}=null!;
    public WeakRef? _host {get;set;}
    public long seed_value {get;set;}
    public FastNoiseLite _macro {get;}=new();
    public FastNoiseLite _hills {get;}=new();
    public FastNoiseLite _weather {get;}=new();
    private readonly Dictionary<Vector2I,double[]> _nodes=new();
    private readonly Dictionary<Vector2I,float[]> _regions=new();
    private readonly Dictionary<Vector2I,Vector3> _carriers=new();
    private readonly Dictionary<Vector2I,double> _structuralNodes=new(),_cascadeCache=new();
    public double[] state {get;set;}=System.Array.Empty<double>();
    public bool profile {get;set;}
    public D timings {get;set;}=new();
    private GodotObject Host()=>_host!.GetRef().AsGodotObject();
    private double P(string key)=>settings.Get(key).AsDouble();
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static Vector2I Cell(Vector2 p,double step)=>new((int)Math.Floor(p.X/step),(int)Math.Floor(p.Y/step));
    public void configure(Resource config,long world_seed,RefCounted host)
    {
        settings=config;seed_value=world_seed;_host?.Dispose();_host=GodotObject.WeakRef(host);var noises=new[]{_macro,_hills,_weather};int[] seeds={24101,24117,24139};double[] frequencies={1.0/6500,1/Math.Max(P("hill_width"),200),1.0/350};
        for(int i=0;i<3;i++){var n=noises[i];n.Seed=unchecked((int)(world_seed+seeds[i]));n.Frequency=(float)frequencies[i];n.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;n.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;n.FractalOctaves=2;n.FractalGain=.35f;}_nodes.Clear();_regions.Clear();_carriers.Clear();_structuralNodes.Clear();_cascadeCache.Clear();timings.Clear();
    }
    public double random(long x,long z,long salt){long h=unchecked(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (double)(h^(h>>16))/2147483647;}
    public float[] _region_node(Vector2I cell)
    {
        if(_regions.TryGetValue(cell,out var found))return found;var p=(Vector2)cell*512;double span=Math.Max(P("region_metres"),1000),closest=double.PositiveInfinity;var center=Cell(p,span);var sites=new List<(double Distance,int Kind)>();double[] occurrence={P("lowland_frequency")*.35,P("lowland_frequency"),P("hill_frequency"),P("hill_frequency")*.45,P("rocky_frequency"),P("mountain_frequency"),.3,P("basin_frequency"),.25,P("highland_frequency")*.6,P("rocky_frequency")*.4,P("plateau_frequency"),.15,.12,.12,P("highland_frequency")*.3};double mass=0;foreach(double v in occurrence)mass+=Math.Max(v,0);
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var q=center+new Vector2I(x,z);var site=((Vector2)q+new Vector2((float)(.15+random(q.X,q.Y,3)*.7),(float)(.15+random(q.X,q.Y,5)*.7)))*(float)span;double roll=random(q.X,q.Y,7)*mass;int id=1;
            if(mass>0)for(int i=0;i<16;i++){roll-=Math.Max(occurrence[i],0);if(roll<=0){id=i;break;}}
            if(id is 0 or 13 or 14){var host=Host();double coastDistance=Math.Abs(host.Call("_island_mask",site.X,site.Y).AsDouble()*host.Get("settings").AsGodotObject().Get("island_size").AsDouble()*.5);if(coastDistance>6000)id=id==0?1:id==13?4:11;}double d=p.DistanceTo(site);closest=Math.Min(closest,d);sites.Add((d,id));
        }
        var result=new float[16];double total=0;foreach(var site in sites){double amount=1-Smooth(0,span*.18,site.Distance-closest);result[site.Kind]=(float)(result[site.Kind]+amount);total+=amount;}for(int i=0;i<16;i++)result[i]=(float)(result[i]/Math.Max(total,.001));if(_regions.Count>=2048)_regions.Clear();_regions[cell]=result;return result;
    }
    public float[] region_weights(Vector2 p)
    {
        var q=p/512;var cell=Cell(q,1);var f=q-(Vector2)cell;var a=_region_node(cell);if(f==Vector2.Zero)return a;var b=_region_node(cell+Vector2I.Right);var c=_region_node(cell+Vector2I.Down);var d=_region_node(cell+Vector2I.One);if(a.SequenceEqual(b)&&a.SequenceEqual(c)&&a.SequenceEqual(d))return a;f=new Vector2((float)Smooth(0,1,f.X),(float)Smooth(0,1,f.Y));var result=new float[16];for(int i=0;i<16;i++)result[i]=(float)Lerp(Lerp(a[i],b[i],f.X),Lerp(c[i],d[i],f.X),f.Y);return result;
    }
    public double _spacing()=>4000/Math.Max(Host().Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),.01);
    public Vector3 _carrier(double x,long lane)
    {var key=new Vector2I(unchecked((int)x),unchecked((int)lane));bool exact=x==Math.Floor(x)&&Math.Abs(x)<2000000000;if(exact&&_carriers.TryGetValue(key,out var found))return found;var result=Host().Call("_river_column",x,lane,_spacing()).AsVector3();if(exact){if(_carriers.Count>=2048)_carriers.Clear();_carriers[key]=result;}return result;}
    public double water_potential(double x){double t=Mathf.PosMod(x+(seed_value%31)*139.0,18000)/18000;return 22+110*Math.Pow(Math.Sin(t*Math.PI),2);}
    public double cascade_height(long segment,long lane,double r)
    {
        if(P("waterfall_frequency")<=0||P("stream_frequency")<=0||P("river_frequency")<=0||r>P("waterfall_frequency")*P("stream_frequency")||random(lane,0,139)>P("river_frequency"))return 0;var key=new Vector2I(unchecked((int)segment),unchecked((int)lane));if(_cascadeCache.TryGetValue(key,out double found))return found;var center=cascade_point(segment,lane,.5);var w=region_weights(center);double rocky=(double)w[3]+w[4]+w[5]+w[9]+w[10]+w[12]+w[15],drop=0;if(rocky>.45&&Host().Call("_island_mask",center.X,center.Y).AsDouble()>.1)drop=P("waterfall_drop")*(.75+random(segment,lane,173)*.5);if(_cascadeCache.Count>=512)_cascadeCache.Clear();_cascadeCache[key]=drop;return drop;
    }
    public Vector2 cascade_point(long segment,long lane,double t)
    {double spacing=_spacing(),span=spacing*.6,r=random(segment,lane,131),x=(segment+.15+r*.3)*span+t*span*.7,side=random(segment,lane,137)<.5?-1:1;return new Vector2((float)x,(float)(_carrier(x,lane).X+side*spacing*.22*t*t));}
    public double cascade_rise(double t){double half=64/(_spacing()*.6*.7);return Smooth(.5-half,.5+half,t);}
    public double _structural_node(long index,long lane)
    {var key=new Vector2I(unchecked((int)index),unchecked((int)lane));if(_structuralNodes.TryGetValue(key,out double found))return found;double value=Host().Call("_grass_river_center",index*2048.0,lane,_spacing()).AsDouble();if(_structuralNodes.Count>=2048)_structuralNodes.Clear();_structuralNodes[key]=value;return value;}
    public double _structural_center(double x,long lane)
    {double q=x/2048;long index=(long)Math.Floor(q);return cubic(_structural_node(index-1,lane),_structural_node(index,lane),_structural_node(index+1,lane),_structural_node(index+2,lane),q-index);}
    public double[] _raw(Vector2 p)
    {
        long tick=profile?(long)Time.GetTicksUsec():0;var weights=region_weights(p);Span<double> w=stackalloc double[16];for(int i=0;i<16;i++)w[i]=weights[i];double a=_macro.GetNoise2D(p.X,p.Y),b=_hills.GetNoise2D(p.X,p.Y),c=_weather.GetNoise2D(p.X,p.Y),spacing=_spacing();var near=Vector3.Zero;long nearestLane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);double best=double.PositiveInfinity;
        for(int k=-1;k<=1;k++){long id=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero)+k;var candidate=_carrier(p.X,id);double d=Math.Abs((double)p.Y-candidate.X);if(d<best){best=d;near=candidate;nearestLane=id;}}
        double channelDistance=best/Math.Sqrt(1+(double)near.Y*near.Y),distance=Math.Abs(p.Y-_structural_center(p.X,nearestLane)),calm=Math.Clamp(w[0]+w[1]+w[6]*.7+w[7]*.8+w[8]*.65,0,1),rugged=Math.Clamp(w[3]+w[4]+w[5]+w[9]+w[10]*.8+w[12]+w[13]*.6+w[15],0,1),water=water_potential(p.X),h=water+30+a*18+(b*.5+.25)*P("hill_height")*(1-calm)*(1-rugged*.3),ridge=0,branches=0;
        if(rugged>.001)
        {
            for(int k=-1;k<=0;k++)
            {
                long id=nearestLane+k;double across=p.Y-(_structural_center(p.X,id)+_structural_center(p.X,id+1))*.5,width=Math.Max(500,P("hill_width")*(.6+w[9]*.6+w[4]*.2-w[10]*.25)),shape=Math.Exp(-Math.Pow(Math.Abs(across)/(width*(.9+b*.2)),1.8));long segment=(long)Math.Floor(p.X/4000.0);double summits=0;
                for(int j=-1;j<=1;j++){double r=random(segment+j,id,101),x=(segment+j+.2+r*.6)*4000;summits=Math.Max(summits,Math.Exp(-Math.Pow((p.X-x)/(850+r*900),2))*(.55+r*.55));}
                double phase=Mathf.PosMod(p.X-across*.5+b*180+id*317.0,2100),branch=Math.Exp(-Math.Pow(Math.Min(phase,2100-phase)/220,2))*shape*(1-Smooth(100,600,Math.Abs(across)));branches=Math.Max(branches,branch);ridge=Math.Max(ridge,shape*(.45+summits*.65));
            }
            double relief=P("hill_height")*(w[3]*1.1+w[4]*1.9+w[9]*2.6+w[10]*1.6+w[12]*1.8+w[13]+w[15]*1.7)+P("mountain_height")*w[5];h+=(ridge+branches*.14)*relief*P("ridge_strength");
        }
        double valleyWidth=P("valley_width")*(1+w[6]*.8+w[7]*.5-w[12]*.65),valley=1-Smooth(40,valleyWidth,distance);h=Lerp(h,water+5+b*2,valley*P("valley_depth"));double erosion=(1-Smooth(.025,.19,Math.Abs(c+b*.15)))*ridge*(1-valley*.8)*rugged*P("erosion");h-=erosion*(35+P("hill_height")*.12)*P("gullies");double shelf=Smooth(-.08,.17,b+a*.3);h+=shelf*(w[11]*150+w[14]*65+w[15]*120)*(1-valley)*P("weathering");double stream=0,lake=0,channel=0;
        bool rivers=P("river_frequency")>0&&Host().Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble()>0&&random(nearestLane,0,139)<=P("river_frequency");
        if(rivers)
        {
            double width=P("river_width")*(.7+w[6]+w[8]*.35)*(1+near.Z*.2),riverBank=1-Smooth(width*1.8,width*1.8+Math.Max(150,Math.Max(h-water,0)/.45),best);h=Lerp(h,Math.Min(h,water+5),riverBank);channel=1-Smooth(width*.4,width*1.8,channelDistance);h=Lerp(h,water-3,channel);
            if(P("stream_frequency")>0)
            {
                double span=spacing*.6;long segment=(long)Math.Floor(p.X/span);
                for(int j=-1;j<=1;j++)
                {
                    double r=random(segment+j,nearestLane,131);if(r>P("stream_frequency"))continue;double t=(p.X-(segment+j+.15+r*.3)*span)/(span*.7);if(t<=0||t>=1)continue;double side=random(segment+j,nearestLane,137)<.5?-1:1,across=Math.Abs((double)p.Y-near.X-side*spacing*.22*t*t),support=Smooth(0,.05,t)*(1-Smooth(.7,1,t)),fallHeight=cascade_height(segment+j,nearestLane,r),grade=water+t*t*(35+r*40)+fallHeight*cascade_rise(t),bankWidth=Math.Max(150,Math.Max(h-grade,0)/.45),bed=(1-Smooth(8,35,across))*support,bank=(1-Smooth(35,bankWidth,across))*support;
                    h=Lerp(h,Math.Min(h,grade+5),bank);h=Lerp(h,grade-1.8,bed);water=Lerp(water,grade,bank);stream=Math.Max(stream,bed);valley=Math.Max(valley,bank);double poolT=fallHeight>0?.4:.55;
                    if(r<P("basin_frequency")*P("stream_frequency")&&Math.Abs(t-poolT)<.4)
                    {
                        double cx=(segment+j+.15+r*.3)*span+poolT*span*.7,cy=_carrier(cx,nearestLane).X+side*spacing*.22*poolT*poolT;var q=new Vector2((float)((p.X-cx)/Math.Min(90+r*180,span*.16)),(float)((p.Y-cy)/(45+r*100)));double contour=q.Length()+Math.Sin(q.X*2.7+r*11)*.1,pool=1-Smooth(.5,1.25,contour),depth=1-Smooth(.25,.8,contour),level=water_potential(cx)+poolT*poolT*(35+r*40);h=Lerp(h,level+3-depth*7,pool);water=Lerp(water,level,pool);lake=Math.Max(lake,pool*depth);
                    }
                }
            }
        }
        if(P("lake_frequency")>0&&P("basin_frequency")>0&&w[7]+w[8]+w[6]>.1)
        {
            long segment=(long)Math.Floor(p.X/6000.0);for(int j=-1;j<=1;j++)
            {
                double r=random(segment+j,nearestLane,151);if(r>P("lake_frequency")*P("basin_frequency"))continue;double x=Math.Round((segment+j+.25+r*.5)*6000/16,MidpointRounding.AwayFromZero)*16,center=_carrier(x,nearestLane).X;var q=new Vector2((float)((p.X-x)/(450+r*1000)),(float)((p.Y-center)/(180+r*450)));double contour=q.Length()+Math.Sin(q.X*2.4+r*8)*.1+Math.Sin((double)q.Y*3)*.07,support=(1-Smooth(.85,1.45,contour))*Math.Clamp(w[7]+w[8]+w[6],0,1),bed=1-Smooth(.3,1,contour),level=water_potential(x)+3;h=Lerp(h,level+12-bed*(20+r*10),support);water=Lerp(water,level,support);lake=Math.Max(lake,bed*support);
            }
        }
        double wet=Math.Clamp(.25+valley*.45+Math.Max(channel,stream)*.3+lake*.4+w[7]*.2+w[6]*.1-ridge*.1,0,1),rock=Math.Clamp(rugged*.3+ridge*.4+erosion*.4+(w[4]+w[10]+w[15])*.2-valley*.3,0,1),red=Math.Clamp(w[9]+w[3]*.6+w[15]*.5+erosion*.4,0,1);int dominant=0;for(int i=1;i<16;i++)if(w[i]>w[dominant])dominant=i;if(profile)timings["raw_us"]=(timings.ContainsKey("raw_us")?timings["raw_us"].AsInt64():0)+(long)Time.GetTicksUsec()-tick;
        return new[]{h,water,wet,(double)dominant/15,rock,erosion,valley,Math.Clamp(ridge,0,1),Math.Max(channel,stream),lake,red,1-rock,stream,channel,shelf,branches};
    }
    public double[] _node(Vector2I cell){if(_nodes.TryGetValue(cell,out var found))return found;var result=_raw((Vector2)cell*16);if(_nodes.Count>=16384)_nodes.Clear();_nodes[cell]=result;return result;}
    public double cubic(double a,double b,double c,double d,double t)=>b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)));
    public double sample(double x,double z)=>sample(x,z,true);
    public double sample(double x,double z,bool publish)
    {
        var q=new Vector2((float)x,(float)z)/16;var cell=Cell(q,1);var f=q-(Vector2)cell;if(f==Vector2.Zero){var value=_node(cell);if(publish)state=value;return value[0];}Span<double> rows=stackalloc double[4],waters=stackalloc double[4];
        for(int j=-1;j<3;j++){var a=_node(cell+new Vector2I(-1,j));var b=_node(cell+new Vector2I(0,j));var c=_node(cell+new Vector2I(1,j));var d=_node(cell+new Vector2I(2,j));rows[j+1]=cubic(a[0],b[0],c[0],d[0],f.X);waters[j+1]=cubic(a[1],b[1],c[1],d[1],f.X);}double h=cubic(rows[0],rows[1],rows[2],rows[3],f.Y);
        if(publish){var a=_node(cell);var b=_node(cell+Vector2I.Right);var c=_node(cell+Vector2I.Down);var d=_node(cell+Vector2I.One);state=new double[16];state[0]=h;state[1]=cubic(waters[0],waters[1],waters[2],waters[3],f.Y);for(int k=2;k<16;k++)state[k]=Math.Clamp(Lerp(Lerp(a[k],b[k],f.X),Lerp(c[k],d[k],f.X),f.Y),0,1);}return h;
    }
    public void clear_numeric_caches(){_nodes.Clear();_regions.Clear();_carriers.Clear();_structuralNodes.Clear();_cascadeCache.Clear();}
    public D cache_counts()=>new() {["nodes"]=_nodes.Count,["regions"]=_regions.Count,["carriers"]=_carriers.Count,["structural_nodes"]=_structuralNodes.Count,["cascades"]=_cascadeCache.Count};
}
