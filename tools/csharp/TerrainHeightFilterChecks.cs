using Godot;
using System;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

/// <summary>Independent original nine-tap reference and canonical-query accounting.</summary>
internal static class TerrainHeightFilterChecks
{
    internal static Godot.Collections.Dictionary Measurements { get; private set; } = new();

    internal static void Run(Action<bool,string> require)
    {
        long referenceQueries=0,optimizedQueries=0;
        double maximumDelta=0;
        var random=new Random(73921);
        // Signed heights, fractional centers, distant footprint sizes and both
        // saturated and partially retained neighborhoods exercise the float boundary.
        for(int trial=0;trial<12000;trial++)
        {
            double scale=Math.Pow(2,trial%21-10),footprint=((trial%4) switch{0=>.5,1=>2,2=>9,_=>81})*scale;
            var heights=new double[9];
            double center=(random.NextDouble()-.5)*5000*scale;
            for(int i=0;i<9;i++)heights[i]=center+(random.NextDouble()-.5)*footprint*(trial%3==0?8:1);
            heights[4]=center;
            double water=trial%5==0?center+(random.NextDouble()-.5)*footprint*4:-10000*scale;
            double Field(double x,double z)=>heights[((int)Math.Round(z/(footprint*.5))+1)*3+(int)Math.Round(x/(footprint*.5))+1];
            double Counted(double x,double z){optimizedQueries++;return Field(x,z);}
            var filter=new TerrainRingHeightFilter(Counted);
            double actual=filter.Sample(0,0,footprint,water,center);
            double expected=Reference(Field,0,0,footprint,water,ref referenceQueries,center);
            maximumDelta=Math.Max(maximumDelta,Math.Abs(actual-expected));
            require((float)actual==(float)expected,"Visual height filter changed a rendered float at case "+trial);
        }
        require(optimizedQueries==referenceQueries,"Filter changed the original canonical query sequence");
        // At a float midpoint, returning center when retention reaches one is
        // not equivalent to the original double interpolation arithmetic.
        double midpoint=1+Math.Pow(2,-24);
        double[] adversarial=[7.450292833472258,-5.258899295041164,-6.985540483565011,-6.327638067082313,midpoint,-2.4964837206892057,5.671276136379005,-1.727694446884838,-1.4079164586285131];
        double Adversarial(double x,double z)=>adversarial[((int)Math.Round(z/.5)+1)*3+(int)Math.Round(x/.5)+1];
        var midpointFilter=new TerrainRingHeightFilter(Adversarial);
        long midpointQueries=0;
        double midpointExpected=Reference(Adversarial,0,0,1,-100,ref midpointQueries,midpoint);
        require((float)midpointExpected!=(float)midpoint,"Adversarial rounding fixture no longer exercises cancellation");
        require(midpointFilter.Sample(0,0,1,-100,midpoint)==midpointExpected,
            "Saturated retention bypassed the precise original interpolation arithmetic");

        int calls=0;
        double Bowl(double x,double z){calls++;return 100+.01*(x*x+z*z);}
        var waterCache=new TerrainRingHeightFilter(Bowl,2);
        double dry=waterCache.Sample(0,0,8,0,100);
        int before=calls;
        double wet=waterCache.Sample(0,0,8,100,100);
        require(dry>100&&wet==100,"Filter cache reused a different water-level retention band");
        require(calls==before,"Canonical shore retention unnecessarily sampled neighbors");
        require(waterCache.Sample(0,0,8,0,100)==dry&&calls>before,
            "Returning to an earlier water context reused stale filter entries");
        before=calls;
        require(waterCache.Sample(0,0,8,0,100)==dry&&calls==before,
            "Same-water filter result was not cached");
        // FIFO eviction is independent of water-context invalidation.
        var evictionCache=new TerrainRingHeightFilter(Bowl,2);
        evictionCache.Sample(0,0,8,0,100);
        evictionCache.Sample(100,100,8,0);
        before=calls;
        evictionCache.Sample(0,0,8,0,100);
        require(calls==before,"Live cache entry was unexpectedly evicted");
        evictionCache.Sample(200,200,8,0);
        before=calls;
        evictionCache.Sample(0,0,8,0,100);
        require(calls>before,"Bounded filter cache did not evict its oldest key");

        // Normal and curvature outputs consume double filter results before
        // conversion. Exact float comparisons catch cancellation-sensitive changes.
        for(int trial=0;trial<256;trial++)
        {
            double offset=(trial%7-3)*97.125,footprint=trial%3==0?81:trial%3==1?9:2;
            double Field(double x,double z)=>offset+Math.Sin(x*.04)*65+Math.Cos(z*.07)*35+(x>0?70:0);
            CompareDerivatives(Field,trial*7.125-800,trial*-3.75+390,footprint,-500,require,ref maximumDelta);
        }

        using var resources=new TerrainBenchmarkResources();
        resources.Retain(GD.Load<Resource>("res://config/world/terrain_settings.tres"));
        string[] biomes=["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands","quarry","wise_mountains","volcanic","spore_forest","radiation_wasteland","crystal_wastes","insect_colony","alien_infected"];
        foreach(string biome in biomes)
        {
            var settings=resources.Retain(TerrainGpuPipelineChecks.GrassSettings());
            settings.Set("grass_coverage",biome=="grass"?100.0:0.0);
            if(biome!="grass")settings.Set(biome+"_coverage",100.0);
            using var builder=TerrainGpuPipelineChecks.Builder(settings);
            foreach(double footprint in new[]{2.0,9.0,81.0})
            foreach(var point in new[]{new Vector2(-17.125f,33.75f),new Vector2(432.5f,-327.125f),new Vector2(-2048.25f,1791.875f)})
                CompareDerivatives(builder._native_height.normal_height,point.X,point.Y,footprint,builder.water_level,require,ref maximumDelta);
        }
        Measurements=new()
        {
            ["random_neighborhoods"]=12000,["surface_biomes"]=biomes.Length,
            ["reference_neighbor_queries"]=referenceQueries,["optimized_neighbor_queries"]=optimizedQueries,
            ["maximum_double_difference"]=maximumDelta,
            ["scope"]="Exact float height, normal and curvature comparison against the prior filter; query counts are synthetic canonical-neighborhood workloads, not frame rate"
        };
        GD.Print($"Height filter queries {referenceQueries} -> {optimizedQueries}; maximum double difference {maximumDelta:R}");
    }

