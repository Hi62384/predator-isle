using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>Deterministic, footprint-sized low-pass sampling of the same canonical terrain field.</summary>
public sealed class TerrainRingHeightFilter
{
    private readonly record struct Key(double X,double Z,double Footprint);
    private readonly Dictionary<Key,double> values=new();
    private readonly Queue<Key> order=new();
    private readonly TerrainHeightField canonical;
    public int Capacity{get;}
    public TerrainRingHeightFilter(TerrainHeightField field,int capacity=8192){if(capacity<1)throw new ArgumentOutOfRangeException(nameof(capacity));canonical=field;Capacity=capacity;}
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    public double Sample(double x,double z,double footprint,double waterLevel,double? canonicalCenter=null)
    {
        if(!double.IsFinite(footprint)||footprint<=0)throw new ArgumentOutOfRangeException(nameof(footprint));var key=new Key(x,z,footprint);if(values.TryGetValue(key,out var saved))return saved;double center=canonicalCenter??canonical.normal_height(x,z),result=center;
        // This retention band already selects the unchanged canonical height.
        // Do not perform eight expensive geographic queries whose contribution is zero.
        if(Math.Abs(center-waterLevel)<=footprint*.75)return Store(key,center);
        // Continuous retention bands protect shores, crests and escarpments without introducing a new height step.
            double offset=footprint*.5,sum=center*4,low=center,high=center,otherLow=double.PositiveInfinity,otherHigh=double.NegativeInfinity;
            for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++){if(dx==0&&dz==0)continue;double height=canonical.normal_height(x+dx*offset,z+dz*offset);sum+=height*(dx==0||dz==0?2:1);low=Math.Min(low,height);high=Math.Max(high,height);otherLow=Math.Min(otherLow,height);otherHigh=Math.Max(otherHigh,height);}
            double retention=1-Smooth(footprint*.75,footprint*1.5,Math.Abs(center-waterLevel));retention=Math.Max(retention,Smooth(footprint*1.5,footprint*2.5,high-low));retention=Math.Max(retention,Smooth(footprint*.05,footprint*.15,center-otherHigh));retention=Math.Max(retention,Smooth(footprint*.05,footprint*.15,otherLow-center));retention=Math.Max(retention,Smooth(0,footprint*.1,Math.Max(0,Math.Min(waterLevel-low,high-waterLevel))));double filtered=sum/16;result=filtered+(center-filtered)*retention;
        return Store(key,result);
    }
    private double Store(Key key,double value){while(values.Count>=Capacity&&order.TryDequeue(out var oldest))values.Remove(oldest);values[key]=value;order.Enqueue(key);return value;}
}
