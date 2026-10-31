using Godot;
using System;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Bounded widening of short solved passages, retaining graph identity, floors and grades.</summary>
public partial class MagmaCaveTubes : RefCounted
{
    private readonly CaveChamberProfiles Profiles=new();private readonly CaveSeepageBasins Basins=new();private readonly CaveBiomeRegions Regions=new();
    private static A Items(D d,string key)=>d.ContainsKey(key)?d[key].AsGodotArray():new A();
    private static Variant Get(D d,string key,Variant fallback)=>d.ContainsKey(key)?d[key]:fallback;
    public bool clear(Vector3 p,double width,double headroom,D region,Callable height,double maximum_depth,double minimum_roof)
    {
        if(!Profiles.compatible(p,width,headroom,region,Items(region,"pockets")))return false;
        foreach(var offset in new[]{Vector2.Zero,new Vector2((float)width,0),new Vector2((float)-width,0),new Vector2(0,(float)width),new Vector2(0,(float)-width)})
        {
            double surface=height.Call((double)p.X+offset.X,(double)p.Z+offset.Y).AsDouble();if(!double.IsFinite(surface)||surface-p.Y>maximum_depth-4||surface-p.Y<headroom+minimum_roof+4)return false;
        }
        foreach(var item in Items(region,"pools"))
        {
            var pool=item.AsGodotDictionary();var center=pool["center"].AsVector3();
            if(new Vector2(p.X-center.X,p.Z-center.Z).Length()<width+pool["radius"].AsDouble()+2&&p.Y+headroom>pool["bed_y"].AsDouble()-1&&p.Y<pool["water_y"].AsDouble()+1)return false;
            if(!Basins.route_clear(p,width,p.Y-.5,p.Y+headroom,new D {["edges"]=Items(pool,"stream_edges")}))return false;
        }
        return true;
    }
    public D decorate(D region,Callable height,long seed_id,D configuration,double maximum_depth,double minimum_roof)
    {
        if(!Get(configuration,"cooled_tubes",true).AsBool()||!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7)return region;
        var result=region;bool changed=false;int additions=0;
        foreach(string table in new[]{"edges","pocket_passages"})
        {
            var edges=Items(region,table).Duplicate();
            for(int index=0;index<edges.Count;index++)
            {
                if(additions>=2)break;var edge=edges[index].AsGodotDictionary();if(edge["entrance"].AsBool())continue;var points=edge["points"].AsVector3Array();double length=0;
                for(int station=1;station<points.Length;station++)length+=points[station-1].DistanceTo(points[station]);if(length<8||length>256)continue;
                string from=edge["from"].AsString(),to=edge["to"].AsString();double frequency=Get(configuration,"tube_frequency",1.0).AsDouble();if(frequency<=0||frequency<1&&Regions.random(from+":"+to,seed_id,"magma/tube_admission")>=frequency)continue;
                var assignment=Get(region,"cave_biome_regions",new D()).AsGodotDictionary();var a=Regions.along_edge(assignment,from,to,0,length);var b=Regions.along_edge(assignment,from,to,length,length);
                if(Math.Min(Get(a["weights"].AsGodotDictionary(),"magma",0).AsDouble(),Get(b["weights"].AsGodotDictionary(),"magma",0).AsDouble())<.8)continue;
                string identity=Get(a["candidate_ids"].AsGodotDictionary(),"magma",edge["from"]).AsString();int shape=Math.Min(2,(int)(Regions.random(identity,seed_id,"magma/tube_profile")*3));double width=shape==0?8:6,headroom=shape==0?12:shape==1?18:13;bool admitted=true;
                if(Regions.random(identity,seed_id,"magma/fissure")<Get(configuration,"fissure_frequency",.12).AsDouble()){shape=3;width=6;headroom=32;}
                for(int station=1;station<points.Length;station++)
                {
                    int steps=Math.Max(1,(int)Math.Ceiling(points[station-1].DistanceTo(points[station])/2.0));
                    for(int probe=0;probe<=steps;probe++)if(!clear(points[station-1].Lerp(points[station],(float)((double)probe/steps)),width,headroom,region,height,maximum_depth,minimum_roof)){admitted=false;break;}
                    if(!admitted)break;
                }
                if(!admitted)continue;var tube=edge.Duplicate();tube["half_width"]=Math.Max(edge["half_width"].AsDouble(),width);tube["headroom"]=Math.Max(edge["headroom"].AsDouble(),headroom);tube["cross_section_style"]=shape<2?0:shape==3?2:3;tube["retain_cross_section_style"]=true;tube["magma_tube_profile"]=new[]{"broad_cooled_flow","high_cooled_tube","irregular_cooled_tube","great_volcanic_fissure"}[shape];edges[index]=tube;additions++;
                if(!changed){result=region.Duplicate();changed=true;}
            }
            if(changed)result[table]=edges;
        }
        return result;
    }
}
