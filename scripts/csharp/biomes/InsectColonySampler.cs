using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class InsectColonySampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Cathedral territory","Ant earthworks","Magnetic clay mounds","Dome nest plains","Abandoned colony","Rocky colony highlands"};
    public Godot.Collections.Array<Vector2> satellites(D d)
    {
        var sites=new Godot.Collections.Array<Vector2>();for(int i=0;i<4;i++){double a=d["angle"].AsDouble()+i*1.57+.25*Math.Sin(i*7+d["age"].AsDouble());sites.Add(d["position"].AsVector2()+new Vector2((float)Math.Cos(a),(float)Math.Sin(a))*(float)d["radius"].AsDouble()*(float)(.55+i*.17));}return sites;
    }
    public override double[] evaluate(Vector2 p,int id)
    {
        var d=nearby(p,2100*P("feature_scale"));var q=local(p,d);double r=new Vector2(q.X,q.Y*(id==2?2:1)).Length()/d["radius"].AsDouble(),foundation=1-Smooth(.15,.9,r),excavation=Math.Exp(-Math.Pow((r-.94)/.24,2))*P("excavation_strength"),path=0,satellite=0;
        foreach(var site in satellites(d)){var distance=segment(p,d["position"].AsVector2(),site);path=Math.Max(path,1-Smooth(12,36,distance.X));satellite=Math.Max(satellite,1-Smooth(28,110,p.DistanceTo(site)));}
        double h=65+macro(p)*new[]{35,20,30,18,45,230}[id]+noise(p)*2;h+=foundation*(id is 1 or 3?40:18)+satellite*12+excavation*10-path*2;if(id==1)h-=Math.Exp(-Math.Pow(r/.2,2))*28;if(id==4)h-=foundation*8;
        double water=0;if(id==4&&d["chance"].AsDouble()<P("water_frequency")){water=48*(1-Smooth(.35,.8,r));h=Lerp(h,40,foundation);}return new[]{h,water,.2+d["age"].AsDouble()*.3,0,Math.Clamp(foundation+satellite*.7+path*.6,0,1)};
    }
}
