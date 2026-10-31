using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CrystalShallowChambers : RefCounted
{
    private static readonly CaveBiomeRegions Regions=new();
    private static readonly ShallowCaveChambers Shallow=new();
    private static A Items(D d,string key)=>d.ContainsKey(key)?d[key].AsGodotArray():new();
    private static D Assignment(D d)=>d.ContainsKey("cave_biome_regions")?d["cave_biome_regions"].AsGodotDictionary():new();
    private static double Weight(D assignment,string id){var weights=Regions.along_edge(assignment,id,id,0,0)["weights"].AsGodotDictionary();return weights.ContainsKey("crystal")?weights["crystal"].AsDouble():0;}
    public D prepare(D region,Callable height)=>prepare(region,height,true,400,10);
    public D prepare(D region,Callable height,bool enabled)=>prepare(region,height,enabled,400,10);
    public D prepare(D region,Callable height,bool enabled,double maximum_depth)=>prepare(region,height,enabled,maximum_depth,10);
    public D prepare(D region,Callable height,bool enabled,double maximum_depth,double minimum_roof)
    {
        long family=region.ContainsKey("cave_family")?region["cave_family"].AsInt64():-1;
        if(!enabled||!region.ContainsKey("valid")||!region["valid"].AsBool()||family is 6 or 7||Items(region,"nodes").Count<2)return region;
        foreach(var value in Items(region,"pockets")){var room=value.AsGodotDictionary();if(room.ContainsKey("shallow_chamber")&&room["shallow_chamber"].AsBool())return region;}
        string parent=region["nodes"].AsGodotArray()[1].AsGodotDictionary()["id"].AsString();if(Weight(Assignment(region),parent)<.8)return region;
        var proposal=Shallow.prepare(region,height,true,maximum_depth,minimum_roof);if(Items(proposal,"pockets").Count==Items(region,"pockets").Count)return region;
        var topology=Regions.graph(proposal);if(topology.Count==0)return region;var assignment=Assignment(proposal).Duplicate(true);assignment[new StringName("edges")]=topology["edges"];
        foreach(var value in Items(assignment,"candidates")){var candidate=value.AsGodotDictionary();if(candidate["biome_id"].AsString()=="crystal")candidate[new StringName("distances")]=Regions.distances(topology,candidate["anchor"].AsString(),candidate["reach_m"].AsDouble());}
        proposal[new StringName("cave_biome_regions")]=assignment;var pockets=Items(proposal,"pockets");string id=pockets[pockets.Count-1].AsGodotDictionary()["id"].AsString();return Weight(assignment,id)<.8?region:proposal;
    }
}
