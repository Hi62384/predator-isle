using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Finite supported molten films and short exposed falls into existing retained lava; no excavation.</summary>
public partial class MagmaCascades : RefCounted
{
    private readonly CaveBiomeRegions Regions=new();private readonly CaveSeepageSurface Surface=new();private readonly CaveFormations Shapes=new();
    private static Variant Get(D d,string key,Variant fallback)=>d.ContainsKey(key)?d[key]:fallback;
    private static A Items(D d,string key)=>Get(d,key,new A()).AsGodotArray();
    private static double N(D d,string key)=>d[key].AsDouble();
    private static double Sample(GodotObject field,Vector3 p)=>field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
    private static Vector3 Normal(GodotObject field,Vector3 p)=>field is CaveField native?native.normal(p):field.Call("normal",p).AsVector3();
    private static D Heat(GodotObject context,Vector3 p)=>context is MagmaCaveHeat native?native.sample(p):context.Call("sample",p).AsGodotDictionary();
    public double backing_distance(GodotObject field,Vector3 point,Vector3 axis)
    {foreach(double distance in new[]{.1,.15,.2,.25,.3})if(Sample(field,point-axis*(float)distance)>=.04)return distance;return double.PositiveInfinity;}
    public bool inside_patch(Vector3 point,Vector3[] vertices)
    {
        var p=new Vector2(point.X,point.Z);
        for(int i=0;i<vertices.Length;i+=3)
        {
            var a=new Vector2(vertices[i].X,vertices[i].Z);var b=new Vector2(vertices[i+1].X,vertices[i+1].Z);var c=new Vector2(vertices[i+2].X,vertices[i+2].Z);
            double x=(b-a).Cross(p-a),y=(c-b).Cross(p-b),z=(a-c).Cross(p-c);if(Math.Min(x,Math.Min(y,z))>=-.00001||Math.Max(x,Math.Max(y,z))<=.00001)return true;
        }
        return false;
    }
    public D prepare(D region,Callable height,long seed_id,D settings,double maximum_depth,double minimum_roof,GodotObject? context)
    {
        if(!Get(settings,"molten_cascades",false).AsBool()||context==null||!Get(region,"valid",false).AsBool()||Get(region,"cave_family",-1).AsInt64() is 6 or 7)return region;
        var pools=Items(region,"pools");var eligible=new List<int>();
        for(int index=0;index<pools.Count;index++)
        {
            var pool=pools[index].AsGodotDictionary();if(Get(pool,"fluid_kind","").AsString()=="magma"&&!Get(pool,"magma_large_lake",false).AsBool()&&!pool.ContainsKey("molten_cascade")&&Regions.random(pool["id"].AsString(),seed_id,"magma/molten_cascade")<Get(settings,"molten_cascade_chance",.06).AsDouble())eligible.Add(index);
        }
        if(eligible.Count==0)return region;using var field=new CaveField {maximum_depth=maximum_depth,minimum_roof=minimum_roof};if(!field.compile(new A {region},height,new A(),Get(region,"cave_biome_regions",new D()).AsGodotDictionary()))return region;
        foreach(int index in eligible)
        {
            var pool=pools[index].AsGodotDictionary();string poolId=pool["id"].AsString(),parentId=poolId.EndsWith(":seepage",StringComparison.Ordinal)?poolId[..^8]:poolId;var parent=new D();var rooms=Items(region,"nodes").Duplicate();rooms.AddRange(Items(region,"pockets"));
            foreach(var item in rooms){var room=item.AsGodotDictionary();if(room["id"].AsString()==parentId){parent=room;break;}}if(parent.Count==0)continue;
            var poolCenter=pool["center"].AsVector3();var radial=(poolCenter-parent["point"].AsVector3())*new Vector3(1,0,1);if(radial.LengthSquared()<1)continue;
            radial=radial.Normalized();var tangent=radial.Cross(Vector3.Up);double rise=5+Regions.random(poolId,seed_id,"magma/cascade_head")*3,width=.24+Regions.random(poolId,seed_id,"magma/cascade_width")*.25;
            var patch=Surface.build(pool,field,Get(region,"cross_section_style",0).AsInt32());if(!patch["valid"].AsBool()||patch["arrays"].AsGodotArray().Count==0)continue;var patchVertices=patch["arrays"].AsGodotArray()[(int)Mesh.ArrayType.Vertex].AsVector3Array();
            var rows=new List<Vector3[]>();var rowNormals=new List<Vector3[]>();bool valid=true;var low=Vector3.Inf;var high=-Vector3.Inf;Vector3[] lip=System.Array.Empty<Vector3>();double lipHeight=0,waterY=N(pool,"water_y");string thermal=pool["thermal_source"].AsString();
            for(int row=0;row<25;row++)
            {
                double y=waterY+.03+rise*(1-(double)row/24);var points=new List<Vector3>(3);var axes=new List<Vector3>(3);
                if(row>0&&y<=waterY+2.5)
                {
                    if(lip.Length==0){lip=rows[^1].ToArray();lipHeight=lip[0].Y;}
                    for(int side=0;side<3;side++)
                    {
                        var point=lip[side]-Vector3.Up*(float)(lipHeight-y)-radial*(float)Math.Min(1.4,(lipHeight-y)*2.8);var witness=Heat(context,point);
                        if(field.sample(point)>-.03||N(witness,"heat")<.5||Get(witness,"id","").AsString()!=thermal||row==24&&!inside_patch(point,patchVertices)){valid=false;break;}
                        points.Add(point);axes.Add(-radial);low=low.Min(point);high=high.Max(point);
                    }
                    if(!valid)break;rows.Add(points.ToArray());rowNormals.Add(axes.ToArray());continue;
                }
                foreach(int side in new[]{-1,0,1})
                {
                    var start=new Vector3(poolCenter.X,(float)y,poolCenter.Z)+tangent*side*(float)width;var previous=start;var wall=Vector3.Inf;if(field.sample(start)>=-.05){valid=false;break;}
                    for(int step=1;step<=(int)Math.Ceiling((N(parent,"chamber_radius")+12)*2);step++)
                    {
                        var point=start+radial*step*.5f;
                        if(field.sample(point)>=0&&field.sample(previous)<0)
                        {
                            var boundary=Shapes.boundary(field,previous,point);bool backed=true;foreach(double distance in new[]{.25,.5,.75,1.0})if(field.sample(boundary+radial*(float)distance)<.04){backed=false;break;}if(backed)wall=boundary;
                        }
                        previous=point;
                    }
                    if(!wall.IsFinite()){valid=false;break;}var axis=field.normal(wall);var surfacePoint=wall-radial*.08f;var source=Heat(context,surfacePoint);
                    if(axis.Dot(-radial)<.2||field.sample(surfacePoint)>-.04||!double.IsFinite(backing_distance(field,surfacePoint,axis))||!double.IsFinite(backing_distance(field,surfacePoint,field.normal(surfacePoint)))||N(source,"heat")<.5||Get(source,"id","").AsString()!=thermal){valid=false;break;}
                    if(row==24&&!inside_patch(surfacePoint,patchVertices)){valid=false;break;}points.Add(surfacePoint);axes.Add(axis);low=low.Min(surfacePoint);high=high.Max(surfacePoint);
                }
                if(!valid)break;rows.Add(points.ToArray());rowNormals.Add(axes.ToArray());
            }
            if(!valid||rows.Count!=25||Shapes.@protected(field,(low+high)*.5f,new Vector2(high.X-low.X,high.Z-low.Z).Length()*.5,low.Y,high.Y))continue;
            var vertices=new List<Vector3>();var normals=new List<Vector3>();
            for(int row=0;row<24;row++)for(int side=0;side<2;side++)
                foreach(var triangle in new[]{new[]{rows[row][side],rows[row+1][side],rows[row+1][side+1]},new[]{rows[row][side],rows[row+1][side+1],rows[row][side+1]}})
                {
                    var n=(triangle[2]-triangle[0]).Cross(triangle[1]-triangle[0]).Normalized();if(n.Dot(rowNormals[row][side])<0){System.Array.Reverse(triangle);n=-n;}if(n.LengthSquared()<.9){valid=false;break;}foreach(var point in triangle){vertices.Add(point);normals.Add(n);}
                }
            if(!valid)continue;
            for(int i=0;i<vertices.Count;i+=3)foreach(var pair in new[]{new Vector2I(0,1),new Vector2I(1,2),new Vector2I(2,0)})
            {
                var point=(vertices[i+pair.X]+vertices[i+pair.Y])*.5f;var axis=field.normal(point);var source=Heat(context,point);
                if(field.sample(point)>-.03||point.Y>lipHeight+.01&&!double.IsFinite(backing_distance(field,point,axis))||N(source,"heat")<.5||Get(source,"id","").AsString()!=thermal){valid=false;break;}
            }
            if(!valid)continue;var result=region.Duplicate(true);Items(result,"pools")[index].AsGodotDictionary()["molten_cascade"]=new D {["vertices"]=vertices.ToArray(),["normals"]=normals.ToArray(),["bounds"]=new Aabb(low,high-low),["thermal_source"]=pool["thermal_source"],["source_kind"]=Get(pool,"heat_source_kind","explicit_diagnostic_intrusion"),["rise"]=rise,["width"]=width*2,["backing_offset"]=.08,["maximum_contact_distance"]=.3,["supported_lip_height"]=lipHeight,["free_fall_height"]=lipHeight-waterY,["clipped_pool_id"]=pool["id"]};return result;
        }
        return region;
    }
    public D append_to(D patch,A regions,Vector3I key)
    {
        var selected=new List<D>();var ids=patch["ids"].AsGodotArray();
        foreach(var item in regions)foreach(var value in Items(item.AsGodotDictionary(),"pools"))
        {
            var pool=value.AsGodotDictionary();var center=pool["center"].AsVector3();
            if(pool.ContainsKey("molten_cascade")&&ids.Contains(pool["id"])&&new Vector3I((int)Math.Floor(center.X/64.0),(int)Math.Floor(N(pool,"water_y")/64),(int)Math.Floor(center.Z/64.0))==key)selected.Add(pool);
        }
        if(selected.Count==0)return patch;var origin=(Vector3)key*64;var arrays=patch["arrays"].AsGodotArray().Duplicate(true);var vertices=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array().ToList();var normals=arrays[(int)Mesh.ArrayType.Normal].AsVector3Array().ToList();var colors=arrays[(int)Mesh.ArrayType.Color].AsColorArray().ToList();var uv=arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array().ToList();var uv2=arrays[(int)Mesh.ArrayType.TexUV2].AsVector2Array().ToList();
        foreach(var pool in selected)
        {
            var cascade=pool["molten_cascade"].AsGodotDictionary();var points=cascade["vertices"].AsVector3Array();var ns=cascade["normals"].AsVector3Array();
            for(int i=0;i<points.Length;i++){vertices.Add(points[i]-origin);normals.Add(ns[i]);colors.Add(Colors.White);uv.Add(Vector2.Zero);uv2.Add(new Vector2((float)(Math.PI*.5),0));}
        }
        arrays[(int)Mesh.ArrayType.Vertex]=vertices.ToArray();arrays[(int)Mesh.ArrayType.Normal]=normals.ToArray();arrays[(int)Mesh.ArrayType.Color]=colors.ToArray();arrays[(int)Mesh.ArrayType.TexUV]=uv.ToArray();arrays[(int)Mesh.ArrayType.TexUV2]=uv2.ToArray();var result=patch.Duplicate();result["arrays"]=arrays;result["molten_cascades"]=selected.Count;return result;
    }
}
