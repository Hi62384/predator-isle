using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

/// <summary>Fine visual edges follow the actual coarse polyline; gameplay ground remains canonical.</summary>
public static class TerrainRingTransitions
{
    public sealed record Result(TerrainRingMeshGeometry.Data[] Meshes,int StitchedVertices,double MaximumHeightAdjustment);
    /// <summary>Worker-owned memoization, retained for the last cut only. No mesh content hashing.</summary>
    public sealed class Cache
    {
        internal Dictionary<string,(TerrainRingMeshGeometry.Data Data,int Count,double Adjustment)> Entries=new();
        public long Hits{get;internal set;}
        public long Misses{get;internal set;}
        public void Clear()=>Entries.Clear();
    }
    private sealed class Working
    {
        public TerrainRingMeshGeometry.Data Data;
        public readonly Vector3[] Vertices,Normals;
        public Working(TerrainRingMeshGeometry.Data data,bool mutable=true)
        {
            if(data.Products is TerrainVertexProducts products){Vertices=mutable?(Vector3[])products.Vertices.Clone():products.Vertices;Normals=mutable?(Vector3[])products.Normals.Clone():products.Normals;Data=mutable?data with{Products=products with{Vertices=Vertices,Normals=Normals},Arrays=null!}:data;}
            else{Data=data with{Arrays=data.Arrays.Duplicate()};Vertices=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();Normals=data.Arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();}
        }
        public void Publish(){if(Data.Products is not null)return;Data.Arrays[(int)Mesh.ArrayType.Vertex]=Vertices;Data.Arrays[(int)Mesh.ArrayType.Normal]=Normals;}
    }
    public static Result Stitch(TerrainRingLayout.Plan plan,IEnumerable<TerrainRingMeshGeometry.Data> source,Func<bool>? cancelled=null,Cache? cache=null,bool gpuPages=false)
    {
        var originals=source.ToDictionary(m=>m.Patch.Key);var final=new Dictionary<Vector3I,TerrainRingMeshGeometry.Data>();var meshes=new Dictionary<Vector3I,Working>();var next=new Dictionary<string,(TerrainRingMeshGeometry.Data Data,int Count,double Adjustment)>();
        foreach(var patch in plan.Patches)if(!originals.TryGetValue(patch.Key,out var value)||value.Patch!=patch)throw new InvalidOperationException("A complete, matching ring cut is required before stitching.");int stitched=0;double maxAdjustment=0,epsilon=plan.BaseSize*.0001;
        // Coarser rings are finalized first, so a corner shared by three levels has one height.
        foreach(var patch in plan.Patches.OrderByDescending(p=>p.Key.Z))
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            var original=originals[patch.Key];int row=original.Topology.Axis.Length;var visits=new List<(int Index,TerrainRingLayout.Patch Owner)>();
            for(int i=0;i<row;i++)
            {
                Find(i,0,-epsilon);Find((row-1)*row+i,0,epsilon);Find(i*row,-epsilon,0);Find(i*row+row-1,epsilon,0);
            }
            // Boundary identities include finalized coarse edges, so corner dependencies propagate.
            // The raw product identity also invalidates water, materials, sidecars and collision.
            string key=original.ProductRevision+":"+gpuPages+":"+string.Join(",",visits.Select(v=>v.Owner.Key).Distinct().OrderBy(k=>k.Z).ThenBy(k=>k.Y).ThenBy(k=>k.X).Select(k=>final[k].ProductRevision));
            if(cache is not null&&cache.Entries.TryGetValue(key,out var saved))
            {cache.Hits++;next[key]=saved;final[patch.Key]=saved.Data;stitched+=saved.Count;maxAdjustment=Math.Max(maxAdjustment,saved.Adjustment);continue;}
            if(cache is not null)cache.Misses++;
            var resolved=new Dictionary<int,(float Height,Vector3 Normal)>();Working? mesh=null;double adjustment=0;
            if(visits.Count>0)
            {
                mesh=new Working(original);
                foreach(var visit in visits)
                {
                    var vertex=mesh.Vertices[visit.Index];var owner=visit.Owner;
                    if(!meshes.TryGetValue(owner.Key,out var coarse))meshes[owner.Key]=coarse=new Working(final[owner.Key],false);
                    var value=SampleEdge(coarse,patch.OriginX+vertex.X,patch.OriginZ+vertex.Z);
                    if(resolved.TryGetValue(visit.Index,out var prior)&&Math.Abs((double)prior.Height-value.Height)>1e-4)throw new InvalidOperationException("Coarse ring corner heights disagree; the cut must remain hidden.");resolved[visit.Index]=value;
                }
                foreach(var pair in resolved){int i=pair.Key;adjustment=Math.Max(adjustment,Math.Abs((double)mesh.Vertices[i].Y-pair.Value.Height));var position=mesh.Vertices[i];position.Y=pair.Value.Height;mesh.Vertices[i]=position;mesh.Normals[i]=pair.Value.Normal;}mesh.Publish();
            }
            var data=mesh is null?original:mesh.Data with{ProductRevision=TerrainRingMeshGeometry.Data.NewRevision()};
            data=data with{GeometryFingerprint=data.ProductRevision.ToString(System.Globalization.CultureInfo.InvariantCulture)};
            data=data with{LocalWater=TerrainRingWater.Build(data,data.WaterLevel,data.BeachesEnabled,data.WaterEnabled)};
            if(gpuPages)data=data with{GpuPage=data.Products is not null?TerrainGpuGridPage.Create(data.Products,row):TerrainGpuGridPage.Create(data.Arrays,row)};
            final[patch.Key]=data;next[key]=(data,resolved.Count,adjustment);stitched+=resolved.Count;maxAdjustment=Math.Max(maxAdjustment,adjustment);
            void Find(int index,double dx,double dz)
            {
                if(patch.Key.Z>=plan.OuterRings)return;var axis=original.Topology.Axis.Span;double x=patch.OriginX+patch.Size*axis[index%row]/original.Topology.Denominator,z=patch.OriginZ+patch.Size*axis[index/row]/original.Topology.Denominator;
                // Probe the open edge, including at its endpoint. A half-open corner
                // otherwise selects a diagonal tile, which need not be an edge neighbor.
                double px=dx==0?Math.Clamp(x,patch.OriginX+epsilon,patch.OriginX+patch.Size-epsilon):x+dx,pz=dz==0?Math.Clamp(z,patch.OriginZ+epsilon,patch.OriginZ+patch.Size-epsilon):z+dz;
                var owner=plan.Owner(px,pz);if(owner is null||owner.Value.Key.Z<=patch.Key.Z)return;if(owner.Value.Key.Z!=patch.Key.Z+1)throw new InvalidOperationException($"Adjacent terrain ring boundaries must differ by exactly one ternary level: {patch.Key} -> {owner.Value.Key}.");visits.Add((index,owner.Value));
            }
        }
        if(cache is not null)cache.Entries=next;return new Result(plan.Patches.Select(p=>final[p.Key]).ToArray(),stitched,maxAdjustment);
    }
    private static (float Height,Vector3 Normal) SampleEdge(Working mesh,double worldX,double worldZ)
    {
        var patch=mesh.Data.Patch;var grid=mesh.Data.Topology;double ux=(worldX-patch.OriginX)/patch.Size*grid.Denominator,uz=(worldZ-patch.OriginZ)/patch.Size*grid.Denominator;var axis=grid.Axis.Span;int x=Segment(axis,ux),z=Segment(axis,uz),row=axis.Length;double tx=Math.Clamp((ux-axis[x])/(axis[x+1]-axis[x]),0,1),tz=Math.Clamp((uz-axis[z])/(axis[z+1]-axis[z]),0,1);
        if(tx>1e-8&&tx<1-1e-8&&tz>1e-8&&tz<1-1e-8)throw new InvalidOperationException("A ring edge must lie on a coarse grid line.");int a=z*row+x,b=a+1,c=a+row,d=c+1;double h0=mesh.Vertices[a].Y+((double)mesh.Vertices[b].Y-mesh.Vertices[a].Y)*tx,h1=mesh.Vertices[c].Y+((double)mesh.Vertices[d].Y-mesh.Vertices[c].Y)*tx;var normal=mesh.Normals[a].Lerp(mesh.Normals[b],(float)tx).Lerp(mesh.Normals[c].Lerp(mesh.Normals[d],(float)tx),(float)tz).Normalized();return ((float)(h0+(h1-h0)*tz),normal);
    }
    private static int Segment(ReadOnlySpan<int> axis,double coordinate)
    {
        if(coordinate<axis[0]-1e-6||coordinate>axis[^1]+1e-6)throw new ArgumentOutOfRangeException(nameof(coordinate),"A seam sample escaped its coarse owner.");int low=0,high=axis.Length-1;while(high-low>1){int mid=(low+high)/2;if(axis[mid]<=coordinate)low=mid;else high=mid;}return Math.Min(low,axis.Length-2);
    }
}
