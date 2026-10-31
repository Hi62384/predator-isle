using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Biomes;
public partial class BeachSampler : RefCounted
{
    public Godot.Collections.Array NAMES {get;}=new() {"wide_beach","narrow_beach","dune_field","high_foredunes","backdunes","parabolic_dunes","sandy_cove","barrier_beach","sand_spit","lagoon","tidal_flat","sandy_estuary","low_sandy_island","storm_scarps","mixed_rock_sand","sandbars"};
    public Resource settings {get;set;}=null!;
    private WeakRef? _coast;
    private readonly FastNoiseLite _wind=new();
    private readonly Dictionary<Vector2I,double> _shoreNodes=new();
    private readonly Dictionary<Vector2I,double[]> _shorePatches=new();
    private GodotObject Coast()=>_coast!.GetRef().AsGodotObject();
    private double P(string key)=>settings.Get(key).AsDouble();
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static Vector2 FromAngle(double value){float angle=(float)value;return new Vector2((float)Math.Cos(angle),(float)Math.Sin(angle));}
    public void configure(Resource config,RefCounted coast)
    {settings=config;_coast?.Dispose();_coast=GodotObject.WeakRef(coast);_wind.Seed=unchecked((int)(coast.Get("seed_value").AsInt64()+61441));_wind.Frequency=(float)(1.0/9000);_wind.FractalOctaves=2;}
    public double wind_angle(Vector2 p)=>P("wind_degrees")*(Math.PI/180)+P("wind_variation")*(Math.PI/180)*Math.Sin(p.X/18000.0+Math.Sin(p.Y/21000.0));
    public double _shore_node(Vector2I cell)
    {
        if(_shoreNodes.TryGetValue(cell,out double value))return value;var host=Coast().Get("_host").As<WeakRef>().GetRef().AsGodotObject();var p=(Vector2)cell*256;value=host.Call("_island_mask",p.X,p.Y).AsDouble()*Math.Max(host.Get("settings").AsGodotObject().Get("island_size").AsDouble()*.5,8);if(_shoreNodes.Count>=4096)_shoreNodes.Clear();_shoreNodes[cell]=value;return value;
    }
    public double shore_distance(Vector2 p)
    {
        var q=p/256;var cell=new Vector2I((int)Math.Floor(q.X),(int)Math.Floor(q.Y));var f=q-(Vector2)cell;
        if(!_shorePatches.TryGetValue(cell,out var coefficients))
        {
            var coast=Coast();var rows=new double[4][];
            for(int z=-1;z<3;z++)rows[z+1]=coast.Call("polynomial",_shore_node(cell+new Vector2I(-1,z)),_shore_node(cell+new Vector2I(0,z)),_shore_node(cell+new Vector2I(1,z)),_shore_node(cell+new Vector2I(2,z))).AsFloat64Array();
            coefficients=new double[16];for(int i=0;i<4;i++){var column=coast.Call("polynomial",rows[0][i],rows[1][i],rows[2][i],rows[3][i]).AsFloat64Array();for(int j=0;j<4;j++)coefficients[i*4+j]=column[j];}if(_shorePatches.Count>=2048)_shorePatches.Clear();_shorePatches[cell]=coefficients;
        }
        double result=0;for(int i=3;i>=0;i--){int k=i*4;result=result*f.X+coefficients[k]+f.Y*(coefficients[k+1]+f.Y*(coefficients[k+2]+f.Y*coefficients[k+3]));}return result;
    }
    public double[] evaluate(Vector2 p,Vector3 frame,float[] weights,double a,double b,double c,double river_distance)
    {
        Span<double> w=stackalloc double[16];for(int i=0;i<16;i++)w[i]=weights[i];var coast=Coast();var n=new Vector2(frame.Y,frame.Z);double selector=_wind.GetNoise2D(p.X,p.Y)*.5+.5,coverage=P("coverage"),amount=1-Smooth(coverage-.12,coverage+.12,selector);if(coverage>=.999)amount=1;if(coverage<=0)amount=0;
        int id=0;for(int i=1;i<16;i++)if(w[i]>w[id])id=i;amount*=1-w[14]*Smooth(-.25,.45,b)*.85;
        double width=P("beach_width")*(1+P("width_variation")*(a*.7+w[0]*1.4-w[1]*.7+w[10]*1.7-w[6]*.3)),duneCountry=Math.Clamp(w[2]+w[3]+w[4]+w[5]+w[13]*.7,0,1)*P("dune_frequency"),flat=w[10]*P("tidal_flat_frequency"),barrier=(w[7]+w[9])*P("barrier_frequency"),lagoon=w[9]*P("lagoon_frequency");
        var wind=FromAngle(wind_angle(p));double alignment=wind.Dot(n),exposure=Math.Clamp(.5-.35*n.Dot(new Vector2(.8f,-.6f))+a*.1-w[6]*.2,0,1),shift=a*80*P("shoreline_irregularity")+w[6]*b*160,spit=w[8]*P("spit_frequency")*Smooth(-.1,.35,b);shift+=spit*(160+100*a);
        double d=shore_distance(p)+shift,slope=P("beach_slope")*(1+w[1]*1.8-w[0]*.4-flat*.85),beach=d*slope;if(d<0)beach=d*(.035-flat*.025)+Math.Max(d+600,0)*.001;double upper=width*slope;if(d>width)beach=upper+(d-width)*.008;
        double berm=P("berm_height")*Math.Exp(-Math.Pow((d-width*.72)/(35+width*.12),2))*(.65+.35*b)*(1-flat);beach+=berm;
        double crest=width+P("foredune_width")*(.9+a*.35+b*.1*P("crest_irregularity")),q=d-crest,scale=P("foredune_width")*(1+P("asymmetry")*alignment*(q<0?.35:-.35)),fore=Math.Exp(-Math.Pow(q/Math.Max(scale,80),2)),height=P("foredune_height")*(.55+w[3]*1.5+w[5]*.5)*(1+a*.25+b*.15);
        double blow=(1-Smooth(.05,.45,Math.Abs(coast.Get("_meso").As<FastNoiseLite>().GetNoise2D((float)(p.X*.4+921),(float)(p.Y*.4-317)))))*P("blowouts")*(w[2]+w[5]+w[13]);fore*=1-blow*.65;double dunes=fore*height;
        for(int k=1;k<4;k++){double center=crest+k*P("foredune_width")*(1.7+k*.17+a*.35),ridge=Math.Exp(-Math.Pow((d-center)/(P("foredune_width")*(.8+k*.15)),2));dunes+=ridge*height*(.65/k)*P("secondary_dunes")*(.7+b*.25)*(1-blow*.4);}
        double back=Smooth(crest,crest+400,d)*(1-Smooth(1500,2300,d));dunes+=back*P("backdune_relief")*height*(.5+a*.3+b*.2);
        var prevailing=FromAngle(P("wind_degrees")*(Math.PI/180));double along=p.Dot(new Vector2(-prevailing.Y,prevailing.X))/700.0+a*.6,arm=Math.Abs(Math.Sin(along+b*.3)),parabola=crest+350+arm*arm*450;dunes+=w[5]*height*.8*Math.Exp(-Math.Pow((d-parabola)/180,2))*Smooth(.2,.65,arm);
        double storm=w[13]*P("storm_erosion")*Smooth(-.2,.3,b),scarpWidth=Math.Max(scale*1.8,height*4);dunes*=Lerp(1,Smooth(crest-scarpWidth*.75,crest+scarpWidth*.25,d),storm);beach+=dunes*duneCountry;
        beach+=Math.Exp(-Math.Pow((d-width*.95)/100,2))*Math.Max(b+c*.3,0)*3*duneCountry;double basin=(barrier+lagoon)*Math.Exp(-Math.Pow((d-width-420)/(260+lagoon*180),2)),inlet=(1-Smooth(.035,.12,Math.Abs(b)))*Math.Max(barrier,flat);beach=Lerp(beach,-1.5,Math.Clamp(Math.Max(basin,inlet*(1-Smooth(width+700,width+1000,d))),0,1));
        double riverBank=100+height*(1+P("secondary_dunes"))*4*duneCountry,river=1-Smooth(18,riverBank,river_distance),channel=Math.Max(river,(1-Smooth(.02,.10,Math.Abs(b+c*.1)))*flat);beach=Lerp(beach,-1.6+Math.Max(d,0)*.0008,channel*(1-Smooth(1300,2100,Math.Max(d,0))));
        double slack=w[4]*back*(1-Smooth(.03,.3,Math.Abs(a)));beach=Lerp(beach,2,slack);double bar=Math.Exp(-Math.Pow((d+200+a*80)/(80+flat*150),2))*(.4+.6*Smooth(-.3,.3,b))*P("sandbar_frequency")*(w[15]+w[0]*.4+flat*.5);if(d<0)beach+=bar*6;
        double rangeWidth=Math.Max(2500,crest+1600);amount*=1-Smooth(rangeWidth*.68,rangeWidth,Math.Abs(d));double sediment=Math.Clamp(w[14]+w[1]*.4+w[11]*.6,0,1);return new[]{beach,amount,(double)id/15,exposure,sediment,width,fore,back,blow,slack,basin,bar,channel,(double)wind.X,wind.Y,storm,spit};
    }
    internal int ShoreNodeCount=>_shoreNodes.Count;
    internal int ShorePatchCount=>_shorePatches.Count;
}
