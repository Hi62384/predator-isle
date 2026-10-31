using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Source-backed finite lava lakes, unequal basalt vaults and measured dry walking banks.</summary>
public partial class MagmaLakeChambers : RefCounted
{
    private readonly CaveChamberProfiles Profiles=new();private readonly CaveSeepageBasins Basins=new();private readonly CaveBiomeRegions Regions=new();
    private static A Items(D d,string key)=>d.ContainsKey(key)?d[key].AsGodotArray():new A();
    private static Variant Get(D d,string key,Variant fallback)=>d.ContainsKey(key)?d[key]:fallback;
    private static double N(D d,string key)=>d[key].AsDouble();
    private static D Heat(GodotObject context,Vector3 point)=>context is MagmaCaveHeat native?native.sample(point):context.Call("sample",point).AsGodotDictionary();
    public bool covered(Vector3 point,double radius,double headroom,Callable height,double maximum_depth,double minimum_roof)
    {
        for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++)
        {
            if(new Vector2(x,z).Length()>2.1)continue;double surface=height.Call(point.X+x*radius*.5,point.Z+z*radius*.5).AsDouble();
            if(!double.IsFinite(surface)||surface-point.Y>maximum_depth-4||surface-point.Y<headroom+minimum_roof+4)return false;
        }
        return true;
    }
    public bool dry_bank(GodotObject field,D pool)
    {
        foreach(double offset in new[]{1.0,2.0,3.0})for(int station=0;station<64;station++)
        {
            double angle=Math.Tau*station/64;var p=pool["center"].AsVector3()+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*(float)(N(pool,"radius")+offset);var low=p-Vector3.Up*4;var high=p+Vector3.Up*6;
            if(Sample(low)<.1||Sample(high)>-.3)return false;
            for(int iteration=0;iteration<16;iteration++){var mid=(low+high)*.5f;if(Sample(mid)>=0)low=mid;else high=mid;}var floor=(low+high)*.5f;
            if(floor.Y<N(pool,"water_y")+.2||floor.Y>pool["center"].AsVector3().Y+4||Normal(floor).Y<.8||Sample(floor+Vector3.Up*1.8f)>-.3)return false;
        }
        return true;
        double Sample(Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
        Vector3 Normal(Vector3 p)=>field is CaveField native?native.normal(p):field.Call("normal",p).AsVector3();
    }
    public D prepare(D region,Callable height,long seed_id,D settings,double maximum_depth,double minimum_roof,GodotObject? heat_context)
    {
        if(!Get(settings,"large_lake_chambers",false).AsBool()||heat_context==null||!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7)return region;
        var pools=Items(region,"pools");
        for(int index=0;index<pools.Count;index++)
        {
            var pool=pools[index].AsGodotDictionary();string poolId=pool["id"].AsString();
            if(Get(pool,"fluid_kind","").AsString()!="magma"||Get(pool,"magma_large_lake",false).AsBool()||Items(pool,"stream_edges").Count>0||Regions.random(poolId,seed_id,"magma/large_lake")>=Get(settings,"large_lake_chance",.08).AsDouble())continue;
            string parentId=poolId.EndsWith(":seepage",StringComparison.Ordinal)?poolId[..^8]:poolId;var parent=new D();var rooms=Items(region,"nodes").Duplicate();rooms.AddRange(Items(region,"pockets"));
            foreach(var item in rooms){var room=item.AsGodotDictionary();if(room["id"].AsString()==parentId){parent=room;break;}}if(parent.Count==0)continue;
            var biomeAssignment=Get(region,"cave_biome_regions",new D()).AsGodotDictionary();var assignment=Regions.along_edge(biomeAssignment,parentId,parentId,0,0);string sourceId=Get(assignment["candidate_ids"].AsGodotDictionary(),"magma","").AsString();bool fitsExtent=false;
            foreach(var item in Items(biomeAssignment,"candidates"))
            {
                var candidate=item.AsGodotDictionary();if(candidate["id"].AsString()==sourceId&&Get(candidate["distances"].AsGodotDictionary(),parentId,double.PositiveInfinity).AsDouble()+N(parent,"chamber_radius")+34<=N(candidate,"reach_m")-N(candidate,"transition_m")){fitsExtent=true;break;}
            }
            if(!fitsExtent)continue;var parentPoint=parent["point"].AsVector3();var direction=(pool["center"].AsVector3()-parentPoint)*new Vector3(1,0,1);if(direction.LengthSquared()<.01)continue;
            direction=direction.Normalized();var center=parentPoint+direction*(float)(N(parent,"chamber_radius")+20);const double radius=14,bankRadius=36;var regional=(Vector2)region["id"].AsVector2I()*1536;
            if(center.X-bankRadius<regional.X+4||center.X+bankRadius>regional.X+1532||center.Z-bankRadius<regional.Y+4||center.Z+bankRadius>regional.Y+1532)continue;
            if(!Profiles.compatible(center,bankRadius,10,region,Items(region,"pockets"))||!covered(center,bankRadius,12,height,maximum_depth,minimum_roof)||!Basins.route_clear(center,radius,center.Y-4.5,N(pool,"water_y"),region))continue;
            var source=Heat(heat_context,new Vector3(center.X,(float)N(pool,"water_y"),center.Z));string thermal=pool["thermal_source"].AsString();bool admitted=N(source,"heat")>=.5&&Get(source,"id","").AsString()==thermal;
            for(int station=0;station<32;station++)
            {
                double angle=Math.Tau*station/32;var witness=Heat(heat_context,new Vector3((float)(center.X+Math.Cos(angle)*radius),(float)N(pool,"water_y"),(float)(center.Z+Math.Sin(angle)*radius)));
                if(N(witness,"heat")<.5||Get(witness,"id","").AsString()!=thermal){admitted=false;break;}
            }
            foreach(var item in pools){var other=item.AsGodotDictionary();var otherCenter=other["center"].AsVector3();if(other["id"].AsString()!=poolId&&new Vector2(otherCenter.X-center.X,otherCenter.Z-center.Z).Length()<bankRadius+N(other,"radius")+2&&Math.Abs(N(other,"water_y")-N(pool,"water_y"))<14){admitted=false;break;}}
            if(!admitted)continue;var result=region.Duplicate(true);var grown=Items(result,"pools")[index].AsGodotDictionary();var oldCenter=grown["center"].AsVector3();double ratio=radius/N(grown,"radius");grown["center"]=center;grown["radius"]=radius;grown["water_radius"]=radius*.8;grown["depth"]=4.5;grown["bed_y"]=center.Y-4.5;var bed=grown["bed"].AsGodotDictionary();bed["point"]=new Vector3(center.X,(float)N(grown,"bed_y"),center.Z);bed["chamber_radius"]=radius*.85;bed["chamber_height"]=12.5;grown["surface_witness"]=source["surface_witness"];grown["source_heat"]=source["heat"];
            foreach(var item in Items(grown,"bed_lobes")){var lobe=item.AsGodotDictionary();var offset=(lobe["point"].AsVector3()-oldCenter)*new Vector3(1,0,1);lobe["point"]=new Vector3(center.X,(float)(N(grown,"bed_y")+.15),center.Z)+offset*(float)ratio;lobe["chamber_radius"]=radius*.65;lobe["chamber_height"]=12.5;}
            var lobes=new A {new D {["id"]=poolId+":magma:bank",["point"]=center,["level"]=parent["level"],["chamber_radius"]=bankRadius,["chamber_height"]=10.0,["cross_section_style"]=0,["biome_parent"]=parentId,["parent"]=parentId}};grown["bank_lobes"]=lobes;bool tall=true;
            foreach(int side in new[]{-1,1})
            {
                var point=center+direction.Cross(Vector3.Up)*side*10;double vault=side<0?38:46;
                if(!Profiles.compatible(point,24,vault,region,Items(region,"pockets"))||!covered(point,24,vault,height,maximum_depth,minimum_roof)){tall=false;break;}
                lobes.Add(new D {["id"]=poolId+":magma:vault:"+side,["point"]=point,["level"]=parent["level"],["chamber_radius"]=24.0,["chamber_height"]=vault,["cross_section_style"]=0,["biome_parent"]=parentId,["parent"]=parentId});
            }
            if(!tall)continue;grown["bank_access"]=new A {new D {["from"]=parentId,["to"]=parentId,["points"]=new[]{parentPoint,center-direction*(float)(radius+2)},["half_width"]=1.0,["headroom"]=3.0,["entrance"]=false,["biome_parent"]=parentId}};grown["precise_shore"]=true;grown["protected_dry_bank"]=true;grown["magma_large_lake"]=true;
            using var field=new CaveField {maximum_depth=maximum_depth,minimum_roof=minimum_roof};if(!field.compile(new A {result},height,new A(),Get(result,"cave_biome_regions",new D()).AsGodotDictionary())||!dry_bank(field,grown))continue;return result;
        }
        return region;
    }
}
