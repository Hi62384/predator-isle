using Godot;
using System;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Insect excavation of the same cave graph, with shared Alien hive fallback.</summary>
public partial class CaveColonyNetwork : CaveHiveNetwork
{
    public override D context(Vector2I cell)
    {
        var sampler=builder.Get("_extras").AsGodotArray()[6].AsGodotObject();
        if(!configuration.Get("insect_networks").AsBool()||sampler==null||!sampler.Get("settings").AsGodotObject().Get("caves_enabled").AsBool()) return base.context(cell);
        var center=Center(cell);builder.Call("_biome_weights",center.X,center.Y);if(builder.Get("_extra_weights").AsFloat64Array()[6]<.65) return base.context(cell);
        var colony=sampler.Call("nearby",center,2100*sampler.Get("settings").AsGodotObject().Get("feature_scale").AsDouble()).AsGodotDictionary();
        return new D {["family"]=6,["render_style"]=6,["colony_id"]=colony["id"],["surface_center"]=colony["position"],["half_width"]=network!.Get("half_width").AsDouble()*1.25,["headroom"]=Math.Min(18,network.Get("headroom").AsDouble()*1.25),["flat_radius"]=36.0};
    }
    public override D decorate(D region,D description)
    {
        if(Family(description)==7) return base.decorate(region,description);
        if(Family(description)!=6||!region.ContainsKey("valid")||!region["valid"].AsBool()) return region;
        region["cave_family"]=6;region["geology"]=6;region["render_style"]=6;region["cross_section_style"]=0;region["colony_id"]=description["colony_id"];region["surface_colony_center"]=description["surface_center"];region["construction"]="excavated_compacted_earth";
        var nodes=Items(region,"nodes");var edges=Items(region,"edges");int enlarged=0;
        for(int index=1;index<nodes.Count;index++)
        {
            var node=nodes[index].AsGodotDictionary();bool major=(index-1)%4==0;var candidate=node.Duplicate();candidate["chamber_radius"]=major?26:20;candidate["chamber_height"]=major?24:18;
            if(room_fits(candidate)&&Profiles.compatible(candidate["point"].AsVector3(),candidate["chamber_radius"].AsDouble(),candidate["chamber_height"].AsDouble(),region,new A())){node["chamber_radius"]=candidate["chamber_radius"];node["chamber_height"]=candidate["chamber_height"];if(major) enlarged++;}
            node["excavation_role"]=major?"major_chamber":"secondary_chamber";
        }
        region["underground_colony_center"]=nodes[nodes.Count>5?5:1].AsGodotDictionary()["point"];int branches=0,originalCount=nodes.Count;var cell=region["id"].AsVector2I();
        foreach(int parentIndex in new[]{5,9})
        {
            if(parentIndex>=originalCount) continue;var parent=nodes[parentIndex].AsGodotDictionary();
            for(int attempt=0;attempt<8;attempt++)
            {
                double angle=Random(cell,3100+parentIndex)*Math.Tau+attempt*Math.Tau/8;var p=parent["point"].AsVector3()+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*72;
                var child=new D {["id"]=parent["id"].AsString()+":satellite",["point"]=p,["level"]=parent["level"],["chamber_radius"]=14.0,["chamber_height"]=14.0,["excavation_role"]="satellite_chamber"};
                if(!room_fits(child)||!Profiles.compatible(p,14,14,region,new A())) continue;
                var edge=Branch(parent,child);if(edge.Count==0) continue;var retained=edges.Duplicate();retained.AddRange(Profiles.protected_edges(nodes));if(!network!.Call("supported_join",edge,retained).AsBool()) continue;
                edge["excavation_role"]="secondary_passage";nodes.Add(child);edges.Add(edge);branches++;break;
            }
        }
        region["major_excavation_chambers"]=enlarged;region["satellite_passages"]=branches;return region;
    }
}
