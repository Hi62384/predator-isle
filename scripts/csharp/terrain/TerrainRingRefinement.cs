using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

/// <summary>Local ternary refinement for cave-support columns and collision-relevant geological features.</summary>
public static class TerrainRingRefinement
{
    private readonly record struct Rect(double X,double Z,double Size)
    {
        public bool Intersects(Rect2 other)=>X<other.End.X&&X+Size>other.Position.X&&Z<other.End.Y&&Z+Size>other.Position.Y;
        public bool Adjacent(Rect other)=>((X+Size==other.X||other.X+other.Size==X)&&Math.Max(Z,other.Z)<Math.Min(Z+Size,other.Z+other.Size))||((Z+Size==other.Z||other.Z+other.Size==Z)&&Math.Max(X,other.X)<Math.Min(X+Size,other.X+other.Size));
    }
    private static Rect[] Owned(TerrainRingLayout.Patch patch)
    {
        if(patch.Hole.Empty)return new[]{new Rect(patch.OriginX,patch.OriginZ,patch.Size)};var result=new List<Rect>(8);double size=patch.Size/3;for(int z=0;z<3;z++)for(int x=0;x<3;x++)if(x<patch.Hole.MinX||x>=patch.Hole.MaxX||z<patch.Hole.MinZ||z>=patch.Hole.MaxZ)result.Add(new Rect(patch.OriginX+x*size,patch.OriginZ+z*size,size));return result.ToArray();
    }
    public static TerrainRingLayout.Plan Apply(TerrainRingLayout.Plan plan,IReadOnlyCollection<Rect2> detailRegions,int maximumPatches=4096)
    {
        if(maximumPatches<plan.Patches.Length)throw new ArgumentOutOfRangeException(nameof(maximumPatches));foreach(var region in detailRegions)if(!region.Position.IsFinite()||!region.Size.IsFinite()||region.Size.X<=0||region.Size.Y<=0)throw new ArgumentException("Refinement regions must have finite, positive extents.");if(detailRegions.Count==0)return plan;var patches=plan.Patches.ToDictionary(p=>p.Key);
        while(true)
        {
            var split=new HashSet<Vector3I>();foreach(var patch in patches.Values)if(patch.Key.Z>0&&Owned(patch).Any(rect=>detailRegions.Any(region=>rect.Intersects(region))))split.Add(patch.Key);if(split.Count==0)break;foreach(var key in split)Split(patches,key,maximumPatches);
        }
        // A local request can touch several rings; refine its shoulders until every actual shared edge is 3:1.
        while(true)
        {
            var current=patches.Values.OrderBy(p=>p.Key.Z).ToArray();var rectangles=current.ToDictionary(p=>p.Key,Owned);var split=new HashSet<Vector3I>();
            for(int i=0;i<current.Length;i++)for(int j=i+1;j<current.Length;j++){var fine=current[i];var coarse=current[j];if(coarse.Key.Z-fine.Key.Z<=1||split.Contains(coarse.Key))continue;bool adjacent=false;foreach(var a in rectangles[fine.Key]){foreach(var b in rectangles[coarse.Key])if(a.Adjacent(b)){adjacent=true;break;}if(adjacent)break;}if(adjacent)split.Add(coarse.Key);}
            if(split.Count==0)break;foreach(var key in split)Split(patches,key,maximumPatches);
        }
        return plan with{Patches=patches.Values.OrderBy(p=>p.Key.Z).ThenBy(p=>p.Key.Y).ThenBy(p=>p.Key.X).ToArray()};
    }
    private static void Split(Dictionary<Vector3I,TerrainRingLayout.Patch> patches,Vector3I key,int maximumPatches)
    {
        if(!patches.TryGetValue(key,out var parent))return;if(parent.Key.Z<=0)return;var children=TerrainRingLayout.Children(key);var accepted=new List<TerrainRingLayout.Patch>(9);int index=0;
        for(int z=0;z<3;z++)for(int x=0;x<3;x++){var child=children[index++];if(!parent.Hole.Empty&&x>=parent.Hole.MinX&&x<parent.Hole.MaxX&&z>=parent.Hole.MinZ&&z<parent.Hole.MaxZ)continue;accepted.Add(new TerrainRingLayout.Patch(child,parent.Size/3,TerrainRingLayout.Mask.None));}
        if(patches.Count-1+accepted.Count>maximumPatches)throw new InvalidOperationException("Local terrain detail exceeds the patch budget; retain the existing committed cut.");patches.Remove(key);foreach(var child in accepted)if(!patches.TryAdd(child.Key,child))throw new InvalidOperationException("Local terrain refinement overlapped existing ownership.");
    }
}
