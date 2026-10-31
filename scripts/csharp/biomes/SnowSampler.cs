using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;

namespace PredatorIsle.Biomes;

/// <summary>Canonical 64 m Hermite snow geography shared by every mesh resolution.</summary>
public partial class SnowSampler : RefCounted
{
    public enum Region{PLAINS,TUNDRA,ALPINE,GLACIAL,LAKES,ARCTIC,PLATEAU,VALLEY}
    public A NAMES{get;}=new(){"Great snow plains","Windswept tundra","Alpine range","Glacial highlands","Frozen lake district","Rocky Arctic highlands","Snow plateau","Glacial valley"};
    private static readonly Vector3[] Colors={new(.75f,.88f,1),new(.55f,.65f,.38f),new(.85f,.25f,.12f),new(.1f,.7f,.9f),new(.3f,.4f,.95f),new(.5f,.35f,.25f),new(.8f,.6f,.9f),new(.15f,.8f,.5f)};
    public const double STEP=64;
    public const int LIMIT=16384;
    public SnowSettings settings{get;set;}=new();
    public long seed_value{get;set;}
    public double phase{get;set;}
    public Vector4 a{get;set;}
    public Vector4 b{get;set;}
    public Vector4 c{get;set;}
    public double last_lowland{get;set;}
    public double last_moraine{get;set;}
    public double last_drift{get;set;}
    private double angle,rawDepth;
    private Vector4 rawSurface,rawFlow;
    private readonly FastNoiseLite macro=new(),meso=new(),structure=new();
    private readonly Dictionary<Vector2I,SampleNode> nodes=new();
    private readonly Dictionary<Vector2I,float[]> regions=new();
    private readonly Dictionary<Vector2I,Vector4> sites=new();
    private Vector2I quadCell=new(int.MaxValue,int.MaxValue);
    private SampleNode[] quad=Array.Empty<SampleNode>();
    private sealed record SampleNode(Vector4 Height,Vector4 Surface,Vector4 Region,Vector4 Flow);
    public SnowSampler(){NAMES.MakeReadOnly();}
    private static double L(double a,double b,double t)=>a+(b-a)*t;
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Mod(double x,double period)=>x-Math.Floor(x/period)*period;
    private static Vector2 Rotate(Vector2 p,double rotation){float sin=(float)Math.Sin((float)rotation),cos=(float)Math.Cos((float)rotation);return new Vector2(p.X*cos-p.Y*sin,p.X*sin+p.Y*cos);}
    private static Vector2I Cell(Vector2 p)=>new((int)Math.Floor(p.X),(int)Math.Floor(p.Y));
    private static Vector2 Point(Vector2I cell)=>new(cell.X,cell.Y);
    private static double Noise(FastNoiseLite noise,double x,double z)=>noise.GetNoise2D((float)x,(float)z);
    public void configure(SnowSettings config,long worldSeed)
    {
        settings=config;seed_value=worldSeed;phase=(worldSeed%10007)*.013;angle=settings.wind_degrees*Math.PI/180;
        foreach(var item in new[]{(macro,8111,1.0/2600,2),(meso,8147,1.0/620,2),(structure,8231,1.0/2100,1)}){item.Item1.Seed=unchecked((int)(worldSeed+item.Item2));item.Item1.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;item.Item1.Frequency=(float)item.Item3;item.Item1.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;item.Item1.FractalOctaves=item.Item4;item.Item1.FractalGain=.4f;}nodes.Clear();regions.Clear();sites.Clear();quad=Array.Empty<SampleNode>();quadCell=new Vector2I(int.MaxValue,int.MaxValue);
    }
    public double _hash(long x,long z,long salt)
    {
        long h=unchecked(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (h^(h>>16))/2147483647.0;
    }
    private Vector4 Site(Vector2I cell)
    {
        if(sites.TryGetValue(cell,out var site))return site;double p=Math.Clamp(settings.plains_frequency,0,1),t=Math.Clamp(settings.tundra_frequency,0,1),m=Math.Clamp(settings.alpine_frequency,0,1),g=Math.Clamp(settings.glacial_frequency,0,1),total=Math.Max(1,p+t+m+g+.29),q=_hash(cell.X,cell.Y,31)*total;int id=q<p?0:q<p+t?1:q<p+t+m?2:q<p+t+m+g?3:4+Math.Clamp((int)((q-p-t-m-g)/Math.Max(total-p-t-m-g,.0001)*4),0,3);double span=Math.Max(settings.region_metres,4000);site=new Vector4((float)((cell.X+.2+_hash(cell.X,cell.Y,37)*.6)*span),(float)((cell.Y+.2+_hash(cell.X,cell.Y,41)*.6)*span),id,(float)_hash(cell.X,cell.Y,43));if(sites.Count>=256)sites.Clear();sites[cell]=site;return site;
    }
    private float[] RegionNode(Vector2I cell)
    {
        if(regions.TryGetValue(cell,out var result))return result;double span=Math.Max(settings.region_metres,4000);var p=Point(cell)*512;var q=p+new Vector2((float)Noise(macro,p.X*.25,p.Y*.25),(float)Noise(macro,p.X*.25+9473,p.Y*.25-2191))*(float)span*.12f;var center=Cell(q/(float)span);var localSites=new Vector4[9];var distances=new float[9];double nearest=double.PositiveInfinity;int index=0;
        for(int z=-1;z<2;z++)for(int x=-1;x<2;x++){var site=Site(center+new Vector2I(x,z));localSites[index]=site;double distance=q.DistanceTo(new Vector2(site.X,site.Y));distances[index++]=(float)distance;nearest=Math.Min(nearest,distance);}result=new float[9];double sum=0;for(int i=0;i<9;i++){double weight=1-Smooth(0,span*.23,distances[i]-nearest);result[(int)localSites[i].Z]=(float)(result[(int)localSites[i].Z]+weight);result[8]=(float)(result[8]+(double)localSites[i].W*weight);sum+=weight;}for(int i=0;i<9;i++)result[i]=(float)(result[i]/Math.Max(sum,.0001));if(regions.Count>=2048)regions.Clear();regions[cell]=result;return result;
    }
    private float[] RegionWeights(Vector2 p)
    {
        var q=p/512;var cell=Cell(q);var f=q-Point(cell);var aa=RegionNode(cell);if(f==Vector2.Zero)return aa;var bb=RegionNode(cell+Vector2I.Right);var cc=RegionNode(cell+Vector2I.Down);var dd=RegionNode(cell+Vector2I.One);if(aa.SequenceEqual(bb)&&aa.SequenceEqual(cc)&&aa.SequenceEqual(dd))return aa;var result=new float[9];for(int i=0;i<9;i++)result[i]=(float)L(L(aa[i],bb[i],f.X),L(cc[i],dd[i],f.X),f.Y);return result;
    }
    public float[] region_weights(Vector2 p)=>(float[])RegionWeights(p).Clone();
    public Vector2 wind_coordinates(Vector2 p)=>Rotate(p,-angle)+new Vector2((float)(Math.Sin(p.X/12000.0+phase)*Math.Cos(p.Y/15000.0-phase)),(float)(Math.Cos(p.X/17000.0-phase)*Math.Sin(p.Y/11000.0+phase)))*(float)settings.wind_variation*400;
    private double Shape(Vector2 p,float[] w,bool publish)
    {
        double macroValue=Noise(macro,p.X,p.Y),mesoValue=Noise(meso,p.X,p.Y),terrainAngle=phase*.13+.37;var q=Rotate(p,-terrainAngle);double ridge=0,mountain=0,gully=0;
        if(w[2]>0||w[3]>0||w[5]>0||w[7]>0){double spine=Math.Sin(q.X/5700.0+phase)*1300+Math.Sin(q.X/2300.0-phase*.7)*270,across=Mod(q.Y-spine+8000,16000)-8000,width=L(1900,450,settings.ruggedness);ridge=Math.Exp(-Math.Pow(Math.Abs(across)/width,1.6));double peaks=.7+.35*Noise(macro,q.X*.7+3191,q.Y*.08),ribs=1-Math.Abs(Noise(structure,q.X*.7,q.Y*1.8));mountain=settings.mountain_height*(ridge*peaks+Math.Pow(ribs,3)*ridge*.14*settings.ruggedness);mountain+=settings.mountain_height*Math.Pow(ribs,8)*ridge*.5*settings.ruggedness;gully=(1-Smooth(.04,.28,Math.Abs(mesoValue)))*Smooth(.1,.7,ridge);mountain-=gully*24*settings.ruggedness;}
        double lateral=2,reach=0,floor=0,uvalley=0,glacial=0,glacier=0,moraine=0,strain=0;
        if(w[3]>0||w[7]>0){double length=Math.Max(settings.glacier_length,6000),flow=Mod(q.X,length)/length,bend=Math.Sin(q.X/3100.0+phase)*420+Math.Sin(q.X/7300.0-phase)*650,across=Mod(q.Y-bend+8000,16000)-8000,width=Math.Max(settings.glacier_width,400)*L(1.25,.45,flow)*(1+mesoValue*.16);lateral=Math.Abs(across)/width;reach=Smooth(.02,.10,flow)*(1-Smooth(.83,.99,flow));floor=L(510,45,flow)+mesoValue*2;uvalley=floor+Math.Pow(Math.Min(lateral*.55,1.6),2)*settings.mountain_height*.64;glacial=L(100+mountain,uvalley,reach*(1-Smooth(1.4,2.6,lateral)));glacier=((double)w[3]+w[7]*.85)*reach*(1-Smooth(.72,1.04,lateral));moraine=((double)w[3]+w[7])*reach*(1-Smooth(.06,.22,Math.Abs(lateral-1.07)));strain=glacier*Math.Clamp(.25+Math.Abs(Math.Cos(q.X/3100.0+phase))*.4+Smooth(.75,.25,width/Math.Max(settings.glacier_width,400))*.3,0,1);}
        double plateau=w[6]>0?65+Smooth(-.17,.13,macroValue)*(280+(double)w[8]*220)+mesoValue*8:0,h=w[0]*(22+macroValue*7+mesoValue*.7)+w[1]*(40+macroValue*42+mesoValue*10);h+=w[2]*(55+mountain)+w[3]*glacial+w[4]*(18+macroValue*6+mesoValue);h+=w[5]*(65+mountain*.48+mesoValue*26)+w[6]*plateau+w[7]*(uvalley*reach+(45+mountain*.7)*(1-reach));h+=moraine*12;h=L(h,floor+18+mesoValue*3,glacier);double fracture=Math.Abs(Math.Sin(q.X/180.0+mesoValue*3));h-=glacier*strain*settings.crevasse_amount*(1-Smooth(.1,.5,fracture))*5;
        double exposure=Math.Clamp(w[1]*.55+w[5]*.65+ridge*((double)w[2]+w[3])*.75+w[6]*.2,0,1)*settings.wind_exposure,shelter=Math.Clamp(gully*((double)w[2]+w[5])*.6+(1-ridge)*((double)w[2]+w[5])*.35+((double)w[7]+w[3])*(1-Smooth(.7,1.4,lateral))*.65,0,1),depth=settings.snow_depth*(.45+w[0]*.9+w[4]*.6+shelter*settings.sheltered_accumulation*1.8)*(1-exposure*.82);depth*=L(.75,1.2,Smooth(-.35,.35,Noise(macro,p.X*2600.0/Math.Max(settings.accumulation_metres,300),p.Y*2600.0/Math.Max(settings.accumulation_metres,300))));var wind=wind_coordinates(p);double gate=Smooth(.05,.40,mesoValue)*settings.drift_frequency*(shelter+w[0]*.3+w[6]*.4),driftLength=Math.Max(settings.drift_length,120),driftWidth=Math.Max(settings.drift_width,40),carrier=Math.Sin(wind.Y/driftWidth+mesoValue*1.6)*.5+.5,crest=Math.Pow(carrier,3)*(.5+.5*Math.Cos(wind.X/driftLength+macroValue)),drift=crest*gate*settings.drift_height;h+=depth*.55+drift;
        if(publish){rawDepth=depth+drift;rawSurface=new Vector4((float)exposure,(float)glacier,(float)Math.Clamp(((double)w[2]+w[3]*.85+w[5]*.8+w[6]*.4+w[7]*.7)*settings.rock_exposure,0,1),(float)strain);var tangent=Rotate(new Vector2(1,(float)(Math.Cos(q.X/3100.0+phase)*420/3100+Math.Cos(q.X/7300.0-phase)*650/7300)),terrainAngle).Normalized();rawFlow=new Vector4(tangent.X,tangent.Y,(float)moraine,(float)drift);}return h;
    }
    private SampleNode Node(Vector2I cell)
    {
        if(nodes.TryGetValue(cell,out var result))return result;var p=Point(cell)*(float)STEP;var w=RegionWeights(p);double h=Shape(p,w,true),depth=rawDepth;var surface=rawSurface;var flow=rawFlow;var px=p+new Vector2(16,0);var pz=p+new Vector2(0,16);double dx=(Shape(px,RegionWeights(px),false)-h)/16,dz=(Shape(pz,RegionWeights(pz),false)-h)/16,slope=1-1/Math.Sqrt(1+dx*dx+dz*dz),facing=(dx*Math.Cos(angle)+dz*Math.Sin(angle))/Math.Sqrt(1+dx*dx+dz*dz),settled=depth*(1-Smooth(.12,.65,slope*settings.slope_influence)*.85);settled*=1+Math.Max(-facing,0)*settings.sheltered_accumulation*.6;settled*=1+Math.Clamp(h/Math.Max(settings.mountain_height,300),0,1)*.2;surface.X=(float)Math.Clamp(surface.X+Math.Max(facing,0)*settings.wind_exposure*.3,0,1);var color=Vector3.Zero;for(int i=0;i<8;i++)color+=Colors[i]*w[i];double lowland=Math.Clamp(w[0]+w[1]*.65+w[4],0,1);result=new SampleNode(new Vector4((float)h,(float)dx,(float)dz,(float)settled),surface,new Vector4(color.X,color.Y,color.Z,(float)lowland),flow);if(nodes.Count>=LIMIT)nodes.Clear();nodes[cell]=result;return result;
    }
    public double _hermite(double v0,double v1,double d0,double d1,double t){double t2=t*t,t3=t2*t;return (2*t3-3*t2+1)*v0+(t3-2*t2+t)*d0+(-2*t3+3*t2)*v1+(t3-t2)*d1;}
    public double _hermite_d(double v0,double v1,double d0,double d1,double t)=>(6*t*t-6*t)*v0+(3*t*t-4*t+1)*d0+(-6*t*t+6*t)*v1+(3*t*t-2*t)*d1;
    public Vector2 gradient(double x,double z)
    {
        var q=new Vector2((float)x,(float)z)/(float)STEP;var cell=Cell(q);var f=q-Point(cell);var av=Node(cell).Height;if(f==Vector2.Zero)return new Vector2(av.Y,av.Z);var bv=Node(cell+Vector2I.Right).Height;var cv=Node(cell+Vector2I.Down).Height;var dv=Node(cell+Vector2I.One).Height;double tx=f.X,ty=f.Y,sx=tx*tx*(3-2*tx),dsx=6*tx*(1-tx),hx0=_hermite(av.X,bv.X,av.Y*STEP,bv.Y*STEP,tx),hx1=_hermite(cv.X,dv.X,cv.Y*STEP,dv.Y*STEP,tx),dx0=_hermite_d(av.X,bv.X,av.Y*STEP,bv.Y*STEP,tx)/STEP,dx1=_hermite_d(cv.X,dv.X,cv.Y*STEP,dv.Y*STEP,tx)/STEP;return new Vector2((float)_hermite(dx0,dx1,((double)bv.Z-av.Z)*dsx,((double)dv.Z-cv.Z)*dsx,ty),(float)(_hermite_d(hx0,hx1,L(av.Z,bv.Z,sx)*STEP,L(cv.Z,dv.Z,sx)*STEP,ty)/STEP));
    }
    public double sample(double x,double z)=>sample(x,z,true);
    public double sample(double x,double z,bool publish)
    {
        var q=new Vector2((float)x,(float)z)/(float)STEP;var cell=Cell(q);var f=q-Point(cell);var aa=cell==quadCell?quad[0]:Node(cell);if(f==Vector2.Zero){last_lowland=aa.Region.W;b=publish?new Vector4(aa.Surface.X,aa.Surface.Y,0,0):Vector4.Zero;if(publish){a=new Vector4(aa.Region.X,aa.Region.Y,aa.Region.Z,(float)Math.Clamp(aa.Height.W/12.0,0,1));c=new Vector4(aa.Surface.Z,aa.Surface.W,(float)(aa.Flow.X*.5+.5),(float)(aa.Flow.Y*.5+.5));last_moraine=aa.Flow.Z;last_drift=aa.Flow.W;}return aa.Height.X;}
        if(cell!=quadCell){quad=new[]{aa,Node(cell+Vector2I.Right),Node(cell+Vector2I.Down),Node(cell+Vector2I.One)};quadCell=cell;}var bb=quad[1];var cc=quad[2];var dd=quad[3];var av=aa.Height;var bv=bb.Height;var cv=cc.Height;var dv=dd.Height;double hx0=_hermite(av.X,bv.X,av.Y*STEP,bv.Y*STEP,f.X),hx1=_hermite(cv.X,dv.X,cv.Y*STEP,dv.Y*STEP,f.X),blend=(double)f.X*f.X*(3-2*(double)f.X),h=_hermite(hx0,hx1,L(av.Z,bv.Z,blend)*STEP,L(cv.Z,dv.Z,blend)*STEP,f.Y);var region=aa.Region.Lerp(bb.Region,f.X).Lerp(cc.Region.Lerp(dd.Region,f.X),f.Y);last_lowland=region.W;if(!publish){b=Vector4.Zero;return h;}var surface=aa.Surface.Lerp(bb.Surface,f.X).Lerp(cc.Surface.Lerp(dd.Surface,f.X),f.Y);var flow=aa.Flow.Lerp(bb.Flow,f.X).Lerp(cc.Flow.Lerp(dd.Flow,f.X),f.Y);double depth=L(L(av.W,bv.W,f.X),L(cv.W,dv.W,f.X),f.Y);a=new Vector4(region.X,region.Y,region.Z,(float)Math.Clamp(depth/12,0,1));b=new Vector4(surface.X,surface.Y,0,0);c=new Vector4(surface.Z,surface.W,(float)(flow.X*.5+.5),(float)(flow.Y*.5+.5));last_moraine=flow.Z;last_drift=flow.W;return h;
    }
    public double freeze(Vector2 p,double coverage,double cold){if(coverage<=0||cold<=0)return 0;if(coverage>=1)return cold;double field=.5+Noise(macro,p.X*.65+2719,p.Y*.65-919)*.35+Noise(meso,p.X+1931,p.Y-711)*.45;return (1-Smooth(coverage-.035,coverage+.035,field))*cold;}
    public float[] pack()
    {
        static double Q(float v)=>Math.Round(Math.Clamp(v,0,1)*255.0,MidpointRounding.AwayFromZero);return new[]{(float)(Q(a.X)+Q(a.Y)*256+Q(a.Z)*65536),(float)(Q(a.W)+Q(b.X)*256+Q(b.Y)*65536),(float)(Q(b.Z)+Q(b.W)*256+Q(c.X)*65536),(float)(Q(c.Y)+Q(c.Z)*256+Q(c.W)*65536)};
    }
}
