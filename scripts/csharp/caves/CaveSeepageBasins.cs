using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Deterministic retained side basins and feeder channels that protect dry graph routes.</summary>
public partial class CaveSeepageBasins : RefCounted
{
    public int MAX_BASINS => 4;
    private readonly CaveChamberProfiles Profiles=new();
    private readonly CaveSeepageSurface Surface=new();
    private static A Items(D d,string key) => d.ContainsKey(key)?d[key].AsGodotArray():new A();
    private static double N(D d,string key) => d[key].AsDouble();
    private static double Sample(GodotObject field,Vector3 p) => field is CaveField native?native.sample(p):field.Call("sample",p).AsDouble();
    public bool route_clear(Vector3 center,double radius,double bed_y,double water_y,D region)
    {
        var edges=Items(region,"edges").Duplicate();edges.AddRange(Items(region,"pocket_passages"));
        foreach(var item in edges)
        {
            var edge=item.AsGodotDictionary();var points=edge["points"].AsVector3Array();double clearance=radius+N(edge,"half_width")+2;
            for(int i=0;i<points.Length-1;i++)
            {
                var a=points[i];var b=points[i+1];
                if(center.X+clearance<Math.Min(a.X,b.X)||center.X-clearance>Math.Max(a.X,b.X)||center.Z+clearance<Math.Min(a.Z,b.Z)||center.Z-clearance>Math.Max(a.Z,b.Z)) continue;
                var ab=new Vector2(b.X-a.X,b.Z-a.Z);var q=new Vector2(center.X-a.X,center.Z-a.Z);double t=Math.Clamp(q.Dot(ab)/Math.Max(ab.LengthSquared(),.000001),0,1),floor=a.Y+((double)b.Y-a.Y)*t;
                if((q-ab*(float)t).Length()<clearance&&floor+N(edge,"headroom")>bed_y-.5&&floor<water_y+1) return false;
            }
        }
        return true;
    }
    public A make(D region,long seed_id) => make(region,seed_id,.15,true);
    public A make(D region,long seed_id,double density) => make(region,seed_id,density,true);
    public A make(D region,long seed_id,double density,bool require_soluble_geology)
    {
        var basins=new A();long geology=region.ContainsKey("geology")?region["geology"].AsInt64():0;
        if(density<=0||!region.ContainsKey("valid")||!region["valid"].AsBool()||(require_soluble_geology&&geology is not (0 or 2 or 5))) return basins;
        var cell=region["id"].AsVector2I();var rooms=Items(region,"nodes").Duplicate();rooms.AddRange(Items(region,"pockets"));
        for(int index=0;index<rooms.Count;index++)
        {
            if(basins.Count>=4) break;var room=rooms[index].AsGodotDictionary();
            if(!room.ContainsKey("level")||room["level"].AsInt64()<0||Profiles.random(cell,seed_id,1800+index)>Math.Clamp(density,0,1)) continue;
            double radius=3+Profiles.random(cell,seed_id,2000+index)*2,depth=1.8+Profiles.random(cell,seed_id,2100+index)*1.7,angle=Profiles.random(cell,seed_id,2200+index)*Math.Tau,offset=N(room,"chamber_radius")*.7;
            var roomPoint=room["point"].AsVector3();var center=roomPoint+new Vector3((float)(Math.Cos(angle)*offset),0,(float)(Math.Sin(angle)*offset));double bedY=center.Y-depth,waterY=center.Y-.4;
            if(!route_clear(center,radius,bedY,waterY,region)) continue;bool overlaps=false;
            foreach(var item in basins)
            {
                var previous=item.AsGodotDictionary();var previousCenter=previous["center"].AsVector3();
                if(new Vector2(center.X-previousCenter.X,center.Z-previousCenter.Z).Length()<radius+N(previous,"radius")+2&&Math.Abs(waterY-N(previous,"water_y"))<depth+2) overlaps=true;
                if(!route_clear(center,radius,bedY,waterY,new D {["edges"]=Items(previous,"stream_edges")})) overlaps=true;
            }
            if(overlaps) continue;var lobe=new Vector3((float)Math.Cos(angle+.8),0,(float)Math.Sin(angle+.8))*(float)radius*.3f;string id=room["id"].AsString();
            var basin=new D {["id"]=id+":seepage",["center"]=center,["radius"]=radius,["water_radius"]=radius*.8,["water_y"]=waterY,["bed_y"]=bedY,["depth"]=depth,
                ["bed"]=new D {["id"]=id+":basin-bed",["point"]=new Vector3(center.X,(float)bedY,center.Z),["level"]=room["level"],["chamber_radius"]=radius*.85,["chamber_height"]=depth+1.5},
                ["bed_lobes"]=new A {new D {["id"]=id+":basin-lobe",["point"]=new Vector3(center.X,(float)(bedY+.15),center.Z)+lobe,["level"]=room["level"],["chamber_radius"]=radius*.65,["chamber_height"]=depth+1.5}}};basins.Add(basin);
            if(Profiles.random(cell,seed_id,2300+index)>=.4) continue;var points=new List<Vector3>();bool admitted=true;double turn=.8*(Profiles.random(cell,seed_id,2400+index)<.5?1:-1);
            for(int station=0;station<17;station++)
            {
                double t=(double)station/16,yaw=angle+turn*(1-t);var point=roomPoint+new Vector3((float)(Math.Cos(yaw)*offset),(float)(-1.2+(-depth+1.2)*t),(float)(Math.Sin(yaw)*offset));
                if(!route_clear(point,1.5,point.Y,waterY+.1,region)){admitted=false;break;}
                for(int i=0;i<basins.Count-1;i++)
                {
                    var previous=basins[i].AsGodotDictionary();var p=previous["center"].AsVector3();
                    if(new Vector2(point.X-p.X,point.Z-p.Z).Length()<1.5+N(previous,"radius")+2&&Math.Abs(waterY-N(previous,"water_y"))<depth+2){admitted=false;break;}
                    if(!route_clear(point,1.5,point.Y,waterY+.1,new D {["edges"]=Items(previous,"stream_edges")})){admitted=false;break;}
                }
                if(!admitted) break;points.Add(point);
            }
            if(admitted){basin["stream_points"]=points.ToArray();basin["stream_edges"]=new A {new D {["from"]=id+":seep",["to"]=basin["id"],["points"]=points.ToArray(),["half_width"]=1.5,["headroom"]=depth+1.5,["entrance"]=false}};}
        }
        return basins;
    }
    public A water_arrays(D basin) => water_arrays(basin,Vector3.Zero);
    public A water_arrays(D basin,Vector3 origin)
    {
        var vertices=new Vector3[144];var normals=new Vector3[144];var colors=new Color[144];var p=basin["center"].AsVector3();var center=new Vector3(p.X,(float)N(basin,"water_y"),p.Z)-origin;
        for(int i=0;i<48;i++)
        {
            double a=i*Math.Tau/48,b=(i+1)*Math.Tau/48,radius=N(basin,"water_radius");
            vertices[i*3]=center;vertices[i*3+1]=center+new Vector3((float)(Math.Cos(a)*radius),0,(float)(Math.Sin(a)*radius));vertices[i*3+2]=center+new Vector3((float)(Math.Cos(b)*radius),0,(float)(Math.Sin(b)*radius));
            for(int j=0;j<3;j++){normals[i*3+j]=Vector3.Up;colors[i*3+j]=new Color(.07f,.13f,.14f,1);}
        }
        var result=new A();result.Resize((int)Mesh.ArrayType.Max);result[(int)Mesh.ArrayType.Vertex]=vertices;result[(int)Mesh.ArrayType.Normal]=normals;result[(int)Mesh.ArrayType.Color]=colors;return result;
    }
    public Vector3[] surface_outline(D basin,GodotObject field)
    {
        var p=basin["center"].AsVector3();var center=new Vector3(p.X,(float)N(basin,"water_y"),p.Z);if(Sample(field,center)>=-.015) return System.Array.Empty<Vector3>();var result=new Vector3[48];
        for(int i=0;i<48;i++)
        {
            var direction=new Vector3((float)Math.Cos(i*Math.Tau/48),0,(float)Math.Sin(i*Math.Tau/48));double low=0,high=N(basin,"radius")*1.25;if(Sample(field,center+direction*(float)high)<0) return System.Array.Empty<Vector3>();
            for(int station=0;station<14;station++){double mid=(low+high)*.5;if(Sample(field,center+direction*(float)mid)<-.035) low=mid;else high=mid;}result[i]=center+direction*(float)low;
        }
        return result;
    }
    public D water_cell(A regions,GodotObject field,Vector3I key) => water_cell(regions,field,key,"water");
    public D water_cell(A regions,GodotObject field,Vector3I key,string fluid_kind)
    {
        var vertices=new List<Vector3>();var normals=new List<Vector3>();var colors=new List<Color>();var uv=new List<Vector2>();var uv2=new List<Vector2>();var ids=new Godot.Collections.Array<string>();var rejected=new Godot.Collections.Array<string>();var reasons=new D();var origin=(Vector3)key*64;int channels=0;
        foreach(var item in regions)
        {
            var region=item.AsGodotDictionary();foreach(var value in Items(region,"pools"))
            {
                var basin=value.AsGodotDictionary();if((basin.ContainsKey("fluid_kind")?basin["fluid_kind"].AsString():"water")!=fluid_kind) continue;var p=basin["center"].AsVector3();var center=new Vector3(p.X,(float)N(basin,"water_y"),p.Z);
                if(field.Call("cell",center).AsVector3I()!=key) continue;var patch=Surface.build(basin,field,region.ContainsKey("cross_section_style")?region["cross_section_style"].AsInt32():0);var arrays=patch.ContainsKey("arrays")?patch["arrays"].AsGodotArray():new A();string id=basin["id"].AsString();
                if(!patch["valid"].AsBool()||arrays.Count==0){rejected.Add(id);reasons[basin["id"]]=patch.ContainsKey("reason")?patch["reason"]:"Empty clipped water patch";continue;}
                ids.Add(id);if(basin.ContainsKey("stream_points")) channels++;foreach(var point in arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array()) vertices.Add(point-origin);
                normals.AddRange(arrays[(int)Mesh.ArrayType.Normal].AsVector3Array());colors.AddRange(arrays[(int)Mesh.ArrayType.Color].AsColorArray());uv.AddRange(arrays[(int)Mesh.ArrayType.TexUV].AsVector2Array());uv2.AddRange(arrays[(int)Mesh.ArrayType.TexUV2].AsVector2Array());
            }
        }
        var result=new A();if(vertices.Count>0){result.Resize((int)Mesh.ArrayType.Max);result[(int)Mesh.ArrayType.Vertex]=vertices.ToArray();result[(int)Mesh.ArrayType.Normal]=normals.ToArray();result[(int)Mesh.ArrayType.Color]=colors.ToArray();result[(int)Mesh.ArrayType.TexUV]=uv.ToArray();result[(int)Mesh.ArrayType.TexUV2]=uv2.ToArray();}
        return new D {["arrays"]=result,["ids"]=ids,["rejected"]=rejected,["channels"]=channels,["rejection_reasons"]=reasons};
    }
}
