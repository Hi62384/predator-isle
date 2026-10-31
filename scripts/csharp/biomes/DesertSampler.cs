using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;

namespace PredatorIsle.Biomes;

/// <summary>Worker-owned canonical desert regions, fixed-world wind and geological controls.</summary>
public partial class DesertSampler : RefCounted
{
    public enum Region{SAND_SEA,ROCKY_PLAIN,CANYON,DRY_BASIN,HIGHLANDS,BADLANDS,OASIS}
    public A REGION_NAMES{get;}=new(){"Great Sand Sea","Rocky Wasteland","Sandstone Canyon Country","Dry Basin","Desert Highlands","Badlands","Oasis Basin"};
    private static readonly Vector3[] RegionColors={new(.96f,.69f,.27f),new(.42f,.40f,.35f),new(.72f,.31f,.17f),new(.89f,.88f,.75f),new(.49f,.34f,.23f),new(.70f,.49f,.48f),new(.16f,.50f,.53f)};
    public const double REGION_GRID=256;
    public const int CACHE_LIMIT=4096,NEIGHBORHOOD_CACHE_LIMIT=128,OCCURRENCE_CACHE_LIMIT=256;
    public DesertSettings settings{get;set;}=new();
    public long seed_value{get;set;}=73921;
    public FastNoiseLite _macro{get;}=new();
    public FastNoiseLite _meso{get;}=new();
    public FastNoiseLite _detail{get;}=new();
    public DesertDrainage _drainage_graph{get;}=new();
    public Vector4 control_region{get;set;}
    public Vector4 control_surface{get;set;}
    public Vector4 control_wind{get;set;}
    public Vector4 control_detail{get;set;}
    public Vector4 last_family_weights{get;set;}
    public double last_irregular_weight{get;set;}
    public double last_obstacle_shelter{get;set;}
    public double last_bedding_coordinate{get;set;}
    public int last_family{get;set;}
    public int last_region{get;set;}
    public double last_fan{get;set;}
    public double last_crest{get;set;}
    public float[] last_weights{get;set;}=Array.Empty<float>();
    private readonly Dictionary<Vector2I,float[]> regionCache=new();
    private readonly Dictionary<Vector2I,Vector4> siteCache=new();
    private readonly Dictionary<Vector2I,Vector4[]> neighborhoods=new(),duneCache=new();
    private readonly Dictionary<Vector3I,Vector4> occurrenceCache=new();
    private readonly Dictionary<Vector3I,Vector4[]> duneSubsets=new();
    private Vector2I lastSiteCenter=new(int.MaxValue,int.MaxValue),lastCell=new(int.MaxValue,int.MaxValue);
    private Vector4[] lastSites=Array.Empty<Vector4>();
    private float[][] corners=Array.Empty<float[]>();
    private bool constantRegion;
    private double regionSpan,regionBlendWidth,rockStyleMin,rockStyleSpan,windX,windZ,rotation,duneWidth,duneSpacing,duneCrest,duneCap,secondaryRatio,megaWidth,windStrength,windPhase,duneOccurrence,dryOccurrence,duneOccurrenceSpan,dryOccurrenceSpan;
    private Vector4 bedding;
    public DesertSampler(){REGION_NAMES.MakeReadOnly();}
    public Godot.Collections.Dictionary cache_counts()=>new(){["regions"]=regionCache.Count,["sites"]=siteCache.Count,["dunes"]=duneCache.Count,["neighborhoods"]=neighborhoods.Count,["occurrences"]=occurrenceCache.Count,["dune_subsets"]=duneSubsets.Count};
    private static double L(double a,double b,double t)=>a+(b-a)*t;
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Mod(double x,double period)=>x-Math.Floor(x/period)*period;
    private static double Noise(FastNoiseLite noise,double x,double z)=>noise.GetNoise2D((float)x,(float)z);
    private static Vector2I Cell(Vector2 p,double span)=>new((int)Math.Floor(p.X/span),(int)Math.Floor(p.Y/span));
    private static Vector2 Point(Vector2I p)=>new(p.X,p.Y);
    private static Vector2 Rotate(Vector2 p,double angle){float s=(float)Math.Sin((float)angle),c=(float)Math.Cos((float)angle);return new Vector2(p.X*c-p.Y*s,p.X*s+p.Y*c);}
    public void configure(DesertSettings config,long worldSeed)
    {
        settings=config;seed_value=worldSeed;rotation=config.wind_direction_degrees*Math.PI/180;windX=Math.Cos(rotation);windZ=Math.Sin(rotation);regionSpan=Math.Max(config.region_size,3000);regionBlendWidth=regionSpan*.22;double sandy=Math.Clamp(config.sandy_frequency,.05,.65);rockStyleMin=Math.Clamp(config.oasis_frequency,0,.06)+sandy;rockStyleSpan=Math.Clamp(config.rocky_frequency,.02,.5)*(1-sandy);double minimum=Math.Max(200,Math.Min(config.dune_width_range.X,config.dune_width_range.Y));duneWidth=Math.Max(minimum,Math.Max(config.dune_width_range.X,config.dune_width_range.Y));duneSpacing=Math.Max(config.dune_spacing,.65);duneOccurrence=Math.Clamp(config.dune_occurrence,0,1);dryOccurrence=Math.Clamp(config.dry_lake_occurrence,0,1);duneOccurrenceSpan=Math.Max(duneWidth*duneSpacing*4,3000);dryOccurrenceSpan=Math.Max(config.basin_size*3,6000);duneCrest=Math.Clamp(config.dune_asymmetry,.55,.82);duneCap=duneWidth*duneSpacing*.65*(1-duneCrest)*.52/((1.5-.5*Math.Clamp(config.slip_face_sharpness,0,1))*1.8);secondaryRatio=duneWidth/minimum;megaWidth=Math.Max(7000,duneWidth*8);windStrength=config.wind_variation*1600;windPhase=(seed_value%10007)*.013;bedding=config.bedding_parameters(worldSeed);Setup(_macro,worldSeed+7013,1.0/2200,2);Setup(_meso,worldSeed+7039,1.0/540,2);Setup(_detail,worldSeed+7069,1.0/95,2);_drainage_graph.configure(config,worldSeed);regionCache.Clear();occurrenceCache.Clear();siteCache.Clear();neighborhoods.Clear();lastSiteCenter=new Vector2I(int.MaxValue,int.MaxValue);lastSites=Array.Empty<Vector4>();duneCache.Clear();duneSubsets.Clear();lastCell=new Vector2I(int.MaxValue,int.MaxValue);
    }
    private static void Setup(FastNoiseLite noise,long seed,double frequency,int octaves){noise.Seed=unchecked((int)seed);noise.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;noise.Frequency=(float)frequency;noise.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;noise.FractalOctaves=octaves;noise.FractalGain=.4f;}
    public double _hash(long x,long z,long salt){long h=unchecked(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (h^(h>>16))/2147483647.0;}
    public double _patch_occurrence(Vector2 p,double span,double probability,int salt)
    {
        if(probability<=0)return 0;if(probability>=1)return 1;var lattice=p/(float)span;var cell=Cell(lattice,1);var key=new Vector3I(cell.X,cell.Y,salt);if(!occurrenceCache.TryGetValue(key,out var sites)){sites=new Vector4(_hash(cell.X,cell.Y,salt)<probability?1:0,_hash(cell.X+1,cell.Y,salt)<probability?1:0,_hash(cell.X,cell.Y+1,salt)<probability?1:0,_hash(cell.X+1,cell.Y+1,salt)<probability?1:0);if(occurrenceCache.Count>=OCCURRENCE_CACHE_LIMIT)occurrenceCache.Clear();occurrenceCache[key]=sites;}var t=lattice-Point(cell);t=new Vector2((float)Smooth(.15,.85,t.X),(float)Smooth(.15,.85,t.Y));return L(L(sites.X,sites.Y,t.X),L(sites.Z,sites.W,t.X),t.Y);
    }
    private Vector4 Site(Vector2I cell)
    {
        if(siteCache.TryGetValue(cell,out var site))return site;double random=_hash(cell.X,cell.Y,7),sandy=Math.Clamp(settings.sandy_frequency,.05,.65),rocky=Math.Clamp(settings.rocky_frequency,.02,.5)*(1-sandy),oasis=Math.Clamp(settings.oasis_frequency,0,.06);int id;if(random<oasis)id=6;else if(random<oasis+sandy)id=0;else if(random<oasis+sandy+rocky)id=1;else{double t=(random-oasis-sandy-rocky)/Math.Max(1-oasis-sandy-rocky,.01);id=new[]{2,3,4,5}[Math.Clamp((int)(t*4),0,3)];}site=new Vector4((float)((cell.X+.2+_hash(cell.X,cell.Y,11)*.6)*regionSpan),(float)((cell.Y+.2+_hash(cell.X,cell.Y,13)*.6)*regionSpan),id,(float)random);if(siteCache.Count>=CACHE_LIMIT)siteCache.Clear();siteCache[cell]=site;return site;
    }
    private float[] RegionNode(Vector2I cell)
    {
        if(regionCache.TryGetValue(cell,out var result))return result;var p=Point(cell)*(float)REGION_GRID;var q=p+new Vector2((float)Noise(_macro,p.X*.24,p.Y*.24),(float)Noise(_macro,p.X*.24+9713,p.Y*.24-3811))*(float)regionSpan*.16f;var center=Cell(q,regionSpan);
        if(center!=lastSiteCenter){if(!neighborhoods.TryGetValue(center,out lastSites!)){lastSites=new Vector4[9];int index=0;for(int z=-1;z<2;z++)for(int x=-1;x<2;x++)lastSites[index++]=Site(center+new Vector2I(x,z));if(neighborhoods.Count>=NEIGHBORHOOD_CACHE_LIMIT)neighborhoods.Clear();neighborhoods[center]=lastSites;}lastSiteCenter=center;}
        var distances=new float[9];double nearest=double.PositiveInfinity;for(int i=0;i<9;i++){double distance=q.DistanceTo(new Vector2(lastSites[i].X,lastSites[i].Y));distances[i]=(float)distance;nearest=Math.Min(nearest,distance);}result=new float[11];double total=0;for(int i=0;i<9;i++){var site=lastSites[i];double weight=1-Smooth(0,regionBlendWidth,distances[i]-nearest);if(weight==0)continue;result[(int)site.Z]=(float)(result[(int)site.Z]+weight);result[7]=(float)(result[7]+(double)site.W*weight);total+=weight;}for(int i=0;i<8;i++)result[i]=(float)(result[i]/Math.Max(total,.0001));double wx=windX+Math.Cos(p.X/9100.0+windPhase)*Math.Cos(p.Y/11700.0-windPhase*.71)*windStrength/9100,wz=windZ-Math.Sin(p.X/9100.0+windPhase)*Math.Sin(p.Y/11700.0-windPhase*.71)*windStrength/11700;var direction=new Vector2((float)wx,(float)wz).Normalized();result[8]=direction.X;result[9]=direction.Y;double rock=Math.Clamp((double)result[2]+result[4]+result[5]*.6+result[1]*.3,0,1);if(rock>0&&settings.wind_shelter_strength>0){double basis=ObstacleEnvelope(p),near=ObstacleEnvelope(p-direction*96)-basis,far=ObstacleEnvelope(p-direction*288)-basis;result[10]=(float)(Math.Max(Smooth(2,26,near),Smooth(6,60,far))*rock);}if(regionCache.Count>=CACHE_LIMIT)regionCache.Clear();regionCache[cell]=result;return result;
    }
    private double ObstacleEnvelope(Vector2 p){double ridge=1-Math.Abs(Noise(_macro,p.X*1.2+3173,p.Y*1.2-991)),flank=Math.Max(0,.5+Noise(_macro,p.X,p.Y));return (ridge*ridge*ridge*.65+flank*flank*.35)*Math.Max(settings.highland_height,100);}
    public float[] region_weights(double x,double z)
    {
        var p=new Vector2((float)x,(float)z)/(float)REGION_GRID;var cell=Cell(p,1);var t=p-Point(cell);t=t*t*(Vector2.One*3-2*t);if(t.X==0&&t.Y==0)return (float[])RegionNode(cell).Clone();var result=new float[11];if(t.X==0||t.Y==0){var aa=RegionNode(cell);var bb=RegionNode(cell+(t.X==0?Vector2I.Down:Vector2I.Right));double blend=t.X==0?t.Y:t.X;for(int i=0;i<11;i++)result[i]=(float)L(aa[i],bb[i],blend);return result;}
        if(cell!=lastCell){corners=new[]{RegionNode(cell),RegionNode(cell+Vector2I.Right),RegionNode(cell+Vector2I.Down),RegionNode(cell+Vector2I.One)};lastCell=cell;constantRegion=true;for(int k=1;k<4;k++)for(int i=0;i<8;i++)if(corners[k][i]!=corners[0][i]){constantRegion=false;break;}}
        if(constantRegion){Array.Copy(corners[0],result,11);for(int i=8;i<11;i++)result[i]=(float)L(L(corners[0][i],corners[1][i],t.X),L(corners[2][i],corners[3][i],t.X),t.Y);}else for(int i=0;i<11;i++)result[i]=(float)L(L(corners[0][i],corners[1][i],t.X),L(corners[2][i],corners[3][i],t.X),t.Y);return result;
    }
    public Vector2 wind_coordinates(double x,double z)=>Rotate(new Vector2((float)x,(float)z),-rotation)+new Vector2((float)(Math.Sin(x/9100+windPhase)*Math.Cos(z/11700-windPhase*.71)),(float)(Math.Cos(x/13700-windPhase*.43)*Math.Sin(z/8300+windPhase)))*(float)windStrength;
}
