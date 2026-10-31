using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class VolcanicSampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Shield volcano","Stratovolcano","Collapse caldera","Cinder fields","Hardened lava plains","Ancient rift highlands"};
    public override double[] evaluate(Vector2 p,int id)
    {
        double span=(id<3?7200:2600)*P("feature_scale");var d=nearby(p,span);var q=local(p,d);
        double radius=d["radius"].AsDouble()*(1+noise(p*.25f)*.12),r=new Vector2(q.X,(float)((double)q.Y*.88)).Length()/radius,angle=(float)Math.Atan2(q.Y,q.X),age=d["age"].AsDouble()*P("weathering");
        double height=P("volcano_height")*(.65+d["age"].AsDouble()*.5),edifice=0,crater=0;
        switch(id)
        {
            case 0:edifice=height*Math.Pow(Math.Max(0,1-r*.45),2)*.65;crater=(1-Smooth(.12,.3,r))*height*.18;break;
            case 1:edifice=height*Math.Pow(Math.Max(0,1-r*.7),1.25);crater=(1-Smooth(.1,.26,r))*height*.32;break;
            case 2:edifice=height*.65*(1-Smooth(.9,1.5,r));crater=height*.5*(1-Smooth(.61,.79,r));break;
            case 3:edifice=height*.18*Math.Pow(Math.Max(0,1-r),1.1);crater=height*.075*(1-Smooth(.12,.28,r));break;
            case 4:edifice=22+macro(p)*38;break;
            case 5:edifice=height*.25*Math.Pow(1-Math.Abs(macro(p)),3);break;
        }
        double drainage=Math.Pow(.5+.5*Math.Sin(angle*11+noise(p*.18f)*2),5)*Smooth(.28,.7,r)*(1-Smooth(1,1.6,r))*age;
        double flow=(1-Smooth(.09,.2,Math.Abs(Math.Sin(angle*3+Math.Sin(r*3)*.25+d["angle"].AsDouble()))))*Smooth(.2,.4,r)*(1-Smooth(1.2,1.8,r))*P("lava_coverage");
        double rough=Lerp(noise(p)*2,Math.Abs(noise(p*1.8f))*15,d["kind"].AsInt64()%2),h=45+macro(p)*35+edifice-crater-drainage*height*.12+flow*(8+rough);
        double chance=d["chance"].AsDouble(),active=P("active_frequency");if(id<3&&chance<active)h-=(1-Smooth(.05,.24,r))*Math.Min(height*.18,130);
        if(id==5)h-=35*(1-Smooth(40,130,Math.Abs(q.Y+Math.Sin(q.X/700.0)*130)));
        double water=0;if(chance<P("water_frequency")&&chance>=active&&id==2)water=(45+height*.23)*(1-Smooth(.82,1.05,r));
        return new[]{h,water,Math.Clamp(age*.7,0,1),0,flow};
    }
    public D active_lava_descriptor(Vector2 p)
    {
        var d=nearby(p,7200*P("feature_scale"));return new D {["source"]=d["id"],["position"]=d["position"],["eligible"]=d["chance"].AsDouble()<P("active_frequency"),["renderer_supported"]=true,["rendered"]="Only when a closed dry crater passes the feature mesher's bed/rim test",["kind"]="retained crater lava, not freshwater"};
    }
}

