using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using D=Godot.Collections.Dictionary;

namespace PredatorIsle.Blobs;

/// <summary>Actual-triangle manifold cleanup and deformation limits; repairs retain authored vertex positions.</summary>
public partial class BlobMeshIntegrity : RefCounted
{
    private static readonly string[] Attributes={"vertices","normals","colors","uvs","uvs2","feature_ids","anchors","mechanics","binds","chain_binds"};
    private static int Stride(string name)=>name is "anchors" or "mechanics" or "binds" or "chain_binds"?4:1;
    private static Vector2I Key(int a,int b)=>new(Math.Min(a,b),Math.Max(a,b));
    private static Vector2I[] Edges(int a,int b,int c)=>new[]{new Vector2I(a,b),new Vector2I(b,c),new Vector2I(c,a)};
    private static bool InRange(int a,int b,int c,int count)=>Math.Min(a,Math.Min(b,c))>=0&&Math.Max(a,Math.Max(b,c))<count;
    private static int Root(int[] parent,int i){while(parent[i]!=i)i=parent[i];return i;}
    public int _root(int[] parent,int i)=>Root(parent,i);
    public D clean(D mesh)=>clean(mesh,false);
    public D clean(D mesh,bool keepLargest)
    {
        for(int pass=0;pass<8;pass++)if(!collapse_tiny_edges(mesh))break;
        var vertices=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var kept=new List<int>();int degenerate=0,invalid=0;
        for(int i=0;i<indices.Length;i+=3)
        {
            int a=indices[i],b=indices[i+1],c=indices[i+2];if(!InRange(a,b,c,vertices.Length)||!vertices[a].IsFinite()||!vertices[b].IsFinite()||!vertices[c].IsFinite()){invalid++;continue;}
            if((vertices[b]-vertices[a]).Cross(vertices[c]-vertices[a]).LengthSquared()<1e-16){degenerate++;continue;}kept.Add(a);kept.Add(b);kept.Add(c);
        }
        mesh["indices"]=indices=kept.ToArray();var report=components(mesh);int omitted=0;
        if(keepLargest&&report["count"].AsInt32()>1)
        {
            int largest=report["largest"].AsInt32();var roots=report["roots"].AsInt32Array();kept.Clear();for(int i=0;i<indices.Length;i+=3)if(roots[indices[i]]==largest){kept.Add(indices[i]);kept.Add(indices[i+1]);kept.Add(indices[i+2]);}omitted=(indices.Length-kept.Count)/3;mesh["indices"]=kept.ToArray();
        }
        _compact(mesh);orient(mesh);int junctions=repair_t_junctions(mesh),repaired=seal_small_boundaries(mesh);recompute_normals(mesh);
        var edges=new Dictionary<Vector2I,List<bool>>();indices=mesh["indices"].AsInt32Array();
        for(int i=0;i<indices.Length;i+=3)foreach(var e in Edges(indices[i],indices[i+1],indices[i+2])){var key=Key(e.X,e.Y);if(!edges.TryGetValue(key,out var list))edges[key]=list=new();list.Add(e.X<e.Y);}
        int winding=0,boundaries=0,nonmanifold=0;foreach(var list in edges.Values){if(list.Count==1)boundaries++;else if(list.Count>2)nonmanifold++;else if(list[0]==list[1])winding++;}
        return new D{["t_junctions_repaired"]=junctions,["boundary_triangles_added"]=repaired,["degenerate_removed"]=degenerate,["invalid_removed"]=invalid,["components_before"]=report["count"],["isolated_triangles_removed"]=omitted,["boundary_edges"]=boundaries,["nonmanifold_edges"]=nonmanifold,["inconsistent_edges"]=winding,["triangles"]=indices.Length/3};
    }
    public D components(D mesh)
    {
        int count=mesh["vertices"].AsVector3Array().Length;var indices=mesh["indices"].AsInt32Array();var parent=new int[count];for(int i=0;i<count;i++)parent[i]=i;
        for(int i=0;i<indices.Length;i+=3){int a=Root(parent,indices[i]),b=Root(parent,indices[i+1]),c=Root(parent,indices[i+2]);parent[b]=a;parent[c]=a;}
        var roots=new int[count];var counts=new Dictionary<int,int>();foreach(int index in indices){int root=Root(parent,index);roots[index]=root;counts.TryGetValue(root,out int n);counts[root]=n+1;}
        int largest=-1,size=0;foreach(var p in counts)if(p.Value>size){largest=p.Key;size=p.Value;}return new D{["roots"]=roots,["count"]=counts.Count,["largest"]=largest};
    }
    private static T[] Select<T>(T[] source,IReadOnlyList<int> ids,int stride)
    {var result=new T[checked(ids.Count*stride)];for(int i=0;i<ids.Count;i++)System.Array.Copy(source,ids[i]*stride,result,i*stride,stride);return result;}
    private static Variant Select(Variant source,IReadOnlyList<int> ids,int stride)=>source.VariantType switch
    {
        Variant.Type.PackedVector3Array=>Select(source.AsVector3Array(),ids,stride),Variant.Type.PackedVector2Array=>Select(source.AsVector2Array(),ids,stride),
        Variant.Type.PackedColorArray=>Select(source.AsColorArray(),ids,stride),Variant.Type.PackedInt32Array=>Select(source.AsInt32Array(),ids,stride),
        Variant.Type.PackedFloat32Array=>Select(source.AsFloat32Array(),ids,stride),Variant.Type.PackedFloat64Array=>Select(source.AsFloat64Array(),ids,stride),
        _=>throw new ArgumentException("Unsupported anatomical vertex attribute: "+source.VariantType)
    };
    public void _compact(D mesh)
    {
        var indices=mesh["indices"].AsInt32Array();int count=mesh["vertices"].AsVector3Array().Length;var used=new HashSet<int>(indices);var ids=new List<int>();var lookup=new int[count];
        for(int i=0;i<count;i++)if(used.Contains(i)){lookup[i]=ids.Count;ids.Add(i);}for(int i=0;i<indices.Length;i++)indices[i]=lookup[indices[i]];mesh["indices"]=indices;
        foreach(string key in Attributes)if(mesh.TryGetValue(key,out var old))mesh[key]=Select(old,ids,Stride(key));
    }
    public void recompute_normals(D mesh)
    {
        var vertices=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var normals=new Vector3[vertices.Length];
        for(int i=0;i<indices.Length;i+=3){int a=indices[i],b=indices[i+1],c=indices[i+2];var n=-(vertices[b]-vertices[a]).Cross(vertices[c]-vertices[a]);normals[a]+=n;normals[b]+=n;normals[c]+=n;}
        for(int i=0;i<normals.Length;i++)normals[i]=normals[i].Normalized();mesh["normals"]=normals;
    }
    public D strain(D mesh,Vector3[] posed)=>strain(mesh,posed,System.Array.Empty<Vector3>());
    public D strain(D mesh,Vector3[] posed,Vector3[] expected)
    {
        var vertices=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();double maximum=0,minimumArea=double.PositiveInfinity,maximumArea=0;int inverted=0,collapsed=0;var suspects=new List<int>();
        for(int i=0;i<indices.Length;i+=3)
        {
            int a=indices[i],b=indices[i+1],c=indices[i+2];var old=(vertices[b]-vertices[a]).Cross(vertices[c]-vertices[a]);var current=(posed[b]-posed[a]).Cross(posed[c]-posed[a]);double area=current.Length()/Math.Max(old.Length(),1e-12);minimumArea=Math.Min(minimumArea,area);maximumArea=Math.Max(maximumArea,area);if(area<.05)collapsed++;
            foreach(var e in Edges(a,b,c))maximum=Math.Max(maximum,posed[e.X].DistanceTo(posed[e.Y])/Math.Max(vertices[e.X].DistanceTo(vertices[e.Y]),1e-8));
            if(expected.Length>0){var normal=expected.Length==indices.Length/3?expected[i/3]:expected[a]+expected[b]+expected[c];if(current.Dot(normal)>1e-10)inverted++;if(current.Dot(normal)>-.8*current.Length()*normal.Length())suspects.Add(i/3);}
        }
        return new D{["maximum_edge_stretch"]=maximum,["minimum_area_ratio"]=minimumArea,["maximum_area_ratio"]=maximumArea,["inverted"]=inverted,["collapsed"]=collapsed,["suspect_faces"]=suspects.ToArray()};
    }
    public void orient(D mesh)
    {
        var indices=mesh["indices"].AsInt32Array();var vertices=mesh["vertices"].AsVector3Array();var edges=new Dictionary<Vector2I,List<Vector2I>>();var adjacency=new Dictionary<int,List<(int Face,bool Same)>>();
        for(int face=0;face<indices.Length/3;face++)foreach(var e in Edges(indices[face*3],indices[face*3+1],indices[face*3+2])){var key=Key(e.X,e.Y);if(!edges.TryGetValue(key,out var list))edges[key]=list=new();list.Add(new Vector2I(face,e.X<e.Y?1:0));}
        foreach(var list in edges.Values)
        {
            if(list.Count!=2)continue;var a=list[0];var b=list[1];bool same=a.Y==b.Y;if(!adjacency.TryGetValue(a.X,out var aa))adjacency[a.X]=aa=new();if(!adjacency.TryGetValue(b.X,out var bb))adjacency[b.X]=bb=new();aa.Add((b.X,same));bb.Add((a.X,same));
        }
        var flips=new Dictionary<int,bool>();
        for(int seed=0;seed<indices.Length/3;seed++)
        {
            if(flips.ContainsKey(seed))continue;var queue=new List<int>{seed};flips[seed]=false;int cursor=0;
            while(cursor<queue.Count){int face=queue[cursor++];if(!adjacency.TryGetValue(face,out var connected))continue;foreach(var next in connected)if(!flips.ContainsKey(next.Face)){flips[next.Face]=flips[face]!=next.Same;queue.Add(next.Face);}}
            double volume=0;foreach(int face in queue){int a=indices[face*3],b=indices[face*3+1],c=indices[face*3+2];volume+=vertices[a].Dot(vertices[b].Cross(vertices[c]))*(flips[face]?-1.0:1.0);}
            foreach(int face in queue)if(flips[face]!=(volume>0)){int saved=indices[face*3+1];indices[face*3+1]=indices[face*3+2];indices[face*3+2]=saved;}
        }
        mesh["indices"]=indices;
    }
    public bool collapse_tiny_edges(D mesh)
    {
        var vertices=mesh["vertices"].AsVector3Array();var indices=mesh["indices"].AsInt32Array();var candidates=new List<int>();
        bool Tiny(int a,int b,int c,out double longest)
        {longest=0;if(!InRange(a,b,c,vertices.Length))return false;var x=vertices[a];var y=vertices[b];var z=vertices[c];longest=Math.Max(x.DistanceSquaredTo(y),Math.Max(y.DistanceSquaredTo(z),z.DistanceSquaredTo(x)));return (y-x).Cross(z-x).LengthSquared()<=Math.Max(1e-14,longest*longest*4e-6);}
        for(int i=0;i<indices.Length;i+=3)if(Tiny(indices[i],indices[i+1],indices[i+2],out _))candidates.Add(i);if(candidates.Count==0)return false;
        var parent=new int[vertices.Length];for(int i=0;i<parent.Length;i++)parent[i]=i;var neighbors=new Dictionary<int,HashSet<int>>();var faces=new Dictionary<Vector2I,int>();
        for(int i=0;i<indices.Length;i+=3)
        {
            if(!InRange(indices[i],indices[i+1],indices[i+2],vertices.Length))continue;
            foreach(var e in Edges(indices[i],indices[i+1],indices[i+2])){if(!neighbors.TryGetValue(e.X,out var aa))neighbors[e.X]=aa=new();if(!neighbors.TryGetValue(e.Y,out var bb))neighbors[e.Y]=bb=new();aa.Add(e.Y);bb.Add(e.X);var key=Key(e.X,e.Y);faces.TryGetValue(key,out int n);faces[key]=n+1;}
        }
        bool changed=false;var locked=new HashSet<int>();
        foreach(int i in candidates)
        {
            int a=indices[i],b=indices[i+1],c=indices[i+2];if(!Tiny(a,b,c,out double longest))continue;double shortest=double.PositiveInfinity;var selected=new Vector2I(a,b);
            foreach(var e in Edges(a,b,c)){double distance=vertices[e.X].DistanceSquaredTo(vertices[e.Y]);if(distance<shortest){shortest=distance;selected=e;}}
            if(shortest>=Math.Max(1e-8,longest*.0025)||locked.Contains(selected.X)||locked.Contains(selected.Y))continue;int common=0;foreach(int id in neighbors[selected.X])if(neighbors[selected.Y].Contains(id))common++;
            faces.TryGetValue(Key(selected.X,selected.Y),out int incidence);if(!((incidence==2&&common==2)||(incidence==1&&common==1)))continue;bool adjacentLocked=false;foreach(int id in neighbors[selected.X])if(locked.Contains(id)){adjacentLocked=true;break;}if(adjacentLocked)continue;
            changed=true;parent[selected.Y]=selected.X;locked.Add(selected.X);locked.Add(selected.Y);foreach(int id in neighbors[selected.X])locked.Add(id);foreach(int id in neighbors[selected.Y])locked.Add(id);
        }
        for(int i=0;i<indices.Length;i++)if(indices[i]>=0&&indices[i]<parent.Length)indices[i]=Root(parent,indices[i]);mesh["indices"]=indices;return changed;
    }
    private readonly record struct BoundaryEdge(int A,int B,int Face);
    public int repair_t_junctions(D mesh)
    {
        int repaired=0;var vertices=mesh["vertices"].AsVector3Array();
        for(int pass=0;pass<4;pass++)
        {
            var indices=mesh["indices"].AsInt32Array();var edges=new Dictionary<Vector2I,List<BoundaryEdge>>();
            for(int i=0;i<indices.Length;i+=3)foreach(var e in Edges(indices[i],indices[i+1],indices[i+2])){var key=Key(e.X,e.Y);if(!edges.TryGetValue(key,out var list))edges[key]=list=new();list.Add(new BoundaryEdge(e.X,e.Y,i/3));}
            var boundary=new List<BoundaryEdge>();var seen=new HashSet<int>();var boundaryVertices=new List<int>();
            foreach(var list in edges.Values){if(list.Count!=1)continue;var edge=list[0];boundary.Add(edge);if(seen.Add(edge.A))boundaryVertices.Add(edge.A);if(seen.Add(edge.B))boundaryVertices.Add(edge.B);}
            var changes=new Dictionary<int,int[]>();
            foreach(var edge in boundary)
            {
                if(changes.ContainsKey(edge.Face))continue;var a=vertices[edge.A];var b=vertices[edge.B];var line=b-a;int third=indices[edge.Face*3];for(int k=0;k<3;k++){int id=indices[edge.Face*3+k];if(id!=edge.A&&id!=edge.B)third=id;}
                int best=-1;double error=1e-10;
                foreach(int id in boundaryVertices){if(id==edge.A||id==edge.B||id==third)continue;var p=vertices[id];double t=Math.Clamp((p-a).Dot(line)/Math.Max(line.LengthSquared(),1e-12),0,1);if(t<.00001||t>.99999)continue;double distance=p.DistanceSquaredTo(a+line*(float)t);if(distance<error){best=id;error=distance;}}
                if(best>=0){changes[edge.Face]=new[]{edge.A,best,third,best,edge.B,third};repaired++;}
            }
            if(changes.Count==0)break;var output=new List<int>();for(int face=0;face<indices.Length/3;face++)if(changes.TryGetValue(face,out var changed))output.AddRange(changed);else{output.Add(indices[face*3]);output.Add(indices[face*3+1]);output.Add(indices[face*3+2]);}mesh["indices"]=output.ToArray();
        }
        return repaired;
    }
    private static T[] Append<T>(T[] values,int first,int stride){int length=values.Length;System.Array.Resize(ref values,length+stride);System.Array.Copy(values,first*stride,values,length,stride);return values;}
    private static Variant Append(Variant value,int first,int stride)=>value.VariantType switch
    {
        Variant.Type.PackedVector3Array=>Append(value.AsVector3Array(),first,stride),Variant.Type.PackedVector2Array=>Append(value.AsVector2Array(),first,stride),Variant.Type.PackedColorArray=>Append(value.AsColorArray(),first,stride),Variant.Type.PackedInt32Array=>Append(value.AsInt32Array(),first,stride),Variant.Type.PackedFloat32Array=>Append(value.AsFloat32Array(),first,stride),Variant.Type.PackedFloat64Array=>Append(value.AsFloat64Array(),first,stride),_=>throw new ArgumentException("Unsupported anatomical boundary attribute.")
    };
    public int seal_small_boundaries(D mesh)
    {
        var indices=new List<int>(mesh["indices"].AsInt32Array());var vertices=new List<Vector3>(mesh["vertices"].AsVector3Array());var edges=new Dictionary<Vector2I,List<Vector2I>>();
        for(int i=0;i<indices.Count;i+=3)foreach(var e in Edges(indices[i],indices[i+1],indices[i+2])){var key=Key(e.X,e.Y);if(!edges.TryGetValue(key,out var list))edges[key]=list=new();list.Add(e);}
        var following=new Dictionary<int,int>();foreach(var list in edges.Values)if(list.Count==1)following[list[0].X]=list[0].Y;var visited=new HashSet<int>();int added=0;
        foreach(int start in following.Keys)
        {
            if(visited.Contains(start))continue;var loop=new List<int>();int vertex=start;double perimeter=0;
            while(following.TryGetValue(vertex,out int next)&&!visited.Contains(vertex)&&loop.Count<32){visited.Add(vertex);loop.Add(vertex);perimeter+=vertices[vertex].DistanceTo(vertices[next]);vertex=next;}
            if(vertex!=start||loop.Count<3||perimeter>.25)continue;var center=Vector3.Zero;foreach(int id in loop)center+=vertices[id];center/=loop.Count;var area=Vector3.Zero;for(int i=0;i<loop.Count;i++)area+=(vertices[loop[i]]-center).Cross(vertices[loop[(i+1)%loop.Count]]-center);if(area.Length()<1e-7)continue;
            int centerIndex=vertices.Count;vertices.Add(center);foreach(string key in Attributes){if(key=="vertices"||!mesh.TryGetValue(key,out var value))continue;mesh[key]=Append(value,loop[0],Stride(key));}
            for(int i=0;i<loop.Count;i++){indices.Add(loop[(i+1)%loop.Count]);indices.Add(loop[i]);indices.Add(centerIndex);added++;}
        }
        mesh["vertices"]=vertices.ToArray();mesh["indices"]=indices.ToArray();return added;
    }
}
