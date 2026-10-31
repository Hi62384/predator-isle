using Godot;
using System;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class RadiationWastelandSampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Barren exclusion plains","Ancient blast scars","Vitrified event ground","Mineralized highlands","Fallout dust lobes","Dry mineral lakebeds"};
    private static readonly double[] Heights={30,60,25,230,25,12},Details={1,4,2,8,1,.5};
    public D source_field(Vector2 p)
    {
        var d=nearby(p,4400*P("feature_scale"));var wind=settings.Get("fallout_wind").AsVector2();float angle=-(float)Math.Atan2(wind.Y,wind.X),sine=(float)Math.Sin(angle),cosine=(float)Math.Cos(angle);var delta=p-d["position"].AsVector2();var q=new Vector2(delta.X*cosine-delta.Y*sine,delta.X*sine+delta.Y*cosine);
        double radius=d["radius"].AsDouble(),r=q.Length()/radius,deposition=Math.Exp(-Math.Pow(q.X/(radius*2.2),2)-Math.Pow(q.Y/(radius*.5),2))*Smooth(-radius*.2,radius*.4,q.X);
        return new D {["id"]=d["id"],["age"]=d["age"],["radius"]=r,["kind"]=d["kind"],["contamination"]=Math.Clamp((Math.Exp(-r*r)*.6+deposition*.4)*(1-d["age"].AsDouble()*P("weathering")*.65),0,1),["damage"]=d["chance"].AsDouble()<P("catastrophe_frequency")?Variant.From(1-Smooth(.9,1.35,r)):Variant.From(0L),["deposition"]=deposition,["descriptor"]=d};
    }
    public Vector3 drainage(Vector2 p)
    {
        var host=Host!.GetRef().AsGodotObject();double spacing=4000/Math.Max(host.Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),.01);long lane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);
        double rootX=Math.Round(p.X/2400.0,MidpointRounding.AwayFromZero)*2400,rootZ=host.Call("_grass_river_center",rootX,lane,spacing).AsDouble(),side=Math.Sign(p.Y-rootZ);var root=new Vector2((float)rootX,(float)rootZ);double distance=double.PositiveInfinity,grade=0;
        for(int branch=0;branch<3;branch++){var tip=root+new Vector2((branch-1)*650,(float)(side*(1300+branch*280)));var near=segment(p,root,tip);if(near.X<distance){distance=near.X;grade=near.Y*80.0+6;}}
        return new Vector3((float)distance,(float)grade,(float)(1-Smooth(20,200,distance)));
    }
    public override double[] evaluate(Vector2 p,int id)
    {
        var s=source_field(p);var d=s["descriptor"].AsGodotDictionary();var q=local(p,d);double r=s["radius"].AsDouble()*(1+.08*Math.Sin((float)Math.Atan2(q.Y,q.X)*3.0+d["angle"].AsDouble())),damage=s["damage"].AsDouble(),h=70+macro(p)*Heights[id]+noise(p)*Details[id];
        if(id is 1 or 2){double bowl=1-Smooth(.15,.95,r),rim=Smooth(.65,.92,r)*(1-Smooth(.94,1.2,r));h+=damage*P("crater_depth")*(-bowl+rim*.24)*(1-d["age"].AsDouble()*.25);}
        if(id==3)h+=Math.Pow(1-Math.Abs(macro(p*.6f)),4)*180;if(id==4)h+=s["deposition"].AsDouble()*8;if(id==5)h=Lerp(h,26+noise(p)*.7,1-Smooth(.45,1.4,r));
        var channel=drainage(p);double cut=(1-Smooth(16,160,channel.X))*P("drainage_strength")*(.25+d["age"].AsDouble()*.75);h=Lerp(h,Math.Min(h,channel.Y+Math.Pow(channel.X/160.0,1.4)*100),cut);h+=channel.Z*(1-cut)*s["deposition"].AsDouble()*2;
        double water=0;if(id is 1 or 5&&d["chance"].AsDouble()<P("water_frequency"))water=(id==5?30:70-P("crater_depth")*.65)*(1-Smooth(.75,1.2,r));return new[]{h,water,.15+Math.Max(0,water-h)*.02,0,id<3?damage:s["deposition"].AsDouble()};
    }
    public override D describe(Vector2 p)
    {var result=base.describe(p);var source=source_field(p);result["contamination"]=source["contamination"];result["physical_damage"]=source["damage"];result["fallout_deposition"]=source["deposition"];result["drainage_distance"]=drainage(p).X;return result;}
}
