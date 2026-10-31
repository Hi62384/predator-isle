using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Finite terrain-owned cavity shells, retained liquids and outlet-connected waterfalls.</summary>
public partial class TerrainFeatureMeshes : RefCounted
{
    public BiomeStructureGeometry g {get;set;}=new();
    public Vector3 origin {get;set;}
    public GodotObject builder {get;set;}=null!;
    public A surfaces {get;set;}=new();
    public Vector3 interior_reference {get;set;}
    private readonly RetainedLiquidGeometry _retained=new();
    private static double N(GodotObject resource,string name)=>resource.Get(name).AsDouble();
    private static double N(D data,string name)=>data[name].AsDouble();
    private double Height(Vector2 p)=>builder.Call("_get_height",p.X,p.Y).AsDouble();
    private double Water(Vector2 p)=>builder.Call("get_water_surface_height",p.X,p.Y).AsDouble();
    private static double Lerp(double a,double b,double t)=>a+(b-a)*t;
    private static double Smooth(double a,double b,double x)=>StructureGeometryAccess.Smooth(a,b,x);
    public void reset(){g.vertices=System.Array.Empty<Vector3>();g.normals=System.Array.Empty<Vector3>();g.colors=System.Array.Empty<Color>();g.uvs=System.Array.Empty<Vector2>();g.origin=origin;}
    public A arrays()=>g.VertexCount==0?new A():g.arrays();
    private bool Owns(Vector2 p)=>builder is not TerrainMeshBuilder native||native.RingOwns is null||native.RingOwns(p);
    public A portal_sites(Rect2 bounds)
    {
        var sites=new A();var extras=builder.Get("_extras").AsGodotArray();
        foreach(int family in new[]{1,2,6,7})
        {
            var sampler=extras[family].AsGodotObject();if(sampler==null)continue;var config=sampler.Get("settings").AsGodotObject();if(!config.Get("caves_enabled").AsBool())continue;double span=8192*N(config,"feature_scale");var first=new Vector2I((int)Math.Floor((bounds.Position.X-320.0)/span)-1,(int)Math.Floor((bounds.Position.Y-320.0)/span)-1);var last=new Vector2I((int)Math.Ceiling((bounds.End.X+320.0)/span),(int)Math.Ceiling((bounds.End.Y+320.0)/span));
            for(int z=first.Y;z<=last.Y;z++)for(int x=first.X;x<=last.X;x++)
            {
                var d=sampler.Call("descriptor",new Vector2I(x,z),span).AsGodotDictionary();if(N(d,"chance")>N(config,"cave_frequency"))continue;var raw=d["position"].AsVector2()/32;var p=new Vector2((float)Math.Round(raw.X,MidpointRounding.AwayFromZero),(float)Math.Round(raw.Y,MidpointRounding.AwayFromZero))*32;
                if(!bounds.Grow(320).HasPoint(p))continue;builder.Call("_biome_weights",p.X,p.Y);if(builder.Get("_extra_weights").AsFloat64Array()[family]<.92||builder.Call("_island_mask",p.X,p.Y).AsDouble()<.1)continue;double roof=double.PositiveInfinity,high=double.NegativeInfinity;bool dry=true;
                for(int dz=-1;dz<=1;dz++)for(int dx=-1;dx<=1;dx++){var q=p+new Vector2(dx*256,dz*128);double h=Height(q);roof=Math.Min(roof,h);high=Math.Max(high,h);dry=dry&&h>Math.Max(N(builder,"water_level"),Water(q))+14;}
                if(!dry||high-roof>170)continue;double floor=Math.Max(N(builder,"water_level")+8,roof-72);if(roof-floor<24)continue;
                sites.Add(new D{["id"]=d["id"],["family"]=family,["position"]=p,["half"]=96.0,["phase"]=d["angle"],["floor"]=floor,["top"]=high+2,["roof"]=floor+20,["owner"]=p,["kind"]=family==2?"lava_tube":family==6?"burrow":family==7?"hive_chamber":"rock_cavern"});
            }
        }
        return sites;
    }
    public void interior_quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Color color)
    {if((c-a).Cross(b-a).Dot(interior_reference-(a+b+c+d)*.25f)>0)g.quad(a,b,c,d,color);else g.quad(a,d,c,b,color);}
    public void cavern(D site)
    {
        var p=site["position"].AsVector2();double r=N(site,"half"),bottom=N(site,"floor"),ceiling=N(site,"roof"),phase=N(site,"phase");interior_reference=new Vector3(p.X,(float)(bottom+5),p.Y);var color=site["family"].AsInt32()!=7?new Color(.4f,.34f,.28f):new Color(.24f,.18f,.19f);var ring=new Vector2[192];
        for(int i=0;i<192;i++){double angle=i*Math.Tau/192,radius=r*(1+.1*Math.Sin(angle*3+phase)+.06*Math.Sin(angle*7-phase));ring[i]=new Vector2((float)Math.Cos(angle),(float)Math.Sin(angle))*(float)radius;}
        for(int i=0;i<192;i++)
        {
            var a=p+ring[i];var b=p+ring[(i+1)%192];double lipA=a.X>p.X+r*.85&&Math.Abs((double)a.Y-p.Y)<4.25?-.5:1,lipB=b.X>p.X+r*.85&&Math.Abs((double)b.Y-p.Y)<4.25?-.5:1;
            var at=new Vector3(a.X,(float)(Height(a)+lipA),a.Y);var bt=new Vector3(b.X,(float)(Height(b)+lipB),b.Y);double floor=((double)a.X+b.X)*.5>p.X+r*.9&&Math.Abs(((double)a.Y+b.Y)*.5-p.Y)<12?ceiling:bottom;interior_quad(new Vector3(a.X,(float)floor,a.Y),new Vector3(b.X,(float)floor,b.Y),bt,at,color);
        }
        var indices=Geometry2D.TriangulatePolygon(ring);for(int i=0;i<indices.Length;i+=3){var a=p+ring[indices[i]];var b=p+ring[indices[i+1]];var c=p+ring[indices[i+2]];g.triangle(new Vector3(a.X,(float)bottom,a.Y),new Vector3(b.X,(float)bottom,b.Y),new Vector3(c.X,(float)bottom,c.Y),color);}
        double radiusAccess=70,entry=ring[0].X;int turns=Math.Max(1,(int)Math.Ceiling((N(site,"top")-bottom)/(Math.Tau*radiusAccess*.12))),segments=turns*96;double top=Height(new Vector2((float)(p.X+entry),p.Y))+.15;
        for(int i=0;i<segments;i++)
        {
            double t=(double)i/segments,u=(i+1.0)/segments;var a=new Vector2((float)Math.Cos(t*turns*Math.Tau),(float)Math.Sin(t*turns*Math.Tau));var b=new Vector2((float)Math.Cos(u*turns*Math.Tau),(float)Math.Sin(u*turns*Math.Tau));
            g.quad(new Vector3((float)(p.X+a.X*(radiusAccess-4)),(float)Lerp(top,bottom,t),(float)(p.Y+a.Y*(radiusAccess-4))),new Vector3((float)(p.X+a.X*(radiusAccess+4)),(float)Lerp(top,bottom,t),(float)(p.Y+a.Y*(radiusAccess+4))),new Vector3((float)(p.X+b.X*(radiusAccess+4)),(float)Lerp(top,bottom,u),(float)(p.Y+b.Y*(radiusAccess+4))),new Vector3((float)(p.X+b.X*(radiusAccess-4)),(float)Lerp(top,bottom,u),(float)(p.Y+b.Y*(radiusAccess-4))),color);
        }
        for(int i=0;i<24;i++)
        {
            double xa=Lerp(74,entry+12,i/24.0),xb=Lerp(74,entry+12,(i+1)/24.0);var vertices=new List<Vector3>();foreach(var q in new[]{new Vector2((float)xa,-4),new Vector2((float)xb,-4),new Vector2((float)xb,4),new Vector2((float)xa,4)}){double blend=Smooth(entry-5,entry+10,q.X),height=Lerp(top,builder.Call("_get_height",(double)p.X+q.X,(double)p.Y+q.Y).AsDouble()+.04,blend);vertices.Add(new Vector3((float)((double)p.X+q.X),(float)height,(float)((double)p.Y+q.Y)));}g.quad(vertices[0],vertices[1],vertices[2],vertices[3],color);
        }
        double x0=p.X+entry-5,x1=p.X+256.0,z0=p.Y-16.0,z1=p.Y+16.0;Vector3 P(double x,double y,double z)=>new((float)x,(float)y,(float)z);
        g.quad(P(x0,bottom,z0),P(x1,bottom,z0),P(x1,bottom,z1),P(x0,bottom,z1),color);g.quad(P(x0,ceiling,z1),P(x1,ceiling,z1),P(x1,ceiling,z0),P(x0,ceiling,z0),color);foreach(double z in new[]{z0,z1})interior_quad(P(x0,bottom,z),P(x1,bottom,z),P(x1,ceiling,z),P(x0,ceiling,z),color);interior_quad(P(x1,bottom,z0),P(x1,bottom,z1),P(x1,ceiling,z1),P(x1,ceiling,z0),color);
    }
    public void clipped_liquid(Vector3 a,Vector3 b,Vector3 c,double level,Color color)
    {var clipped=_retained.clipped_polygon(builder,a,b,c,level);for(int i=1;i<clipped.Length-1;i++)g.triangle(clipped[0],clipped[i],clipped[i+1],color);}
    public bool pool(Vector2 p,double radius,Color color)
    {
        var measurement=_retained.measure(builder,p,radius);if(!measurement["retained"].AsBool())return false;double level=N(measurement,"surface_y"),step=radius/12;
        for(int z=-12;z<12;z++)for(int x=-12;x<12;x++){if(new Vector2(x+.5f,z+.5f).Length()>11.4)continue;var v=new List<Vector3>();foreach(var offset in new[]{new Vector2(x,z),new Vector2(x+1,z),new Vector2(x+1,z+1),new Vector2(x,z+1)}){var q=p+offset*(float)step;v.Add(new Vector3(q.X,(float)Height(q),q.Y));}clipped_liquid(v[0],v[1],v[2],level,color);clipped_liquid(v[0],v[2],v[3],level,color);}return true;
    }
    public A liquid_sites(Rect2 bounds,int family_id)
    {
        var sites=new A();var sampler=builder.Get("_extras").AsGodotArray()[family_id].AsGodotObject();if(sampler==null)return sites;var config=sampler.Get("settings").AsGodotObject();if(!config.Get("special_liquids_enabled").AsBool())return sites;double span=(family_id==2?7200:4096)*N(config,"feature_scale");var first=new Vector2I((int)Math.Floor(bounds.Position.X/span)-1,(int)Math.Floor(bounds.Position.Y/span)-1);var last=new Vector2I((int)Math.Ceiling(bounds.End.X/span),(int)Math.Ceiling(bounds.End.Y/span));
        for(int z=first.Y;z<=last.Y;z++)for(int x=first.X;x<=last.X;x++)
        {
            var cell=new Vector2I(x,z);var d=sampler.Call("descriptor",cell,span).AsGodotDictionary();var p=family_id==2?d["position"].AsVector2():sampler.Call("hive_node",cell).AsVector2();if(!bounds.HasPoint(p)||!Owns(p))continue;if(family_id==2&&N(d,"chance")>=N(config,"active_frequency"))continue;if(family_id==2&&sampler.Call("region",p).AsDouble()>2.65)continue;if(family_id==7&&(sampler.Call("region",p).AsDouble()<2.65||sampler.Call("region",p).AsDouble()>3.4))continue;
            builder.Call("_biome_weights",p.X,p.Y);if(builder.Get("_extra_weights").AsFloat64Array()[family_id]<.95||builder.Call("_island_mask",p.X,p.Y).AsDouble()<.1)continue;sites.Add(new D{["position"]=p,["radius"]=family_id==2?N(d,"radius")*(sampler.Call("region",p).AsDouble()>1.6?.85:.38):300.0,["id"]=d["id"]});
        }
        return sites;
    }
    public D build(GodotObject host,Vector2I coordinate)
    {
        builder=host;double size=N(builder,"chunk_size");origin=new Vector3((float)(coordinate.X*size),0,(float)(coordinate.Y*size));var bounds=new Rect2(new Vector2(origin.X,origin.Z),Vector2.One*(float)size);var portals=portal_sites(bounds);var openings=new List<Vector4>();var owned=new A();
        foreach(var value in portals){var site=value.AsGodotDictionary();var p=site["position"].AsVector2();double half=N(site,"half");var q=p-new Vector2(origin.X,origin.Z);if(bounds.Intersects(new Rect2(p-Vector2.One*(float)half*1.2f,Vector2.One*(float)half*2.4f)))openings.Add(new Vector4(q.X,q.Y,(float)half,(float)N(site,"phase")));if(bounds.HasPoint(site["owner"].AsVector2())&&Owns(site["owner"].AsVector2()))owned.Add(site);}
        reset();foreach(var value in owned)cavern(value.AsGodotDictionary());var output=new A{arrays()};var liquids=new A();
        foreach(int family in new[]{2,7}){reset();foreach(var value in liquid_sites(bounds,family)){var site=value.AsGodotDictionary();if(pool(site["position"].AsVector2(),N(site,"radius"),family==2?new Color(1,.24f,.025f):new Color(.18f,.42f,.27f)))liquids.Add(new D{["family"]=family,["position"]=site["position"],["id"]=site["id"]});}output.Add(arrays());}
        reset();var falls=waterfalls(bounds);output.Add(arrays());if(!builder.Get("_extras_enabled").AsBool()&&falls.Count==0)return new();return new D{["surfaces"]=output,["openings"]=openings.ToArray(),["cavities"]=owned,["liquids"]=liquids,["waterfalls"]=falls};
    }
    public A waterfalls(Rect2 bounds)
    {
        var records=tropical_waterfalls(bounds);var sampler=builder.Get("_extras").AsGodotArray()[1].AsGodotObject();if(sampler==null||!sampler.Get("settings").AsGodotObject().Get("waterfalls_enabled").AsBool())return records;double spacing=4000/Math.Max(N(builder.Get("settings").AsGodotObject(),"grass_river_frequency"),.01);
        for(int ix=(int)Math.Floor(bounds.Position.X/4096.0)-1;ix<(int)Math.Ceiling(bounds.End.X/4096.0)+1;ix++)for(int lane=(int)Math.Floor(bounds.Position.Y/spacing)-1;lane<(int)Math.Ceiling(bounds.End.Y/spacing)+1;lane++)
        {
            double x=ix*4096.0+Math.Sin(ix*1.7+N(sampler,"seed_value"))*180,outlet=builder.Call("_grass_river_center",x,lane,spacing).AsDouble(),side=sampler.Call("random",ix,lane,921).AsDouble()>.5?1:-1;var p=new Vector2((float)x,(float)(outlet+side*500));if(!bounds.HasPoint(p)||!Owns(p))continue;builder.Call("_biome_weights",p.X,p.Y);if(builder.Get("_extra_weights").AsFloat64Array()[1]<.95||builder.Call("_island_mask",p.X,p.Y).AsDouble()<.1)continue;if(Water(p)<20||Height(p)>Water(p)-.5)continue;
            for(int i=0;i<24;i++){double za=outlet+side*(470+i*2.5),zb=za+side*2.5,ha=sampler.Call("tributary",new Vector2((float)x,(float)za)).AsVector4().X+.12,hb=sampler.Call("tributary",new Vector2((float)x,(float)zb)).AsVector4().X+.12;g.quad(new Vector3((float)(x-10),(float)ha,(float)za),new Vector3((float)(x+10),(float)ha,(float)za),new Vector3((float)(x+10),(float)hb,(float)zb),new Vector3((float)(x-10),(float)hb,(float)zb),new Color(.65f,.78f,.81f));}
            records.Add(new D{["position"]=p,["outlet"]=new Vector2((float)x,(float)outlet),["drop_metres"]=34.0,["connected_to_carrier"]=true});
        }
        return records;
    }
    public A tropical_waterfalls(Rect2 bounds)
    {
        var records=new A();var sampler=builder.Get("_tropical").AsGodotObject();if(sampler==null||N(sampler.Get("settings").AsGodotObject(),"waterfall_frequency")<=0||!builder.Get("settings").AsGodotObject().Get("water_enabled").AsBool())return records;
        double spacing=sampler.Call("_spacing").AsDouble(),span=spacing*.6;var color=new Color(.65f,.78f,.81f);
        for(int segment=(int)Math.Floor(bounds.Position.X/span)-1;segment<(int)Math.Ceiling(bounds.End.X/span)+1;segment++)for(int lane=(int)Math.Floor(bounds.Position.Y/spacing)-2;lane<(int)Math.Ceiling(bounds.End.Y/spacing)+2;lane++)
        {
            double r=sampler.Call("random",segment,lane,131).AsDouble(),drop=sampler.Call("cascade_height",segment,lane,r).AsDouble();if(drop<=0)continue;var center=sampler.Call("cascade_point",segment,lane,.5).AsVector2();if(!bounds.HasPoint(center)||!Owns(center))continue;builder.Call("_biome_weights",center.X,center.Y);if(N(builder,"_tropical_weight")<.95)continue;
            var points=new Godot.Collections.Array<Vector3>();var stations=new List<Vector2>();bool valid=true;double extent=128/(span*.7),previous=double.NegativeInfinity;
            for(int i=0;i<33;i++){double t=Lerp(.5-extent,.5+extent,i/32.0);var p=sampler.Call("cascade_point",segment,lane,t).AsVector2();double bed=Height(p),level=N(builder,"_last_swamp_water");if(level<bed+.12||level<N(builder,"water_level")+4||level<previous-.001){valid=false;break;}points.Add(new Vector3(p.X,(float)(level+.12),p.Y));stations.Add(p);previous=level;}
            if(!valid||points.Count!=33)continue;double actual=(double)points[^1].Y-points[0].Y;if(actual<Math.Max(6,drop*Math.Max(N(builder.Get("settings").AsGodotObject(),"height_multiplier"),.01)*.35))continue;var sections=new List<Vector3[]>();
            for(int i=0;i<points.Count;i++){var tangent=(stations[Math.Min(i+1,32)]-stations[Math.Max(i-1,0)]).Normalized();var side=new Vector2(-tangent.Y,tangent.X)*(float)(3+r*2);var section=new List<Vector3>();foreach(var p in new[]{stations[i]-side,stations[i]+side}){double bed=Height(p),level=N(builder,"_last_swamp_water");if(level<bed+.05){valid=false;break;}section.Add(new Vector3(p.X,(float)(level+.12),p.Y));}if(!valid)break;sections.Add(section.ToArray());}
            if(!valid)continue;for(int i=0;i<32;i++)g.quad(sections[i][0],sections[i][1],sections[i+1][1],sections[i+1][0],color);
            records.Add(new D{["id"]="tropical:"+segment+":"+lane,["position"]=center,["segment"]=segment,["lane"]=lane,["drop_metres"]=actual,["connected_to_carrier"]=true,["kind"]="rocky_tributary_cascade",["canonical_water_profile"]=points,["pool_t"]=.4,["renderer"]="existing terrain_features kind 3; no water collision"});
        }
        return records;
    }
}
