using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Worker-owned cooled volcanic geology and witnessed retained lava on the shared cave graph.</summary>
public partial class MagmaCaveFeatures : RefCounted
{
    // These helpers use pure operations only. Query fields, templates and mesh buffers remain local to each build.
    private static readonly CaveBiomeRegions Regions=new();private static readonly CaveChamberProfiles Profiles=new();private static readonly CaveSeepageBasins Basins=new();private static readonly MagmaCaveTubes Tubes=new();private static readonly MagmaLakeChambers Lakes=new();private static readonly MagmaCascades Cascades=new();
    private static Variant Get(D d,string name,Variant fallback)=>d.ContainsKey(name)?d[name]:fallback;
    private static A Items(D d,string name)=>Get(d,name,new A()).AsGodotArray();
    private static double N(D d,string name)=>d[name].AsDouble();
    private static bool Flag(D d,string name,bool fallback=false)=>Get(d,name,fallback).AsBool();
    private static double Setting(D d,string name,double fallback)=>Get(d,name,fallback).AsDouble();
    private static bool Excluded(D region)=>!Flag(region,"valid")||Get(region,"cave_family",-1).AsInt64() is 6 or 7;
    private static string Parent(string id)=>id.EndsWith(":seepage",StringComparison.Ordinal)?id[..^8]:id;
    private static double Smooth(double a,double b,double x){double t=Math.Clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static D Heat(GodotObject context,Vector3 p)=>context is MagmaCaveHeat native?native.sample(p):context.Call("sample",p).AsGodotDictionary();
    private D Assignment(D region,string from,string to,double first=0,double length=0)=>Regions.along_edge(Get(region,"cave_biome_regions",new D()).AsGodotDictionary(),from,to,first,length);
    private static double Amount(D assignment)=>Setting(assignment["weights"].AsGodotDictionary(),"magma",0);
    public D decorate_region_with_context(D region,Callable height,long seed_id,D configuration,double maximum_depth,double minimum_roof,GodotObject? heat_context)
    {
        var cooled=decorate_region(region,height,seed_id,configuration,maximum_depth,minimum_roof);if(heat_context==null||Excluded(cooled)||!Flag(configuration,"source_heat",true))return cooled;
        var pools=Items(cooled,"pools").Duplicate();bool changed=false;var rooms=Items(cooled,"nodes").Duplicate();rooms.AddRange(Items(cooled,"pockets"));var proposed=new HashSet<string>(StringComparer.Ordinal);
        foreach(var room in rooms.Select(v=>v.AsGodotDictionary()).OrderBy(r=>r["id"].AsString(),StringComparer.Ordinal))
        {
            if(pools.Count>=4)break;if(Get(room,"level",-1).AsInt64()<0)continue;string roomId=room["id"].AsString(),poolId=roomId+":seepage";if(pools.Any(v=>v.AsGodotDictionary()["id"].AsString()==poolId))continue;
            if(Amount(Assignment(cooled,roomId,roomId))<.7||Regions.random(poolId,seed_id,"magma/active_pool")>Setting(configuration,"active_pool_chance",.14)||N(Heat(heat_context,room["point"].AsVector3()),"heat")<.5)continue;
            var basinRegion=cooled.Duplicate();basinRegion["nodes"]=new A {room};basinRegion["pockets"]=new A();
            foreach(var item in Basins.make(basinRegion,seed_id,1,false))
            {
                var candidate=item.AsGodotDictionary();var center=candidate["center"].AsVector3();bool overlaps=false;
                foreach(var value in pools)
                {
                    var previous=value.AsGodotDictionary();var previousCenter=previous["center"].AsVector3();
                    if(new Vector2(center.X-previousCenter.X,center.Z-previousCenter.Z).Length()<N(candidate,"radius")+N(previous,"radius")+2&&Math.Abs(N(candidate,"water_y")-N(previous,"water_y"))<N(candidate,"depth")+N(previous,"depth")+2){overlaps=true;break;}
                    if(!Basins.route_clear(center,N(candidate,"radius"),N(candidate,"bed_y"),N(candidate,"water_y"),new D {["edges"]=Items(previous,"stream_edges")})){overlaps=true;break;}
                }
                if(!overlaps){pools.Add(candidate);proposed.Add(candidate["id"].AsString());}
            }
        }
        var accepted=new A();
        foreach(var item in pools)
        {
            var pool=item.AsGodotDictionary();string id=pool["id"].AsString(),parent=Parent(id);double amount=Amount(Assignment(cooled,parent,parent));
            if(amount<.7||Regions.random(id,seed_id,"magma/active_pool")>Setting(configuration,"active_pool_chance",.14)){Retain();continue;}
            var center=pool["center"].AsVector3();var witness=Heat(heat_context,new Vector3(center.X,(float)N(pool,"water_y"),center.Z));if(N(witness,"heat")<.5){Retain();continue;}bool admitted=true;
            for(int side=0;side<16;side++)
            {
                double angle=side*Math.Tau/16;var point=new Vector3(center.X,(float)N(pool,"water_y"),center.Z)+new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle))*(float)N(pool,"radius");var sample=Heat(heat_context,point);
                if(N(sample,"heat")<.5||Get(sample,"id","").AsString()!=witness["id"].AsString()){admitted=false;break;}
            }
            foreach(var point in Get(pool,"stream_points",System.Array.Empty<Vector3>()).AsVector3Array())
            {
                var sample=Heat(heat_context,new Vector3(point.X,(float)N(pool,"water_y"),point.Z));if(N(sample,"heat")<.5||Get(sample,"id","").AsString()!=witness["id"].AsString()){admitted=false;break;}
            }
            if(!admitted){Retain();continue;}var molten=pool.Duplicate();molten["fluid_kind"]="magma";molten["thermal_source"]=witness["id"];molten["surface_witness"]=witness["surface_witness"];molten["source_heat"]=witness["heat"];molten["heat_source_kind"]=Get(witness,"kind","explicit_diagnostic_intrusion");if(proposed.Contains(id))molten["construction"]="source_backed_magmatic_side_basin";accepted.Add(molten);changed=true;
            void Retain(){if(!proposed.Contains(id))accepted.Add(pool);}
        }
        var result=cooled;if(changed){result=cooled.Duplicate();result["pools"]=accepted;}
        return Cascades.prepare(Lakes.prepare(result,height,seed_id,configuration,maximum_depth,minimum_roof,heat_context),height,seed_id,configuration,maximum_depth,minimum_roof,heat_context);
    }
    public D decorate_region(D region,Callable height,long seed_id,D configuration,double maximum_depth,double minimum_roof)
    {
        if(!Flag(configuration,"chamber_growth",true)||Excluded(region))return region;var result=region;bool changed=false;
        foreach(string table in new[]{"nodes","pockets"})
        {
            var rooms=Items(region,table).Duplicate();
            for(int index=0;index<rooms.Count;index++)
            {
                var node=rooms[index].AsGodotDictionary();if(Get(node,"level",-1).AsInt64()<0)continue;string id=node["id"].AsString();var assignment=Assignment(region,id,id);if(Amount(assignment)<.7)continue;
                double radius=Math.Max(N(node,"chamber_radius"),22+Regions.random(id,seed_id,"magma/radius")*4),headroom=Math.Max(N(node,"chamber_height"),32+Regions.random(id,seed_id,"magma/vault")*16);int layout=0;
                if(Flag(configuration,"chamber_variety"))
                {
                    string province=Get(assignment["candidate_ids"].AsGodotDictionary(),"magma",node["id"]).AsString();layout=Math.Min(4,(int)(Regions.random(province,seed_id,"magma/geological_province")*5));var extents=new[]{new Vector2(26,48),new Vector2(32,30),new Vector2(28,36),new Vector2(30,28),new Vector2(24,40)};radius=Math.Max(N(node,"chamber_radius"),extents[layout].X);headroom=Math.Max(N(node,"chamber_height"),extents[layout].Y);
                }
                if(radius>(Flag(configuration,"chamber_variety")?32:26)||headroom>48||!Profiles.compatible(node["point"].AsVector3(),radius,headroom,region,Items(region,"pockets")))continue;bool admitted=true;var point=node["point"].AsVector3();
                for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++){if(new Vector2(x,z).Length()>2.1)continue;double surface=height.Call(point.X+x*radius*.5,point.Z+z*radius*.5).AsDouble();if(!double.IsFinite(surface)||surface-point.Y>maximum_depth-4||surface-point.Y<headroom+minimum_roof+4)admitted=false;}
                if(!admitted)continue;var grown=node.Duplicate();grown["chamber_radius"]=radius;grown["chamber_height"]=headroom;grown["magma_profile"]=new[]{"cooled_basalt_vault","collapsed_lava_tube","rough_scoria_chamber","volcanic_ash_cavern","obsidian_lens_cavern"}[layout];grown["cross_section_style"]=new[]{0,3,3,1,2}[layout];rooms[index]=grown;if(!changed){result=region.Duplicate();changed=true;}
            }
            if(changed)result[table]=rooms;
        }
        var final=Tubes.decorate(result,height,seed_id,configuration,maximum_depth,minimum_roof);
        if(Flag(configuration,"cooled_deposits")&&(changed||!final.RecursiveEqual(region))){final=final.Duplicate();var relief=Get(final,"cave_floor_relief",new D()).AsGodotDictionary().Duplicate();final["cave_floor_relief"]=relief;relief["magma"]=Setting(configuration,"deposit_height",.45);}
        return final;
    }
    public D build(GodotObject field,Vector3I key,long seed_id,A regions,D configuration,D _water)
    {
        double density=Math.Clamp(Setting(configuration,"density",.65),0,1);if(density<=0)return new D {["valid"]=true,["batches"]=new A(),["placements"]=new A()};
        bool oldAir=field.Get("include_surface_air").AsBool();double oldCover=field.Get("opening_rock_cover").AsDouble();field.Set("include_surface_air",false);field.Set("opening_rock_cover",6.0);
        using var shapes=new CaveFormations();using var geometry=new MagmaCaveGeometry();using var fit=new CaveMeasuredFormation();var placements=new A();var rejected=new D();var vertices=new List<Vector3>();var normals=new List<Vector3>();var colors=new List<Color>();var uvs=new List<Vector2>();var collision=new List<Vector3>();var far=new List<int>();var origin=(Vector3)key*64;var rooms=new D();int intrusionPrototypes=0;
        try
        {
            foreach(var item in regions)
            {
                var region=item.AsGodotDictionary();if(Get(region,"cave_family",-1).AsInt64() is 6 or 7)continue;var all=Items(region,"nodes").Duplicate();all.AddRange(Items(region,"pockets"));foreach(var pool in Items(region,"pools"))all.AddRange(Items(pool.AsGodotDictionary(),"bank_lobes"));foreach(var roomValue in all){var room=roomValue.AsGodotDictionary();if(Get(room,"level",-1).AsInt64()>=0)rooms[room["id"].AsString()]=room;}
            }
            foreach(string id in rooms.Keys.Select(k=>k.AsString()).OrderBy(s=>s,StringComparer.Ordinal))
            {
                var room=rooms[id].AsGodotDictionary();string parent=Get(room,"biome_parent",id).AsString();var assignment=Regions.along_edge(field.Get("_biome_assignment").AsGodotDictionary(),parent,parent,0,0);if(Amount(assignment)<.3)continue;double radius=N(room,"chamber_radius");var roomPoint=room["point"].AsVector3();var box=new Aabb(roomPoint-new Vector3((float)(radius+4),4,(float)(radius+4)),new Vector3((float)((radius+4)*2),(float)(N(room,"chamber_height")+8),(float)((radius+4)*2)));if(!box.Intersects(new Aabb(origin,Vector3.One*64)))continue;
                for(int patch=0;patch<48;patch++)
                {
                    if(placements.Count>=64)break;string identity=id+"/basalt/"+patch;if(Regions.random(identity,seed_id,"admit")>density)continue;double angle=patch*Math.Tau/48+Regions.random(id,seed_id,"magma/phase")*Math.Tau;var radial=new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle));int family=patch%12<(int)(12*Setting(configuration,"column_frequency",.75))?0:Regions.random(id,seed_id,"silica_lens")<Setting(configuration,"obsidian_lens_chance",.12)?2:1;
                    double width=.45+Regions.random(identity,seed_id,"width")*1.5;var air=roomPoint+radial*(float)radius*(float)(.55+Regions.random(identity,seed_id,"inset")*.25)+Vector3.Up*3;
                    if(family==0&&patch%12!=0)
                    {
                        var start=roomPoint+Vector3.Up*(float)Math.Min(12,N(room,"chamber_height")*.35);var wall=Vector3.Inf;var previous=start;if(Sample(start)>=0)continue;
                        for(int station=1;station<=(int)Math.Ceiling((radius+32)/2);station++){var point=start+radial*station*2;if(Sample(point)>=0){wall=shapes.boundary(field,previous,point);break;}previous=point;}
                        if(!wall.IsFinite())continue;air=new Vector3(wall.X,(float)(roomPoint.Y+3.0),wall.Z)-radial*(float)(width*1.7+.7);
                    }
                    var rock=air-Vector3.Up*10;if(Sample(air)>=0||Sample(rock)<0)continue;var root=shapes.boundary(field,rock,air);if(Cell(root)!=key)continue;double amount=Weight(root+Vector3.Up);if(amount<.3)continue;
                    width*=Smooth(.15,.8,amount);double shapeHeight=(2+Math.Pow(Regions.random(identity,seed_id,"height"),1.5)*Math.Min(20,N(room,"chamber_height")*.6))*Smooth(.15,.8,amount),phase=Regions.random(identity,seed_id,"phase")*Math.Tau;
                    if(family==0){var ceiling=shapes.ceiling_at(field,root);if(!ceiling.IsFinite())continue;shapeHeight=Math.Min(shapeHeight,((double)ceiling.Y-root.Y)*.82);}if(family!=0){shapeHeight*=.3;width*=1.3;}
                    var fitted=fit.fit(field,geometry.prototype(family,patch%4),root,Vector3.Up,width,shapeHeight,phase);
                    if(!fitted["valid"].AsBool()){string reason=fitted["reason"].AsString();rejected[reason]=Get(rejected,reason,0).AsInt64()+1;continue;}var points=fitted["vertices"].AsVector3Array();var ns=fitted["normals"].AsVector3Array();if(vertices.Count+points.Length>24000)break;
                    int first=vertices.Count;double age=Regions.random(id,seed_id,"cooled_age");var tint=new Color(.13f,.14f,.15f).Lerp(new Color(.28f,.19f,.14f),(float)(age*.4));bool physical=shapeHeight>=1.5&&width>=.35;
                    for(int i=0;i<points.Length;i++){vertices.Add(points[i]-origin);normals.Add(ns[i]);colors.Add(tint);uvs.Add(new Vector2(family,(float)age));if(physical)collision.Add(vertices[^1]);if(family==0||shapeHeight>=4)far.Add(first+i);}
                    placements.Add(new D {["id"]=identity,["kind"]=new[]{"jointed_basalt_column","volcanic_block","obsidian_wedge"}[family],["owner"]=key,["root"]=root,["height"]=shapeHeight,["width"]=width,["bounds"]=fitted["bounds"],["attachments"]=fitted["attachments"],["collider"]=physical,["first_vertex"]=first,["vertex_count"]=points.Length,["family"]=family,["raw_weight"]=amount});
                }
            }
            if(Flag(configuration,"cooled_intrusions")&&placements.Count<64)
            {
                using var intrusions=new MagmaIntrusions();var extra=intrusions.build(field,key,seed_id,rooms,density,64-placements.Count,configuration);var points=extra["vertices"].AsVector3Array();
                if(vertices.Count+points.Length<=24000)
                {
                    int offset=vertices.Count;foreach(var item in Items(extra,"placements")){var placement=item.AsGodotDictionary();placement["first_vertex"]=placement["first_vertex"].AsInt64()+offset;placements.Add(placement);}vertices.AddRange(points);normals.AddRange(extra["normals"].AsVector3Array());colors.AddRange(extra["colors"].AsColorArray());uvs.AddRange(extra["uv"].AsVector2Array());collision.AddRange(extra["collision"].AsVector3Array());for(int i=0;i<points.Length;i++)far.Add(offset+i);intrusionPrototypes=extra["prototype_count"].AsInt32();
                }
            }
        }
        finally{field.Set("include_surface_air",oldAir);field.Set("opening_rock_cover",oldCover);}
        var batches=new A();if(vertices.Count>0)
        {
            var arrays=new A();arrays.Resize((int)Mesh.ArrayType.Max);arrays[(int)Mesh.ArrayType.Vertex]=vertices.ToArray();arrays[(int)Mesh.ArrayType.Normal]=normals.ToArray();arrays[(int)Mesh.ArrayType.Color]=colors.ToArray();arrays[(int)Mesh.ArrayType.TexUV]=uvs.ToArray();arrays[(int)Mesh.ArrayType.Index]=Enumerable.Range(0,vertices.Count).ToArray();var lods=new D();if(Flag(configuration,"mesh_lods",true)&&far.Count>0&&far.Count<vertices.Count)lods[1.5]=far.ToArray();batches.Add(new D {["kind"]="cooled_volcanic",["arrays"]=arrays,["lods"]=lods,["collision_faces"]=collision.ToArray(),["shadows"]=true});
        }
        var molten=Cascades.append_to(Basins.water_cell(regions,field,key,"magma"),regions,key);if(molten["arrays"].AsGodotArray().Count>0)batches.Add(new D {["kind"]="molten_volcanic",["arrays"]=molten["arrays"],["lods"]=new D(),["collision_faces"]=System.Array.Empty<Vector3>(),["shadows"]=false,["source_basins"]=molten["ids"]});
        return new D {["valid"]=true,["batches"]=batches,["placements"]=placements,["rejections"]=rejected,["prototype_count"]=geometry.templates.Count+intrusionPrototypes};
        double Sample(Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
        Vector3I Cell(Vector3 p)=>field is CaveField native?native.cell(p):field.Call("cell",p).AsVector3I();
        double Weight(Vector3 p)=>field is CaveField native?native.biome_weights_at(p,new A {"magma"}).X:field.Call("biome_weights_at",p,new A {"magma"}).AsVector4().X;
    }
}
