using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CrystalLakeChambers : RefCounted
{
    private static readonly CaveChamberProfiles Profiles=new();
    private static readonly CrystalConnectedProfiles Base=new();
    private static readonly CaveBiomeRegions Regions=new();
    private static Variant Get(D d,string key,Variant fallback=default)=>d.ContainsKey(key)?d[key]:fallback;
    private static A Items(D d,string key)=>Get(d,key,new A()).AsGodotArray();
    private static double N(D d,string key)=>d[key].AsDouble();
    public D prepare(D region,Callable height,long seed_id,D settings)=>prepare(region,height,seed_id,settings,400,10);
    public D prepare(D region,Callable height,long seed_id,D settings,double maximum_depth)=>prepare(region,height,seed_id,settings,maximum_depth,10);
    public D prepare(D region,Callable height,long seed_id,D settings,double maximum_depth,double minimum_roof)
    {
        if(!Get(settings,"lake_chambers",false).AsBool()||!Get(settings,"chamber_growth",true).AsBool()||!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7)return region;
        var pools=Items(region,"pools");
        for(int index=0;index<pools.Count;index++)
        {
            var pool=pools[index].AsGodotDictionary();string poolId=pool["id"].AsString(),parentId=poolId.EndsWith(":seepage",StringComparison.Ordinal)?poolId[..^8]:poolId;
            if(Get(pool,"crystal_large_lake",false).AsBool()||Items(pool,"stream_edges").Count>0)continue;
            var assignment=Regions.along_edge(Get(region,"cave_biome_regions",new D()).AsGodotDictionary(),parentId,parentId,0,0);
            if(Get(assignment["weights"].AsGodotDictionary(),"crystal",0).AsDouble()<.8||Regions.random(poolId,seed_id,"crystal/large_lake")>=Get(settings,"large_lake_frequency",.12).AsDouble())continue;
            var parent=new D();foreach(var item in Items(region,"nodes").Concat(Items(region,"pockets"))){var room=item.AsGodotDictionary();if(room["id"].AsString()==parentId){parent=room;break;}}
            var center=pool["center"].AsVector3();if(parent.Count==0||Math.Abs((double)parent["point"].AsVector3().Y-center.Y)>.01)continue;
            const double radius=36,headroom=10;var regional=(Vector2)region["id"].AsVector2I()*1536;
            if(center.X-radius<regional.X+4||center.X+radius>regional.X+1532||center.Z-radius<regional.Y+4||center.Z+radius>regional.Y+1532)continue;
            if(!Profiles.compatible(center,radius,headroom,region,Items(region,"pockets"))||!Base.covered(center,radius,headroom,height,maximum_depth,minimum_roof))continue;
            bool unsafeWater=false;foreach(var item in pools){var other=item.AsGodotDictionary();var c=other["center"].AsVector3();if(other["id"].AsString()!=poolId&&N(other,"water_y")>center.Y+.1&&new Vector2(c.X-center.X,c.Z-center.Z).Length()<radius+N(other,"radius")+2)unsafeWater=true;}if(unsafeWater)continue;
            var bank=new D {["id"]=poolId+":crystal:bank",["point"]=center,["level"]=parent["level"],["chamber_radius"]=radius,["chamber_height"]=headroom,["cross_section_style"]=0,["biome_parent"]=parentId,["parent"]=parentId,["crystal_region"]=Get(assignment["candidate_ids"].AsGodotDictionary(),"crystal",parentId).AsString(),["crystal_layout"]=4,["crystal_profile"]="lake_bank"};
            var candidate=region.Duplicate(true);candidate["nodes"].AsGodotArray().Add(bank);candidate.Remove("crystal_connected_profiles_version");var controls=settings.Duplicate();controls[new StringName("geode_frequency")]=0.0;controls[new StringName("ravine_frequency")]=0.0;
            var result=Base.decorate(candidate,height,seed_id,controls,maximum_depth,minimum_roof);var grown=Items(result,"pools")[index].AsGodotDictionary();if(!Get(grown,"crystal_large_lake",false).AsBool())continue;
            var nodes=new A();foreach(var item in Items(result,"nodes"))if(item.AsGodotDictionary()["id"].AsString()!=bank["id"].AsString())nodes.Add(item);
            result[new StringName("nodes")]=nodes;grown["bank_lobes"]=new A {bank};grown["precise_shore"]=Get(settings,"precise_shores",true);
            var direction=parent["point"].AsVector3()-center;direction.Y=0;if(direction.LengthSquared()<.01)continue;var shore=center+direction.Normalized()*(float)(N(grown,"radius")+2);
            grown["bank_access"]=new A {new D {["from"]=parentId,["to"]=parentId,["points"]=new[]{parent["point"].AsVector3(),shore},["half_width"]=1.0,["headroom"]=3.0,["entrance"]=false,["biome_parent"]=parentId}};
            using var field=new CaveField {maximum_depth=maximum_depth,minimum_roof=minimum_roof};if(!field.compile(new A {result},height))continue;return result;
        }
        return region;
    }
}
