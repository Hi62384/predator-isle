using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Hierarchical protected region ownership and continuous world-grid boundary weights.</summary>
public partial class TerrainRegions : RefCounted
{
    public Resource settings {get;set;}=null!;
    public long world_seed {get;set;}
    public double[] sizes {get;set;}=System.Array.Empty<double>();
    public Godot.Collections.Array<bool> enabled {get;set;}=new();
    public Godot.Collections.Array<int> levels {get;set;}=new();
    public Godot.Collections.Array<Vector4> probabilities {get;set;}=new();
    public Vector4 coverage {get;set;}
    public double jungle_coverage {get;set;}
    public double mountain_coverage {get;set;}
    public double tropical_coverage {get;set;}
    public double badlands_coverage {get;set;}
    public double[] extra_coverage {get;set;}=new double[8];
    public double[] jungle_probabilities {get;set;}=System.Array.Empty<double>();
    public double[] mountain_probabilities {get;set;}=System.Array.Empty<double>();
    public double[] tropical_probabilities {get;set;}=System.Array.Empty<double>();
    public double[] badlands_probabilities {get;set;}=System.Array.Empty<double>();
    private double[][] _extraProbabilities=System.Array.Empty<double[]>();
    public A extra_probabilities {get {var result=new A();foreach(var p in _extraProbabilities)result.Add(p);return result;}}
    public double minimum_size {get;set;}
    public double root_size {get;set;}
    public double temperature_period {get;set;}
    public double temperature_phase {get;set;}
    public double jungle_weight {get;set;}
    public double mountain_weight {get;set;}
    public double tropical_weight {get;set;}
    public double badlands_weight {get;set;}
    public double[] extra_weights {get;set;}=new double[8];
    public bool extras_enabled {get;set;}
    public D label_cache {get;set;}=new();
    public D cell_cache {get;set;}=new();
    public FastNoiseLite warp_large {get;}=new();
    public FastNoiseLite warp_small {get;}=new();
    private readonly TerrainParameterSnapshot _parameters=new();
    private double P(string name)=>_parameters[name];
    private static double Smooth(double x){double t=Math.Clamp(x,0,1);return t*t*(3-2*t);}
    private static FastNoiseLite Setup(FastNoiseLite noise,long seed,double frequency)
    {noise.Seed=unchecked((int)seed);noise.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;noise.Frequency=(float)frequency;noise.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;noise.FractalOctaves=1;noise.FractalGain=.5f;return noise;}
    public void configure(Resource configuration,long seed,bool extension_samplers_enabled,double[] extension_coverage)
    {
        settings=configuration;world_seed=seed;extras_enabled=extension_samplers_enabled;extra_coverage=(double[])extension_coverage.Clone();enabled.Clear();levels.Clear();probabilities.Clear();label_cache.Clear();cell_cache.Clear();
        _parameters.Capture(configuration);
        double grassSize=P("grass_region_size");var regionSizes=new List<double>{grassSize,P("forest_coverage")>0?P("forest_region_size"):grassSize,P("savanna_coverage")>0?P("savanna_region_size"):grassSize,P("swamp_coverage")>0?P("swamp_region_size"):grassSize};
        coverage=new Vector4((float)Math.Max(P("grass_coverage"),0),(float)Math.Max(P("forest_coverage"),0),(float)Math.Max(P("savanna_coverage"),0),(float)Math.Max(P("swamp_coverage"),0));double total=(double)coverage.X+coverage.Y+coverage.Z+coverage.W;
        jungle_coverage=Math.Max(P("jungle_coverage"),0);mountain_coverage=Math.Max(P("mountain_coverage"),0);tropical_coverage=Math.Max(P("tropical_coverage"),0);badlands_coverage=Math.Max(P("badlands_coverage"),0);total+=jungle_coverage+mountain_coverage+tropical_coverage+badlands_coverage;foreach(double amount in extra_coverage)total+=amount;
        if(total<=0)coverage=new Vector4(1,0,0,0);else{coverage/=(float)total;jungle_coverage/=total;mountain_coverage/=total;tropical_coverage/=total;badlands_coverage/=total;for(int i=0;i<8;i++)extra_coverage[i]/=total;}
        if(jungle_coverage>0||mountain_coverage>0||tropical_coverage>0||badlands_coverage>0)regionSizes.Add(jungle_coverage>0?P("jungle_region_size"):grassSize);
        if(mountain_coverage>0||tropical_coverage>0||badlands_coverage>0)regionSizes.Add(mountain_coverage>0?P("mountain_region_size"):grassSize);
        if(tropical_coverage>0||badlands_coverage>0)regionSizes.Add(tropical_coverage>0?P("tropical_region_size"):grassSize);
        if(badlands_coverage>0)regionSizes.Add(P("badlands_region_size"));
        if(extras_enabled){while(regionSizes.Count<8)regionSizes.Add(grassSize);foreach(string key in TerrainBiomeCatalog.ExtensionKeys)regionSizes.Add(P(key+"_region_size"));}
        sizes=new double[regionSizes.Count];minimum_size=double.PositiveInfinity;
        for(int i=0;i<sizes.Length;i++){sizes[i]=Math.Max(regionSizes[i]*Math.Max(P("biome_size"),.001),16);bool active=(i<4?coverage[i]:i==4?jungle_coverage:i==5?mountain_coverage:i==6?tropical_coverage:i==7?badlands_coverage:extra_coverage[i-8])>0;enabled.Add(active);if(active)minimum_size=Math.Min(minimum_size,sizes[i]);}
        int top=0;for(int i=0;i<sizes.Length;i++){int level=Math.Max(0,(int)Math.Round(Math.Log(sizes[i]/minimum_size)/Math.Log(2),MidpointRounding.AwayFromZero));levels.Add(level);if(enabled[i])top=Math.Max(top,level);}root_size=minimum_size*Math.Pow(2,top);
        probabilities.Resize(top+1);jungle_probabilities=new double[top+1];mountain_probabilities=new double[top+1];tropical_probabilities=new double[top+1];badlands_probabilities=new double[top+1];_extraProbabilities=new double[8][];for(int i=0;i<8;i++)_extraProbabilities[i]=new double[top+1];double remaining=1;
        for(int level=top;level>=0;level--)
        {
            var p=Vector4.Zero;double assigned=0;for(int i=0;i<4;i++)if(levels[i]==level){p[i]=(float)(coverage[i]/Math.Max(remaining,.000000001));assigned+=coverage[i];}
            if(sizes.Length>=5&&levels[4]==level){jungle_probabilities[level]=jungle_coverage/Math.Max(remaining,.000000001);assigned+=jungle_coverage;}
            if(sizes.Length>=6&&levels[5]==level){mountain_probabilities[level]=mountain_coverage/Math.Max(remaining,.000000001);assigned+=mountain_coverage;}
            if(sizes.Length>=7&&levels[6]==level){tropical_probabilities[level]=tropical_coverage/Math.Max(remaining,.000000001);assigned+=tropical_coverage;}
            if(sizes.Length>=8&&levels[7]==level){badlands_probabilities[level]=badlands_coverage/Math.Max(remaining,.000000001);assigned+=badlands_coverage;}
            if(extras_enabled)for(int i=0;i<8;i++)if(levels[8+i]==level){_extraProbabilities[i][level]=extra_coverage[i]/Math.Max(remaining,.000000001);assigned+=extra_coverage[i];}probabilities[level]=p;remaining-=assigned;
        }
        Setup(warp_large,unchecked(world_seed+811),1/root_size);Setup(warp_small,unchecked(world_seed+919),1/minimum_size);temperature_period=Math.Max(P("temperature_region_size")*Math.Max(P("biome_size"),.001),root_size*8);temperature_phase=random(0,0,0,9371)*Math.Tau;
    }
    public double random(long x,long z,long biome,long salt)=>random(x,z,biome,salt,world_seed);
    public double random(long x,long z,long biome,long salt,long seed)
    {long h=unchecked(x*73856093^z*19349663^seed*83492791^biome*2654435761^salt)&0xffffffff;h=unchecked((h^(h>>16))*73244475)&0xffffffff;h=unchecked((h^(h>>16))*73244475)&0xffffffff;h=(h^(h>>16))&0xffffffff;return h/4294967296.0;}
    public Vector2 warp_point(double x,double z)
    {
        var p=new Vector2((float)(x*.932327-z*.361615),(float)(x*.361615+z*.932327));p.X=(float)(p.X+warp_large.GetNoise1D(p.Y)*root_size*.16+warp_small.GetNoise1D(p.Y)*minimum_size*.18);p.Y=(float)(p.Y+warp_large.GetNoise1D((float)(p.X+713.0))*root_size*.16+warp_small.GetNoise1D((float)(p.X+317.0))*minimum_size*.18);return p;
    }
    public double temperature(Vector2 p)=>P("average_temperature")+P("temperature_variation")*Math.Sin(p.X*Math.Tau/temperature_period+temperature_phase);
    public double get_temperature(double x,double z)=>temperature(warp_point(x,z));
    public int owner(Vector2 p)
    {
        for(int level=probabilities.Count-1;level>=0;level--)
        {
            double span=minimum_size*Math.Pow(2,level),roll=random((long)Math.Floor(p.X/span),(long)Math.Floor(p.Y/span),level,2731),cumulative=0;var probabilitiesAtLevel=probabilities[level];
            for(int i=0;i<4;i++){cumulative+=probabilitiesAtLevel[i];if(roll<cumulative&&enabled[i])return i;}
            if(jungle_probabilities[level]>0&&roll<cumulative+jungle_probabilities[level])return 4;cumulative+=jungle_probabilities[level];
            if(mountain_probabilities[level]>0&&roll<cumulative+mountain_probabilities[level])return 5;cumulative+=mountain_probabilities[level];
            if(tropical_probabilities[level]>0&&roll<cumulative+tropical_probabilities[level])return 6;cumulative+=tropical_probabilities[level];
            if(badlands_probabilities[level]>0&&roll<cumulative+badlands_probabilities[level])return 7;cumulative+=badlands_probabilities[level];
            if(extras_enabled)for(int i=0;i<8;i++){cumulative+=_extraProbabilities[i][level];if(_extraProbabilities[i][level]>0&&roll<cumulative)return 8+i;}
        }
        for(int i=0;i<4;i++)if(enabled[i])return i;if(jungle_coverage>0)return 4;if(mountain_coverage>0)return 5;if(tropical_coverage>0)return 6;if(badlands_coverage>0)return 7;for(int i=0;i<8;i++)if(extra_coverage[i]>0)return 8+i;return 0;
    }
    public int grid_owner(long x,long z,double step)
    {var key=new Vector2I(unchecked((int)x),unchecked((int)z));if(!label_cache.ContainsKey(key)){if(label_cache.Count>=4096)label_cache.Clear();label_cache[key]=owner(warp_point(x*step,z*step));}return label_cache[key].AsInt32();}
    private double Coverage(int id)=>id<4?coverage[id]:id==4?jungle_coverage:id==5?mountain_coverage:id==6?tropical_coverage:id==7?badlands_coverage:extra_coverage[id-8];
    public bool pure_rect(Rect2 bounds,int id)
    {
        double coverage=Coverage(id);if(coverage<=0)return false;if(coverage==1)return true;double step=Math.Max(minimum_size/(Math.Max(P("height_blend"),.1)*4),1);var first=new Vector2I((int)Math.Floor(bounds.Position.X/step),(int)Math.Floor(bounds.Position.Y/step));var last=new Vector2I((int)Math.Ceiling(bounds.End.X/step),(int)Math.Ceiling(bounds.End.Y/step));if(((long)last.X-first.X+1)*((long)last.Y-first.Y+1)>256)return false;
        for(int z=first.Y;z<=last.Y;z++)for(int x=first.X;x<=last.X;x++)if(grid_owner(x,z,step)!=id)return false;return true;
    }
    public int pure_extension_rect(Rect2 bounds)
    {
        if(!extras_enabled)return -1;for(int i=0;i<8;i++)if(extra_coverage[i]==1)return i;double step=Math.Max(minimum_size/(Math.Max(P("height_blend"),.1)*4),1);var first=new Vector2I((int)Math.Floor(bounds.Position.X/step),(int)Math.Floor(bounds.Position.Y/step));var last=new Vector2I((int)Math.Ceiling(bounds.End.X/step),(int)Math.Ceiling(bounds.End.Y/step));if(((long)last.X-first.X+1)*((long)last.Y-first.Y+1)>256)return -1;int id=grid_owner(first.X,first.Y,step);if(id<8)return -1;for(int z=first.Y;z<=last.Y;z++)for(int x=first.X;x<=last.X;x++)if(grid_owner(x,z,step)!=id)return -1;return id-8;
    }
    private void ResetWeights(){System.Array.Clear(extra_weights);jungle_weight=0;mountain_weight=0;tropical_weight=0;badlands_weight=0;}
    public Vector4 weights(double x,double z)
    {
        ResetWeights();for(int i=0;i<8;i++)if(extra_coverage[i]==1){extra_weights[i]=1;return Vector4.Zero;}if(badlands_coverage==1){badlands_weight=1;return Vector4.Zero;}if(tropical_coverage==1){tropical_weight=1;return Vector4.Zero;}if(mountain_coverage==1){mountain_weight=1;return Vector4.Zero;}if(jungle_coverage==1){jungle_weight=1;return Vector4.Zero;}if(coverage.Y==1||coverage.Z==1||coverage.W==1)return coverage;
        double step=Math.Max(minimum_size/(Math.Max(P("height_blend"),.1)*4),1),px=x/step,pz=z/step;long ix=(long)Math.Floor(px),iz=(long)Math.Floor(pz);var cell=new Vector2I(unchecked((int)ix),unchecked((int)iz));
        if(!cell_cache.ContainsKey(cell)){if(cell_cache.Count>=4096)cell_cache.Clear();cell_cache[cell]=new Vector4I(grid_owner(ix,iz,step),grid_owner(ix+1,iz,step),grid_owner(ix,iz+1,step),grid_owner(ix+1,iz+1,step));}var labels=cell_cache[cell].AsVector4I();var result=Vector4.Zero;
        if(labels.X==labels.Y&&labels.X==labels.Z&&labels.X==labels.W){Set(labels.X,1);return result;}
        double fx=Smooth(px-ix),fz=Smooth(pz-iz);if(!extras_enabled&&jungle_coverage==0&&mountain_coverage==0&&tropical_coverage==0&&badlands_coverage==0){result[labels.X]=(float)(result[labels.X]+(1-fx)*(1-fz));result[labels.Y]=(float)(result[labels.Y]+fx*(1-fz));result[labels.Z]=(float)(result[labels.Z]+(1-fx)*fz);result[labels.W]=(float)(result[labels.W]+fx*fz);}
        else{var contributions=new Vector4((float)((1-fx)*(1-fz)),(float)(fx*(1-fz)),(float)((1-fx)*fz),(float)(fx*fz));for(int i=0;i<4;i++)Set(labels[i],contributions[i]);}return result;
        void Set(int id,double amount){if(id==4)jungle_weight+=amount;else if(id==5)mountain_weight+=amount;else if(id==6)tropical_weight+=amount;else if(id==7)badlands_weight+=amount;else if(id>=8)extra_weights[id-8]+=amount;else result[id]=(float)(result[id]+amount);}
    }
}
