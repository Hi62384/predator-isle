using Godot;
using System;

namespace PredatorIsle.Biomes;
public partial class WiseMountainsSampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Sandstone pillar forest","Granite peaks","Limestone tower karst","Weathered highlands","Mountain labyrinth","Open river valley"};
    private GodotObject Owner()=>Host!.GetRef().AsGodotObject();
    private double Spacing()=>4000/Math.Max(Owner().Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),.01);
    public Vector4 tributary(Vector2 p)
    {
        double spacing=Spacing();long index=(long)Math.Round(p.X/4096.0,MidpointRounding.AwayFromZero),lane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);double x=index*4096+Math.Sin(index*1.7+seed_value)*180,lateral=Math.Abs(p.X-x);
        if(lateral>70)return Vector4.Zero;
        double outlet=Owner().Call("_grass_river_center",x,lane,spacing).AsDouble(),side=random(index,lane,921)>.5?1:-1,t=(p.Y-outlet)*side/1000,support=(1-Smooth(14,38,lateral))*Smooth(.025,.12,t)*(1-Smooth(.94,1,t));
        return new Vector4((float)(4+8*t+34*Smooth(.488,.512,t)),(float)support,(float)t,(float)x);
    }
    public override double[] evaluate(Vector2 p,int id)
    {
        double width=P("pillar_width")*P("feature_scale");var warp=p+new Vector2((float)macro(p+new Vector2(39,887)),(float)macro(p+new Vector2(1771,13)))*(float)width*1.7f;
        double a=Math.Abs(Math.Sin(warp.X/(width*1.5)+noise(p*.4f)*.5)),b=Math.Abs(Math.Sin((warp.Y+warp.X*.23)/(width*1.2))),joint=Math.Min(a,b),column=Smooth(.10,.24,joint);
        double uplift=P("pillar_height")*(.5+macro(p*.8f)*.8+noise(p*.25f)*.3),h=55+macro(p)*35,peak=0;
        switch(id)
        {
            case 0:peak=column*uplift*(.88+noise(p*.35f)*.08)+column*noise(p*2.2f)*12;break;
            case 1:peak=Math.Pow(1-Math.Abs(macro(p*1.5f)),4)*uplift*(.6+Math.Abs(noise(p*.5f)));break;
            case 2:peak=Math.Pow(Smooth(.17,.53,a*b),.45)*uplift*.7;break;
            case 3:peak=(.3+macro(p*.6f))*.6*uplift+noise(p*.4f)*50;break;
            case 4:peak=Smooth(.08,.23,joint)*uplift*.8;break;
            case 5:peak=column*uplift*Smooth(.3,.8,Math.Abs(macro(p*.7f)));break;
        }
        double spacing=Spacing();long lane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);double distance=Math.Abs(p.Y-Owner().Call("_grass_river_center",p.X,lane,spacing).AsDouble()),valley=1-Smooth(80,id is 2 or 5?520:180,distance);
        h+=peak;h=Lerp(h,10+noise(p)*1.4,valley);h=Lerp(h,-3,1-Smooth(25,50,distance));h+=(1-valley)*column*(Math.Sin(p.Y/67.0+Math.Sin(p.X/370.0)*.6)*4+noise(p*2.7f)*7);
        var stream=tributary(p);double water=4*(1-Smooth(90,170,distance));if(stream.Y>0){h=Lerp(h,Math.Min(h,(double)stream.X-3),stream.Y);water=Math.Max(water,(double)stream.X*stream.Y);}
        return new[]{h,water,Math.Clamp(.4+Math.Max(valley,stream.Y)*.6,0,1),0,column};
    }
}
