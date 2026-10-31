using Godot;
using System;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Organic chambers and nerve branches extending the existing solved cave graph.</summary>
public partial class CaveHiveNetwork : RefCounted
{
    public GodotObject builder { get; set; } = null!;
    public Resource configuration { get; set; } = null!;
    private WeakRef? _graph;
    public GodotObject? network => _graph?.GetRef().AsGodotObject();
    protected readonly CaveChamberProfiles Profiles = new();
    public void configure(GodotObject owner,Resource caves,GodotObject graph) {builder=owner;configuration=caves;_graph=GodotObject.WeakRef(graph);}
    protected double Random(Vector2I cell,long salt) => network is CaveNetwork graph?graph.random(cell,salt):network!.Call("random",cell,salt).AsDouble();
    protected double Number(string key) => configuration.Get(key).AsDouble();
    protected static A Items(D d,string key) => d[key].AsGodotArray();
    protected static long Family(D description) => description.ContainsKey("family")?description["family"].AsInt64():-1;
    protected Vector2 Center(Vector2I cell) => ((Vector2)cell+new Vector2((float)(.4+.2*Random(cell,1)),(float)(.4+.2*Random(cell,2))))*1536;
    public virtual D context(Vector2I cell)
    {
        var field=builder.Get("_extras").AsGodotArray()[7].AsGodotObject();
        if(!configuration.Get("hive_networks").AsBool()||field==null||!field.Get("settings").AsGodotObject().Get("caves_enabled").AsBool()) return new();
        var center=Center(cell);builder.Call("_biome_weights",center.X,center.Y);if(builder.Get("_extra_weights").AsFloat32Array()[7]<.65) return new();
        var source=field.Call("network",center).AsGodotDictionary();
        return new D {["family"]=7,["render_style"]=7,["hive_id"]=source["id"],["surface_center"]=source["center"],["hive_region"]=field.Call("region",center),["half_width"]=network!.Get("half_width").AsDouble()*1.25,["headroom"]=Math.Min(18,network.Get("headroom").AsDouble()*1.25),["flat_radius"]=36.0,["planning_depth_reserve"]=2.0};
    }
    public bool room_fits(D room)
    {
        var point=room["point"].AsVector3();double radius=room["chamber_radius"].AsDouble();
        for(int z=-2;z<=2;z++) for(int x=-2;x<=2;x++)
        {
            if(new Vector2(x,z).Length()>2.1) continue;
            double depth=builder.Call("_get_height",point.X+x*radius*.5,point.Z+z*radius*.5).AsDouble()-point.Y;
            if(!double.IsFinite(depth)||depth>Number("maximum_depth_metres")-4||depth<room["chamber_height"].AsDouble()+Number("minimum_rock_cover_metres")+4) return false;
        }
        return true;
    }
    protected D Branch(D parent,D child)
    {
        var graph=network!;double width=graph.Get("half_width").AsDouble(),height=graph.Get("headroom").AsDouble();
        graph.Set("half_width",Number("main_route_width_metres")*.5);graph.Set("headroom",Number("main_route_height_metres"));
        try {var a=parent["point"].AsVector3();var b=child["point"].AsVector3();return graph.Call("route",parent,child,new[]{new Vector2(a.X,a.Z),new Vector2(b.X,b.Z)}).AsGodotDictionary();}
        finally {graph.Set("half_width",width);graph.Set("headroom",height);}
    }
    public virtual D decorate(D region,D description)
    {
        if(Family(description)!=7||!region.ContainsKey("valid")||!region["valid"].AsBool()) return region;
        region["cave_family"]=7;region["geology"]=7;region["render_style"]=7;region["cross_section_style"]=7;region["hive_id"]=description["hive_id"];region["surface_hive_center"]=description["surface_center"];region["hive_region"]=description["hive_region"];region["construction"]="assimilated_organic_volume";
        var nodes=Items(region,"nodes");var edges=Items(region,"edges");int enlarged=0;var cell=region["id"].AsVector2I();
        for(int i=1;i<nodes.Count;i++)
        {
            var node=nodes[i].AsGodotDictionary();bool major=(i-1)%4==0;var candidate=node.Duplicate();candidate["chamber_radius"]=major?26:22;candidate["chamber_height"]=major?26:20;
            if(room_fits(candidate)&&Profiles.compatible(candidate["point"].AsVector3(),candidate["chamber_radius"].AsDouble(),candidate["chamber_height"].AsDouble(),region,new A())){node["chamber_radius"]=candidate["chamber_radius"];node["chamber_height"]=candidate["chamber_height"];if(major) enlarged++;}
            node["hive_role"]=major?"primary_nerve_junction":"organic_chamber";
        }
        var core=nodes[nodes.Count>9?9:nodes.Count>5?5:1].AsGodotDictionary();region["underground_hive_center"]=core["point"];region["hive_core_node"]=core["id"];region["underground_geometry"]=true;var pockets=new A();var corePoint=core["point"].AsVector3();
        for(int lobe=0;lobe<6;lobe++)
        {
            double angle=Random(cell,4300)*Math.Tau+lobe*Math.Tau/6,span=30+Random(cell,4310+lobe)*8;
            var room=new D {["id"]=core["id"].AsString()+":neural_lobe:"+lobe,["parent"]=core["id"],["point"]=corePoint+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*(float)span,["level"]=core["level"],["chamber_radius"]=22+Random(cell,4320+lobe)*3,["chamber_height"]=22+Random(cell,4330+lobe)*4,["hive_role"]="folded_core_lobe"};
            if(!room_fits(room)||!Profiles.compatible(room["point"].AsVector3(),room["chamber_radius"].AsDouble(),room["chamber_height"].AsDouble(),region,pockets)) continue;
            bool clear=true;int count=(int)Math.Ceiling(span/2);
            for(int step=0;step<=count;step++) if(!Profiles.compatible(corePoint.Lerp(room["point"].AsVector3(),(float)((double)step/count)),4,8,region,pockets)){clear=false;break;}
            if(clear) pockets.Add(room);
        }
        region["pockets"]=pockets;region["pocket_passages"]=Profiles.passages(region,pockets);int branches=0,originalCount=nodes.Count;
        foreach(int parentIndex in new[]{5,9})
        {
            if(parentIndex>=originalCount) continue;var parent=nodes[parentIndex].AsGodotDictionary();
            for(int attempt=0;attempt<8;attempt++)
            {
                double angle=Random(cell,4400+parentIndex)*Math.Tau+attempt*Math.Tau/8;
                var child=new D {["id"]=parent["id"].AsString()+":nerve_branch",["point"]=parent["point"].AsVector3()+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*76,["level"]=parent["level"],["chamber_radius"]=16.0,["chamber_height"]=16.0,["hive_role"]="secondary_nerve_chamber"};
                if(!room_fits(child)||!Profiles.compatible(child["point"].AsVector3(),16,16,region,pockets)) continue;
                var edge=Branch(parent,child);var rooms=nodes.Duplicate();rooms.AddRange(pockets);var retained=edges.Duplicate();retained.AddRange(Profiles.protected_edges(rooms));
                if(edge.Count==0||!network!.Call("supported_join",edge,retained).AsBool()) continue;
                edge["hive_role"]="secondary_nerve_conduit";nodes.Add(child);edges.Add(edge);branches++;break;
            }
        }
        region["primary_hive_chambers"]=enlarged;region["secondary_nerve_branches"]=branches;return region;
    }
}
