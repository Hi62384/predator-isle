using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

/// <summary>Fine visual edges follow the actual coarse polyline; gameplay ground remains canonical.</summary>
public static class TerrainRingTransitions
{
    public sealed record Result(TerrainRingMeshGeometry.Data[] Meshes,int StitchedVertices,double MaximumHeightAdjustment);
    private sealed class Working
    {
        public TerrainRingMeshGeometry.Data Data;
        public readonly Vector3[] Vertices,Normals;
        public Working(TerrainRingMeshGeometry.Data data){Data=data with{Arrays=data.Arrays.Duplicate()};Vertices=data.Arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();Normals=data.Arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();}
        public void Publish(){Data.Arrays[(int)Mesh.ArrayType.Vertex]=Vertices;Data.Arrays[(int)Mesh.ArrayType.Normal]=Normals;}
    }
    public static Result Stitch(TerrainRingLayout.Plan plan,IEnumerable<TerrainRingMeshGeometry.Data> source,Func<bool>? cancelled=null)
    {
        var meshes=source.ToDictionary(m=>m.Patch.Key,m=>new Working(m));foreach(var patch in plan.Patches)if(!meshes.TryGetValue(patch.Key,out var value)||value.Data.Patch!=patch)throw new InvalidOperationException("A complete, matching ring cut is required before stitching.");int stitched=0;double maxAdjustment=0,epsilon=plan.BaseSize*.0001;
        // Coarser rings are finalized first, so a corner shared by three levels has one height.
        foreach(var patch in plan.Patches.OrderByDescending(p=>p.Key.Z))
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            if(patch.Key.Z>=plan.OuterRings)continue;var mesh=meshes[patch.Key];int row=mesh.Data.Topology.Axis.Length;var resolved=new Dictionary<int,(float Height,Vector3 Normal)>();
            for(int i=0;i<row;i++)
            {
                Visit(i,0,-epsilon);Visit((row-1)*row+i,0,epsilon);Visit(i*row,-epsilon,0);Visit(i*row+row-1,epsilon,0);
            }
            foreach(var pair in resolved){int i=pair.Key;maxAdjustment=Math.Max(maxAdjustment,Math.Abs((double)mesh.Vertices[i].Y-pair.Value.Height));var position=mesh.Vertices[i];position.Y=pair.Value.Height;mesh.Vertices[i]=position;mesh.Normals[i]=pair.Value.Normal;stitched++;}mesh.Publish();
            void Visit(int index,double dx,double dz)
            {
                var vertex=mesh.Vertices[index];double x=patch.OriginX+vertex.X,z=patch.OriginZ+vertex.Z;
                // Probe the open edge, including at its endpoint. A half-open corner
                // otherwise selects a diagonal tile, which need not be an edge neighbor.
                double px=dx==0?Math.Clamp(x,patch.OriginX+epsilon,patch.OriginX+patch.Size-epsilon):x+dx,pz=dz==0?Math.Clamp(z,patch.OriginZ+epsilon,patch.OriginZ+patch.Size-epsilon):z+dz;
                var owner=plan.Owner(px,pz);if(owner is null||owner.Value.Key.Z<=patch.Key.Z)return;if(owner.Value.Key.Z!=patch.Key.Z+1)throw new InvalidOperationException($"Adjacent terrain ring boundaries must differ by exactly one ternary level: {patch.Key} -> {owner.Value.Key}.");var coarse=meshes[owner.Value.Key];var value=SampleEdge(coarse,x,z);if(resolved.TryGetValue(index,out var prior)&&Math.Abs((double)prior.Height-value.Height)>1e-4)throw new InvalidOperationException("Coarse ring corner heights disagree; the cut must remain hidden.");resolved[index]=value;
            }
        }
        foreach(var mesh in meshes.Values)mesh.Publish();return new Result(plan.Patches.Select(p=>meshes[p.Key].Data).ToArray(),stitched,maxAdjustment);
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
