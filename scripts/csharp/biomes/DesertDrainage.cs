using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;

/// <summary>Worker-owned, finite rooted catchments with conservative two-level culling.</summary>
public partial class DesertDrainage : RefCounted
{
    public double TILE {get;}=1024;
    public long MAX_TILES {get;}=512;
    public Resource settings {get;set;}=null!;
    public long seed_value {get;set;}
    public double last_floor {get;set;}=4;
    public double last_fan_lift {get;set;}
    public double last_fan_channels {get;set;}
    public double last_lee {get;set;}=.5;
    public double last_gully {get;set;}
    public double last_gully_floor {get;set;}=4;
    private sealed record Edge(Vector2 A,Vector2 B,double FloorA,double FloorB,double Width,double Bend,Vector2 BendVector,Vector2 Delta,double LengthSquared,Rect2 Bounds,double ReachSquared,Vector2 Acceleration,Rect2 PointBounds,double Phase,double Support)
    {
        internal A Payload()=>new(){A,B,FloorA,FloorB,Width,Bend,BendVector,Delta,LengthSquared,Bounds,ReachSquared,Acceleration,PointBounds,Phase,Support};
    }
    private sealed record Fan(Vector2 Origin,Vector2 Direction,double Length,double Gate,Rect2 Bounds,Vector2 Normal)
    {
        internal A Payload()=>new(){Origin,Direction,Length,Gate,Bounds,Normal};
    }
    private sealed record Network(Edge[] Edges,Fan[] Fans,Edge[] Gullies)
    {
        internal static readonly Network Empty=new(System.Array.Empty<Edge>(),System.Array.Empty<Fan>(),System.Array.Empty<Edge>());
        internal A Payload(){var e=new A();var f=new A();var g=new A();foreach(var edge in Edges)e.Add(edge.Payload());foreach(var fan in Fans)f.Add(fan.Payload());foreach(var edge in Gullies)g.Add(edge.Payload());return new(){e,f,g};}
    }
    private readonly Dictionary<Vector2I,Network> _catchments=new(),_tiles=new(),_localTiles=new();
    private Vector2I _lastLocalTile=new(int.MaxValue,int.MaxValue);
    private Network _localNear=Network.Empty,_near=Network.Empty;
    private double _span,_occurrence=1;
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static Vector2 Normalize(Vector2 v)=>v.LengthSquared()==0?v:v.Normalized();
    private static float[] SourceWeights(RefCounted source,Vector2 p)=>source is DesertSampler native?native.region_weights(p.X,p.Y):source.Call("region_weights",p.X,p.Y).AsFloat32Array();
    private static Vector2I Cell(Vector2 p,double size)=>new((int)Math.Floor(p.X/size),(int)Math.Floor(p.Y/size));
    public void reset_sample(){last_floor=4;last_lee=.5;last_fan_lift=0;last_fan_channels=0;last_gully=0;last_gully_floor=4;}
    public void configure(Resource config,long seed_number)
    {
        settings=config;seed_value=seed_number;_span=Math.Max(config.Get("basin_size").AsDouble()*5,6000);_occurrence=Math.Clamp(config.Get("canyon_occurrence").AsDouble(),0,1);
        _catchments.Clear();_tiles.Clear();_localTiles.Clear();_lastLocalTile=new(int.MaxValue,int.MaxValue);_localNear=Network.Empty;_near=Network.Empty;
    }
    public double _hash(long x,long z,long salt){long h=unchecked(x*374761393+z*668265263+seed_value*69069+salt*1274126177)&0x7fffffff;h=unchecked((h^(h>>13))*1274126177)&0x7fffffff;return (double)(h^(h>>16))/2147483647;}
    private Edge Curve(Vector2 a,Vector2 b,double bend,double floorA,double floorB,double width,double support=1250)
    {
        var delta=b-a;var bendVector=Normalize(new Vector2(-delta.Y,delta.X))*(float)bend;
        double reach=support+Math.Abs(bend),margin=Math.Max(1,Math.Max(Math.Max(Math.Abs((double)a.X),Math.Abs((double)a.Y)),Math.Max(Math.Abs((double)b.X),Math.Abs((double)b.Y)))*.000001);
        var bounds=new Rect2(a,Vector2.Zero).Expand(b).Grow((float)reach);
        double phase=_hash((long)Math.Floor(a.X/17.0),(long)Math.Floor(a.Y/17.0),491)*Math.Tau;
        return new(a,b,floorA,floorB,width,bend,bendVector,delta,Math.Max(delta.LengthSquared(),1),bounds,reach*reach,-bendVector*8,bounds.Grow((float)margin),phase,support);
    }
    public A _curve(Vector2 a,Vector2 b,double bend,long segments,double floor_a,double floor_b,double width)=>_curve(a,b,bend,segments,floor_a,floor_b,width,1250);
    public A _curve(Vector2 a,Vector2 b,double bend,long segments,double floor_a,double floor_b,double width,double support)=>new(){Curve(a,b,bend,floor_a,floor_b,width,support).Payload()};
    public A _catchment(Vector2I cell,RefCounted source)=>Catchment(cell,source).Payload();
    private Network Catchment(Vector2I cell,RefCounted source)
    {
        if(_catchments.TryGetValue(cell,out var cached))return cached;
        if(_occurrence<1&&(_occurrence<=0||_hash(cell.X,cell.Y,791)>=_occurrence))return Store(Network.Empty);
        var root=((Vector2)cell+Vector2.One*.5f)*(float)_span;double best=double.PositiveInfinity;
        var macro=source is DesertSampler native?native._macro:source.Get("_macro").As<FastNoiseLite>();
        for(int i=0;i<5;i++)
        {
            var p=((Vector2)cell+new Vector2((float)(.30+_hash(cell.X,cell.Y,301+i*2)*.40),(float)(.30+_hash(cell.X,cell.Y,302+i*2)*.40)))*(float)_span;
            var w=SourceWeights(source,p);
            double potential=macro.GetNoise2D(p.X,p.Y)-((double)w[3]+w[6])*.6+((double)w[4]+w[2])*.25;
            if(potential<best){best=potential;root=p;}
        }
        var edges=new List<Edge>();var fans=new List<Fan>();var gullies=new List<Edge>();
        double inset=_span*.08;var minimum=(Vector2)cell*(float)_span+Vector2.One*(float)inset;var maximum=(Vector2)(cell+Vector2I.One)*(float)_span-Vector2.One*(float)inset;
        var head=root;double headScore=double.NegativeInfinity;
        for(int i=0;i<9;i++)
        {
            var p=((Vector2)cell+new Vector2((float)(.08+_hash(cell.X,cell.Y,321+i*2)*.84),(float)(.08+_hash(cell.X,cell.Y,322+i*2)*.84)))*(float)_span;
            var w=SourceWeights(source,p);double score=p.DistanceTo(root)/_span+((double)w[2]+w[4]+w[5])*.23-((double)w[3]+w[6])*.18;
            if(score>headScore){headScore=score;head=p;}
        }
        var direction=Normalize(head-root);var normal=new Vector2(-direction.Y,direction.X);double length=root.DistanceTo(head);
        int segments=4+(int)(_hash(cell.X,cell.Y,317)*2);var points=new List<Vector2>{root};var floors=new List<double>{3.5};
        for(int i=1;i<=segments;i++)
        {
            double fraction=i<segments?(i+(_hash(cell.X,cell.Y,341+i)-.5)*.38)/segments:1,side=(_hash(cell.X,cell.Y,351+i)-.5)*length*.12*Math.Sin(fraction*Math.PI);
            points.Add((root.Lerp(head,(float)fraction)+normal*(float)side).Clamp(minimum,maximum));floors.Add(3.5+fraction*4.5);
            double width=Lerp(76,28,fraction),bend=(_hash(cell.X,cell.Y,371+i)-.5)*length*.035;
            edges.Add(Curve(points[i-1],points[i],bend,floors[i-1],floors[i],width));
        }
        double firstSide=_hash(cell.X,cell.Y,391)<.5?-1:1;
        for(int branch=1;branch<segments;branch++)
        {
            double side=firstSide*(branch%2==0?1:-1),reach=_span*Lerp(.12,.23,_hash(cell.X,cell.Y,401+branch));var junction=points[branch];
            var upstream=(junction+normal*(float)side*(float)reach+direction*(float)reach*(float)Lerp(.12,.62,_hash(cell.X,cell.Y,441+branch))).Clamp(minimum,maximum);
            var join=junction.Lerp(upstream,(float)Lerp(.42,.64,_hash(cell.X,cell.Y,411+branch)));
            double bend=(_hash(cell.X,cell.Y,421+branch)-.5)*reach*.16,floor=floors[branch];
            edges.Add(Curve(junction,join,bend,floor,floor+.85,34));edges.Add(Curve(join,upstream,-bend*.6,floor+.85,floor+1.8,20));
            if(branch==1){var twig=(join+direction*(float)reach*.52f+normal*(float)side*(float)reach*.16f).Clamp(minimum,maximum);edges.Add(Curve(join,twig,bend*.4,floor+.85,floor+2,14));}
            var up=SourceWeights(source,upstream);var down=SourceWeights(source,junction);
            if(up[5]>.12&&gullies.Count<4)
            {
                double gullyLength=Lerp(160,340,_hash(cell.X,cell.Y,501+branch)),gullyFloor=floor+.85;
                var tip=(join+direction*(float)gullyLength*.75f+normal*(float)side*(float)gullyLength*.65f).Clamp(minimum,maximum);
                var gullyJoin=join.Lerp(tip,.55f);var main=Curve(join,tip,bend*.08,gullyFloor,gullyFloor+32,11,190);gullies.Add(main);gullyJoin+=main.BendVector*(float)(4.0*.55*.45);
                var twigTip=(gullyJoin+direction*(float)gullyLength*.30f-normal*(float)side*(float)gullyLength*.40f).Clamp(minimum,maximum);
                gullies.Add(Curve(gullyJoin,twigTip,-bend*.04,gullyFloor+32*.55,gullyFloor+39,7,125));
            }
            double gate=Math.Clamp(((double)up[2]+up[4]+up[5])*((double)down[3]+down[6])*2,0,1);
            if(gate>.06)
            {
                var fanDirection=Normalize(junction-join);double fanLength=Math.Min(reach*.60,1400),radius=Math.Sqrt(fanLength*fanLength+Math.Pow(fanLength*.65+35,2));
                var bounds=new Rect2(join-Vector2.One*(float)radius,Vector2.One*(float)radius*2);
                fans.Add(new(join,fanDirection,fanLength,gate,bounds,new Vector2(-fanDirection.Y,fanDirection.X)));
            }
        }
        return Store(new(edges.ToArray(),fans.ToArray(),gullies.ToArray()));
        Network Store(Network value){if(_catchments.Count>=128)_catchments.Clear();_catchments[cell]=value;return value;}
    }
    public A _nearby(Vector2I tile,RefCounted source)=>Nearby(tile,source).Payload();
    private Network Nearby(Vector2I tile,RefCounted source)
    {
        if(_tiles.TryGetValue(tile,out var found))return found;
        var bounds=new Rect2((Vector2)tile*1024,Vector2.One*1024);var center=Cell(bounds.GetCenter(),_span);
        var edges=new List<Edge>();var fans=new List<Fan>();var gullies=new List<Edge>();
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var cell=center+new Vector2I(x,z);
            if(!new Rect2((Vector2)cell*(float)_span,Vector2.One*(float)_span).Grow((float)(_span*.20+1250)).Intersects(bounds,true))continue;
            var network=Catchment(cell,source);
            foreach(var edge in network.Edges)if(edge.Bounds.Intersects(bounds,true))edges.Add(edge);
            foreach(var fan in network.Fans)if(fan.Bounds.Intersects(bounds,true))fans.Add(fan);
            foreach(var gully in network.Gullies)if(gully.Bounds.Intersects(bounds,true))gullies.Add(gully);
        }
        var result=new Network(edges.ToArray(),fans.ToArray(),gullies.ToArray());if(_tiles.Count>=512)_tiles.Clear();_tiles[tile]=result;return result;
    }
    public A _local_candidates(Vector2 p,RefCounted source)=>LocalCandidates(p,source).Payload();
    private Network LocalCandidates(Vector2 p,RefCounted source)
    {
        var cell=Cell(p,128);if(cell==_lastLocalTile)return _localNear;_lastLocalTile=cell;
        if(_localTiles.TryGetValue(cell,out var found)){_localNear=found;return found;}
        var parent=Nearby(Cell(p,1024),source);var bounds=new Rect2((Vector2)cell*128,Vector2.One*128).Grow(.1f);
        var edges=new List<Edge>();var fans=new List<Fan>();var gullies=new List<Edge>();
        foreach(var edge in parent.Edges)if(edge.PointBounds.Intersects(bounds,true))edges.Add(edge);
        foreach(var fan in parent.Fans)if(fan.Bounds.Intersects(bounds,true))fans.Add(fan);
        foreach(var gully in parent.Gullies)if(gully.PointBounds.Intersects(bounds,true))gullies.Add(gully);
        var result=new Network(edges.ToArray(),fans.ToArray(),gullies.ToArray());if(_localTiles.Count>=2048)_localTiles.Clear();_localTiles[cell]=result;_localNear=result;return result;
    }
    public Vector4 sample(Vector2 p,RefCounted source)=>sample(p,source,Vector2.Zero);
    public Vector4 sample(Vector2 p,RefCounted source,Vector2 wind)
    {
        reset_sample();if(_occurrence<=0)return new(0,0,10000,0);_near=LocalCandidates(p,source);
        double best=double.PositiveInfinity,valley=0,bed=0,floorSum=0,floorWeight=0,leeSum=0;
        foreach(var edge in _near.Edges)
        {
            if(!edge.PointBounds.HasPoint(p))continue;
            double t=Math.Clamp((p-edge.A).Dot(edge.Delta)/edge.LengthSquared,0,1);
            if(p.DistanceSquaredTo(edge.A+edge.Delta*(float)t)>edge.ReachSquared)continue;
            for(int iteration=0;iteration<2;iteration++)
            {
                var curve=edge.A+edge.Delta*(float)t+edge.BendVector*(float)(4*t*(1-t));var tangent=edge.Delta+edge.BendVector*(float)(4-8*t);var offset=curve-p;
                // Each vector dot is Float32, then promoted to the original scalar expression.
                t=Math.Clamp(t-offset.Dot(tangent)/Math.Max((double)tangent.LengthSquared()+offset.Dot(edge.Acceleration),1),0,1);
            }
            var separation=p-(edge.A+edge.Delta*(float)t+edge.BendVector*(float)(4*t*(1-t)));double distance=separation.Length(),envelope=Math.Sin(t*Math.PI),ratio=1+.22*envelope*envelope*Math.Sin(t*Math.Tau+edge.Phase),width=edge.Width*ratio;
            double adjusted=Math.Max(0,distance/ratio-edge.Width*.25),blend=1-Smooth(0,1200,distance);
            if(blend>0)
            {
                blend*=blend;blend*=blend;double relative=distance/Math.Max(width*.4,5),squared=relative*relative;blend/=1+squared*squared;
                floorSum+=(Lerp(edge.FloorA,edge.FloorB,t)-4)*blend;floorWeight+=blend;
                double flank=Math.Clamp(.5-separation.Dot(wind)/Math.Max(distance,1)*.5,0,1);leeSum+=(flank-.5)*blend;
            }
            valley=Math.Max(valley,1-Smooth(width*1.5,1200,adjusted));bed=Math.Max(bed,1-Smooth(width*.35,width*1.7,adjusted));if(adjusted<best)best=adjusted;
        }
        if(floorWeight>0){double normalization=Math.Max(floorWeight,.000001);last_floor=4+floorSum/normalization;last_lee=Math.Clamp(.5+leeSum/normalization,0,1);}
        if(settings.Get("erosion_intensity").AsDouble()>0){var weights=source is DesertSampler native?native.last_weights:source.Get("last_weights").AsFloat32Array();if(weights.Length>5&&weights[5]>.001)_sample_gullies(p);}
        double fanMask=0;
        foreach(var fan in _near.Fans)
        {
            var d=p-fan.Origin;double t=d.Dot(fan.Direction)/fan.Length;if(t<=0||t>=1)continue;
            double signed=d.Dot(fan.Normal),across=Math.Abs(signed),extent=35+t*fan.Length*.65;if(across>=extent)continue;
            double shape=(1-Smooth(extent*.55,extent,across))*Smooth(0,.08,t)*(1-Smooth(.6,1,t)),spread=t*fan.Length*.43,wander=t*(1-t)*fan.Length*.10;
            double ribbonDistance=Math.Min(Math.Abs(signed-wander),Math.Min(Math.Abs(signed-spread+wander),Math.Abs(signed+spread+wander))),ribbon=1-Smooth(10,35+t*24,ribbonDistance),deposit=shape*fan.Gate;
            fanMask=Math.Max(fanMask,deposit);last_fan_channels=Math.Max(last_fan_channels,deposit*ribbon);last_fan_lift=Math.Max(last_fan_lift,deposit*(1-t)*12*(1-ribbon*.18));
        }
        return new((float)valley,(float)bed,(float)Math.Min(best,10000),(float)fanMask);
    }
    public void _sample_gullies(Vector2 p)
    {
        double sum=0,weightSum=0;
        foreach(var edge in _near.Gullies)
        {
            if(!edge.PointBounds.HasPoint(p))continue;double t=Math.Clamp((p-edge.A).Dot(edge.Delta)/edge.LengthSquared,0,1);
            if(p.DistanceSquaredTo(edge.A+edge.Delta*(float)t)>edge.ReachSquared)continue;
            var q=edge.A+edge.Delta*(float)t+edge.BendVector*(float)(4*t*(1-t));var tangent=edge.Delta+edge.BendVector*(float)(4-8*t);var offset=q-p;
            t=Math.Clamp(t-offset.Dot(tangent)/Math.Max((double)tangent.LengthSquared()+offset.Dot(edge.Acceleration),1),0,1);
            q=edge.A+edge.Delta*(float)t+edge.BendVector*(float)(4*t*(1-t));double distance=p.DistanceTo(q),mask=(1-Smooth(edge.Width,edge.Support,distance))*(1-Smooth(.72,1,t));if(mask<=0)continue;
            last_gully=Math.Max(last_gully,mask);double weight=mask*mask*mask*mask;sum+=Lerp(edge.FloorA,edge.FloorB,t)*weight;weightSum+=weight;
        }
        if(weightSum>0)last_gully_floor=sum/weightSum;
    }
    public D cache_counts()=>new(){["catchments"]=_catchments.Count,["tiles"]=_tiles.Count,["local_tiles"]=_localTiles.Count};
}
