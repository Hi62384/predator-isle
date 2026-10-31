using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>Reusable masked grids. Third boundaries are explicit knots rather than rounded cell cuts.</summary>
public sealed class TerrainRingTopology
{
    public sealed record Grid(int Denominator,ReadOnlyMemory<int> Axis,ReadOnlyMemory<int> Indices)
    {
        public int VertexCount=>checked(Axis.Length*Axis.Length);
    }
    private readonly record struct Key(int Resolution,bool Thirds,TerrainRingLayout.Mask Hole);
    private readonly Dictionary<Key,Grid> entries=new();
    private readonly Queue<Key> order=new();
    private readonly object sync=new();
    private long residentBytes;
    public int Capacity{get;}
    public long ByteBudget{get;}
    public TerrainRingTopology(int capacity=256,long byteBudget=16L*1024*1024){if(capacity<1||byteBudget<2L*1024*1024)throw new ArgumentOutOfRangeException(nameof(capacity));Capacity=capacity;ByteBudget=byteBudget;}
    public Grid Get(int resolution,bool thirds,TerrainRingLayout.Mask hole)
    {
        if(resolution<1||resolution>256)throw new ArgumentOutOfRangeException(nameof(resolution));if(hole.Full)throw new ArgumentException("Fully masked patches must be omitted by the ring planner.");if(!hole.Empty&&!thirds)throw new ArgumentException("Masked ring grids require third-boundary knots.");
        if(hole.Empty)hole=TerrainRingLayout.Mask.None;var key=new Key(resolution,thirds,hole);lock(sync){if(entries.TryGetValue(key,out var cached))return cached;int denominator=checked(resolution*3);var knots=new SortedSet<int>();for(int i=0;i<=resolution;i++)knots.Add(i*3);if(thirds){knots.Add(resolution);knots.Add(resolution*2);}var axis=new int[knots.Count];knots.CopyTo(axis);var triangles=new List<int>(resolution*resolution*6);int stride=axis.Length;
            for(int z=0;z<stride-1;z++)for(int x=0;x<stride-1;x++)
            {
                // Every mask edge is a grid line; no triangle straddles finer ownership.
                bool masked=!hole.Empty&&axis[x]>=hole.MinX*resolution&&axis[x+1]<=hole.MaxX*resolution&&axis[z]>=hole.MinZ*resolution&&axis[z+1]<=hole.MaxZ*resolution;if(masked)continue;int a=z*stride+x,b=a+1,c=a+stride,d=c+1;triangles.Add(a);triangles.Add(b);triangles.Add(c);triangles.Add(b);triangles.Add(d);triangles.Add(c);
            }
            var result=new Grid(denominator,axis,triangles.ToArray());long bytes=Bytes(result);while((entries.Count>=Capacity||residentBytes+bytes>ByteBudget)&&order.TryDequeue(out var oldest))if(entries.Remove(oldest,out var removed))residentBytes-=Bytes(removed);entries[key]=result;residentBytes+=bytes;order.Enqueue(key);return result;}
    }
    private static long Bytes(Grid grid)=>((long)grid.Axis.Length+grid.Indices.Length)*sizeof(int);
}
