using Godot;
using System;

namespace PredatorIsle.Biomes;
public partial class CrystalWastesSampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Quartz plains","Amethyst highlands","Selenite blade wastes","Smoky crystalline ridges","Fluorite block country","Mineral basins"};
    public override double[] evaluate(Vector2 p,int id)
    {
        var d=nearby(p,1700*P("feature_scale"));var q=local(p,d);double radius=d["radius"].AsDouble();double growth=(1-Smooth(.4,1.6,q.Length()/radius+noise(p)*.15))*P("structure_density"),ridge=Math.Pow(1-Math.Abs(macro(p*.7f)),5);
        double h=65+macro(p)*new[]{25,200,65,350,120,20}[id]+noise(p)*new[]{2,7,3,8,4,1}[id]+ridge*new[]{15,120,25,220,60,5}[id];double vein=1-Smooth(22,80,Math.Abs(q.Y+Math.Sin(q.X/700.0)*90));h+=vein*growth*18;double water=0;
        if(id==5){double basin=1-Smooth(.4,1.2,q.Length()/radius);h=Lerp(h,24+noise(p),basin);if(d["chance"].AsDouble()<P("water_frequency"))water=32*(1-Smooth(.8,1.4,q.Length()/radius));}
        return new[]{h,water,.2,0,growth};
    }
}
