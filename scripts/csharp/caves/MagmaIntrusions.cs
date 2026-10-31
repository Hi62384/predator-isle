using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Measured cooled dikes, sills, solidified wall flows and basaltic lava stalactites.</summary>
public partial class MagmaIntrusions : RefCounted
{
    public D templates {get;}=new();private readonly Dictionary<int,Vector3[]> _templates=new();
    private readonly CaveFormations Shapes=new();private readonly CaveMeasuredFormation Fit=new();private readonly CaveBiomeRegions Regions=new();
    private static double N(D d,string name)=>d[name].AsDouble();
    private static double Setting(D d,string name,double fallback)=>d.ContainsKey(name)?N(d,name):fallback;
    private static double Sample(GodotObject field,Vector3 point)=>field is CaveField native?native.sample(point):field.Call("sample",point).AsDouble();
    private static Vector3 Normal(GodotObject field,Vector3 point)=>field is CaveField native?native.normal(point):field.Call("normal",point).AsVector3();
    private static Vector3I Cell(GodotObject field,Vector3 point)=>field is CaveField native?native.cell(point):field.Call("cell",point).AsVector3I();
    private static double Weight(GodotObject field,Vector3 point)=>field is CaveField native?native.biome_weights_at(point,new A {"magma"}).X:field.Call("biome_weights_at",point,new A {"magma"}).AsVector4().X;
    public Vector3[] prototype(int kind)
    {
        if(_templates.TryGetValue(kind,out var cached))return cached;Vector3[] result;
        if(kind==3)
        {
            using var geometry=new MagmaCaveGeometry();result=geometry.prototype(0,0).Select(point=>{double taper=1-point.Y*.93;return new Vector3((float)(point.X*taper),point.Y,(float)(point.Z*taper));}).ToArray();
        }
        else
        {
            var vertices=new List<Vector3>();double width=kind==0?.12:1,depth=kind==1?.12:1;
            for(int strip=0;strip<4;strip++)
            {
                double a=-depth+strip*depth*.5,c=a+depth*.5,faceA=kind==2?.65+.2*Math.Cos(a*5):1,faceC=kind==2?.65+.2*Math.Cos(c*5):1;
                var p=new Vector3((float)-width,0,(float)a);var q=new Vector3((float)width,0,(float)a);var r=new Vector3((float)width,0,(float)c);var s=new Vector3((float)-width,0,(float)c);
                var u=new Vector3((float)-width,(float)faceA,(float)a);var v=new Vector3((float)width,(float)faceA,(float)a);var w=new Vector3((float)width,(float)faceC,(float)c);var t=new Vector3((float)-width,(float)faceC,(float)c);
                Quad(p,q,v,u);Quad(s,t,w,r);Quad(p,u,t,s);Quad(q,r,w,v);Quad(u,v,w,t);Quad(p,s,r,q);
            }
            result=vertices.ToArray();
            void Triangle(Vector3 a,Vector3 b,Vector3 c){if((c-a).Cross(b-a).LengthSquared()<.00000001)return;vertices.Add(a);vertices.Add(b);vertices.Add(c);}
            void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d){Triangle(a,b,c);Triangle(a,c,d);}
        }
        _templates[kind]=result;templates[kind]=result;return result;
    }
    public D build(GodotObject field,Vector3I key,long seed_id,D rooms,double density,int limit)=>build(field,key,seed_id,rooms,density,limit,new D());
    public D build(GodotObject field,Vector3I key,long seed_id,D rooms,double density,int limit,D settings)
    {
        var placements=new A();var vertices=new List<Vector3>();var normals=new List<Vector3>();var colors=new List<Color>();var uv=new List<Vector2>();var collision=new List<Vector3>();var ids=rooms.Keys.Select(k=>k.AsString()).OrderBy(s=>s,StringComparer.Ordinal).ToArray();var origin=(Vector3)key*64;var cellBounds=new Aabb(origin,Vector3.One*64);
        foreach(string id in ids)
        {
            var room=rooms[id].AsGodotDictionary();double radius=N(room,"chamber_radius");var roomPoint=room["point"].AsVector3();
            if(!new Aabb(roomPoint-new Vector3((float)(radius+5),0,(float)(radius+5)),new Vector3((float)((radius+5)*2),(float)N(room,"chamber_height"),(float)((radius+5)*2))).Intersects(cellBounds))continue;
            for(int trial=0;trial<9;trial++)
            {
                if(placements.Count>=Math.Min(8,limit))break;string identity=id+"/intrusion/"+trial;if(Regions.random(identity,seed_id,"admit")>density*Setting(settings,"intrusion_frequency",.55))continue;
                int kind=trial%3;double angle=Regions.random(id,seed_id,"intrusion_phase")*Math.Tau+trial*Math.Tau/9;var radial=new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle));var start=roomPoint+Vector3.Up*(float)(6+Regions.random(identity,seed_id,"elevation")*Math.Min(12,N(room,"chamber_height")*.4));var previous=start;var wall=Vector3.Inf;
                if(Sample(field,start)>=0)continue;
                for(int step=1;step<=(int)Math.Ceiling((radius+32)/2);step++){var point=start+radial*step*2;if(Sample(field,point)>=0){wall=Shapes.boundary(field,previous,point);break;}previous=point;}
                if(!wall.IsFinite()||Cell(field,wall)!=key)continue;var axis=Normal(field,wall);if(Math.Abs(axis.Y)>.45)continue;double weight=Weight(field,wall+axis);if(weight<.7)continue;
                double width=2.5+Regions.random(identity,seed_id,"width")*3.5,thickness=1+Regions.random(identity,seed_id,"thickness")*1.5;
                if(kind==2){width=1.5+Regions.random(identity,seed_id,"width")*1.5;thickness=2+Regions.random(identity,seed_id,"thickness");}
                var fitted=Fit.fit(field,prototype(kind),wall,axis,width,thickness,0);if(!fitted["valid"].AsBool())continue;int first=vertices.Count;var tint=kind<2?new Color(.065f,.07f,.075f):new Color(.085f,.067f,.052f);Append(fitted,tint,new Vector2(3+kind,.4f));
                placements.Add(new D {["id"]=identity,["kind"]=new[]{"cooled_volcanic_dike","cooled_volcanic_sill","solidified_lava_cascade"}[kind],["owner"]=key,["root"]=wall,["axis"]=axis,["height"]=thickness,["width"]=width,["bounds"]=fitted["bounds"],["attachments"]=fitted["attachments"],["collider"]=true,["first_vertex"]=first,["vertex_count"]=fitted["vertices"].AsVector3Array().Length,["family"]=3+kind,["raw_weight"]=weight});
            }
        }
        foreach(string id in ids)
        {
            if(placements.Count>=Math.Min(8,limit))break;var room=rooms[id].AsGodotDictionary();double radius=N(room,"chamber_radius");var roomPoint=room["point"].AsVector3();
            if(!new Aabb(roomPoint-new Vector3((float)(radius+5),0,(float)(radius+5)),new Vector3((float)((radius+5)*2),(float)(N(room,"chamber_height")+5),(float)((radius+5)*2))).Intersects(cellBounds))continue;
            for(int trial=0;trial<2;trial++)
            {
                if(placements.Count>=Math.Min(8,limit))break;string identity=id+"/lava_drip/"+trial;if(Regions.random(identity,seed_id,"admit")>=density*Setting(settings,"lava_drip_frequency",.1))continue;
                double angle=Regions.random(identity,seed_id,"phase")*Math.Tau;var start=roomPoint+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*(float)radius*(float)(.25+.3*Regions.random(identity,seed_id,"inset"))+Vector3.Up*2;var attachment=Shapes.ceiling_at(field,start);
                if(!attachment.IsFinite()||Cell(field,attachment)!=key)continue;double weight=Weight(field,attachment+Vector3.Down);if(weight<.7)continue;
                double width=.18+Regions.random(identity,seed_id,"width")*.27,length=.8+Regions.random(identity,seed_id,"length")*1.6;var fitted=Fit.fit(field,prototype(3),attachment,Vector3.Down,width,length,angle);if(!fitted["valid"].AsBool())continue;int first=vertices.Count;Append(fitted,new Color(.07f,.067f,.06f),new Vector2(6,.6f));
                placements.Add(new D {["id"]=identity,["kind"]="basaltic_lava_stalactite",["owner"]=key,["root"]=attachment,["axis"]=Vector3.Down,["height"]=length,["width"]=width,["bounds"]=fitted["bounds"],["attachments"]=fitted["attachments"],["collider"]=true,["first_vertex"]=first,["vertex_count"]=fitted["vertices"].AsVector3Array().Length,["family"]=6,["raw_weight"]=weight});
            }
        }
        return new D {["vertices"]=vertices.ToArray(),["normals"]=normals.ToArray(),["colors"]=colors.ToArray(),["uv"]=uv.ToArray(),["collision"]=collision.ToArray(),["placements"]=placements,["prototype_count"]=_templates.Count};
        void Append(D fitted,Color tint,Vector2 texture)
        {
            var points=fitted["vertices"].AsVector3Array();var ns=fitted["normals"].AsVector3Array();
            for(int i=0;i<points.Length;i++){var point=points[i]-origin;vertices.Add(point);normals.Add(ns[i]);colors.Add(tint);uv.Add(texture);collision.Add(point);}
        }
    }
}
