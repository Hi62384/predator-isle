using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class AlienInfectedSampler : BiomeExtensionSampler
{
    public Godot.Collections.Array NAMES {get;}=new() {"Assimilation fringe","Nerve lowlands","Carapace highlands","Membrane sinklands","Hive rupture country","Ancient dormant tissue"};
    private readonly Dictionary<Vector2,D> _networkCache=new();
    private readonly Dictionary<Vector2I,Vector2> _hiveNodes=new();
    private readonly Dictionary<Vector2I,Vector2[]> _edges=new();
    private readonly Dictionary<Vector2I,Tile> _tiles=new();
    private readonly Dictionary<Vector2I,int> _probes=new();
    public long tile_hits {get;set;}
    public long tile_builds {get;set;}
    public long probe_resets {get;set;}
    public long uncached_queries {get;set;}
    private bool _wantFrame;
    private Vector2 _framePoint=Vector2.Inf;
    private Frame _frame;
    private readonly record struct Frame(Vector2 Start,Vector2 End,double T,Vector2I Cell,int Edge,double Gap=0);
    internal sealed record Tile(Vector2I Parent,Vector2[] Nodes,string[] Names,Vector2[][] Trunks,Vector3I[] Labels,Vector2[][] Branches,D Payload);
    private static readonly double[] Heights={45,20,280,35,100,170},Details={2,2,5,1,4,4},Offsets={-140,90,260},Widths={70,90,55},Strengths={1,.7,.4};
    private bool Fibres=>P("nerve_fibre_height")>0;
    private static Vector2I Cell(Vector2 p,double span)=>new((int)Math.Floor(p.X/span),(int)Math.Floor(p.Y/span));
    private static string Identity(Vector2I cell)=>FormattableString.Invariant($"({cell.X}, {cell.Y})");
    public override void configure(Resource config,long seed_id,RefCounted host,long family_id)
    {
        base.configure(config,seed_id,host,family_id);_networkCache.Clear();_hiveNodes.Clear();_edges.Clear();_tiles.Clear();_probes.Clear();_wantFrame=false;_framePoint=Vector2.Inf;_frame=default;tile_hits=tile_builds=probe_resets=uncached_queries=0;
    }
    public Vector2 hive_node(Vector2I cell)
    {
        if(_hiveNodes.TryGetValue(cell,out var value))return value;var p=((Vector2)cell+new Vector2((float)(.3+random(cell.X,cell.Y,31)*.4),(float)(.3+random(cell.X,cell.Y,32)*.4)))*4096*(float)P("feature_scale");if(_hiveNodes.Count>=512)_hiveNodes.Clear();_hiveNodes[cell]=p;return p;
    }
    public Vector2[] network_edges(Vector2I cell)=>Edges(cell);
    private Vector2[] Edges(Vector2I cell)
    {
        if(_edges.TryGetValue(cell,out var value))return value;var a=hive_node(cell);var result=new Vector2[8];int at=0;
        foreach(var direction in new[]{Vector2I.Right,Vector2I.Down})
        {
            var b=hive_node(cell+direction);var delta=b-a;var side=new Vector2(-delta.Y,delta.X);var mid=(a+b)*.5f+side*(float)(.08*Math.Sin((double)(cell.X+cell.Y)*1.71));var tip=mid+side*.23f;result[at++]=a;result[at++]=mid;result[at++]=b;result[at++]=tip;
        }
        if(_edges.Count>=512)_edges.Clear();_edges[cell]=result;return result;
    }
    private D Result(Vector2 p,string identity,Vector2 nearest,double center,double trunk,double branch)
    {
        double influence=Math.Max(Math.Exp(-trunk/340)*(1-Smooth(900,1600,trunk)),Math.Exp(-branch/110)*.65*(1-Smooth(400,700,branch)));
        return new D {["id"]=identity,["center"]=nearest,["center_distance"]=center,["trunk_distance"]=trunk,["branch_distance"]=branch,["influence"]=influence,["age"]=.5+.5*macro(p*.25f),["underground_geometry"]=false};
    }
    public D _network_without_fibres(Vector2 p)
    {
        if(_networkCache.TryGetValue(p,out var value))return value;var cell=Cell(p,4096*P("feature_scale"));double trunk=double.PositiveInfinity,branch=double.PositiveInfinity,center=double.PositiveInfinity;var nearest=Vector2.Zero;string identity="";
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var c=cell+new Vector2I(x,z);var a=hive_node(c);if(p.DistanceTo(a)<center){center=p.DistanceTo(a);nearest=a;identity=Identity(c);}var edges=Edges(c);
            for(int edge=0;edge<8;edge+=4){var b=edges[edge+2];var mid=edges[edge+1];trunk=Math.Min(trunk,Math.Min(segment(p,a,mid).X,segment(p,mid,b).X));branch=Math.Min(branch,segment(p,mid,edges[edge+3]).X);}
        }
        var result=Result(p,identity,nearest,center,trunk,branch);if(_networkCache.Count>=8192)_networkCache.Clear();_networkCache[p]=result;return result;
    }
    public override double[] _node(Vector2I cell)
    {
        if(!Fibres||HasCachedNode(cell))return base._node(cell);double r=region((Vector2)cell*16);int id=(int)Math.Floor(r);bool previous=_wantFrame;_wantFrame=id==1||(id==0&&Smooth(.25,.75,r-Math.Floor(r))>0);
        try{return base._node(cell);}finally{_wantFrame=previous;}
    }
    public D network(Vector2 p)
    {
        if(!settings.Get("network_query_cache_enabled").AsBool()){_tiles.Clear();_probes.Clear();return _network_unpruned(p);}return _network_tiled(p);
    }
    public D _network_unpruned(Vector2 p)
    {
        if(!_wantFrame||!Fibres)return _network_without_fibres(p);if(_networkCache.TryGetValue(p,out var cached)&&_framePoint==p)return cached;
        var cell=Cell(p,4096*P("feature_scale"));double trunk=double.PositiveInfinity,second=double.PositiveInfinity,branch=double.PositiveInfinity,center=double.PositiveInfinity;var nearest=Vector2.Zero;string identity="";Frame frame=default;
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var c=cell+new Vector2I(x,z);var a=hive_node(c);if(p.DistanceTo(a)<center){center=p.DistanceTo(a);nearest=a;identity=Identity(c);}var edges=Edges(c);
            for(int edge=0;edge<8;edge+=4)
            {
                var b=edges[edge+2];var mid=edges[edge+1];var first=segment(p,a,mid);var last=segment(p,mid,b);double distance=Math.Min(first.X,last.X);
                if(distance<trunk){second=Math.Min(second,trunk);frame=new Frame(first.X<=last.X?a:mid,first.X<=last.X?mid:b,first.X<=last.X?first.Y*.5:.5+last.Y*.5,c,edge/4);}else second=Math.Min(second,distance);
                trunk=Math.Min(trunk,distance);branch=Math.Min(branch,segment(p,mid,edges[edge+3]).X);
            }
        }
        var result=Result(p,identity,nearest,center,trunk,branch);Store(p,result);_frame=frame with {Gap=Math.Max(0,second-trunk)};_framePoint=p;return result;
    }
    private void Store(Vector2 p,D value){if(!_networkCache.ContainsKey(p)&&_networkCache.Count>=8192)_networkCache.Clear();_networkCache[p]=value;}
    private double FibreRelief(Vector2 p,D net)
    {
        double t=_frame.T,scale=P("feature_scale"),arc=Math.Sin(t*Math.PI),taper=Smooth(0,.15,t)*Smooth(0,.15,1-t),isolation=Smooth(0,100*scale,_frame.Gap),signed=net["trunk_distance"].AsDouble()*Math.Sign((_frame.End-_frame.Start).Cross(p-_frame.Start)),relief=0;
        for(int i=0;i<3;i++)
        {
            long seedOffset=380+_frame.Edge*19+i*3;double maturity=.75+.5*random(_frame.Cell.X,_frame.Cell.Y,seedOffset),offset=Offsets[i]*scale*arc*maturity;offset+=macro(p*.6f)*(30+i*20)*scale*arc*arc;
            double width=Widths[i]*scale*(.4+.6*arc)*(.8+.4*random(_frame.Cell.X,_frame.Cell.Y,seedOffset+1)),q=Math.Abs(signed-offset)/Math.Max(width,.1),crest=Math.Pow(Math.Max(0,1-q*q),3);relief=Math.Max(relief,crest*Strengths[i]);
        }
        return P("nerve_fibre_height")*Math.Min(scale,1)*relief*taper*isolation*(.6+net["age"].AsDouble()*.4);
    }
    public double nerve_fibre_relief(Vector2 p)
    {if(!Fibres)return 0;bool previous=_wantFrame;_wantFrame=true;try{return FibreRelief(p,network(p));}finally{_wantFrame=previous;}}
    public override double[] evaluate(Vector2 p,int id)
    {
        bool previous=_wantFrame;_wantFrame=_wantFrame||(id==1&&Fibres);
        try
        {
            var net=network(p);double influence=net["influence"].AsDouble(),ridge=Math.Exp(-Math.Pow(net["trunk_distance"].AsDouble()/100,2))+Math.Exp(-Math.Pow(net["branch_distance"].AsDouble()/42,2))*.35,core=1-Smooth(160,650,net["center_distance"].AsDouble()),h=60+macro(p)*Heights[id]+noise(p)*Details[id];h+=ridge*P("nerve_height")*(.7+net["age"].AsDouble()*.6);
            if(id==2)h+=Math.Pow(1-Math.Abs(macro(p*.6f)),4)*160;if(id==3)h+=50-core*75-ridge*P("nerve_height")*(.7+net["age"].AsDouble()*.6)*core;if(id==4)h+=core*45-core*core*P("breach_depth");if(id==1&&Fibres)h+=FibreRelief(p,net);return new[]{h,0,.25+influence*.5,0,influence};
        }
        finally{_wantFrame=previous;}
    }
    public override D describe(Vector2 p)
    {
        var result=base.describe(p);result.Merge(network(p));result["infection_age"]=result["age"];result["infection_intensity"]=result["influence"];result["underground_center"]=default(Variant);result["underground_source"]="Shared cave region underground_hive_center;surface descriptors alone do not assert a traversable core";double r=result["region"].AsDouble();result["organic_fluid"]=new D {["eligible"]=r>2.6&&r<3.5&&result["center_distance"].AsDouble()<300,["renderer_supported"]=true,["rendered"]="Only retained basins passing the feature mesher's bed/rim test"};result["breach_traversable"]=false;return result;
    }
    public double lower_bound(Vector2 a,Vector2 b,double[] bounds)
    {double x=Math.Max(0,Math.Max(Math.Min(a.X,b.X)-bounds[2],bounds[0]-Math.Max(a.X,b.X))),z=Math.Max(0,Math.Max(Math.Min(a.Y,b.Y)-bounds[3],bounds[1]-Math.Max(a.Y,b.Y)));return Math.Sqrt(x*x+z*z);}
    public D query_tile(Vector2 p,Vector2I parent)=>QueryTile(p,parent).Payload;
    internal Tile QueryTile(Vector2 p,Vector2I parent)
    {
        double step=256*P("feature_scale");var key=Cell(p,step);if(_tiles.TryGetValue(key,out var cached)&&cached.Parent==parent){tile_hits++;return cached;}tile_builds++;
        double magnitude=Math.Max(Math.Max(Math.Abs(key.X*step),Math.Abs((key.X+1)*step)),Math.Max(Math.Abs(key.Y*step),Math.Abs((key.Y+1)*step))),pad=.25+magnitude*.000004;double[] bounds={key.X*step-pad,key.Y*step-pad,(key.X+1)*step+pad,(key.Y+1)*step+pad};var center=new Vector2((float)((key.X+.5)*step),(float)((key.Y+.5)*step));double radius=step*Math.Sqrt(.5)+pad*2,trunkUpper=double.PositiveInfinity,branchUpper=double.PositiveInfinity;
        var nodes=new List<Vector2>();var names=new List<string>();var paths=new List<Vector2[]>();var labels=new List<Vector3I>();var branchPaths=new List<Vector2[]>();
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var cell=parent+new Vector2I(x,z);var a=hive_node(cell);nodes.Add(a);names.Add(Identity(cell));var edges=Edges(cell);
            for(int edge=0;edge<8;edge+=4){var mid=edges[edge+1];var b=edges[edge+2];var tip=edges[edge+3];paths.Add(new[]{a,mid,b});labels.Add(new Vector3I(cell.X,cell.Y,edge/4));branchPaths.Add(new[]{mid,tip});trunkUpper=Math.Min(trunkUpper,Math.Min(segment(center,a,mid).X,segment(center,mid,b).X)+radius);branchUpper=Math.Min(branchUpper,segment(center,mid,tip).X+radius);}
        }
        var trunks=new List<Vector2[]>();var trunkLabels=new List<Vector3I>();var branches=new List<Vector2[]>();
        for(int i=0;i<paths.Count;i++){var path=paths[i];if(Math.Min(lower_bound(path[0],path[1],bounds),lower_bound(path[1],path[2],bounds))<=trunkUpper+100*P("feature_scale")){trunks.Add(path);trunkLabels.Add(labels[i]);}var branch=branchPaths[i];if(lower_bound(branch[0],branch[1],bounds)<=branchUpper)branches.Add(branch);}
        if(trunks.Count==0||branches.Count==0)throw new InvalidOperationException("Alien query tile lost its nearest supported path");
        var payload=new D {["parent"]=parent,["nodes"]=nodes.ToArray(),["names"]=new Godot.Collections.Array<string>(names),["trunks"]=new Godot.Collections.Array<Vector2[]>(trunks),["labels"]=new Godot.Collections.Array<Vector3I>(trunkLabels),["branches"]=new Godot.Collections.Array<Vector2[]>(branches)};
        var result=new Tile(parent,nodes.ToArray(),names.ToArray(),trunks.ToArray(),trunkLabels.ToArray(),branches.ToArray(),payload);if(_tiles.Count>=512)_tiles.Clear();_tiles[key]=result;return result;
    }
    public D _network_tiled(Vector2 p)
    {
        bool frameNeeded=_wantFrame&&Fibres;if(_networkCache.TryGetValue(p,out var cached)&&(!frameNeeded||_framePoint==p))return cached;var key=Cell(p,256*P("feature_scale"));
        if(!_tiles.ContainsKey(key)){if(_probes.Count>=512&&!_probes.ContainsKey(key)){_probes.Clear();probe_resets++;}int count=_probes.TryGetValue(key,out int previous)?previous+1:1;_probes[key]=count;if(count<4){uncached_queries++;return _network_unpruned(p);}}
        var data=QueryTile(p,Cell(p,4096*P("feature_scale")));double trunk=double.PositiveInfinity,second=double.PositiveInfinity,branch=double.PositiveInfinity,center=double.PositiveInfinity;var nearest=Vector2.Zero;string identity="";Frame frame=default;
        for(int i=0;i<data.Nodes.Length;i++){var node=data.Nodes[i];double distance=p.DistanceTo(node);if(distance<center){center=distance;nearest=node;identity=data.Names[i];}}
        for(int i=0;i<data.Trunks.Length;i++)
        {
            var path=data.Trunks[i];var first=segment(p,path[0],path[1]);var last=segment(p,path[1],path[2]);double distance=Math.Min(first.X,last.X);
            if(frameNeeded){if(distance<trunk){second=Math.Min(second,trunk);var label=data.Labels[i];frame=new Frame(first.X<=last.X?path[0]:path[1],first.X<=last.X?path[1]:path[2],first.X<=last.X?first.Y*.5:.5+last.Y*.5,new Vector2I(label.X,label.Y),label.Z);}else second=Math.Min(second,distance);}trunk=Math.Min(trunk,distance);
        }
        foreach(var path in data.Branches)branch=Math.Min(branch,segment(p,path[0],path[1]).X);var result=Result(p,identity,nearest,center,trunk,branch);Store(p,result);if(frameNeeded){_frame=frame with {Gap=Math.Max(0,second-trunk)};_framePoint=p;}return result;
    }
    internal int NetworkCacheCount=>_networkCache.Count;
    internal int TileCacheCount=>_tiles.Count;
    internal int ProbeCacheCount=>_probes.Count;
}
