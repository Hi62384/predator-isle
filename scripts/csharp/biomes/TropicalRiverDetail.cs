using Godot;
using System;

namespace PredatorIsle.Biomes;

/// <summary>Bounded density hint for the inherited main river; never changes the canonical field.</summary>
public partial class TropicalRiverDetail : RefCounted
{
    public double spacing(RefCounted builder,Rect2 bounds,long lod)
    {
        var settings=builder.Get("settings").AsGodotObject();
        var config=settings.Get("tropical").AsGodotObject();
        double detail=config.Get("river_detail_metres").AsDouble();
        if(detail<=0||lod<2||lod>Math.Clamp(config.Get("river_detail_max_lod").AsInt64(),2,4))return 0;
        var field=builder.Get("_tropical").AsGodotObject();
        if(field==null||!settings.Get("water_enabled").AsBool()||config.Get("river_frequency").AsDouble()<=0||settings.Get("grass_river_frequency").AsDouble()<=0)return 0;
        double laneSpacing=field is TropicalSampler native?native._spacing():field.Call("_spacing").AsDouble();
        long first=(long)Math.Floor(bounds.Position.Y/laneSpacing)-2,last=(long)Math.Ceiling(bounds.End.Y/laneSpacing)+2;
        detail=Math.Clamp(detail,16,64);if(lod==4)detail*=2;
        if(last-first+1>8)return detail;
        double margin=Math.Max(config.Get("river_width").AsDouble()*4,bounds.Size.X/8.0),frequency=config.Get("river_frequency").AsDouble();
        for(long lane=first;lane<=last;lane++)
        {
            double roll=field is TropicalSampler sampler?sampler.random(lane,0,139):field.Call("random",lane,0,139).AsDouble();
            if(roll>frequency)continue;
            for(int index=0;index<9;index++)
            {
                double x=bounds.Position.X+((double)bounds.End.X-bounds.Position.X)*(index/8.0);
                Vector3 carrier=field is TropicalSampler current?current._carrier(x,lane):field.Call("_carrier",x,lane).AsVector3();
                if(carrier.X>=bounds.Position.Y-margin&&carrier.X<=bounds.End.Y+margin)return detail;
            }
        }
        return 0;
    }
}
