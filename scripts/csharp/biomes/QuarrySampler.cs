using Godot;
using System;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class QuarrySampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Exposed granite plains","Limestone benches","Slate highlands","Sandstone excavation","Basalt bedrock","Gravel basins"};
    private readonly Dictionary<string,D> _rampPlans=new();
    internal int RampPlanCount=>_rampPlans.Count;
    private static readonly double[] Relief={45,90,240,130,170,15};
    public override void configure(Resource config,long seed_id,RefCounted host,long family_id)
    {_rampPlans.Clear();base.configure(config,seed_id,host,family_id);}
    private static Vector2 Rotate(Vector2 p,double value)
    {float angle=(float)value,sine=(float)Math.Sin(angle),cosine=(float)Math.Cos(angle);return new Vector2(p.X*cosine-p.Y*sine,p.X*sine+p.Y*cosine);}
    private static double Angle(Vector2 p)=>(float)Math.Atan2(p.Y,p.X);
    public D ramp_plan(D d)
    {
        string id=d["id"].AsString();if(_rampPlans.TryGetValue(id,out var cached))return cached;var plan=new D();double radius=d["radius"].AsDouble();
        if(d["kind"].AsInt64()%2==0&&d["chance"].AsDouble()<=P("excavation_frequency"))
        {
            double angle=d["angle"].AsDouble(),factor=1+.08*Math.Sin(-Math.PI*3+angle)+.05*Math.Sin(-Math.PI*7+.4);var position=d["position"].AsVector2();var start=position+Rotate(new Vector2((float)(-.22*radius*factor),0),angle);var end=position+Rotate(new Vector2((float)(-1.3*radius*factor),0),angle);
            double low=base.sample(start.X,start.Y,false),high=base.sample(end.X,end.Y,false);int turns=Math.Max(1,(int)Math.Ceiling(Math.Abs(high-low)/Math.Max(P("ramp_grade")*.55*Math.Tau*.22*radius/1.25,.001)));double width=Math.Min(48,radius*1.08/turns*.32),span=3200*P("feature_scale"),required=1.3*1.13*radius+width*1.35+16;bool clearance=true;var cell=new Vector2I((int)Math.Floor(position.X/span),(int)Math.Floor(position.Y/span));
            for(int dz=-2;dz<=2;dz++)for(int dx=-2;dx<=2;dx++){if(dx==0&&dz==0)continue;var other=descriptor(cell+new Vector2I(dx,dz),span);if(position.DistanceTo(other["position"].AsVector2())<required*2)clearance=false;}
            if(turns<=12&&width>=24&&clearance)plan=new D {["start"]=start,["end"]=end,["low"]=low,["high"]=high,["turns"]=turns,["half_width"]=width};
        }
        if(_rampPlans.Count>=256)_rampPlans.Clear();_rampPlans[id]=plan;return plan;
    }
    public override double sample(double x,double z,bool publish)
    {
        double h=base.sample(x,z,publish);var p=new Vector2((float)x,(float)z);var d=nearby(p,3200*P("feature_scale"));var q=local(p,d);double sourceRadius=d["radius"].AsDouble();
        if(q.Length()<sourceRadius*1.65)
        {
            var plan=ramp_plan(d);if(plan.Count>0)
            {
                double angle=Angle(q),radius=sourceRadius*(1+.08*Math.Sin(angle*3+d["angle"].AsDouble())+.05*Math.Sin(angle*7+.4)),r=new Vector2(q.X,(float)((double)q.Y*1.25)).Length()/radius,angleT=(angle+Math.PI)/Math.Tau,best=0,target=h;int turns=plan["turns"].AsInt32();double width=plan["half_width"].AsDouble();
                for(int turn=-1;turn<=turns;turn++)
                {
                    double t=(turn+angleT)/turns,pathRadius=.22+1.08*t,cap=width/Math.Max(turns*Math.Tau*.22*sourceRadius,.001),influence=(1-Smooth(width,width*1.35,Math.Abs(r-pathRadius)*radius))*Smooth(-cap,0,t)*(1-Smooth(1,1+cap,t));
                    if(influence>best){best=influence;target=Lerp(plan["low"].AsDouble(),plan["high"].AsDouble(),Math.Clamp(t,0,1));}
                }
                h=Lerp(h,target,best);
            }
        }
        if(publish)state[0]=h;return h;
    }
    public double terraces(double t,double age)
    {
        double q=Math.Clamp(t,0,1),result=0;int count=Math.Clamp((int)Math.Round(P("pit_depth")/Math.Max(P("bench_height"),10),MidpointRounding.AwayFromZero),3,10);
        for(int i=1;i<=count;i++){double threshold=(double)i/(count+1)+.024*Math.Sin(i*2.31);result+=Smooth(threshold-.012-age*.012,threshold+.012+age*.018,q)/count;}return result;
    }
    public override double[] evaluate(Vector2 p,int id)
    {
        var d=nearby(p,3200*P("feature_scale"));var q=local(p,d);double age=d["age"].AsDouble()*P("weathering"),natural=280+macro(p)*100+Math.Pow(1-Math.Abs(macro(p*.7f+new Vector2(710,49))),3)*Relief[id]+noise(p)*6,angle=Angle(q);
        double radius=d["radius"].AsDouble()*(1+.08*Math.Sin(angle*3+d["angle"].AsDouble())+.05*Math.Sin(angle*7+.4)),r=new Vector2(q.X,(float)((double)q.Y*1.25)).Length()/radius,excavation=1-Smooth(.95,1.25,r);if(d["chance"].AsDouble()>P("excavation_frequency"))excavation=0;
        double depth=P("pit_depth")*(.55+d["age"].AsDouble()*.8);var position=d["position"].AsVector2();double roof=280+macro(position)*100+Math.Pow(1-Math.Abs(macro(position*.7f+new Vector2(710,49))),3)*60,level=Math.Max(25,roof-depth),bench=terraces((r-.18)/.85,age),floor=level+noise(p)*2+(macro(p*2)+.5)*3,cut=floor+bench*depth,h=Lerp(natural,Math.Min(natural,cut),excavation),water=0;
        if(d["chance"].AsDouble()<P("water_frequency")&&excavation>0)water=(level+depth*.15)*(1-Smooth(.84,1.1,r));return new[]{h,water,Math.Clamp(.25+excavation*.4,0,1),0,excavation};
    }
}
