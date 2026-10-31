using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using PredatorIsle.Terrain;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class RockyCoastSampler : RefCounted
{
    public A NAMES {get;}=new() {"Towering cliffs","Rugged shore","Headlands","Sheltered coves","Wave-cut platforms","Boulder/shingle","Sea stacks","Granite highlands","Sedimentary cliffs","Dark rocky coast","Fjord-like inlets","Coastal plateau","Wave-battered coast","Sheltered inlets","Low rocky islands","Coastal ravines"};
    public Resource settings {get;set;}=null!;
    public GodotObject? beach {get;set;}
    public long seed_value {get;set;}
    public WeakRef? _host {get;set;}
    public FastNoiseLite _macro {get;}=new();
    public FastNoiseLite _meso {get;}=new();
    public FastNoiseLite _detail {get;}=new();
    private readonly Dictionary<Vector2I,double[]> _nodes=new(),_patches=new();
    private readonly Dictionary<Vector2I,float[]> _regions=new();
    private readonly Dictionary<Vector2I,A> _formations=new();
    public double[] state {get;set;}=System.Array.Empty<double>();
    public double[] neutral {get;set;}=System.Array.Empty<double>();
    public bool profile {get;set;}
    public D timings {get;set;}=new();
    private static readonly double[] Heights={1.1,.2,.9,.15,.3,.25,.65,.7,.9,.5,1,.9,.7,.18,.1,.4};
    private GodotObject Host()=>_host!.GetRef().AsGodotObject();
    private readonly TerrainParameterSnapshot numericSettings=new();
    private TerrainParameterSnapshot? beachNumbers;
    private double P(string key)=>numericSettings[key];
    private Resource BeachSettings()=>beach!.Get("settings").As<Resource>();
    private double B(string key){if(beachNumbers is null){beachNumbers=new TerrainParameterSnapshot();beachNumbers.Capture(BeachSettings());}return beachNumbers[key];}
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static Vector2I Cell(Vector2 p,double step)=>new((int)Math.Floor(p.X/step),(int)Math.Floor(p.Y/step));
    public void configure(Resource config,long seed,RefCounted host)
    {
        settings=config;numericSettings.Capture(config);beachNumbers=null;seed_value=seed;_host?.Dispose();_host=GodotObject.WeakRef(host);beach=null;
        if(host.Get("settings").AsGodotObject().Get("beaches_enabled").AsBool()){var sand=new BeachSampler();sand.configure(host.Get("settings").AsGodotObject().Get("beach").As<Resource>(),this);beach=sand;}
        neutral=new double[21];state=neutral;var noises=new[]{_macro,_meso,_detail};int[] seeds={31013,31039,31051};double[] frequencies={1/P("bay_scale"),1.0/220,1.0/48};
        for(int i=0;i<3;i++){var n=noises[i];n.Seed=unchecked((int)(seed+seeds[i]));n.Frequency=(float)frequencies[i];n.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;n.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;n.FractalOctaves=2;n.FractalGain=.3f;}
        _nodes.Clear();_patches.Clear();_regions.Clear();_formations.Clear();timings.Clear();
    }
    public double random(long x,long z,long salt){long h=unchecked(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (double)(h^(h>>16))/2147483647;}
    public float[] _region_node(Vector2I cell)
    {
        if(_regions.TryGetValue(cell,out var found))return found;var p=(Vector2)cell*512;double span=P("region_metres"),closest=double.PositiveInfinity;var center=Cell(p,span);var sites=new List<(double Distance,int Kind)>();
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++){var q=center+new Vector2I(x,z);var point=((Vector2)q+new Vector2((float)(.15+random(q.X,q.Y,3)*.7),(float)(.15+random(q.X,q.Y,5)*.7)))*(float)span;double d=p.DistanceTo(point);closest=Math.Min(closest,d);sites.Add((d,Math.Min(15,(int)(random(q.X,q.Y,7)*16))));}
        var result=new float[16];double total=0;foreach(var item in sites){double amount=1-Smooth(0,span*.22,item.Distance-closest);result[item.Kind]=(float)(result[item.Kind]+amount);total+=amount;}for(int i=0;i<16;i++)result[i]=(float)(result[i]/Math.Max(total,.001));if(_regions.Count>=2048)_regions.Clear();_regions[cell]=result;return result;
    }
    public float[] region_weights(Vector2 p)
    {
        var q=p/512;var cell=Cell(q,1);var f=q-(Vector2)cell;var a=_region_node(cell);var b=_region_node(cell+Vector2I.Right);var d=_region_node(cell+Vector2I.Down);var e=_region_node(cell+Vector2I.One);if(a.SequenceEqual(b)&&a.SequenceEqual(d)&&a.SequenceEqual(e))return a;
        var result=new float[16];for(int i=0;i<16;i++)result[i]=(float)Lerp(Lerp(a[i],b[i],f.X),Lerp(d[i],e[i],f.X),f.Y);return result;
    }
    public double max_width(){double rock=P("influence_width")*3.5+P("stack_size")*4+500;return beach==null?rock:Math.Max(rock,Math.Max(2500,B("beach_width")*(1+2.4*B("width_variation"))+B("foredune_width")*1.35+1600)+500);}
    public double influence_width(float[] w,double a)=>P("influence_width")*(.65+w[0]*.8+w[7]*.4+w[11]*.5+w[10]*.6)*(1+a*.25);
    public bool may_affect(double x,double z,double distance_hint)
    {
        if(beach!=null)
        {
            if(Math.Abs(distance_hint)>max_width()*2){state=neutral;return false;}
            if(x%8==0&&z%8==0){var p=new Vector2((float)x,(float)z);var w=region_weights(p);double a=_macro.GetNoise2D((float)x,(float)z),sandWidth=Math.Max(2500,B("beach_width")*(1+2.4*B("width_variation"))+B("foredune_width")*1.35+1600);if(Math.Abs(distance_hint)>2*influence_width(w,a)){double shore=beach is BeachSampler native?native.shore_distance(p):beach.Call("shore_distance",p).AsDouble();if(Math.Abs(shore)>sandWidth+500){state=neutral;return false;}}}return true;
        }
        if(P("coverage")<=0||Math.Abs(distance_hint)>max_width()){state=neutral;return false;}if(x%8!=0||z%8!=0)return true;
        var point=new Vector2((float)x,(float)z);var weights=region_weights(point);double macro=_macro.GetNoise2D(point.X,point.Y);if(Math.Abs(distance_hint)>2*influence_width(weights,macro)){state=neutral;return false;}if(P("coverage")<.999){double selector=_macro.GetNoise2D((float)(point.X*.23+81731),(float)(point.Y*.23-73191))*.5+.5;if(selector>=P("coverage")+.08){state=neutral;return false;}}return true;
    }
    public Vector3 coast_frame(Vector2 p)
    {
        var host=Host();double radius=Math.Max(host.Get("settings").AsGodotObject().Get("island_size").AsDouble()*.5,8),d=Mask(p.X,p.Y)*radius;
        var g=new Vector2((float)(Mask((double)p.X+16,p.Y)-Mask((double)p.X-16,p.Y)),(float)(Mask(p.X,(double)p.Y+16)-Mask(p.X,(double)p.Y-16)))*(float)radius/32;double length=g.Length();g/=(float)Math.Max(length,.001);return new Vector3((float)(d/Math.Clamp(length,.5,2)),g.X,g.Y);
        double Mask(double x,double z)=>host.Call("_island_mask",x,z).AsDouble();
    }
    public A _formation_sites(Vector2I cell)
    {
        if(_formations.TryGetValue(cell,out var found))return found;var result=new A();for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var q=cell+new Vector2I(x,z);double roll=random(q.X,q.Y,431);if(roll>P("stack_frequency"))continue;var p=((Vector2)q+new Vector2((float)(.2+random(q.X,q.Y,433)*.6),(float)(.2+random(q.X,q.Y,439)*.6)))*768;var unit=p/128;p=new Vector2((float)Math.Round(unit.X,MidpointRounding.AwayFromZero),(float)Math.Round(unit.Y,MidpointRounding.AwayFromZero))*128;var frame=coast_frame(p);if(frame.X>-100||frame.X< -650)continue;result.Add(new A {p,roll,frame.X});
        }
        if(_formations.Count>=512)_formations.Clear();_formations[cell]=result;return result;
    }
    public double inherited_river(Vector2 p)
    {
        var host=Host();double frequency=host.Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),river=0;if(frequency<=0)return river;double spacing=4000/Math.Max(frequency,.1);long lane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);for(int k=-1;k<=1;k++)river=Math.Max(river,1-Smooth(18,80,Math.Abs(p.Y-host.Call("_grass_river_center",p.X,lane+k,spacing).AsDouble())));return river;
    }
    public double inherited_river_distance(Vector2 p)
    {
        var host=Host();double frequency=host.Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),distance=double.PositiveInfinity;if(frequency<=0)return distance;double spacing=4000/Math.Max(frequency,.1);long lane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);for(int k=-1;k<=1;k++)distance=Math.Min(distance,Math.Abs(p.Y-host.Call("_grass_river_center",p.X,lane+k,spacing).AsDouble()));return distance;
    }
    public double[] _raw(Vector2 p)
    {
        if(beach==null)return _raw_rock(p);var frame=coast_frame(p);var w=region_weights(p);double a=_macro.GetNoise2D(p.X,p.Y),b=_meso.GetNoise2D(p.X,p.Y),c=_detail.GetNoise2D(p.X,p.Y),riverDistance=inherited_river_distance(p),river=1-Smooth(18,80,riverDistance);var s=beach is BeachSampler native?native.evaluate(p,frame,w,a,b,c,riverDistance):beach.Call("evaluate",p,frame,w,a,b,c,riverDistance).AsFloat64Array();
        if(s[1]>=1){var result=new double[21];result[0]=s[0];result[2]=1;result[3]=s[2];result[4]=s[3];result[5]=s[4];result[6]=frame.X;result[7]=frame.Y;result[8]=frame.Z;result[18]=river;result[19]=1;result[20]=s[2];return result;}
        var combinedResult=_raw_rock(p);double combined=Lerp(combinedResult[2],1,s[1]);if(combined>0){double amount=s[1]/combined;combinedResult[0]=Lerp(combinedResult[0],s[0],amount);combinedResult[1]*=1-amount;combinedResult[19]=amount;}combinedResult[2]=combined;combinedResult[20]=s[2];return combinedResult;
    }
    public double[] _raw_rock(Vector2 p)
    {
        long start=profile?(long)Time.GetTicksUsec():0;var frame=coast_frame(p);double originalD=frame.X;var n=new Vector2(frame.Y,frame.Z);var tangent=new Vector2(-n.Y,n.X);var weights=region_weights(p);Span<double> w=stackalloc double[16];for(int i=0;i<16;i++)w[i]=weights[i];int id=0;for(int i=1;i<16;i++)if(w[i]>w[id])id=i;
        double a=_macro.GetNoise2D(p.X,p.Y),b=_meso.GetNoise2D(p.X,p.Y),c=_detail.GetNoise2D(p.X,p.Y),selector=_macro.GetNoise2D((float)(p.X*.23+81731),(float)(p.Y*.23-73191))*.5+.5,ownership=1-Smooth(P("coverage")-.08,P("coverage")+.08,selector);if(P("coverage")>=.999)ownership=1;if(P("coverage")<=0)ownership=0;
        double width=influence_width(weights,a),influence=ownership*(1-Smooth(width*.6,width,Math.Abs(originalD))),headland=a*P("headlands")*(300+w[2]*450-w[3]*120),d=originalD+headland*(1-Smooth(width*.35,width*.9,Math.Abs(originalD))),exposure=Math.Clamp(.55+.4*(-n).Dot(new Vector2(.8f,-.6f))+a*.15-w[3]*.35-w[13]*.35,0,1),platform=Math.Clamp((w[1]*.5+w[4]+w[5]*.5+w[7]*.35+w[9]*.5+w[14]*.7)*P("platform_frequency")*1.5,0,1),shelfWidth=P("platform_width")*(.25+platform)*(1+b*.25),height=0;
        for(int i=0;i<16;i++)height+=w[i]*Heights[i];height*=P("cliff_height")*(.8+a*.25+b*.15)*P("cliff_frequency");double cliffWidth=P("cliff_width")*(1+w[3]*1.8+w[5]+w[14]*1.2+w[7]*.5),rise=Smooth(shelfWidth*.5+b*20,shelfWidth*.5+cliffWidth+b*20,d),platformH=1.5+(b*.7+c*.3)*P("platform_relief"),h=platformH+rise*height+Math.Max(d-shelfWidth-cliffWidth,0)*.035,submerged=-6-(1-platform)*10;h=Lerp(submerged,h,Smooth(-shelfWidth,0,d));
        double weather=(1-Smooth(.03,.3,Math.Abs(b+c*.15)))*P("erosion")*rise*(1-rise*.6);h-=weather*(12+w[15]*30);h+=Math.Sin(d/34+b*1.5)*rise*(1-rise)*8*w[8];h+=c*P("ruggedness")*(3+w[5]*4)*Smooth(-20,80,d);
        var host=Host();double frequency=host.Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),spacing=4000/Math.Max(frequency,.1),river=0;if(frequency>0){long lane=(long)Math.Round(p.Y/spacing,MidpointRounding.AwayFromZero);for(int k=-1;k<=1;k++)river=Math.Max(river,1-Smooth(18,80+w[13]*100,Math.Abs(p.Y-host.Call("_grass_river_center",p.X,lane+k,spacing).AsDouble())));}
        double inlet=(1-Smooth(.015,.12,Math.Abs(b)))*(w[10]+w[13]+w[15]*.6)*P("inlet_frequency"),outlet=Math.Max(river,inlet)*(1-Smooth(width*.45,width*.95,Math.Max(d,0)));h=Lerp(h,-1.2+Math.Max(d,0)*.001,outlet);double stack=0;
        if(originalD<100&&originalD> -850&&w[6]+w[2]+w[7]+w[14]>.1)foreach(var value in _formation_sites(Cell(p,768)))
        {
            var site=value.AsGodotArray();double roll=site[1].AsDouble(),size=P("stack_size")*(.7+roll*2);var q=p-site[0].AsVector2();double length=new Vector2((float)(q.Dot(tangent)/size),(float)(q.Dot(n)/(size*.65))).Length(),shape=1-Smooth(.25,.95,length+Math.Sin(q.Dot(tangent)/100.0)*.1),tower=shape*(45+height*(.5+roll))-8;h=Math.Max(h,tower);stack=Math.Max(stack,shape);
        }
        double pool=0,poolWater=0,connectedPool=0;
        if(platform>.12&&rise<.2&&outlet<.1&&d> -40&&d<shelfWidth*.7)
        {
            var cell=Cell(p,96);for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
            {
                var k=cell+new Vector2I(x,z);double r=random(k.X,k.Y,503);if(r>P("pool_frequency"))continue;var center=((Vector2)k+new Vector2((float)(.2+random(k.X,k.Y,509)*.6),(float)(.2+random(k.X,k.Y,521)*.6)))*96;var delta=p-center;double size=P("pool_size")*(.65+r*.8),contour=new Vector2((float)(delta.Dot(tangent)/size),(float)(delta.Dot(n)/(size*(.45+r)))).Length()+c*.15;bool compound=r<P("pool_frequency")*.35;
                if(compound){var second=delta-tangent*(float)size*.8f-n*(float)size*.3f;contour=Math.Min(contour,new Vector2((float)(second.Dot(tangent)/(size*.85)),(float)(second.Dot(n)/(size*.7))).Length()+c*.1);}double support=1-Smooth(.6,1.25,contour),bed=1-Smooth(.15,.7,contour);h=Lerp(h,1.8+(.4-bed*(.4+P("pool_depth"))),support*platform);pool=Math.Max(pool,bed*support*platform);poolWater=Math.Max(poolWater,1.8*support);if(compound)connectedPool=Math.Max(connectedPool,bed*support*platform);
            }
        }
        double sediment=Math.Clamp((w[3]+w[5]+w[13]*.6)*(1-exposure*.5)*(1-rise)*(1-stack),0,1);if(profile)timings["coastal_fields_us"]=(timings.ContainsKey("coastal_fields_us")?timings["coastal_fields_us"].AsInt64():0)+(long)Time.GetTicksUsec()-start;
        return new[]{h,poolWater,influence,(double)id/15,exposure,sediment,originalD,(double)frame.Y,frame.Z,rise,height,headland,platform,pool,stack,outlet,weather,connectedPool,river,0,0};
    }
    public double[] _node(Vector2I cell)
    {if(_nodes.TryGetValue(cell,out var found))return found;var result=_raw((Vector2)cell*8);if(_nodes.Count>=8192)_nodes.Clear();_nodes[cell]=result;return result;}
    public double cubic(double a,double b,double c,double d,double t)=>b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)));
    public double bounded_influence(double value){if(value<.05)return Math.Max(value,0)*Smooth(0,.05,value);if(value>.95)return 1-Math.Max(1-value,0)*Smooth(0,.05,1-value);return value;}
    public double sample(double x,double z,double baseline,double distance_hint)=>sample(x,z,baseline,distance_hint,true);
    public double sample(double x,double z,double baseline,double distance_hint,bool publish)
    {
        if(Math.Abs(distance_hint)>max_width()*(beach!=null?2:1)||(P("coverage")<=0&&beach==null)){if(publish)state=neutral;return baseline;}double qx=x/8,qz=z/8;var cell=new Vector2I((int)Math.Floor(qx),(int)Math.Floor(qz));var f=new Vector2((float)(qx-cell.X),(float)(qz-cell.Y));
        if(f==Vector2.Zero){var exact=(double[])_node(cell).Clone();exact[2]=bounded_influence(exact[2]);if(publish)state=exact;return Lerp(baseline,exact[0],exact[2]);}
        var coefficients=_patch(cell);var s=new double[21];Span<double> column=stackalloc double[4];for(int k=0;k<3;k++){int first=k*16;for(int i=0;i<4;i++){int offset=first+i*4;column[i]=coefficients[offset]+f.Y*(coefficients[offset+1]+f.Y*(coefficients[offset+2]+f.Y*coefficients[offset+3]));}s[k]=column[0]+f.X*(column[1]+f.X*(column[2]+f.X*column[3]));}
        for(int k=3;k<21;k++){int offset=48+(k-3)*4;s[k]=coefficients[offset]+coefficients[offset+1]*f.X+coefficients[offset+2]*f.Y+coefficients[offset+3]*f.X*f.Y;}s[2]=bounded_influence(s[2]);s[3]=Math.Clamp(s[3],0,1);s[4]=Math.Clamp(s[4],0,1);s[5]=Math.Clamp(s[5],0,1);s[1]=Math.Max(s[1],0);if(publish)state=s;return Lerp(baseline,s[0],s[2]);
    }
    public double[] polynomial(double a,double b,double c,double d)=>new[]{b,(c-a)*.5,a-2.5*b+2*c-.5*d,-.5*a+1.5*b-1.5*c+.5*d};
    public double[] _patch(Vector2I cell)
    {
        if(_patches.TryGetValue(cell,out var found))return found;var nodes=new double[16][];int at=0;for(int z=-1;z<3;z++)for(int x=-1;x<3;x++)nodes[at++]=_node(cell+new Vector2I(x,z));var result=new double[120];
        for(int k=0;k<3;k++){var rows=new double[4][];for(int row=0;row<4;row++)rows[row]=polynomial(nodes[row*4][k],nodes[row*4+1][k],nodes[row*4+2][k],nodes[row*4+3][k]);for(int column=0;column<4;column++){var p=polynomial(rows[0][column],rows[1][column],rows[2][column],rows[3][column]);for(int j=0;j<4;j++)result[k*16+column*4+j]=p[j];}}
        for(int k=3;k<21;k++){double a=nodes[5][k],b=nodes[6][k],c=nodes[9][k],d=nodes[10][k];int offset=48+(k-3)*4;result[offset]=a;result[offset+1]=b-a;result[offset+2]=c-a;result[offset+3]=d-b-c+a;}if(_patches.Count>=2048)_patches.Clear();_patches[cell]=result;return result;
    }
    internal int NodeCount=>_nodes.Count;
    internal int PatchCount=>_patches.Count;
    internal int RegionCount=>_regions.Count;
    internal int FormationCount=>_formations.Count;
    public void clear_numeric_caches()=>clear_numeric_caches(true);
    public void clear_numeric_caches(bool include_regions)
    {_nodes.Clear();_patches.Clear();if(include_regions){_regions.Clear();_formations.Clear();}}
    public D cache_counts()=>new() {["nodes"]=_nodes.Count,["patches"]=_patches.Count,["regions"]=_regions.Count,["formations"]=_formations.Count};
    public A formation_cache_values(){var result=new A();foreach(var value in _formations.Values)result.Add(value);return result;}
}
