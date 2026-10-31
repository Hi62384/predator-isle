using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using A=Godot.Collections.Array;
using S=PredatorIsle.Terrain.StructureGeometryAccess;

namespace PredatorIsle.Terrain;

/// <summary>Adaptive roof bands retaining every original apron and shoulder contact cell.</summary>
public partial class AlienConduitContactLod : RefCounted
{
    public Vector3[] proposed_triangle(Vector3 a,Vector3 b,Vector3 c)=>new[]{a,b,c};
    private static void Quad(List<Vector3[]> faces,Vector3 a,Vector3 b,Vector3 c,Vector3 d){faces.Add(new[]{a,b,c});faces.Add(new[]{a,c,d});}
    private static bool Valid(IEnumerable<Vector3[]> faces)=>faces.All(f=>(f[2]-f[0]).Cross(f[1]-f[0]).Y>.00000001);
    public bool winding_valid(A faces)=>Valid(faces.Select(f=>f.AsVector3Array()));
    private static List<Vector3[]> Proposal(IReadOnlyList<Vector3[]> rings,int low,int high,int left,int right)
    {
        var faces=new List<Vector3[]>();for(int c=left+1;c<right-1;c++)Quad(faces,rings[low][c],rings[low][c+1],rings[high][c+1],rings[high][c]);
        for(int row=low;row<high;row++){faces.Add(new[]{rings[row][left],rings[low][left+1],rings[row+1][left]});faces.Add(new[]{rings[low][right-1],rings[row][right],rings[row+1][right]});}
        faces.Add(new[]{rings[high][left],rings[low][left+1],rings[high][left+1]});faces.Add(new[]{rings[low][right-1],rings[high][right],rings[high][right-1]});return faces;
    }
    private static List<Vector3[]> Select(IReadOnlyList<Vector3[]> rings,int low,int high)
    {
        if(high-low==1){var original=new List<Vector3[]>();for(int c=3;c<11;c++)Quad(original,rings[low][c],rings[low][c+1],rings[high][c+1],rings[high][c]);return original;}
        var wide=Proposal(rings,low,high,3,11);if(Valid(wide))return wide;int middle=(low+high)/2;var faces=Select(rings,low,middle);faces.AddRange(Select(rings,middle,high));var narrow=Proposal(rings,low,high,5,9);
        if(Valid(narrow)){for(int row=low;row<high;row++)foreach(int c in new[]{3,4,9,10})Quad(narrow,rings[row][c],rings[row][c+1],rings[row+1][c+1],rings[row+1][c]);if(narrow.Count<faces.Count)return narrow;}return faces;
    }
    public A core_proposal(A rings,int low,int high,int left,int right)=>Payload(Proposal(rings.Select(r=>r.AsVector3Array()).ToArray(),low,high,left,right));
    public A select_core_faces(A rings,int low,int high)=>Payload(Select(rings.Select(r=>r.AsVector3Array()).ToArray(),low,high));
    private static A Payload(IEnumerable<Vector3[]> faces){var result=new A();foreach(var f in faces)result.Add(f);return result;}
    public void triangulate(GodotObject g,A rings,Color color,int stride)=>Triangulate(g,rings.Select(r=>r.AsVector3Array()).ToArray(),color,stride);
    internal void Triangulate(GodotObject g,IReadOnlyList<Vector3[]> rings,Color color,int stride)
    {
        if(stride<=0)throw new ArgumentOutOfRangeException(nameof(stride));
        int segments=rings.Count-1;var selected=new List<int>();for(int row=0;row<segments;row+=stride)selected.Add(row);selected.Add(segments);
        for(int interval=0;interval<selected.Count-1;interval++){int low=selected[interval],high=selected[interval+1];for(int row=low;row<high;row++)foreach(int c in new[]{0,1,2,11,12,13})S.Quad(g,rings[row][c],rings[row][c+1],rings[row+1][c+1],rings[row+1][c],color);foreach(var face in Select(rings,low,high))S.Triangle(g,face[0],face[1],face[2],color);}
    }
}
