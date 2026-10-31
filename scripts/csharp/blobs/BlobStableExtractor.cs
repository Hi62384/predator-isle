using Godot;
using System;

namespace PredatorIsle.Blobs;

/// <summary>Conditions crossings before triangulation; final manifold normals belong to mesh integrity.</summary>
public partial class BlobStableExtractor : OrganicMeshExtractor
{
    public override int _edge(int first,int second)
    {
        int low=Math.Min(first,second),high=Math.Max(first,second);long key=(long)low*sample_count+high;if(edge_vertices.TryGetValue(key,out var cached))return cached.AsInt32();
        double a=field[low],b=field[high];float t=(float)Math.Clamp(a/(a-b),.035,.965);var point=_point(low).Lerp(_point(high),t);var normal=_gradient(low).Lerp(_gradient(high),t).Normalized();if(normal.LengthSquared()<.01)normal=Vector3.Up;
        int id=Vertices.Count;Vertices.Add(point);Normals.Add(normal);edge_vertices[key]=id;return id;
    }
    public override void _reconcile_normals() { /* Final oriented, area-weighted normals are computed once by mesh integrity. */ }
}
