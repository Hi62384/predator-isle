using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;
using static PredatorIsle.Caves.CaveField;

namespace PredatorIsle.Caves;

// Optional fissures connect two already reachable levels. The vertical void
// is off the protected route centreline, not a replacement for either route.
internal static class CaveVerticalFeatures
{
    private readonly record struct Station(Vector3 Point,D Edge);
    internal static A Build(D region,Func<double,double,double> height,double minimumRoof,double maximumDepth,long seed,Func<D,A,bool> supportedJoin)
    {
        var result=new A();
        var cell=region["id"].AsVector2I();
        var stations=new List<Station>();
        var bins=new Dictionary<Vector2I,List<int>>();
        var edges=Arr(region,"edges").Duplicate();
        edges.AddRange(Arr(region,"pocket_passages"));
        edges.AddRange(Arr(region,"fracture_passages"));
        static Vector2 Xz(Vector3 p)=>new(p.X,p.Z);
        static Vector2I Bin(Vector3 p)=>(Vector2I)(Xz(p)/32).Floor();
        foreach(var raw in edges)
        {
            var edge=raw.AsGodotDictionary();
            if(Flag(edge,"entrance"))continue;
            var points=edge["points"].AsVector3Array();
            for(int i=2;i<points.Length-2;i+=2)
            {
                var p=points[i];
                if(height(p.X,p.Z)-p.Y<minimumRoof+25)continue;
                var key=Bin(p);
                if(!bins.TryGetValue(key,out var bucket))bins[key]=bucket=new();
                bucket.Add(stations.Count);stations.Add(new Station(p,edge));
            }
        }
        var rooms=Arr(region,"nodes").Duplicate();rooms.AddRange(Arr(region,"pockets"));
        int budget=1+(int)(CaveNetwork.SeededRandom(cell,seed,88000)*4);
        // The index is sparse and bounds the number of pair examinations.
        for(int i=0;i<stations.Count&&result.Count<budget;i++)
        {
            if(CaveNetwork.SeededRandom(cell,seed,88100+i)>.36)continue;
            var lower=stations[i];var l=lower.Point;var bin=Bin(l);
            bool accepted=false;
            for(int z=-2;z<=2&&!accepted;z++)for(int x=-2;x<=2&&!accepted;x++)
            {
                if(!bins.TryGetValue(bin+new Vector2I(x,z),out var bucket))continue;
                foreach(int j in bucket)
                {
                    var upper=stations[j];var u=upper.Point;
                    double drop=u.Y-l.Y;
                    if(drop<18||drop>78||lower.Edge==upper.Edge)continue;
                    float horizontal=Xz(u).DistanceTo(Xz(l));
                    float radius=3.5f+2*(float)CaveNetwork.SeededRandom(cell,seed,89100+i*13L+j);
                    if(horizontal<2*(radius+Math.Max(Num(upper.Edge,"half_width"),Num(lower.Edge,"half_width"))+3)||horizontal>56)continue;
                    var mid=(Xz(l)+Xz(u))*.5f;
                    var bottom=new Vector3(mid.X,l.Y,mid.Y);
                    var top=new Vector3(mid.X,u.Y,mid.Y);
                    if(result.Any(raw=>Xz(raw.AsGodotDictionary()["bottom"].AsVector3()).DistanceSquaredTo(mid)<80*80))continue;
                    if(!Clear(bottom,top,radius,upper,lower))continue;
                    result.Add(new D{["bottom"]=bottom,["top"]=top,["lower_access"]=l,["upper_access"]=u,
                        ["radius"]=radius,["headroom"]=Math.Min(8,Num(upper.Edge,"headroom",8)),
                        ["from"]=lower.Edge["from"],["to"]=upper.Edge["to"]});
                    accepted=true;break;
                }
            }
        }
        return result;

        bool Clear(Vector3 bottom,Vector3 top,float radius,Station upper,Station lower)
        {
            var center=Xz(bottom);var origin=(Vector2)cell*1536;
            if(center.X<origin.X+radius+8||center.Y<origin.Y+radius+8||
                center.X>origin.X+1536-radius-8||center.Y>origin.Y+1536-radius-8||bottom.Y< -1000)return false;
            // The fissure must not undercut a main-route floor. Search actual
            // polyline segments, not just nodes; the upper approach is lateral.
            foreach(var raw in edges)
            {
                var edge=raw.AsGodotDictionary();var points=edge["points"].AsVector3Array();
                double clear=radius+Num(edge,"half_width")+4;
                for(int k=1;k<points.Length;k++)
                {
                    var a=points[k-1];var b=points[k];
                    if(Math.Max(a.Y,b.Y)<bottom.Y+1||Math.Min(a.Y,b.Y)>top.Y+12)continue;
                    var q=Xz(a);var delta=Xz(b)-q;
                    float t=Math.Clamp((center-q).Dot(delta)/Math.Max(delta.LengthSquared(),.00001f),0,1);
                    var nearest=a.Lerp(b,t);
                    if(nearest.Y>bottom.Y+1&&nearest.Y<top.Y+12&&center.DistanceTo(Xz(nearest))<clear)return false;
                }
            }
            foreach(var raw in rooms)
            {
                var room=raw.AsGodotDictionary();var p=room["point"].AsVector3();
                if(p.Y<=bottom.Y+1||p.Y>=top.Y+12)continue;
                if(center.DistanceTo(Xz(p))<radius+Num(room,"chamber_radius")+3)return false;
            }
            foreach(var raw in Arr(region,"pools"))
            {
                var pool=raw.AsGodotDictionary();var p=pool["center"].AsVector3();
                if(p.Y>=bottom.Y-10&&p.Y<=top.Y+12&&center.DistanceTo(Xz(p))<Num(pool,"radius")+radius+5)return false;
            }
            bool Covered(Vector3 a,Vector3 b,double width,double head)
            {
                int n=Math.Max(1,(int)Math.Ceiling(a.DistanceTo(b)/4));
                for(int k=0;k<=n;k++)
                {
                    var p=a.Lerp(b,(float)k/n);
                    foreach(var off in new[]{Vector2.Zero,Vector2.Right*(float)width,Vector2.Left*(float)width,
                        Vector2.Up*(float)width,Vector2.Down*(float)width})
                    {
                        double h=height(p.X+off.X,p.Z+off.Y);
                        if(!double.IsFinite(h)||h-p.Y<minimumRoof+head+4||h-p.Y>maximumDepth-4)return false;
                    }
                }
                return true;
            }
            // Side galleries must also meet the same support test as the
            // regular graph. A shaft never undercuts an unrelated main route.
            bool Side(Vector3 a,Vector3 b,string id)=>supportedJoin(new D{
                ["from"]=id,["to"]=id,["points"]=new[]{a,b},["half_width"]=4.0,["headroom"]=8.0},edges);
            return Covered(bottom,top,radius,10)&&Covered(lower.Point,bottom,4,8)&&Covered(upper.Point,top,4,8)
                &&Side(lower.Point,bottom,lower.Edge["from"].AsString())&&Side(upper.Point,top,upper.Edge["to"].AsString());
        }
    }
}
