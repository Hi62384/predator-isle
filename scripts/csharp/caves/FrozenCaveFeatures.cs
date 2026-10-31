using Godot;
using System;
using System.Collections.Generic;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Measured ice contacts, retained frozen pools and supported shore transitions on the shared cave field.</summary>
public partial class FrozenCaveFeatures : RefCounted
{
    private static readonly StringName WaterRadiusKey="water_radius";
    private static readonly CaveSeepageBasins Basins=new();private static readonly CaveChamberProfiles Profiles=new();private static readonly CaveBiomeRegions Regions=new();
    public CaveFormations shapes {get;set;}=new();public CaveFormations thin {get;set;}=new();public A placements {get;set;}=new();public Vector3I key {get;set;}public Vector3 origin {get;set;}public bool smooth_normals {get;set;}=true;
    internal static Variant Get(D d,string name,Variant fallback)=>d.ContainsKey(name)?d[name]:fallback;
    internal static A Items(D d,string name)=>Get(d,name,new A()).AsGodotArray();
    internal static double N(D d,string name)=>d[name].AsDouble();
    internal static double Setting(D d,string name,double fallback)=>Get(d,name,fallback).AsDouble();
    internal static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    internal static double Sample(GodotObject field,Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
    internal static bool Hot(GodotObject field,Aabb bounds)=>field is CaveField native?native.hot_bounds(bounds):field.Call("hot_bounds",bounds).AsBool();
    internal static Vector3I Cell(GodotObject field,Vector3 p)=>field is CaveField native?native.cell(p):field.Call("cell",p).AsVector3I();
    internal static string Parent(string id)=>id.EndsWith(":seepage",StringComparison.Ordinal)?id[..^8]:id;
    public void smooth_range(CaveFormations builder,int first)
    {
        if(!smooth_normals)return;var accumulated=new Dictionary<Vector3,Vector3>();var vertices=builder.VertexBuffer;var normals=builder.NormalBuffer;
        for(int i=first;i<vertices.Count;i++)accumulated[vertices[i]]=accumulated.GetValueOrDefault(vertices[i])+normals[i];
        for(int i=first;i<vertices.Count;i++){var normal=accumulated[vertices[i]].Normalized();if(normal.Dot(normals[i])>.15)normals[i]=normal;}
    }
    public D decorate_region(D region,Callable height,long _seed_id,D configuration,double maximum_depth,double minimum_roof)
    {
        if(!Get(configuration,"large_lakes",true).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7||!Get(region,"valid",false).AsBool())return region;var pools=Items(region,"pools");var grown=pools.Duplicate();bool changed=false;
        for(int index=0;index<pools.Count;index++)
        {
            var pool=pools[index].AsGodotDictionary();string parent=Parent(pool["id"].AsString());var assignment=Regions.along_edge(Get(region,"cave_biome_regions",new D()).AsGodotDictionary(),parent,parent,0,0);double cold=Setting(assignment["weights"].AsGodotDictionary(),"frozen",0);if(cold<.8)continue;
            double radius=Math.Clamp(N(pool,"radius")*Setting(configuration,"lake_radius_multiplier",1.8),Setting(configuration,"lake_radius_minimum",8),Setting(configuration,"lake_radius_maximum",12)),depth=Math.Min(4.8,N(pool,"depth")*1.3),bedY=pool["center"].AsVector3().Y-depth,headroom=depth+8;var center=pool["center"].AsVector3();
            if(radius<=N(pool,"radius")+.01||!Basins.route_clear(center,radius,bedY,N(pool,"water_y"),region)||!Profiles.compatible(center,radius,8,region,Items(region,"pockets")))continue;bool admitted=true;
            for(int otherIndex=0;otherIndex<grown.Count;otherIndex++)
            {
                if(otherIndex==index)continue;var other=grown[otherIndex].AsGodotDictionary();var otherCenter=other["center"].AsVector3();if(new Vector2(center.X-otherCenter.X,center.Z-otherCenter.Z).Length()<radius+N(other,"radius")+2&&Math.Abs(N(pool,"water_y")-N(other,"water_y"))<depth+N(other,"depth")+2)admitted=false;
            }
            for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++){if(new Vector2(x,z).Length()>2.1)continue;double surface=height.Call(center.X+x*radius*.5,center.Z+z*radius*.5).AsDouble();if(!double.IsFinite(surface)||surface-bedY>maximum_depth-4||surface-center.Y<8+minimum_roof+4)admitted=false;}
            if(!admitted)continue;var expanded=pool.Duplicate(true);double ratio=radius/N(pool,"radius");expanded["frozen_lake"]=true;expanded["frozen_original_radius"]=pool["radius"];expanded["radius"]=radius;expanded["depth"]=depth;expanded["bed_y"]=bedY;expanded[WaterRadiusKey]=radius*.8;var bed=expanded["bed"].AsGodotDictionary();var bedPoint=bed["point"].AsVector3();bedPoint.Y=(float)bedY;bed["point"]=bedPoint;bed["chamber_radius"]=radius*.85;bed["chamber_height"]=headroom;
            foreach(var value in Items(expanded,"bed_lobes")){var lobe=value.AsGodotDictionary();var offset=lobe["point"].AsVector3()-center;lobe["point"]=new Vector3((float)(center.X+offset.X*ratio),(float)(bedY+.15),(float)(center.Z+offset.Z*ratio));lobe["chamber_radius"]=radius*.65;lobe["chamber_height"]=headroom;}grown[index]=expanded;changed=true;
        }
        if(!changed)return region;var output=region.Duplicate();output["pools"]=grown;return output;
    }
    public double weight(GodotObject field,Vector3 point)=>field is CaveField native?native.biome_weights_at(point,new A {"frozen"}).X:field.Call("biome_weights_at",point,new A {"frozen"}).AsVector4().X;
    public bool hot_points(GodotObject field,A points)
    {
        var sources=field is CaveField native?native.thermal_sources:field.Get("thermal_sources").AsGodotArray();if(sources.Count==0)return false;var low=Vector3.Inf;var high=-Vector3.Inf;
        foreach(var row in points)foreach(var point in row.AsVector3Array()){low=low.Min(point);high=high.Max(point);}return Hot(field,new Aabb(low,high-low));
    }
    public double wetness(Vector3 point,A regions)
    {
        double wet=0;foreach(var item in regions)foreach(var value in Items(item.AsGodotDictionary(),"pools")){var pool=value.AsGodotDictionary();wet=Math.Max(wet,1-Smooth(N(pool,"radius")+8,N(pool,"radius")+72,point.DistanceTo(pool["center"].AsVector3())));}return wet;
    }
    public A arrays(CaveFormations builder)
    {
        if(builder.VertexBuffer.Count==0)return new();var result=new A();result.Resize((int)Mesh.ArrayType.Max);result[(int)Mesh.ArrayType.Vertex]=builder.vertices;result[(int)Mesh.ArrayType.Normal]=builder.normals;result[(int)Mesh.ArrayType.Color]=builder.colors;return result;
    }
    public void forms(GodotObject field,long seed_id,A regions,double density)
    {
        for(int z=0;z<4;z++)for(int x=0;x<4;x++)
        {
            var cell=new Vector3I(key.X*4+x,key.Y,key.Z*4+z);if(shapes.random(cell,seed_id,51001)>density)continue;var p=new Vector3((float)((cell.X+.2+shapes.random(cell,seed_id,51002)*.6)*16),origin.Y-2,(float)((cell.Z+.2+shapes.random(cell,seed_id,51003)*.6)*16));var previous=p;double previousValue=Sample(field,previous);
            for(int station=0;station<34;station++)
            {
                p.Y=origin.Y+station*2;double value=Sample(field,p);
                if(previousValue>=0&&value<0&&placements.Count<32)
                {
                    var floor=shapes.boundary(field,previous,p);var ceiling=shapes.ceiling_at(field,floor);
                    if(floor.Y<origin.Y-.0001||floor.Y>=origin.Y+64-.0001||!ceiling.IsFinite()||field.Get("height").AsCallable().Call(p.X,p.Z).AsDouble()-ceiling.Y<10){previous=p;previousValue=value;continue;}
                    double cold=weight(field,floor+Vector3.Up),moisture=wetness(floor,regions);if(cold<.55||moisture<.08){previous=p;previousValue=value;continue;}
                    double roomHeight=(double)ceiling.Y-floor.Y,phase=shapes.random(cell,seed_id,51004)*Math.Tau,radius=.25+Math.Pow(shapes.random(cell,seed_id,51005),2)*2.4,shapeHeight=Math.Min(.9+Math.Pow(shapes.random(cell,seed_id,51006),1.7)*18,roomHeight*.72)*Smooth(.45,.9,cold),up=shapes.random(cell,seed_id,51007)<.74?-1:1;var root=up<0?ceiling:floor;bool joined=roomHeight>9&&roomHeight<38&&moisture>.35&&shapes.random(cell,seed_id,51008)<.12;
                    if(joined){root=floor;up=1;shapeHeight=roomHeight;radius=Math.Max(radius,1.2);}if(shapeHeight<.7){previous=p;previousValue=value;continue;}
                    var tip=root+new Vector3(0,(float)(up*shapeHeight),0);double extent=radius*1.15+shapeHeight*.025;
                    if(Hot(field,new Aabb(new Vector3((float)(root.X-extent),(float)(Math.Min(root.Y,tip.Y)-.9),(float)(root.Z-extent)),new Vector3((float)(extent*2),(float)(Math.Abs((double)tip.Y-root.Y)+1.8),(float)(extent*2))))||shapes.@protected(field,root,extent,Math.Min(root.Y,tip.Y)-.9,Math.Max(root.Y,tip.Y)+.9)){previous=p;previousValue=value;continue;}
                    var foot=shapes.contacts(field,root,radius,up,phase,shapeHeight);if(foot.Length==0){previous=p;previousValue=value;continue;}var attachments=new A {foot};var selected=radius<.5&&shapeHeight<3&&up<0?thin:shapes;int first=selected.VertexBuffer.Count;
                    if(joined){var crown=shapes.contacts(field,ceiling,radius,-1,phase,shapeHeight);if(crown.Length==0){previous=p;previousValue=value;continue;}shapes.column(floor,ceiling,radius,phase,foot,crown);attachments.Add(crown);}else selected.growth(root,radius,shapeHeight,up,phase,foot,up>0);
                    smooth_range(selected,first);placements.Add(new D {["kind"]=joined?"ice_column":up<0?"icicle":"ice_stalagmite",["owner"]=key,["root"]=root,["height"]=shapeHeight,["radius"]=extent,["up"]=up,["attachments"]=attachments,["cold"]=cold,["groundwater"]=moisture,["thin"]=selected==thin});
                }
                previous=p;previousValue=value;
            }
        }
    }
    public Vector3 wall_point(GodotObject field,Vector3 center,Vector3 direction,double maximum)
    {
        if(Sample(field,center)>=-.03)return Vector3.Inf;var previous=center;for(int step=1;step<=(int)Math.Ceiling(maximum/.75);step++){var next=center+direction*step*.75f;if(Sample(field,next)>=0)return shapes.boundary(field,previous,next);previous=next;}return Vector3.Inf;
    }
    public void quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,Vector3 n,Color tint){shapes.triangle(a,b,c,n,tint);shapes.triangle(a,c,d,n,tint);}
    public void curtains(GodotObject field,long seed_id,A regions,double chance)=>FrozenCaveGeometry.Curtains(this,field,seed_id,regions,chance);
    public void lake(GodotObject field,D water)=>FrozenCaveGeometry.Lake(this,field,water);
    public void shore_aprons(GodotObject field,A regions,D water)=>FrozenCaveGeometry.Aprons(this,field,regions,water);
    public D build(GodotObject field,Vector3I cell,long seed_id,A regions,D configuration,D water)
    {
        key=cell;origin=(Vector3)cell*64;shapes=new CaveFormations {origin=origin};thin=new CaveFormations {origin=origin};placements=new();smooth_normals=Get(configuration,"smooth_normals",true).AsBool();bool air=field.Get("include_surface_air").AsBool();double cover=field.Get("opening_rock_cover").AsDouble();field.Set("include_surface_air",false);field.Set("opening_rock_cover",6.0);
        try{forms(field,seed_id,regions,Math.Clamp(Setting(configuration,"density",.6),0,1));curtains(field,seed_id,regions,Math.Clamp(Setting(configuration,"curtain_chance",.2),0,1));if(Get(configuration,"lake_ice",true).AsBool()){lake(field,water);shore_aprons(field,regions,water);}}
        finally{field.Set("include_surface_air",air);field.Set("opening_rock_cover",cover);}
        if(shapes.VertexBuffer.Count+thin.VertexBuffer.Count>120000)return new D {["valid"]=false,["reason"]="Frozen geometry vertex bound exceeded",["batches"]=new A()};
        for(int i=0;i<shapes.ColorBuffer.Count;i++)if(shapes.ColorBuffer[i].R>.70&&shapes.ColorBuffer[i].R<.76)shapes.ColorBuffer[i]=new Color(.65f,.28f,.95f,1);for(int i=0;i<thin.ColorBuffer.Count;i++)thin.ColorBuffer[i]=new Color(.3f,.05f,.95f,1);
        var batches=new A();if(shapes.VertexBuffer.Count>0)batches.Add(new D {["kind"]="ice",["arrays"]=arrays(shapes)});if(thin.VertexBuffer.Count>0)batches.Add(new D {["kind"]="thin_ice",["arrays"]=arrays(thin)});return new D {["valid"]=true,["batches"]=batches,["placements"]=placements};
    }
}
