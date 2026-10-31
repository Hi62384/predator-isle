using Godot;
using System;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class CrystalCorridorFeatures : RefCounted
{
    private static readonly CaveBiomeRegions Regions=new();
    private static Variant Get(D d,string key,Variant fallback=default)=>d.ContainsKey(key)?d[key]:fallback;
    private static A Items(D d,string key)=>Get(d,key,new A()).AsGodotArray();
    private static int Compare(D a,D b){int priority=a["priority"].AsDouble().CompareTo(b["priority"].AsDouble());return priority!=0?priority:StringComparer.Ordinal.Compare(a["id"].AsString(),b["id"].AsString());}
    private static void Sort(A values){var sorted=values.Select(v=>v.AsGodotDictionary()).ToList();sorted.Sort(Compare);values.Clear();foreach(var item in sorted)values.Add(item);}
    public bool order(D a,D b)=>Compare(a,b)<0;
    public void propose(A candidates,D seen,D region,D edge,double total,double along,Vector3 middle,Vector3 side,long station_id,Vector3 origin,long seed_id,double density)
    {
        if(middle.X<origin.X-36||middle.X>origin.X+100||middle.Z<origin.Z-36||middle.Z>origin.Z+100||middle.Y<origin.Y-36||middle.Y>origin.Y+100)return;
        var assignment=Regions.along_edge(Get(region,"cave_biome_regions",new D()).AsGodotDictionary(),Get(edge,"from","").AsString(),Get(edge,"to","").AsString(),along,total);
        if(Get(assignment["weights"].AsGodotDictionary(),"crystal",0).AsDouble()<.6)return;
        string theme=Get(assignment["candidate_ids"].AsGodotDictionary(),"crystal","").AsString();int family=Math.Min(5,(int)(Regions.random(theme,seed_id,"crystal/mineral")*6));
        for(int direction=0;direction<3;direction++)
        {
            string id="corridor/"+Get(edge,"from","").AsString()+"/"+Get(edge,"to","").AsString()+"/"+station_id+"/"+direction;
            if(seen.ContainsKey(id)||Regions.random(id,seed_id,"corridor/admit")>density*.65)continue;
            seen[id]=true;candidates.Add(new D {["id"]=id,["theme"]=theme,["family"]=family,["start"]=middle+Vector3.Up*3.5f,["direction"]=direction==2?Vector3.Up:side*(direction==0?1:-1),["priority"]=Regions.random(id,seed_id,"corridor/priority")});
            if(candidates.Count>64){Sort(candidates);candidates.Resize(64);}
        }
    }
    public int append(GodotObject generator,GodotObject field,A regions,long seed_id,D configuration)
    {
        double density=Get(configuration,"density",.65).AsDouble();if(!Get(configuration,"corridor_growth",false).AsBool()||density<=0)return 0;
        var candidates=new A();var seen=new D();var origin=generator.Get("origin").AsVector3();
        foreach(var item in regions)
        {
            var region=item.AsGodotDictionary();if(!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7)continue;
            var regional=(Vector2)region["id"].AsVector2I()*1536;if(origin.X+64<regional.X-36||origin.X>regional.X+1572||origin.Z+64<regional.Y-36||origin.Z>regional.Y+1572)continue;
            foreach(var raw in Items(region,"edges").Concat(Items(region,"pocket_passages")))
            {
                var edge=raw.AsGodotDictionary();if(Get(edge,"entrance",false).AsBool())continue;var points=edge["points"].AsVector3Array();double total=0,station=0;for(int index=0;index<points.Length-1;index++)total+=points[index].DistanceTo(points[index+1]);
                for(int index=0;index<points.Length-1;index++)
                {
                    var a=points[index];var b=points[index+1];double length=a.DistanceTo(b);int first=Math.Max(0,(int)Math.Ceiling(station/8-.5)),last=(int)Math.Ceiling((station+length)/8-.5)-1;double start=station;station+=length;if(length<.01)continue;
                    var forward=new Vector3(b.X-a.X,0,b.Z-a.Z).Normalized();var side=new Vector3(-forward.Z,0,forward.X);if(side.LengthSquared()<.9)continue;
                    for(int id=first;id<=last;id++){double along=(id+.5)*8;var middle=a.Lerp(b,(float)((along-start)/length));propose(candidates,seen,region,edge,total,along,middle,side,id,origin,seed_id,density);}
                }
            }
        }
        Sort(candidates);int emitted=0;var placements=generator.Get("placements").AsGodotArray();var key=generator.Get("key").AsVector3I();
        foreach(var item in candidates)
        {
            if(emitted>=24||placements.Count>=160)break;var candidate=item.AsGodotDictionary();var root=generator.Call("boundary",field,candidate["start"],candidate["direction"],32).AsVector3();
            if(!root.IsFinite()||(field is CaveField native?native.cell(root):field.Call("cell",root).AsVector3I())!=key)continue;
            var axis=field is CaveField nativeField?nativeField.normal(root):field.Call("normal",root).AsVector3();string id=candidate["id"].AsString();int family=candidate["family"].AsInt32();double height=Math.Min(Get(configuration,"maximum_height",32).AsDouble(),1.2+Regions.random(id,seed_id,"corridor/height")*1.6),width=height*(family==2?.06:.14);
            if(family==4)width=height/Math.Sqrt(2);else if(family==5)width=height*.55;
            if(generator.Call("form",field,root,axis,width,height,family,Regions.random(id,seed_id,"corridor/broken")<.2,Regions.random(candidate["theme"].AsString(),seed_id,"crystal/weather")*.7,id,1,true,Regions.random(id,seed_id,"corridor/phase")*Math.Tau).AsBool())
            {var form=placements[placements.Count-1].AsGodotDictionary();form["corridor_crystal"]=true;form["region_theme"]=candidate["theme"];emitted++;}
        }
        return emitted;
    }
}
