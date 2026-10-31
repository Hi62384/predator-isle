using Godot;
using System;
using System.Linq;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
public partial class ShallowCaveChambers : RefCounted
{
    private static readonly CaveChamberProfiles Profiles=new();
    private static A Items(D d,string key)=>d.ContainsKey(key)?d[key].AsGodotArray():new();
    private static double N(D d,string key)=>d[key].AsDouble();
    private static bool Flag(D d,string key)=>d.ContainsKey(key)&&d[key].AsBool();
    private static Vector3 V(double x,double y,double z)=>new((float)x,(float)y,(float)z);
    private static bool FloorSafe(CaveField original,CaveField candidate,Vector3 a,Vector3 b,double width)
    {
        var across=new Vector2(-(b-a).Z,(b-a).X).Normalized();int count=Math.Max(1,(int)Math.Ceiling(a.DistanceTo(b)/2.0));
        for(int step=0;step<=count;step++)foreach(double offset in new[]{-width,0,width})
        {
            var p=a.Lerp(b,(float)((double)step/count))+new Vector3(across.X,0,across.Y)*(float)offset-Vector3.Up*.02f;
            if(original.sample(p)>=0&&candidate.sample(p)<-.001)return false;
        }
        return true;
    }
    public bool retained_floors_safe(D region,GodotObject original,GodotObject candidate,Vector3 start,Vector3 join,Vector3 point)
    {
        if(original is not CaveField a||candidate is not CaveField b)throw new ArgumentException("Shallow chamber checks require the shared cave field");
        var low=start.Min(join).Min(point)-new Vector3(20,6,20);var high=start.Max(join).Max(point)+new Vector3(20,20,20);var changed=new Aabb(low,high-low);
        var edges=new List<Variant>(Items(region,"edges").Concat(Items(region,"pocket_passages")));foreach(var item in Items(region,"pools"))edges.AddRange(Items(item.AsGodotDictionary(),"bank_access"));
        foreach(var item in edges)
        {
            var edge=item.AsGodotDictionary();var path=edge["points"].AsVector3Array();double width=N(edge,"half_width");
            for(int segment=0;segment<path.Length-1;segment++)
            {
                var first=path[segment].Min(path[segment+1])-V(width+1,.1,width+1);var last=path[segment].Max(path[segment+1])+V(width+1,.1,width+1);
                if(changed.Intersects(new Aabb(first,last-first))&&!FloorSafe(a,b,path[segment],path[segment+1],Math.Max(0,width-.5)))return false;
            }
        }
        foreach(var item in Items(region,"pools"))
        {
            var pool=item.AsGodotDictionary();var center=pool["center"].AsVector3();
            for(int station=0;station<64;station++)
            {
                double angle=Math.Tau*station/64;var p=V(center.X,N(pool,"water_y")-.05,center.Z)+V(Math.Cos(angle),0,Math.Sin(angle))*(float)(N(pool,"radius")+.5);
                if(changed.HasPoint(p)&&a.sample(p)>=0&&b.sample(p)<-.001)return false;
            }
        }
        return true;
    }
    public D prepare(D region,Callable height)=>prepare(region,height,true,400,10);
    public D prepare(D region,Callable height,bool enabled)=>prepare(region,height,enabled,400,10);
    public D prepare(D region,Callable height,bool enabled,double maximum_depth)=>prepare(region,height,enabled,maximum_depth,10);
    public D prepare(D region,Callable height,bool enabled,double maximum_depth,double minimum_roof)
    {
        long family=region.ContainsKey("cave_family")?region["cave_family"].AsInt64():-1;
        if(!enabled||!Flag(region,"valid")||family is 6 or 7||Items(region,"pockets").Count>=24)return region;
        var access=region["edges"].AsGodotArray()[0].AsGodotDictionary();var points=access["points"].AsVector3Array();int attempts=0;
        using var original=new CaveField {maximum_depth=maximum_depth,minimum_roof=minimum_roof};if(!original.compile(new A {region},height))return region;
        for(int index=1;index<points.Length-1;index++)
        {
            var start=points[index];double depth=height.Call(start.X,start.Z).AsDouble()-start.Y;if(depth<28||depth>36)continue;
            var delta=points[index+1]-points[index-1];var heading=new Vector2(delta.X,delta.Z).Normalized();double grade=delta.Y/Math.Max(new Vector2(delta.X,delta.Z).Length(),.001);if(Math.Abs(grade)>.18)continue;
            foreach(double side in new[]{-1.0,1.0})
            {
                if(++attempts>12)return region;var lateral=new Vector2(-heading.Y,heading.X)*(float)side;var diagonal=heading*(float)(23*Math.Cos(Math.PI/7.2))+lateral*(float)(23*Math.Sin(Math.PI/7.2));
                var join=start+V(diagonal.X,grade*23*Math.Cos(Math.PI/7.2),diagonal.Y);var point=join+new Vector3(lateral.X,0,lateral.Y)*30;double finalDepth=height.Call(point.X,point.Z).AsDouble()-point.Y;
                if(finalDepth<24||finalDepth>=40||!Profiles.compatible(point,14,10,region,Items(region,"pockets")))continue;
                bool safe=true;for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++){double cover=height.Call(point.X+x*7,point.Z+z*7).AsDouble()-point.Y;if(!double.IsFinite(cover)||cover<minimum_roof+14||cover>maximum_depth-4)safe=false;}if(!safe)continue;
                var path=new List<Vector3>();for(int retained=points.Length-1;retained>=index;retained--)path.Add(points[retained]);path.Add(join);path.Add(point);
                string id=access["to"].AsString()+":shallow:0";var proposal=region.Duplicate(true);
                proposal["pockets"].AsGodotArray().Add(new D {["id"]=id,["parent"]=access["to"].AsString(),["point"]=point,["level"]=0,["chamber_radius"]=14.0,["chamber_height"]=10.0,["shallow_chamber"]=true});
                proposal["pocket_passages"].AsGodotArray().Add(new D {["from"]=access["to"].AsString(),["to"]=id,["points"]=path.ToArray(),["half_width"]=4.0,["headroom"]=8.0,["entrance"]=false,["maximum_grade"]=Math.Abs(grade),["shallow_chamber"]=true});
                using var candidate=new CaveField {maximum_depth=maximum_depth,minimum_roof=minimum_roof};if(!candidate.compile(new A {proposal},height))continue;
                for(int segment=0;segment<points.Length-1;segment++)if(!FloorSafe(original,candidate,points[segment],points[segment+1],3.5)){safe=false;break;}
                if(safe)return retained_floors_safe(region,original,candidate,start,join,point)?proposal:region;
            }
        }
        return region;
    }
}
