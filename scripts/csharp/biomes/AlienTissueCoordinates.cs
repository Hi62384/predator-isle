using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Biomes;
public partial class AlienTissueCoordinates : RefCounted
{
    private readonly record struct Paths(Vector2[][] Trunks,Vector3I[] Labels);
    private readonly record struct Projection(Vector2[] Path,Vector3I Label,Vector2 First,Vector2 Last,double Nearest,double Second);
    private static double Smooth(double a,double b,double value){double t=Math.Clamp((value-a)/(b-a),0,1);return t*t*(3-2*t);}
    private static double Scale(GodotObject field)=>field.Get("settings").AsGodotObject().Get("feature_scale").AsDouble();
    private static Vector2 Segment(GodotObject field,Vector2 p,Vector2 a,Vector2 b)=>field is BiomeExtensionSampler native?native.segment(p,a,b):field.Call("segment",p,a,b).AsVector2();
    private static Paths GetPaths(GodotObject field,Vector2 p,double scale,bool tiled)
    {
        double span=4096*scale;var parent=new Vector2I((int)Math.Floor(p.X/span),(int)Math.Floor(p.Y/span));
        if(tiled)
        {
            if(field is AlienInfectedSampler native){var tile=native.QueryTile(p,parent);return new Paths(tile.Trunks,tile.Labels);}
            var data=field.Call("query_tile",p,parent).AsGodotDictionary();return new Paths(data["trunks"].AsGodotArray().Select(v=>v.AsVector2Array()).ToArray(),data["labels"].AsGodotArray().Select(v=>v.AsVector3I()).ToArray());
        }
        var paths=new List<Vector2[]>();var labels=new List<Vector3I>();
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)
        {
            var cell=parent+new Vector2I(x,z);var edges=field is AlienInfectedSampler current?current.network_edges(cell):field.Call("network_edges",cell).AsVector2Array();
            for(int edge=0;edge<2;edge++){paths.Add(new[]{edges[edge*4],edges[edge*4+1],edges[edge*4+2]});labels.Add(new Vector3I(cell.X,cell.Y,edge));}
        }
        return new Paths(paths.ToArray(),labels.ToArray());
    }
    private static Projection Project(GodotObject field,Vector2 p,Paths paths)
    {
        double nearest=double.PositiveInfinity,second=double.PositiveInfinity;int chosen=-1;var a=Vector2.Zero;var b=Vector2.Zero;
        for(int i=0;i<paths.Trunks.Length;i++)
        {
            var path=paths.Trunks[i];var first=Segment(field,p,path[0],path[1]);var last=Segment(field,p,path[1],path[2]);double distance=Math.Min(first.X,last.X);
            if(distance<nearest){second=Math.Min(second,nearest);nearest=distance;chosen=i;a=first;b=last;}else second=Math.Min(second,distance);
        }
        if(chosen<0)throw new InvalidOperationException("Alien material projection has no finite path");return new Projection(paths.Trunks[chosen],paths.Labels[chosen],a,b,nearest,second);
    }
    private static (double Arc,double Across,Vector2 Tangent,double Node,double Bend) Coordinates(Vector2 p,Projection projection)
    {
        var path=projection.Path;bool first=projection.First.X<=projection.Last.X;var start=first?path[0]:path[1];var end=first?path[1]:path[2];var tangent=(end-start).Normalized();var foot=start.Lerp(end,first?projection.First.Y:projection.Last.Y);
        double arc=first?start.DistanceTo(foot):(double)path[0].DistanceTo(path[1])+start.DistanceTo(foot),across=projection.Nearest*Math.Sign(tangent.Cross(p-foot));return(arc,across,tangent,Math.Min(p.DistanceTo(path[0]),p.DistanceTo(path[2])),p.DistanceTo(path[1]));
    }
    private static double Weight(Projection projection,double scale,double node,double bend)=>(1-Smooth(120*scale,300*scale,projection.Nearest))*Smooth(10*scale,80*scale,Math.Max(0,projection.Second-projection.Nearest))*Smooth(12*scale,80*scale,node)*Smooth(12*scale,80*scale,bend);
    public D sample(GodotObject field,Vector2 p)=>sample(field,p,true);
    public D sample(GodotObject field,Vector2 p,bool tiled)
    {
        double scale=Scale(field);var projection=Project(field,p,GetPaths(field,p,scale,tiled));var coordinates=Coordinates(p,projection);
        return new D {["path"]=projection.Label,["arc_metres"]=coordinates.Arc,["across_metres"]=coordinates.Across,["tangent"]=coordinates.Tangent,["node_distance"]=coordinates.Node,["bend_distance"]=coordinates.Bend,["weight"]=Weight(projection,scale,coordinates.Node,coordinates.Bend),["distance"]=projection.Nearest};
    }
    private static Vector4 Packed(GodotObject field,Vector2 p,double scale,Func<Vector3I,int> identity)
    {
        var projection=Project(field,p,GetPaths(field,p,scale,true));if(projection.Nearest>=300*scale)return Vector4.Zero;var coordinates=Coordinates(p,projection);double weight=Weight(projection,scale,coordinates.Node,coordinates.Bend);if(weight<=0)return Vector4.Zero;
        return new Vector4((float)coordinates.Arc,(float)coordinates.Across,(float)weight,identity(projection.Label));
    }
    public Vector4 packed_sample(GodotObject field,Vector2 p,D ids)=>Packed(field,p,Scale(field),label=>{if(!ids.ContainsKey(label))ids[label]=ids.Count+1;return ids[label].AsInt32();});
    public D atlas(GodotObject field,Vector2 origin,double span,long resolution)
    {int cells=(int)Math.Min(resolution,Math.Max(1,Math.Ceiling(span/8)));return rectangle(field,origin,Vector2.One*(float)span,new Vector2I(cells,cells));}
    public D rectangle(GodotObject field,Vector2 origin,Vector2 span,Vector2I cells)
    {
        int columns=cells.X+1,rows=cells.Y+1;var pixels=new float[columns*rows*4];var ids=new Dictionary<Vector3I,int>();bool nonzero=false;double scale=Scale(field);
        Func<Vector3I,int> identity=label=>{if(!ids.TryGetValue(label,out int id)){id=ids.Count+1;ids[label]=id;}return id;};
        for(int z=0;z<rows;z++)for(int x=0;x<columns;x++)
        {
            var p=origin+new Vector2(x,z)*(span/(Vector2)cells);var value=Packed(field,p,scale,identity);if(value.W<=0)continue;int offset=(z*columns+x)*4;pixels[offset]=value.X;pixels[offset+1]=value.Y;pixels[offset+2]=value.Z;pixels[offset+3]=value.W;nonzero=true;
        }
        var bytes=nonzero?new byte[pixels.Length*sizeof(float)]:System.Array.Empty<byte>();if(nonzero)Buffer.BlockCopy(pixels,0,bytes,0,bytes.Length);return new D {["data"]=bytes,["columns"]=nonzero?columns:0,["rows"]=nonzero?rows:0};
    }
    public D structure_atlas(GodotObject builder,A arrays,Vector2 origin)
    {
        if(arrays.Count==0||!builder.Get("settings").AsGodotObject().Get("alien_infected").AsGodotObject().Get("nerve_flow_texturing").AsBool())return new();var vertices=arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();if(vertices.Length==0)return new();var minimum=Vector2.Inf;var maximum=-Vector2.Inf;
        foreach(var vertex in vertices){var p=new Vector2(vertex.X,vertex.Z);minimum=minimum.Min(p);maximum=maximum.Max(p);}var offset=(minimum/8).Floor()*8-new Vector2(8,8);var span=(maximum/8).Ceil()*8+new Vector2(8,8)-offset;var cells=new Vector2I(Math.Clamp((int)Math.Ceiling(span.X/8.0),1,128),Math.Clamp((int)Math.Ceiling(span.Y/8.0),1,128));var result=rectangle(builder.Get("_extras").AsGodotArray()[7].AsGodotObject(),origin+offset,span,cells);if(result["data"].AsByteArray().Length==0)return new();result["offset"]=offset;result["span"]=span;return result;
    }
}
