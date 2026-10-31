using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CrystalConnectedProfiles : RefCounted
{
    private static readonly CaveBiomeRegions Regions=new();
    private static readonly CaveChamberProfiles Profiles=new();
    private static readonly CaveSeepageBasins Basins=new();
    private static Variant Get(D d,string key,Variant fallback=default)=>d.ContainsKey(key)?d[key]:fallback;
    private static A Items(D d,string key)=>Get(d,key,new A()).AsGodotArray();
    private static double N(D d,string key)=>d[key].AsDouble();
    private static D Assignment(D d)=>Get(d,"cave_biome_regions",new D()).AsGodotDictionary();
    private static Vector3 V(double x,double y,double z)=>new((float)x,(float)y,(float)z);
    public bool dry_bank(GodotObject field,D pool,double radius)
    {
        foreach(double offset in new[]{1.0,2.0,3.0})for(int station=0;station<64;station++)
        {
            double angle=Math.Tau*station/64;var p=pool["center"].AsVector3()+V(Math.Cos(angle)*(radius+offset),0,Math.Sin(angle)*(radius+offset));var low=p-Vector3.Up*4;var high=p+Vector3.Up*6;
            if(Sample(low)<.1||Sample(high)>-.3)return false;
            for(int iteration=0;iteration<16;iteration++){var mid=(low+high)*.5f;if(Sample(mid)>=0)low=mid;else high=mid;}var floor=(low+high)*.5f;
            if(floor.Y<N(pool,"water_y")+.2||floor.Y>pool["center"].AsVector3().Y+4||Normal(floor).Y<.8||Sample(floor+Vector3.Up*1.8f)>-.3)return false;
        }
        return true;
        double Sample(Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
        Vector3 Normal(Vector3 p)=>field is CaveField native?native.normal(p):field.Call("normal",p).AsVector3();
    }
    public bool covered(Vector3 point,double radius,double headroom,Callable height,double maximum_depth,double minimum_roof)
    {
        for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++)
        {
            if(new Vector2(x,z).Length()>2.1)continue;double surface=height.Call(point.X+x*radius*.5,point.Z+z*radius*.5).AsDouble();
            if(!double.IsFinite(surface)||surface-point.Y>maximum_depth-4||surface-point.Y<headroom+minimum_roof+4)return false;
        }
        return true;
    }
    public bool corridor_clear(Vector3 a,Vector3 b,D region,A pockets,Callable height,double maximum_depth,double minimum_roof)
    {
        int stations=Math.Max(1,(int)Math.Ceiling(a.DistanceTo(b)/2.0));
        for(int i=0;i<=stations;i++)
        {
            var p=a.Lerp(b,(float)((double)i/stations));if(!Profiles.compatible(p,4,8,region,pockets)||!covered(p,4,8,height,maximum_depth,minimum_roof))return false;
            foreach(var item in Items(region,"pools"))
            {
                var pool=item.AsGodotDictionary();var center=pool["center"].AsVector3();
                if(p.Y+8.5>N(pool,"bed_y")-.5&&p.Y-.5<N(pool,"water_y")+1&&new Vector2(p.X-center.X,p.Z-center.Z).Length()<N(pool,"radius")+6)return false;
                if(!Basins.route_clear(p,4,p.Y-.5,p.Y+8,new D {["edges"]=Items(pool,"stream_edges")}))return false;
            }
        }
        return true;
    }
    public D decorate(D region,Callable height,long seed_id,D settings,double maximum_depth,double minimum_roof)
    {
        if(!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7||region.ContainsKey("crystal_connected_profiles_version"))return region;
        double geodes=Math.Clamp(Get(settings,"geode_frequency",.15).AsDouble(),0,1),ravines=Math.Clamp(Get(settings,"ravine_frequency",.08).AsDouble(),0,1),lakes=Math.Clamp(Get(settings,"large_lake_frequency",.12).AsDouble(),0,1);
        if(geodes<=0&&ravines<=0&&lakes<=0)return region;
        var output=region.Duplicate(true);var pockets=Items(output,"pockets");var passages=Items(output,"pocket_passages");var parents=Items(output,"nodes").Select(v=>v.AsGodotDictionary()).OrderBy(d=>d["id"].AsString(),StringComparer.Ordinal).ToArray();int added=0;bool changed=false;
        foreach(var parent in parents)
        {
            if(added>=4||pockets.Count>=24)break;if(Get(parent,"level",-1).AsInt64()<0||Get(parent,"chamber_radius",0).AsDouble()<20)continue;
            string parentId=parent["id"].AsString();var assignment=Regions.along_edge(Assignment(region),parentId,parentId,0,0);if(Get(assignment["weights"].AsGodotDictionary(),"crystal",0).AsDouble()<.8)continue;
            string identity=Get(assignment["candidate_ids"].AsGodotDictionary(),"crystal",parentId).AsString();double sample=Regions.random(parentId,seed_id,"crystal/connected_profile");bool ravine=sample<ravines,geode=!ravine&&sample<ravines+geodes;if(!ravine&&!geode)continue;
            var source=new D();foreach(var item in Items(Assignment(region),"candidates")){var candidate=item.AsGodotDictionary();if(candidate["id"].AsString()==identity){source=candidate;break;}}if(source.Count==0)continue;
            double heading=Regions.random(identity,seed_id,"crystal/profile_axis")*Math.Tau;var previous=parent;int count=ravine?3:2;
            for(int lobe=0;lobe<count;lobe++)
            {
                if(added>=4||pockets.Count>=24)break;string id=parentId+":crystal:"+(ravine?"ravine:":"geode:")+lobe;double yaw=ravine?heading:heading+(lobe==0?-.75:.9),radius=(ravine?12:15)+Regions.random(id,seed_id,"radius")*(ravine?3:5),span=ravine?22:28;
                var point=previous["point"].AsVector3()+V(Math.Cos(yaw),0,Math.Sin(yaw))*(float)span;double headroom=(ravine?36:26)+Regions.random(id,seed_id,"vault")*12;
                if(Get(source["distances"].AsGodotDictionary(),parentId,double.PositiveInfinity).AsDouble()+span*(ravine?lobe+1:1)>N(source,"reach_m")-N(source,"transition_m"))continue;
                if(!Profiles.compatible(point,radius,headroom,output,pockets)||!corridor_clear(previous["point"].AsVector3(),point,output,pockets,height,maximum_depth,minimum_roof)||!covered(point,radius,headroom,height,maximum_depth,minimum_roof))continue;
                var room=new D {["id"]=id,["parent"]=previous["id"],["point"]=point,["level"]=parent["level"],["chamber_radius"]=radius,["chamber_height"]=headroom,["cross_section_style"]=ravine?3:0,["crystal_layout"]=geode?2:1,["crystal_profile"]=ravine?"ravine":"geode",["crystal_region"]=identity};
                pockets.Add(room);passages.Add(new D {["from"]=previous["id"].AsString(),["to"]=id,["points"]=new[]{previous["point"].AsVector3(),point},["half_width"]=4.0,["headroom"]=8.0,["entrance"]=false,["maximum_grade"]=0.0});previous=ravine?room:parent;added++;changed=true;
            }
        }
        output["pockets"]=pockets;output["pocket_passages"]=passages;
        if(changed)
        {
            var topology=Regions.graph(output);if(topology.Count==0)return region;var assignment=Assignment(output);assignment["edges"]=topology["edges"];
            foreach(var item in Items(assignment,"candidates")){var candidate=item.AsGodotDictionary();if(candidate["biome_id"].AsString()=="crystal")candidate["distances"]=Regions.distances(topology,candidate["anchor"].AsString(),N(candidate,"reach_m"));}
        }
        CaveField? field=null;
        try
        {
            var pools=Items(output,"pools");foreach(var item in pools)
            {
                var pool=item.AsGodotDictionary();string poolId=pool["id"].AsString(),parent=poolId.EndsWith(":seepage",StringComparison.Ordinal)?poolId[..^8]:poolId;
                if(Get(Regions.along_edge(Assignment(output),parent,parent,0,0)["weights"].AsGodotDictionary(),"crystal",0).AsDouble()<.8||Regions.random(poolId,seed_id,"crystal/large_lake")>=lakes)continue;
                double radius=8+Regions.random(poolId,seed_id,"crystal/lake_radius")*4,depth=Math.Min(N(pool,"depth")*1.2,4.5);var center=pool["center"].AsVector3();double bedY=center.Y-depth;
                if(radius<=N(pool,"radius")||!Basins.route_clear(center,radius,bedY,N(pool,"water_y"),output)||!Profiles.compatible(center,radius,8,output,pockets)||!covered(V(center.X,bedY,center.Z),radius,depth+8,height,maximum_depth,minimum_roof))continue;
                bool collision=false;foreach(var raw in pools){var other=raw.AsGodotDictionary();if(other["id"].AsString()==poolId)continue;var c=other["center"].AsVector3();if(new Vector2(c.X-center.X,c.Z-center.Z).Length()<radius+N(other,"radius")+2&&Math.Abs(N(other,"water_y")-N(pool,"water_y"))<N(other,"depth")+depth+2){collision=true;break;}}if(collision)continue;
                if(field==null){field=new CaveField {maximum_depth=maximum_depth,minimum_roof=minimum_roof};if(!field.compile(new A {output},height)){field.Dispose();field=null;continue;}}
                if(!dry_bank(field,pool,radius))continue;
                double ratio=radius/N(pool,"radius");pool["crystal_original_radius"]=pool["radius"];pool["crystal_large_lake"]=true;pool[new StringName("radius")]=radius;pool[new StringName("depth")]=depth;pool[new StringName("bed_y")]=bedY;pool[new StringName("water_radius")]=radius*.8;
                var bed=pool["bed"].AsGodotDictionary();var bp=bed["point"].AsVector3();bp.Y=(float)bedY;bed[new StringName("point")]=bp;bed[new StringName("chamber_radius")]=radius*.85;bed[new StringName("chamber_height")]=depth+8;
                foreach(var raw in Items(pool,"bed_lobes")){var lobe=raw.AsGodotDictionary();var offset=lobe["point"].AsVector3()-center;lobe[new StringName("point")]=V(center.X+offset.X*ratio,bedY+.15,center.Z+offset.Z*ratio);lobe[new StringName("chamber_radius")]=radius*.65;lobe[new StringName("chamber_height")]=depth+8;}changed=true;
            }
        }
        finally{field?.Dispose();}
        if(!changed)return region;output["crystal_connected_profiles_version"]=1;return output;
    }
}
