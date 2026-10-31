using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Canonical sedimentary terrain cut by finite, world-anchored drainage trees.</summary>
public partial class BadlandsSampler : RefCounted
{
    public A NAMES {get;}=new(){"Painted hills","Red mudstone","Gray clay","Bentonite hills","Eroded ridge country","Hoodoo country","Badlands canyon","Dissected plateau","Sediment basin","Dry wash country","Stratified clay hills","Pale badlands","Rocky highlands","Stratified escarpment","Sediment fans","Barren plain"};
    private static readonly double[] Reliefs={150,200,100,115,300,180,340,340,38,85,160,180,390,300,75,18};
    public A REGION_RELIEFS {get;}=new(){150,200,100,115,300,180,340,340,38,85,160,180,390,300,75,18};
    public double STEP {get;}=16;
    public long CHANNELS {get;}=16;
    public Resource settings {get;set;}=null!;
    public WeakRef? _host {get;set;}
    public long seed_value {get;set;}
    public FastNoiseLite _macro {get;}=new();
    public FastNoiseLite _weather {get;}=new();
    public double[] state {get;set;}=System.Array.Empty<double>();
    public Vector4 palette_state {get;set;}
    public double remnant_delta {get;set;}
    public bool profile {get;set;}
    public D timings {get;set;}=new();
    public bool _use_segment_index {get;set;}=true;
    public bool _use_grade_bound {get;set;}=true;
    public long _tree_radius_override {get;set;}
    private readonly Dictionary<Vector2I,double[]> _nodes=new();
    private readonly Queue<Vector2I> _nodeOrder=new(),_patchOrder=new();
    private sealed record Patch(double[] Coefficients,double[][] Corners);
    private sealed record Edge(Vector3 A,Vector3 B,int Order);
    private sealed record Tree(D Data,Vector3 Root,double Random,Vector4 Support,Vector4[] Bounds,Vector4[] Vectors,Vector4[] Metrics,Dictionary<Vector2I,int[]> Cells,double GradeScale);
    private readonly Dictionary<Vector2I,Patch> _patches=new();
    private readonly Dictionary<Vector2I,float[]> _regions=new();
    private readonly Dictionary<Vector3I,Tree> _trees=new();
    private readonly Dictionary<Vector2I,double> _carriers=new();
    private readonly BadlandsFanGeometry _fan=new();
    private GodotObject Host()=>_host!.GetRef().AsGodotObject();
    private double P(string name)=>settings.Get(name).AsDouble();
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static Vector2 Normalize(Vector2 p)=>p.LengthSquared()==0?p:p.Normalized();
    private static Vector2 Rotate(Vector2 p,double value){float angle=(float)value,c=(float)Math.Cos(angle),s=(float)Math.Sin(angle);return new(p.X*c-p.Y*s,p.X*s+p.Y*c);}
    private static Vector2I Cell(Vector2 p,double step)=>new((int)Math.Floor(p.X/step),(int)Math.Floor(p.Y/step));
    private static long Lane(double value)=>(long)Math.Round(value,MidpointRounding.AwayFromZero);
    public void configure(Resource config,long world_seed,RefCounted host)
    {
        settings=config;seed_value=world_seed;_host?.Dispose();_host=GodotObject.WeakRef(host);
        var noises=new[]{_macro,_weather};int[] salts={31013,31039};double[] frequencies={1.0/2900,1.0/380};
        for(int i=0;i<2;i++){var n=noises[i];n.Seed=unchecked((int)(world_seed+salts[i]));n.Frequency=(float)frequencies[i];n.NoiseType=FastNoiseLite.NoiseTypeEnum.SimplexSmooth;n.FractalType=FastNoiseLite.FractalTypeEnum.Fbm;n.FractalOctaves=2;n.FractalGain=.3f;}
        clear_numeric_caches();timings.Clear();
    }
    public double random(long x,long z,long salt){long h=unchecked(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (double)(h^(h>>16))/2147483647;}
    public float[] _region(Vector2I cell)
    {
        if(_regions.TryGetValue(cell,out var found))return found;
        var p=(Vector2)cell*256;double span=P("region_metres"),closest=double.PositiveInfinity;var center=Cell(p,span);var sites=new List<(double Distance,int Kind)>();
        double[] occurrence={P("painted_frequency"),.5,P("clay_frequency"),P("clay_frequency")*.6,P("rugged_frequency"),.18,.25,.3,P("basin_frequency"),.3,.4,.4,P("rugged_frequency")*.5,.25,.25,P("basin_frequency")*.7};double mass=0;foreach(double v in occurrence)mass+=v;
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var q=center+new Vector2I(x,z);var site=((Vector2)q+new Vector2((float)(.2+random(q.X,q.Y,1)*.6),(float)(.2+random(q.X,q.Y,2)*.6)))*(float)span;
            double roll=random(q.X,q.Y,3)*mass;int id=15;for(int i=0;i<16;i++){roll-=occurrence[i];if(roll<=0){id=i;break;}}
            double distance=p.DistanceTo(site);closest=Math.Min(closest,distance);sites.Add((distance,id));
        }
        var weights=new float[16];double total=0;foreach(var site in sites){double amount=1-Smooth(0,span*.2,site.Distance-closest);weights[site.Kind]=(float)(weights[site.Kind]+amount);total+=amount;}for(int i=0;i<16;i++)weights[i]=(float)(weights[i]/Math.Max(total,.00001));
        if(_regions.Count>=2048)_regions.Clear();_regions[cell]=weights;return weights;
    }
    public float[] region_weights(Vector2 p)
    {
        var q=p/256;var cell=Cell(q,1);var f=q-(Vector2)cell;var a=_region(cell);var b=_region(cell+Vector2I.Right);var c=_region(cell+Vector2I.Down);var d=_region(cell+Vector2I.One);
        if(a.SequenceEqual(b)&&a.SequenceEqual(c)&&a.SequenceEqual(d))return a;
        f=new Vector2((float)Smooth(0,1,f.X),(float)Smooth(0,1,f.Y));var result=new float[16];for(int i=0;i<16;i++)result[i]=(float)Lerp(Lerp(a[i],b[i],f.X),Lerp(c[i],d[i],f.X),f.Y);return result;
    }
    public Vector4 material_palette(Vector2 p){var w=region_weights(p);return new((float)((double)w[2]+w[3]),(float)((double)w[8]+w[15]),(float)(w[1]+w[10]*.5),w[11]);}
    public double _spacing()=>4000/Math.Max(Host().Get("settings").AsGodotObject().Get("grass_river_frequency").AsDouble(),.01);
    public double _carrier(double x,long lane)=>Host().Call("_grass_river_center",x,lane,_spacing()).AsDouble();
    public double _carrier_node(long index,long lane)
    {var key=new Vector2I(unchecked((int)index),unchecked((int)lane));if(_carriers.TryGetValue(key,out double found))return found;double value=_carrier(index*1024.0,lane);if(_carriers.Count>=2048)_carriers.Clear();_carriers[key]=value;return value;}
    public double _broad_carrier(double x,long lane){double q=x/1024;long i=(long)Math.Floor(q);return cubic(_carrier_node(i-1,lane),_carrier_node(i,lane),_carrier_node(i+1,lane),_carrier_node(i+2,lane),q-i);}
    public D _tree(long index,long lane,long side)=>GetTree(index,lane,side).Data;
    private Tree GetTree(long index,long lane,long side)
    {
        var key=new Vector3I(unchecked((int)index),unchecked((int)lane),unchecked((int)side));if(_trees.TryGetValue(key,out var found))return found;
        double r=random(index,lane,41+side),span=P("drainage_spacing"),x=(index+.25+r*.5)*span,extent=_spacing()*(.32+r*.09);
        var root=new Vector3((float)x,28,(float)_carrier(x,lane));var junction=root+new Vector3((float)((r-.5)*span*.4),(float)(extent*.025),(float)(side*extent*.36));
        var edges=new List<Edge>{new(root,junction,0)};var ends=new List<Vector3>();double[] stationBase={.06,.28,.63},stationScale={.18,.33,.30};
        foreach(int branch in new[]{-1,1})
        {
            double b=random(index,lane,55+branch*3+side);var shoulder=junction+new Vector3((float)(branch*span*(.18+b*.14)),(float)(extent*.033),(float)(side*extent*.36));
            var top=shoulder+new Vector3((float)(branch*span*(.08+b*.12)),(float)(extent*.03),(float)(side*extent*.28));edges.Add(new(junction,shoulder,1));edges.Add(new(shoulder,top,1));ends.Add(top);
            for(int station=0;station<3;station++)foreach(int twig in new[]{-1,1})
            {
                double variation=random(index,lane,83+station*17+twig*5+branch*3+side),t=stationBase[station]+variation*stationScale[station];var join=shoulder.Lerp(top,(float)t);
                var parent=Normalize(new Vector2((float)((double)top.X-shoulder.X),(float)((double)top.Z-shoulder.Z)));var direction=Rotate(parent,twig*(.5+variation*.65));double reach=span*(.13+variation*.13);
                var end=join+new Vector3((float)(direction.X*reach),(float)(extent*(.017+variation*.014)),(float)(direction.Y*reach));edges.Add(new(join,end,2));if(station==1)ends.Add(end);
            }
        }
        int parentCount=edges.Count;
        for(int i=0;i<parentCount;i++)
        {
            var edge=edges[i];if(edge.Order!=2)continue;
            foreach(int k in new[]{-1,1})
            {
                double t=.35+random(index,lane,i*11+k+side)*.3,variation=random(index,lane,1703+i*29+k*7+side);var join=edge.A.Lerp(edge.B,(float)t);
                var direction=Rotate(Normalize(new Vector2((float)((double)edge.B.X-edge.A.X),(float)((double)edge.B.Z-edge.A.Z))),k*(.45+variation*.7));double reach=span*(.045+variation*.075);
                var end=join+new Vector3((float)(direction.X*reach),(float)(extent*(.009+variation*.016)),(float)(direction.Y*reach));edges.Add(new(join,end,3));
            }
        }
        int sourceCount=edges.Count;
        for(int i=0;i<sourceCount;i++)
        {
            var edge=edges[i];if(edge.Order!=3)continue;double t=.4+random(index,lane,i*17+side)*.3,handed=random(index,lane,i*19+side)<.5?-1:1,variation=random(index,lane,1901+i*23+side);var join=edge.A.Lerp(edge.B,(float)t);
            var direction=Rotate(Normalize(new Vector2((float)((double)edge.B.X-edge.A.X),(float)((double)edge.B.Z-edge.A.Z))),handed*(.5+variation*.65));double reach=span*(.02+variation*.04);
            var end=join+new Vector3((float)(direction.X*reach),(float)(extent*(.004+variation*.008)),(float)(direction.Y*reach));edges.Add(new(join,end,4));
        }
        var bounds=new Vector4[edges.Count];var vectors=new Vector4[edges.Count];var metrics=new Vector4[edges.Count];var segmentLists=new Dictionary<Vector2I,List<int>>();
        double fanReach=350+391*P("relief");var support=new Vector4((float)(root.X-320.0),(float)(root.Z-fanReach),(float)(root.X+320.0),(float)(root.Z+fanReach));
        var payloadEdges=new A();
        for(int i=0;i<edges.Count;i++)
        {
            var e=edges[i];var delta=new Vector2((float)((double)e.B.X-e.A.X),(float)((double)e.B.Z-e.A.Z));
            bounds[i]=new(Math.Min(e.A.X,e.B.X),Math.Min(e.A.Z,e.B.Z),Math.Max(e.A.X,e.B.X),Math.Max(e.A.Z,e.B.Z));vectors[i]=new(e.A.X,e.A.Z,delta.X,delta.Y);
            metrics[i]=new((float)(1.0/delta.LengthSquared()),e.A.Y,(float)((double)e.B.Y-e.A.Y),e.Order);payloadEdges.Add(new A{e.A,e.B,e.Order});
            var bound=bounds[i];double bank=(390+391*P("relief"))*(e.Order>=2?1.6:1)/(1+e.Order*.4)+31;
            var low=new Vector2I((int)Math.Floor((bound.X-bank)/256),(int)Math.Floor((bound.Y-bank)/256));var high=new Vector2I((int)Math.Floor((bound.Z+bank)/256),(int)Math.Floor((bound.W+bank)/256));
            support=new((float)Math.Min(support.X,bound.X-bank),(float)Math.Min(support.Y,bound.Y-bank),(float)Math.Max(support.Z,bound.Z+bank),(float)Math.Max(support.W,bound.W+bank));
            for(int cz=low.Y;cz<=high.Y;cz++)for(int cx=low.X;cx<=high.X;cx++){var cell=new Vector2I(cx,cz);if(!segmentLists.TryGetValue(cell,out var list)){list=new();segmentLists[cell]=list;}list.Add(i);}
        }
        var cells=new Dictionary<Vector2I,int[]>();var payloadCells=new D();foreach(var pair in segmentLists){cells[pair.Key]=pair.Value.ToArray();var items=new A();foreach(int i in pair.Value)items.Add(i);payloadCells[pair.Key]=items;}
        var rootWeights=region_weights(new Vector2(root.X,root.Z));double rootRelief=0;for(int i=0;i<16;i++)rootRelief+=rootWeights[i]*Reliefs[i];double grade=Math.Clamp(rootRelief*P("relief")/300,.12,1.6);
        var payloadEnds=new A();foreach(var end in ends)payloadEnds.Add(end);
        var data=new D{["root"]=root,["edges"]=payloadEdges,["ends"]=payloadEnds,["random"]=r,["extent"]=extent,["edge_bounds"]=bounds,["edge_vectors"]=vectors,["edge_metrics"]=metrics,["segment_cells"]=payloadCells,["grade_scale"]=grade};data[new StringName("support_bounds")]=support;
        var result=new Tree(data,root,r,support,bounds,vectors,metrics,cells,grade);if(_trees.Count>=512)_trees.Clear();_trees[key]=result;return result;
    }
    public double geological_coordinate(Vector2 p,double height)
    {double beds=height+settings.Get("strata_dip").AsVector2().Dot(p)+(24*Math.Sin(p.X/5300.0+Math.Sin(p.Y/7100.0))+17*Math.Sin(p.Y/3900.0))*P("fold_strength"),unit=P("strata_metres")*.35;return beds/unit+P("thickness_variation")*Math.Sin(beds/(unit*1.7)+p.X/11000.0);}
    public Vector2 strata(Vector2 p,double height)
    {double phase=Mathf.PosMod(geological_coordinate(p,height),5),hard=Smooth(.48,.53,phase)*(1-Smooth(.67,.74,phase));hard=Math.Max(hard,Smooth(3.57,3.63,phase)*(1-Smooth(3.92,4.02,phase)));return new((float)phase,(float)hard);}
    public A _remnant_formations(D tree,long index,long lane,long side)
    {
        if(tree.ContainsKey("formations"))return tree["formations"].AsGodotArray();var formations=new A();double unit=P("strata_metres")*.35;var ends=tree["ends"].AsGodotArray();
        for(int ordinal=0;ordinal<ends.Count;ordinal++)
        {
            var end=ends[ordinal].AsVector3();long salt=ordinal*97+side;double r=random(index,lane,271+salt);var anchor=new Vector2((float)(end.X+80.0),end.Z);
            double potential=_base_sample(anchor.X,anchor.Y,false)+P("remnant_height")*(1.1+r*.6),coordinate=geological_coordinate(anchor,potential),cycle=Math.Floor(coordinate/5)*5;
            double target=Math.Max(coordinate>=cycle+.60?cycle+.60:cycle-5+.60,coordinate>=cycle+3.77?cycle+3.77:cycle-5+3.77),height=potential+(target-coordinate)*unit;
            for(int iteration=0;iteration<4;iteration++)
            {
                double beds=height+settings.Get("strata_dip").AsVector2().Dot(anchor)+(24*Math.Sin(anchor.X/5300.0+Math.Sin(anchor.Y/7100.0))+17*Math.Sin(anchor.Y/3900.0))*P("fold_strength"),derivative=(1+P("thickness_variation")/1.7*Math.Cos(beds/(unit*1.7)+anchor.X/11000.0))/unit;
                height-=(geological_coordinate(anchor,height)-target)/derivative;
            }
            formations.Add(new D{["position"]=anchor,["height"]=height,["radius"]=new Vector2((float)(22+r*28),(float)(22+random(index,lane,283+salt)*32)),["angle"]=random(index,lane,293+salt)*Math.Tau,["phase"]=r*Math.Tau,["shoulder"]=.18+random(index,lane,307+salt)*.22,["weathering"]=.9+random(index,lane,311+salt)*.35});
        }
        tree["formations"]=formations;return formations;
    }
    public double remnant_surface(Vector2 p,double baseline,bool publish)
    {
        if(P("remnants")<=0)return baseline;var weights=region_weights(p);double mass=weights[5];if(mass<=.000001)return baseline;
        double spacing=_spacing(),closest=double.PositiveInfinity;long initial=Lane(p.Y/spacing),lane=initial;
        for(int offset=-1;offset<=1;offset++){long candidate=initial+offset;double distance=Math.Abs(p.Y-_broad_carrier(p.X,candidate));if(distance<closest){closest=distance;lane=candidate;}}
        long side=p.Y<_broad_carrier(p.X,lane)?-1:1,index=(long)Math.Floor(p.X/P("drainage_spacing"));double height=baseline,influence=0;
        for(int offset=-1;offset<=1;offset++)
        {
            var tree=GetTree(index+offset,lane,side);if(tree.Random>=P("remnants"))continue;
            foreach(var item in _remnant_formations(tree.Data,index+offset,lane,side))
            {
                var f=item.AsGodotDictionary();var relative=p-f["position"].AsVector2();if(Math.Abs(relative.X)>160||Math.Abs(relative.Y)>160)continue;
                var q=Rotate(relative,-f["angle"].AsDouble())/f["radius"].AsVector2();double phase=f["phase"].AsDouble();
                double radius=Math.Pow(Math.Pow(Math.Abs((double)q.X),3)+Math.Pow(Math.Abs((double)q.Y),3),1.0/3)+Math.Sin(q.X*3.0+phase)*.06+Math.Sin(q.Y*4.0-phase)*.04,angle=Math.Atan2(q.Y,q.X),joints=Math.Pow(Math.Abs(Math.Sin(angle*5+phase)),8)*.22;
                radius+=(Math.Sin(angle*5+phase)*.10+Math.Sin(angle*9-phase)*.06+joints)*Smooth(.15,.65,radius);
                double top=f["height"].AsDouble();if(radius>=1.8||top<=height)continue;
                double shoulder=f["shoulder"].AsDouble(),core=Math.Pow(1-Smooth(shoulder,shoulder+.65,radius),f["weathering"].AsDouble()),apron=1-Smooth(.8,1.8,radius),support=(core*.86+apron*.14)*mass;
                influence=Math.Max(influence,support);height=Lerp(height,top,support);
            }
        }
        if(publish){state[0]=height;state[10]=influence;remnant_delta=height-baseline;state[4]=Math.Clamp(state[4]+influence,0,1);var beds=strata(p,height);state[11]=beds.Y;state[15]=beds.X;}return height;
    }
    public double[] _raw(Vector2 p)
    {
        long tick=profile?(long)Time.GetTicksUsec():0;var weights=region_weights(p);Span<double> w=stackalloc double[16];for(int i=0;i<16;i++)w[i]=weights[i];double macro=_macro.GetNoise2D(p.X,p.Y),weather=_weather.GetNoise2D(p.X,p.Y),relief=0;int dominant=0;
        for(int i=0;i<16;i++){relief+=w[i]*Reliefs[i];if(w[i]>w[dominant])dominant=i;}relief*=P("relief");
        double calm=Math.Clamp(w[8]+w[9]*.4+w[14]*.6+w[15],0,1),clay=Math.Clamp(w[0]*.5+w[2]+w[3]+w[10]*.6,0,1),dissected=Math.Clamp(w[4]+w[5]*.65+w[6]+w[7]+w[12]*.7+w[13],0,1),eligibility=(1-Smooth(.65,.99,calm))*Lerp(1,.4,clay),spacing=_spacing(),primary=double.PositiveInfinity;
        long initial=Lane(p.Y/spacing),lane=initial;for(int j=-1;j<=1;j++){long candidate=initial+j;double d=Math.Abs(p.Y-_broad_carrier(p.X,candidate));if(d<primary){primary=d;lane=candidate;}}
        double fine=Math.Abs(p.Y-_carrier(p.X,lane));long side=p.Y<_broad_carrier(p.X,lane)?-1:1;
        double width=P("wash_width")*(1+w[9]*1.5+w[8]),upland=1-Math.Exp(-Math.Pow(Math.Max(primary-width,0)/(900+clay*500+w[8]*700),1.6)),plateau=Smooth(.35,.72,upland+macro*.3),massHeight=relief*(.82+macro*.3)*upland,rounded=w[0]+w[2]*.8+w[3]+w[10]*.65+w[11]*.55;
        if(P("rounded_hill_strength")>0&&rounded>.000001){double broad=_weather.GetNoise2Dv(p*.45f),lobes=Math.Pow(Math.Clamp(.5+weather*.8+broad*.35,0,1),1.35),height=relief*(.15+.95*lobes+macro*.08)*upland;massHeight=Lerp(massHeight,height,Math.Clamp(rounded*P("rounded_hill_strength"),0,1));}
        double h=28+(massHeight+relief*.25*plateau*(w[7]+w[13])),main=1-Smooth(width*.5,width*2,fine);h=Lerp(h,Math.Min(h,25+weather*.8),main);
        double drainage=main,second=0,fan=0,remnant=0,depositSum=0,depositWeight=0,protection=main,nearest=double.PositiveInfinity;long index=(long)Math.Floor(p.X/P("drainage_spacing"));var segmentCell=Cell(p,256);
        Span<double> banks=stackalloc double[5],floors=stackalloc double[5];for(int order=0;order<5;order++){banks[order]=(390+relief)*(1-calm*.55)/(1+order*(.4+dissected*.18))*(order>=2?1-clay*.45:1)*(order>=2?1+dissected*.6:1);floors[order]=24.0/(1+order*.6);}
        long treeRadius=(long)Math.Ceiling((P("drainage_spacing")*1.5+(390+391*P("relief"))*1.6/1.8)/P("drainage_spacing"));if(_tree_radius_override>0)treeRadius=_tree_radius_override;
        for(long j=-treeRadius;j<=treeRadius;j++)
        {
            var tree=GetTree(index+j,lane,side);var root=tree.Root;var support=tree.Support;if(p.X<support.X||p.Y<support.Y||p.X>support.Z||p.Y>support.W)continue;
            int[]? candidates=null;if(_use_segment_index&&!tree.Cells.TryGetValue(segmentCell,out candidates))candidates=System.Array.Empty<int>();int count=_use_segment_index?candidates!.Length:tree.Metrics.Length;
            for(int ci=0;ci<count;ci++)
            {
                int ei=_use_segment_index?candidates![ci]:ci;var metric=tree.Metrics[ei];int order=(int)metric.W;
                if(_use_grade_bound&&28+((double)metric.Y-28+Math.Min(metric.Z,0))*tree.GradeScale>=h)continue;
                if(order>=2&&(P("secondary_gullies")<=0||eligibility<=0))continue;if(order==4&&dissected<=.05)continue;
                double bank=banks[order];var bound=tree.Bounds[ei];if(p.X<bound.X-bank-30||p.Y<bound.Y-bank-30||p.X>bound.Z+bank+30||p.Y>bound.W+bank+30)continue;
                var segment=tree.Vectors[ei];var delta=new Vector2(segment.Z,segment.W);var relative=p-new Vector2(segment.X,segment.Y);double t=Math.Clamp((double)relative.Dot(delta)*metric.X,0,1),distance=(relative-delta*(float)t).Length();if(distance>bank+30)continue;
                double grade=28+((double)metric.Y-28+metric.Z*t)*tree.GradeScale,floorWidth=floors[order],valley=1-Smooth(floorWidth,bank,distance),bed=1-Smooth(floorWidth*.3,floorWidth*1.8,distance),amount=P("erosion")*(order>=2?P("secondary_gullies"):1);
                if(order>=2)amount*=eligibility;if(order==4)amount*=Smooth(.05,.45,dissected);
                double effective=bank*Math.Sqrt(Math.Clamp(amount,0,1)),shape=Math.Pow(Math.Clamp(distance/Math.Max(effective,1),0,1),Lerp(1.35,2.6,Math.Clamp(P("ridge_sharpness")*.5+dissected*.35,0,1))),before=h;
                h=Lerp(h,Math.Min(h,grade+relief*1.5*shape),Smooth(0,.12,amount));double cut=Smooth(.02,.5,before-h),core=1-Smooth(Math.Max(floorWidth,16),Math.Max(floorWidth*2,32),distance);
                protection=Math.Max(protection,core*cut*Smooth(0,.12,amount));drainage=Math.Max(drainage,bed*amount*cut);if(order>0)second=Math.Max(second,valley*amount*cut);nearest=Math.Min(nearest,distance);
            }
            double along=(p.Y-(double)root.Z)*side,fanSpan=350+relief,mask=(1-Smooth(0,fanSpan,Math.Abs(along)))*(1-Smooth(70,320,Math.Abs((double)p.X-root.X)));
            if(P("fan_shape_strength")>0&&P("fans")>0&&w[14]+w[8]*.6+w[9]*.3>0)mask=Lerp(mask,_fan.mask(p,tree.Data,fanSpan),Math.Clamp(P("fan_shape_strength"),0,1));
            if(P("fan_gradient")>0&&P("fan_shape_strength")>0)
            {
                double contribution=mask*P("fans")*(w[14]+w[8]*.6+w[9]*.3)*Math.Clamp(P("fan_shape_strength"),0,1);if(contribution>0){var basis=_fan.frame(tree.Data);if(basis.Length>0){double upstream=Math.Clamp((p-new Vector2((float)basis[0],(float)basis[1])).Dot(new Vector2((float)basis[2],(float)basis[3])),0,Math.Min(fanSpan,Math.Max(32,basis[4]*.85)));depositSum+=contribution*upstream*P("fan_gradient");depositWeight+=contribution;}}
            }
            fan=Math.Max(fan,mask*P("fans")*(w[14]+w[8]*.6+w[9]*.3));
        }
        var layers=strata(p,h);double exposed=Math.Clamp((1-calm)*(.2+second*.5+w[12]*.4+w[13]*.35)+remnant,0,1),divide=(1-protection)*(1-fan)*exposed*upland*(1-remnant);
        h+=divide*_weather.GetNoise2Dv(p*1.7f)*(3+dissected*5);h+=layers.Y*P("ledges")*5*exposed*(1-protection)*(1-remnant);
        if(P("fan_shape_strength")>0)h=Lerp(h,28+weather+(depositWeight>0?depositSum/depositWeight:0),fan*.6*(1-protection*Math.Clamp(P("fan_shape_strength"),0,1)));else h=Lerp(h,28+weather,fan*.6);
        double pool=0,water=0;
        if(w[8]>.5&&P("pool_frequency")>0){var tree=GetTree(index,lane,side);if(tree.Random<P("pool_frequency")){var q=new Vector2((float)((p.X-(double)tree.Root.X)/100),(float)((p.Y-(double)tree.Root.Z)/65));double radius=q.Length()+Math.Sin(q.X*3.0)*.08,support=1-Smooth(.7,1.5,radius);pool=(1-Smooth(.25,.9,radius))*support;water=24*support;h=Lerp(h,29-pool*9,support);}}
        if(profile)timings["raw_us"]=(timings.ContainsKey("raw_us")?timings["raw_us"].AsInt64():0)+(long)Time.GetTicksUsec()-tick;
        return new[]{h,water,pool*.8,(double)dominant/15,exposed,second,Math.Clamp(Math.Max(main,fan)+second*.15,0,1),Math.Clamp(upland*(1-second),0,1),main,second,remnant,(double)layers.Y,clay,fan,pool,(double)layers.X};
    }
    public double[] _node(Vector2I cell)
    {
        if(_nodes.TryGetValue(cell,out var found))return found;var value=_raw((Vector2)cell*16);if(_nodes.Count==0)_nodeOrder.Clear();
        if(_nodeOrder.Count>=16384)_nodes.Remove(_nodeOrder.Dequeue());_nodeOrder.Enqueue(cell);_nodes[cell]=value;return value;
    }
    public double cubic(double a,double b,double c,double d,double t)=>b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)));
    private Patch GetPatch(Vector2I cell)
    {
        if(_patches.TryGetValue(cell,out var found))return found;var coefficients=new double[32];var corners=new List<double[]>();int cursor=0;
        for(int row=-1;row<3;row++)
        {
            var a=_node(cell+new Vector2I(-1,row));var b=_node(cell+new Vector2I(0,row));var c=_node(cell+new Vector2I(1,row));var d=_node(cell+new Vector2I(2,row));
            for(int channel=0;channel<2;channel++){coefficients[cursor++]=b[channel];coefficients[cursor++]=c[channel]-a[channel];coefficients[cursor++]=2*a[channel]-5*b[channel]+4*c[channel]-d[channel];coefficients[cursor++]=3*(b[channel]-c[channel])+d[channel]-a[channel];}
            if(row is 0 or 1){corners.Add(b);corners.Add(c);}
        }
        var result=new Patch(coefficients,corners.ToArray());if(_patchOrder.Count>=1024)_patches.Remove(_patchOrder.Dequeue());_patchOrder.Enqueue(cell);_patches[cell]=result;return result;
    }
    public A _patch(Vector2I cell){var p=GetPatch(cell);var corners=new A();foreach(var corner in p.Corners)corners.Add(corner);return new(){p.Coefficients,corners};}
    public double _patch_row(double[] coefficients,long index,double t){int i=checked((int)index);return coefficients[i]+.5*t*(coefficients[i+1]+t*(coefficients[i+2]+t*coefficients[i+3]));}
    public double sample(double x,double z)=>sample(x,z,true);
    public double sample(double x,double z,bool publish){if(publish){palette_state=material_palette(new Vector2((float)x,(float)z));remnant_delta=0;}return remnant_surface(new Vector2((float)x,(float)z),_base_sample(x,z,publish),publish);}
    public double _base_sample(double x,double z,bool publish)
    {
        var q=new Vector2((float)x,(float)z)/16;var cell=Cell(q,1);var f=q-(Vector2)cell;
        if(f==Vector2.Zero){var value=_node(cell);if(publish)state=(double[])value.Clone();return value[0];}
        var patch=GetPatch(cell);var c=patch.Coefficients;double h=cubic(_patch_row(c,0,f.X),_patch_row(c,8,f.X),_patch_row(c,16,f.X),_patch_row(c,24,f.X),f.Y);
        if(publish){var a=patch.Corners[0];var b=patch.Corners[1];var d=patch.Corners[2];var e=patch.Corners[3];state=new double[16];state[0]=h;state[1]=cubic(_patch_row(c,4,f.X),_patch_row(c,12,f.X),_patch_row(c,20,f.X),_patch_row(c,28,f.X),f.Y);for(int i=2;i<16;i++)state[i]=Math.Clamp(Lerp(Lerp(a[i],b[i],f.X),Lerp(d[i],e[i],f.X),f.Y),0,1);}return h;
    }
    public void clear_numeric_caches(){_nodes.Clear();_nodeOrder.Clear();_patches.Clear();_patchOrder.Clear();_regions.Clear();_trees.Clear();_carriers.Clear();}
    public D cache_counts()=>new(){["nodes"]=_nodes.Count,["patches"]=_patches.Count,["regions"]=_regions.Count,["trees"]=_trees.Count,["carriers"]=_carriers.Count};
}
