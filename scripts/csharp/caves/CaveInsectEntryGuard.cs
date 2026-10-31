using Godot;
using System;
using System.Linq;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Conservative insect mound and finite-cavity reservations, sharing hive clearance admission.</summary>
public partial class CaveInsectEntryGuard : RefCounted
{
    public GodotObject builder { get; set; } = null!;
    public D _roots { get; set; } = new();
    public D _finite { get; set; } = new();
    public CaveHiveEntryGuard _hive { get; set; } = null!;
    public void configure(GodotObject owner) { builder=owner; _roots.Clear(); _finite.Clear(); _hive=new(); _hive.configure(owner); }
    private GodotObject? Sampler => builder.Get("_extras").AsGodotArray()[6].AsGodotObject();
    private static D Roots(bool valid, A roots) => new() { ["valid"]=valid,["roots"]=roots };
    public D roots_near(Vector2 point,double radius)
    {
        var sampler=Sampler; if(sampler==null) return Roots(true,new());
        var settings=sampler.Get("settings").AsGodotObject(); double density=settings.Get("structure_density").AsDouble(); if(density<=0) return Roots(true,new());
        double span=2100*settings.Get("feature_scale").AsDouble(), pad=1+Math.Max(Math.Abs(point.X),Math.Abs(point.Y))*.000002;
        double nest=settings.Get("nest_height").AsDouble(), reach=nest*1.45*1.344+radius+8+pad;
        if(!double.IsFinite(reach)||!double.IsFinite(span)||span<=0) return Roots(false,new());
        int ring=(int)Math.Ceiling(reach/span); if(ring>8) return Roots(false,new());
        var cell=new Vector2I((int)Math.Floor(point.X/span),(int)Math.Floor(point.Y/span)); var key=new Vector3I(cell.X,cell.Y,ring);
        if(_roots.ContainsKey(key)) return _roots[key].AsGodotDictionary();
        var result=new A();
        for(int z=cell.Y-ring;z<=cell.Y+ring;z++) for(int x=cell.X-ring;x<=cell.X+ring;x++)
        {
            var descriptor=sampler.Call("descriptor",new Vector2I(x,z),span).AsGodotDictionary(); var p=descriptor["position"].AsVector2();
            if(descriptor["chance"].AsDouble()>density||builder.Call("_island_mask",p.X,p.Y).AsDouble()<.03) continue;
            builder.Call("_biome_weights",p.X,p.Y); if(builder.Get("_extra_weights").AsFloat64Array()[6]<.55) continue;
            int kind=Math.Clamp((int)Math.Round(sampler.Call("region",p).AsDouble(),MidpointRounding.AwayFromZero),0,5); if(kind==1) continue;
            double ground=builder.Call("_get_height",p.X,p.Y).AsDouble(); if(ground<builder.Call("get_water_surface_height",p.X,p.Y).AsDouble()+2) continue;
            double scale=nest*(.45+descriptor["age"].AsDouble())*(1-.35*(kind==4?1:0)); bool dome=kind==3&&settings.Get("nest_broad_domes").AsBool();
            result.Add(new D { ["id"]=descriptor["id"],["point"]=p,["radius"]=scale*(dome?1.344:.8),["scale"]=scale,["archetype"]=kind,["phase"]=descriptor["angle"],["ground"]=ground,["broad_dome"]=dome });
        }
        if(_roots.Count>=32) _roots.Remove(_roots.Keys.First()); var data=Roots(true,result); _roots[key]=data; return data;
    }
    public bool clear_mounds(Vector3 point,double radius)
    {
        if(!point.IsFinite()||!double.IsFinite(radius)||radius<0) return false;
        var p=new Vector2(point.X,point.Z); var data=roots_near(p,radius); if(!data["valid"].AsBool()) return false;
        double pad=1+Math.Max(Math.Abs(p.X),Math.Abs(p.Y))*.000002;
        foreach(var item in data["roots"].AsGodotArray()) {var root=item.AsGodotDictionary(); if(p.DistanceTo(root["point"].AsVector2())<root["radius"].AsDouble()+radius+8+pad) return false;}
        return true;
    }
    public bool clear_finite(Vector3 point,double radius)
    {
        var cell=new Vector2I((int)Math.Floor((double)point.X/64),(int)Math.Floor((double)point.Z/64));
        if(!_finite.ContainsKey(cell))
        {
            using var features=new Terrain.TerrainFeatureMeshes { builder=builder };
            var sites=features.portal_sites(new Rect2((Vector2)cell*64,Vector2.One*64).Grow((float)(384+radius)));
            if(_finite.Count>=64) _finite.Remove(_finite.Keys.First()); _finite[cell]=sites;
        }
        foreach(var item in _finite[cell].AsGodotArray()) {var site=item.AsGodotDictionary(); if(new Vector2(point.X,point.Z).DistanceTo(site["position"].AsVector2())<Math.Max(320,site["half"].AsDouble()*1.2)+radius) return false;}
        return true;
    }
    public bool clear_access(D edge)
    {
        if(!_hive.clear_access(edge)) return false; if(Sampler==null) return true;
        var points=edge["points"].AsVector3Array(); if(points.Length<2) return false;
        var first=points[0]; var direction=new Vector2(points[1].X-first.X,points[1].Z-first.Z).Normalized(); double width=edge["half_width"].AsDouble();
        for(int station=0;station<6;station++)
        {
            var p=first-new Vector3(direction.X,0,direction.Y)*station*8; p.Y=(float)builder.Call("_get_height",p.X,p.Z).AsDouble();
            if(p.Y<=builder.Call("get_water_surface_height",p.X,p.Z).AsDouble()+2||!clear_mounds(p,width)||!clear_finite(p,width)) return false;
        }
        foreach(var point in points) {if(builder.Call("_get_height",point.X,point.Z).AsDouble()-point.Y>64) continue; if(!clear_mounds(point,width)||!clear_finite(point,width)) return false;}
        return true;
    }
}