    private static void CompareDerivatives(Func<double,double,double> field,double x,double z,double footprint,double water,
        Action<bool,string> require,ref double maximumDelta)
    {
        var filter=new TerrainRingHeightFilter(field);
        double derivative=Math.Max(1,footprint);
        var points=new[]{new Vector2((float)x,(float)z),new Vector2((float)(x-derivative),(float)z),new Vector2((float)(x+derivative),(float)z),new Vector2((float)x,(float)(z-derivative)),new Vector2((float)x,(float)(z+derivative))};
        var a=new double[5];var b=new double[5];long ignored=0;
        for(int i=0;i<5;i++)
        {
            a[i]=filter.Sample(points[i].X,points[i].Y,footprint,water);
            b[i]=Reference(field,points[i].X,points[i].Y,footprint,water,ref ignored);
            maximumDelta=Math.Max(maximumDelta,Math.Abs(a[i]-b[i]));
            require((float)a[i]==(float)b[i],"Height-filter canonical float changed");
        }
        Vector3 Normal(double[] v)=>new Vector3((float)(v[1]-v[2]),(float)(2*derivative),(float)(v[3]-v[4])).Normalized();
        float Curvature(double[] v)=>(float)((v[1]+v[2]+v[3]+v[4]-4*(float)v[0])/derivative);
        require(Normal(a)==Normal(b),"Height-filter float normal changed");
        require(Curvature(a)==Curvature(b),"Height-filter float curvature changed");
    }

    private static double Reference(Func<double,double,double> field,double x,double z,double footprint,double water,
        ref long queries,double? knownCenter=null)
    {
        double center=knownCenter??field(x,z);
        if(Math.Abs(center-water)<=footprint*.75)return center;
        double offset=footprint*.5,sum=center*4,low=center,high=center,otherLow=double.PositiveInfinity,otherHigh=double.NegativeInfinity;
        for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++)
        {
            if(dx==0&&dz==0)continue;queries++;
            double height=field(x+dx*offset,z+dz*offset);sum+=height*(dx==0||dz==0?2:1);
            low=Math.Min(low,height);high=Math.Max(high,height);otherLow=Math.Min(otherLow,height);otherHigh=Math.Max(otherHigh,height);
        }
        double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
        double retention=1-Smooth(footprint*.75,footprint*1.5,Math.Abs(center-water));
        retention=Math.Max(retention,Smooth(footprint*1.5,footprint*2.5,high-low));
        retention=Math.Max(retention,Smooth(footprint*.05,footprint*.15,center-otherHigh));
        retention=Math.Max(retention,Smooth(footprint*.05,footprint*.15,otherLow-center));
        retention=Math.Max(retention,Smooth(0,footprint*.1,Math.Max(0,Math.Min(water-low,high-water))));
        double filtered=sum/16;return filtered+(center-filtered)*retention;
    }
}
