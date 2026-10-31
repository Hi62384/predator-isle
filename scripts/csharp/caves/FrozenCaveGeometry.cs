using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;
using static PredatorIsle.Caves.FrozenCaveFeatures;

namespace PredatorIsle.Caves;
/// <summary>Numeric curtain, lake shell and shore-apron construction for the Frozen provider.</summary>
internal static class FrozenCaveGeometry
{
    internal static void Curtains(FrozenCaveFeatures owner,GodotObject field,long seed,A regions,double chance)
    {
        foreach(var item in regions)foreach(var value in Items(item.AsGodotDictionary(),"pools"))
        {
            var region=item.AsGodotDictionary();var pool=value.AsGodotDictionary();string parent=Parent(pool["id"].AsString());var room=new D();var rooms=Items(region,"nodes").Duplicate();rooms.AddRange(Items(region,"pockets"));foreach(var entry in rooms){var node=entry.AsGodotDictionary();if(node["id"].AsString()==parent){room=node;break;}}
            if(room.Count==0||N(room,"chamber_height")<12)continue;var roomPoint=room["point"].AsVector3();var center=pool["center"].AsVector3();var direction=new Vector3(center.X-roomPoint.X,0,center.Z-roomPoint.Z).Normalized();if(direction.LengthSquared()<.5)continue;
            var basis=owner.wall_point(field,roomPoint+Vector3.Up,direction,N(room,"chamber_radius")+48);if(!basis.IsFinite()||Cell(field,basis)!=owner.key||owner.weight(field,basis-direction)<.65||owner.shapes.random(field is CaveField native?native.bin_cell(basis):field.Call("bin_cell",basis).AsVector3I(),seed,52001)>chance)continue;
            double height=Math.Min(N(room,"chamber_height")*.78,34),width=3+N(pool,"radius")*.75,yaw=Math.Atan2(direction.Z,direction.X);var front=new List<Vector3[]>();var back=new List<Vector3[]>();var attached=new List<Vector3>();bool accepted=true;
            for(int row=0;row<=32;row++)
            {
                double t=(double)row/32;var strip=new List<Vector3>(25);var buried=new List<Vector3>(25);
                for(int col=0;col<=24;col++)
                {
                    double s=(double)col/24,spread=.55+.45*Math.Pow(Math.Sin(Math.PI*t),.35),angle=yaw+(s-.5)*width*spread/Math.Max(N(room,"chamber_radius"),8);var radial=new Vector3((float)Math.Cos(angle),0,(float)Math.Sin(angle));double crown=.72+.28*Math.Pow(.5+.5*Math.Sin(s*Math.Tau*1.5+yaw),.6);var station=roomPoint+new Vector3(0,(float)(.15+(height*crown-.15)*t),0);var contact=owner.wall_point(field,station,radial,N(room,"chamber_radius")+48);
                    if(!contact.IsFinite()){accepted=false;break;}double thickness=(.75+1.7*Math.Pow(.5+.5*Math.Sin(s*Math.Tau*5+.3*Math.Sin(t*Math.Tau)),2)+1.15*Math.Pow(1-t,3))*Math.Sin(Math.PI*(.13+.74*s))*Math.Sin(Math.PI*(.18+.64*t));var point=contact-radial*(float)thickness;var rear=contact+radial*1.2f;
                    if(Sample(field,rear)<.08||owner.shapes.@protected(field,point,.45,point.Y-.5,point.Y+.5)||owner.weight(field,point)<.55){accepted=false;break;}strip.Add(point);buried.Add(rear);attached.Add(rear);
                }
                if(!accepted)break;front.Add(strip.ToArray());back.Add(buried.ToArray());
            }
            if(!accepted||owner.hot_points(field,Rows(front.Concat(back))))continue;var lower=front[1][12]-roomPoint;var upper=front[30][12]-roomPoint;if(Math.Abs((double)new Vector2(lower.X,lower.Z).Length()-new Vector2(upper.X,upper.Z).Length())<.6)continue;
            var tint=new Color(.65f,.22f,.9f,1);int first=owner.shapes.VertexBuffer.Count;
            for(int row=0;row<32;row++)
            {
                for(int col=0;col<24;col++){owner.quad(front[row][col],front[row+1][col],front[row+1][col+1],front[row][col+1],-direction,tint);owner.quad(back[row][col+1],back[row+1][col+1],back[row+1][col],back[row][col],direction,tint);}
                foreach(int col in new[]{0,24})owner.quad(front[row][col],back[row][col],back[row+1][col],front[row+1][col],col==0?-direction.Cross(Vector3.Up):direction.Cross(Vector3.Up),tint);
            }
            for(int col=0;col<24;col++){owner.quad(front[0][col],front[0][col+1],back[0][col+1],back[0][col],Vector3.Down,tint);owner.quad(front[32][col+1],front[32][col],back[32][col],back[32][col+1],Vector3.Up,tint);}
            owner.smooth_range(owner.shapes,first);owner.placements.Add(new D {["kind"]="frozen_waterfall",["owner"]=owner.key,["root"]=basis,["height"]=height,["width"]=width,["source_basin"]=pool["id"],["attachments"]=new A {attached.ToArray()},["measured_wall_vertices"]=attached.Count,["front"]=Rows(front)});
        }
    }
    private readonly record struct EdgeKey(int AX,int AY,int AZ,int BX,int BY,int BZ)
    {internal EdgeKey(Vector3 a,Vector3 b):this(BitConverter.SingleToInt32Bits(a.X),BitConverter.SingleToInt32Bits(a.Y),BitConverter.SingleToInt32Bits(a.Z),BitConverter.SingleToInt32Bits(b.X),BitConverter.SingleToInt32Bits(b.Y),BitConverter.SingleToInt32Bits(b.Z)){} }
    private readonly record struct Edge(Vector3 A,Vector3 B,Vector3 Outward);
    internal static void Lake(FrozenCaveFeatures owner,GodotObject field,D water)
    {
        var original=Items(water,"arrays");if(original.Count==0)return;var vertices=original[(int)Mesh.ArrayType.Vertex].AsVector3Array();var edges=new Dictionary<EdgeKey,LinkedListNode<Edge>>();var order=new LinkedList<Edge>();int triangles=0;
        for(int i=0;i<vertices.Length;i+=3)
        {
            var a=vertices[i]+owner.origin;var b=vertices[i+1]+owner.origin;var c=vertices[i+2]+owner.origin;
            if(owner.hot_points(field,new A {new[]{a,b,c,a-Vector3.Up*.55f,b-Vector3.Up*.55f,c-Vector3.Up*.55f}})||Math.Min(owner.weight(field,a),Math.Min(owner.weight(field,b),owner.weight(field,c)))<.70)continue;
            a.Y=(float)(a.Y+.06);b.Y=(float)(b.Y+.06);c.Y=(float)(c.Y+.06);if(Sample(field,a)>=0||Sample(field,b)>=0||Sample(field,c)>=0)continue;var tint=new Color(.85f,.08f,.95f,1);owner.shapes.triangle(a,b,c,Vector3.Up,tint);owner.shapes.triangle(a-new Vector3(0,.55f,0),c-new Vector3(0,.55f,0),b-new Vector3(0,.55f,0),Vector3.Down,tint);triangles++;
            foreach(var pair in new[]{(a,b),(b,c),(c,a)})
            {
                var first=pair.Item1;var last=pair.Item2;bool forward=first.X<last.X||first.X==last.X&&(first.Y<last.Y||first.Y==last.Y&&first.Z<last.Z);var start=forward?first:last;var end=forward?last:first;var id=new EdgeKey(start,end);
                if(edges.Remove(id,out var node))order.Remove(node);else edges[id]=order.AddLast(new Edge(start,end,((first+last)*.5f-(a+b+c)/3)*new Vector3(1,0,1)));
            }
        }
        foreach(var edge in order)owner.quad(edge.A,edge.B,edge.B-new Vector3(0,.55f,0),edge.A-new Vector3(0,.55f,0),edge.Outward.Normalized(),new Color(.8f,.2f,.95f,1));
        if(triangles>0)owner.placements.Add(new D {["kind"]="frozen_water",["owner"]=owner.key,["source_basins"]=Get(water,"ids",new A()),["top_triangles"]=triangles,["shore_edges"]=edges.Count,["thickness"]=.55,["water_offset"]=.06,["stream_count"]=Get(water,"channels",0)});
    }
    internal static void Aprons(FrozenCaveFeatures owner,GodotObject field,A regions,D water)
    {
        foreach(var item in regions)foreach(var value in Items(item.AsGodotDictionary(),"pools"))
        {
            var region=item.AsGodotDictionary();var pool=value.AsGodotDictionary();if(!Items(water,"ids").Contains(pool["id"]))continue;string parent=Parent(pool["id"].AsString());var room=new D();var rooms=Items(region,"nodes").Duplicate();rooms.AddRange(Items(region,"pockets"));foreach(var entry in rooms){var node=entry.AsGodotDictionary();if(node["id"].AsString()==parent){room=node;break;}}if(room.Count==0)continue;
            var center=pool["center"].AsVector3();var roomPoint=room["point"].AsVector3();var finish=new Vector3(center.X,(float)(N(pool,"water_y")+.06),center.Z);if(Cell(field,new Vector3(center.X,(float)N(pool,"water_y"),center.Z))!=owner.key||owner.weight(field,finish)<.7)continue;var direction=new Vector3(center.X-roomPoint.X,0,center.Z-roomPoint.Z).Normalized();double span=Math.Min(N(pool,"radius")+6,new Vector2(center.X-roomPoint.X,center.Z-roomPoint.Z).Length()-1.0);if(span<5)continue;
            var start=finish-direction*(float)span;start.Y=roomPoint.Y;var side=direction.Cross(Vector3.Up);var top=new List<Vector3[]>();var bottom=new List<Vector3[]>();Vector3[] contact=System.Array.Empty<Vector3>();bool valid=true;double maximumGrade=0;
            for(int row=0;row<25;row++)
            {
                double t=(double)row/24;var middle=start.Lerp(finish,(float)t);middle.Y=(float)(middle.Y+.13*Math.Sin(Math.PI*t));double width=1.75+Math.Sin(Math.PI*t)*.45;var strip=new List<Vector3>(9);var buried=new List<Vector3>(9);
                for(int col=0;col<9;col++)
                {
                    double u=(double)col/8*2-1;var p=middle+side*(float)u*(float)width;p.Y=(float)(p.Y-.015*Math.Pow(Math.Abs(u),3)*Math.Sin(Math.PI*t));if(Sample(field,p+new Vector3(0,2.1f,0))>=-.1){valid=false;break;}strip.Add(p);buried.Add(p-new Vector3(0,.55f,0));
                }
                if(!valid)break;if(row==0){foreach(var point in buried)if(Sample(field,point)<.08)valid=false;contact=buried.ToArray();}
                if(top.Count>0)maximumGrade=Math.Max(maximumGrade,Math.Abs((double)strip[4].Y-top[^1][4].Y)/(span/24));top.Add(strip.ToArray());bottom.Add(buried.ToArray());
            }
            if(!valid||maximumGrade>.2||owner.hot_points(field,Rows(top.Concat(bottom))))continue;var tint=new Color(.8f,.24f,.95f,1);
            for(int row=0;row<24;row++)
            {
                for(int col=0;col<8;col++){owner.quad(top[row][col],top[row+1][col],top[row+1][col+1],top[row][col+1],Vector3.Up,tint);owner.quad(bottom[row][col+1],bottom[row+1][col+1],bottom[row+1][col],bottom[row][col],Vector3.Down,tint);}
                foreach(int col in new[]{0,8})owner.quad(top[row][col],bottom[row][col],bottom[row+1][col],top[row+1][col],col==0?-side:side,tint);
            }
            for(int col=0;col<8;col++){owner.quad(top[0][col+1],top[0][col],bottom[0][col],bottom[0][col+1],-direction,tint);owner.quad(top[24][col],top[24][col+1],bottom[24][col+1],bottom[24][col],direction,tint);}
            owner.placements.Add(new D {["kind"]="ice_shore_apron",["owner"]=owner.key,["source_basin"]=pool["id"],["start"]=start,["finish"]=finish,["maximum_grade"]=maximumGrade,["width_minimum"]=3.5,["thickness"]=.55,["attachments"]=new A {contact}});
        }
    }
    private static A Rows(IEnumerable<Vector3[]> rows){var result=new A();foreach(var row in rows)result.Add(row);return result;}
}
