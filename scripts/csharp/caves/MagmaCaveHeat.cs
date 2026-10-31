using Godot;
using System;
using System.Linq;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Worker-local heat suitability witnessed by retained lava or explicitly enabled volcanic intrusions.</summary>
public partial class MagmaCaveHeat : RefCounted
{
    private readonly RetainedLiquidGeometry Liquid=new();
    public bool enabled {get;set;}=true;
    private bool _intrusions;
    public bool geological_intrusions {get=>_intrusions;set{_intrusions=value;_points.Clear();_sources.Clear();}}
    private WeakRef? _owner;
    public D _sources {get;set;}=new();
    public D _points {get;set;}=new();
    public void configure(GodotObject builder){_owner=GodotObject.WeakRef(builder);_sources.Clear();_points.Clear();}
    private static double N(D d,string key)=>d[key].AsDouble();
    private static A Items(D d,string key)=>d.ContainsKey(key)?d[key].AsGodotArray():new A();
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private void StoreSource(string id,D source){if(_sources.Count>=32)_sources.Remove(_sources.Keys.First());_sources[id]=source;}
    public D source_descriptor(GodotObject builder,GodotObject sampler,D descriptor)
    {
        string id=descriptor["id"].AsString();if(_sources.ContainsKey(id))return _sources[id].AsGodotDictionary();var result=new D();var center=descriptor["position"].AsVector2();var settings=sampler.Get("settings").AsGodotObject();
        if(N(descriptor,"chance")<settings.Get("active_frequency").AsDouble())
        {
            double regional=sampler.Call("region",center).AsDouble();
            if(regional<=2.65)
            {
                builder.Call("_biome_weights",center.X,center.Y);
                if(builder.Get("_extra_weights").AsFloat32Array()[2]>=.95&&builder.Call("_island_mask",center.X,center.Y).AsDouble()>=.1)
                {
                    double radius=N(descriptor,"radius")*(regional>1.6?.85:.38);var measurement=Liquid.measure(builder,center,radius);
                    if(measurement["retained"].AsBool())result=new D {["id"]=id,["center"]=center,["radius"]=radius,["surface_y"]=measurement["surface_y"],["bed_y"]=measurement["bed_y"],["rim_y"]=measurement["rim_y"],["age"]=descriptor["age"],["kind"]="retained_surface_crater_vertical_intrusion",["source_evidence"]="Same canonical terrain owner,island,active,regional,32rim,level and clipped-grid conditions as surface renderer;not eligibility hash alone."};
                }
            }
        }
        StoreSource(id,result);return result;
    }
    public bool in_rendered_footprint(GodotObject builder,Vector2 point,D source)
    {
        double step=N(source,"radius")/12;var center=source["center"].AsVector2();var local=(point-center)/(float)step;int x=(int)Math.Floor(local.X),z=(int)Math.Floor(local.Y);
        if(x< -12||x>=12||z< -12||z>=12||new Vector2(x+.5f,z+.5f).Length()>11.4)return false;
        if(builder.Call("_get_height",point.X,point.Y).AsDouble()>=N(source,"surface_y")-.25)return false;
        var offsets=new[]{new Vector2(x,z),new Vector2(x+1,z),new Vector2(x+1,z+1),new Vector2(x,z+1)};var corners=new Vector3[4];
        for(int i=0;i<4;i++){var p=center+offsets[i]*(float)step;corners[i]=new Vector3(p.X,(float)builder.Call("_get_height",p.X,p.Y).AsDouble(),p.Y);}
        foreach(var indices in new[]{new Vector3I(0,1,2),new Vector3I(0,2,3)})
        {
            var polygon=Liquid.clipped_polygon(builder,corners[indices.X],corners[indices.Y],corners[indices.Z],N(source,"surface_y"));
            if(polygon.Length>=3&&Geometry2D.IsPointInPolygon(point,polygon.Select(p=>new Vector2(p.X,p.Z)).ToArray()))return true;
        }
        return false;
    }
    public D intrusion_descriptor(GodotObject builder,GodotObject sampler,D descriptor)
    {
        string id=descriptor["id"].AsString(),key="intrusion/"+id;if(_sources.ContainsKey(key))return _sources[key].AsGodotDictionary();var result=new D();var center=descriptor["position"].AsVector2();
        if(geological_intrusions&&N(descriptor,"chance")<sampler.Get("settings").AsGodotObject().Get("active_frequency").AsDouble()&&sampler.Call("region",center).AsDouble()<=2.65)
        {
            builder.Call("_biome_weights",center.X,center.Y);
            if(builder.Get("_extra_weights").AsFloat32Array()[2]>=.95&&builder.Call("_island_mask",center.X,center.Y).AsDouble()>=.1)
            {
                double surface=builder.Call("_get_height",center.X,center.Y).AsDouble(),ceiling=surface-64;
                if(double.IsFinite(surface)&&surface>builder.Get("water_level").AsDouble()+2)result=new D {["id"]=id+"/intrusion",["center"]=center,["radius"]=N(descriptor,"radius")*.38,["surface_y"]=ceiling,["bed_y"]=ceiling-320,["age"]=descriptor["age"],["kind"]="explicit_modeled_active_volcanic_intrusion",["source_evidence"]="Explicit idealized intrusive body64–864m below a canonical normally active volcanic centre;normal source hash,region,owner and island required. Not a retained surface pool,measured temperature or depth-only geothermal gradient."};
            }
        }
        StoreSource(key,result);return result;
    }
    public D witness(Vector2 point)
    {
        if(!enabled||!point.IsFinite()||_owner==null)return new();var builder=_owner.GetRef().AsGodotObject();if(builder==null)return new();var extras=builder.Get("_extras").AsGodotArray();
        if(extras.Count<=2||extras[2].AsGodotObject()==null)return new();var sampler=extras[2].AsGodotObject();var settings=sampler.Get("settings").AsGodotObject();if(!settings.Get("special_liquids_enabled").AsBool())return new();
        if(_points.ContainsKey(point))return _points[point].AsGodotDictionary();double span=7200*settings.Get("feature_scale").AsDouble();var cell=new Vector2I((int)Math.Floor(point.X/span),(int)Math.Floor(point.Y/span));var result=new D();var candidates=new System.Collections.Generic.List<D>();
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var descriptor=sampler.Call("descriptor",cell+new Vector2I(x,z),span).AsGodotDictionary();
            if(N(descriptor,"chance")>=settings.Get("active_frequency").AsDouble()||point.DistanceSquaredTo(descriptor["position"].AsVector2())>Math.Pow(N(descriptor,"radius")*.85*1.02,2))continue;candidates.Add(descriptor);
        }
        foreach(var descriptor in candidates.OrderBy(d=>d["id"].AsString(),StringComparer.Ordinal))
        {
            var source=source_descriptor(builder,sampler,descriptor);
            if(source.Count>0&&in_rendered_footprint(builder,point,source)){result=source.Duplicate();result["surface_witness"]=new Vector3(point.X,(float)N(source,"surface_y"),point.Y);break;}
            var intrusive=intrusion_descriptor(builder,sampler,descriptor);if(intrusive.Count==0||point.DistanceTo(intrusive["center"].AsVector2())>=N(intrusive,"radius"))continue;
            result=intrusive.Duplicate();result["surface_witness"]=new Vector3(point.X,(float)N(intrusive,"surface_y"),point.Y);break;
        }
        if(_points.Count>=512)_points.Remove(_points.Keys.First());_points[point]=result;return result;
    }
    public D sample(Vector3 point)
    {
        if(!point.IsFinite())return new D {["heat"]=0.0};var source=witness(new Vector2(point.X,point.Z));if(source.Count==0)return new D {["heat"]=0.0};double below=N(source,"surface_y")-point.Y;
        if(below<0||below>=800)return new D {["heat"]=0.0};var result=source.Duplicate();result["heat"]=1-Smooth(128,800,below);
        if(source["kind"].AsString()=="explicit_modeled_active_volcanic_intrusion")result["heat"]=N(result,"heat")*(1-Smooth(N(source,"radius")*.55,N(source,"radius"),new Vector2(point.X,point.Z).DistanceTo(source["center"].AsVector2())));
        result["distance_below_source_m"]=below;return result;
    }
    public Vector2I cache_counts()=>new(_sources.Count,_points.Count);
    public D annotate_region(D region)
    {
        long family=region.ContainsKey("cave_family")?region["cave_family"].AsInt64():-1;
        if(!enabled||!region.ContainsKey("valid")||!region["valid"].AsBool()||family is 6 or 7||_owner==null)return region;
        var builder=_owner.GetRef().AsGodotObject();if(builder==null)return region;var extras=builder.Get("_extras").AsGodotArray();if(extras.Count<=2||extras[2].AsGodotObject()==null||!extras[2].AsGodotObject().Get("settings").AsGodotObject().Get("special_liquids_enabled").AsBool())return region;
        var rooms=Items(region,"nodes").Duplicate();rooms.AddRange(Items(region,"pockets"));foreach(var item in Items(region,"pools"))rooms.AddRange(Items(item.AsGodotDictionary(),"bank_lobes"));var sources=new A();var seen=new System.Collections.Generic.HashSet<string>(StringComparer.Ordinal);
        foreach(var room in rooms.Select(v=>v.AsGodotDictionary()).OrderBy(d=>d["id"].AsString(),StringComparer.Ordinal))
        {
            if(sources.Count>=64)break;string id=room["id"].AsString();if(!room.ContainsKey("level")||room["level"].AsInt64()<0||!seen.Add(id))continue;var point=room["point"].AsVector3();var source=sample(point+Vector3.Up*(float)Math.Min(8,N(room,"chamber_height")*.3));if(N(source,"heat")<=.01)continue;
            sources.Add(new D {["id"]=id+"/intrusive_heat",["point"]=point,["radius"]=Math.Min(96,N(room,"chamber_radius")+12),["height"]=Math.Min(96,N(room,"chamber_height")+8),["heat"]=source["heat"],["surface_source"]=source["id"],["surface_witness"]=source["surface_witness"],["kind"]=source["kind"]});
        }
        var edges=Items(region,"edges").Duplicate();edges.AddRange(Items(region,"pocket_passages"));
        foreach(var edge in edges.Select(v=>v.AsGodotDictionary()).OrderBy(d=>d["from"].AsString()+"/"+d["to"].AsString(),StringComparer.Ordinal))
        {
            if(sources.Count>=64)break;var points=edge["points"].AsVector3Array();double distance=0,nextStation=0;int station=0;
            for(int index=1;index<points.Length;index++)
            {
                var a=points[index-1];var b=points[index];double length=a.DistanceTo(b);
                while(nextStation<=distance+length&&sources.Count<64)
                {
                    var point=a.Lerp(b,(float)Math.Clamp((nextStation-distance)/Math.Max(length,.000001),0,1));var source=sample(point+Vector3.Up*(float)Math.Min(4,N(edge,"headroom")*.5));
                    if(N(source,"heat")>.01)sources.Add(new D {["id"]=edge["from"].AsString()+"/"+edge["to"].AsString()+"/intrusive_heat/"+station,["point"]=point,["radius"]=Math.Min(32,N(edge,"half_width")+16),["height"]=Math.Min(96,N(edge,"headroom")+8),["heat"]=source["heat"],["surface_source"]=source["id"],["surface_witness"]=source["surface_witness"],["kind"]=source["kind"]});
                    nextStation+=32;station++;
                }
                distance+=length;
            }
        }
        if(sources.Count==0)return region;var result=region.Duplicate();result["cave_thermal_sources"]=sources;return result;
    }
}
