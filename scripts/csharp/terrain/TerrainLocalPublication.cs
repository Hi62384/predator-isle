using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

/// <summary>Replace the overlap/boundary dependency closure, retaining every other published owner.</summary>
internal static class TerrainLocalPublication
{
    private readonly record struct Rectangle(double X0,double Z0,double X1,double Z1)
    {
        public double Area=>(X1-X0)*(Z1-Z0);
        public bool Overlaps(Rectangle b)=>X0<b.X1&&X1>b.X0&&Z0<b.Z1&&Z1>b.Z0;
        public bool Touches(Rectangle b)=>((X1==b.X0||X0==b.X1)&&Math.Min(Z1,b.Z1)>Math.Max(Z0,b.Z0))||((Z1==b.Z0||Z0==b.Z1)&&Math.Min(X1,b.X1)>Math.Max(X0,b.X0));
        public double IntersectionArea(Rectangle b)=>Math.Max(0,Math.Min(X1,b.X1)-Math.Max(X0,b.X0))*Math.Max(0,Math.Min(Z1,b.Z1)-Math.Max(Z0,b.Z0));
    }
    internal static TerrainRingLayout.Patch[]? Select(TerrainRingLayout.Patch[] published,TerrainRingLayout.Patch[] requested,HashSet<TerrainRingLayout.Patch> ready,Func<bool>? cancelled=null, int additionBudget=int.MaxValue)
    {
        var regions=new Dictionary<TerrainRingLayout.Patch,Rectangle[]>();
        Rectangle[] Regions(TerrainRingLayout.Patch p)
        {if(!regions.TryGetValue(p,out var result))regions[p]=result=p.OwnedRegions().Select(r=>new Rectangle(p.OriginX+r.Position.X,p.OriginZ+r.Position.Y,p.OriginX+r.End.X,p.OriginZ+r.End.Y)).ToArray();return result;}
        // Reject disjoint bounding envelopes before enumerating partial-hole
        // ownership rectangles. Cache exact pair answers for the duration of
        // this publication transaction; repeated dependency closures then
        // reuse the same proof without rebuilding LINQ enumerations.
        var overlapping=new Dictionary<(TerrainRingLayout.Patch,TerrainRingLayout.Patch),bool>();
        var touching=new Dictionary<(TerrainRingLayout.Patch,TerrainRingLayout.Patch),bool>();
        static bool EnvelopesMeet(TerrainRingLayout.Patch a,TerrainRingLayout.Patch b,bool strict)
        {
            if(strict)
                return a.OriginX<b.OriginX+b.Size&&a.OriginX+a.Size>b.OriginX&&
                    a.OriginZ<b.OriginZ+b.Size&&a.OriginZ+a.Size>b.OriginZ;
            return a.OriginX<=b.OriginX+b.Size&&a.OriginX+a.Size>=b.OriginX&&
                a.OriginZ<=b.OriginZ+b.Size&&a.OriginZ+a.Size>=b.OriginZ;
        }
        bool Overlap(TerrainRingLayout.Patch a,TerrainRingLayout.Patch b)
        {
            if(!EnvelopesMeet(a,b,true))return false;
            if(overlapping.TryGetValue((a,b),out bool cached))return cached;
            bool hit=Regions(a).Any(x=>Regions(b).Any(x.Overlaps));
            overlapping[(a,b)]=hit;return hit;
        }
        bool Touch(TerrainRingLayout.Patch a,TerrainRingLayout.Patch b)
        {
            if(!EnvelopesMeet(a,b,false))return false;
            if(touching.TryGetValue((a,b),out bool cached))return cached;
            bool hit=Regions(a).Any(x=>Regions(b).Any(x.Touches));
            touching[(a,b)]=hit;return hit;
        }
        bool CoversRetiredOwners(IEnumerable<TerrainRingLayout.Patch> retired, IEnumerable<TerrainRingLayout.Patch> incoming)
        {
            var replacements = incoming.ToHashSet();
            // Only the part inside the new view needs a successor. Requiring
            // coverage outside it holds a retiring edge tile until the final swap.
            foreach (var old in retired)
                foreach (var target in requested)
                    if (Overlap(old,target) && !replacements.Contains(target)) return false;
            return true;
        }
        var original=new HashSet<TerrainRingLayout.Patch>(published);var accepted=new HashSet<TerrainRingLayout.Patch>(published);
        int maximumPublished = Math.Max(published.Length, requested.Length * 2);
        // Near owners get the first opportunity. Disjoint distant closures can also complete.
        int added = 0;
        foreach(var seed in requested)
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            if(accepted.Contains(seed))continue;
            if(!ready.Contains(seed))continue;
            var additions=new HashSet<TerrainRingLayout.Patch>{seed};var removals=new HashSet<TerrainRingLayout.Patch>();bool valid=true,changed=true;
            while(changed&&valid)
            {
                changed=false;
                foreach(var old in accepted)if(!removals.Contains(old)&&additions.Any(p=>Overlap(old,p))){removals.Add(old);changed=true;}
                foreach(var next in requested)if(!additions.Contains(next)&&removals.Any(p=>Overlap(p,next)))
                {if(!ready.Contains(next)&&!accepted.Contains(next)){valid=false;break;}additions.Add(next);changed=true;}
                if(!valid)break;
                var mixed=accepted.Where(p=>!removals.Contains(p)).Concat(additions).Distinct().ToArray();
                // Retained neighbors already passed the edge check in the visible cut.
                foreach(var incoming in additions)
                {
                    foreach(var neighbor in mixed)
                    {
                        if(Math.Abs(incoming.Key.Z-neighbor.Key.Z)<=1 || !Touch(incoming,neighbor))continue;
                        if(additions.Contains(neighbor)){valid=false;break;}
                        if(removals.Add(neighbor))changed=true;
                    }
                    if(!valid)break;
                }
                if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            }
            if(!valid)continue;
            if (removals.Count == 0)
            {
                // A long flight can put the nearby grid outside the old cut.
                // Publish independent ready owners while retaining old ground.
                if (accepted.Count + additions.Count > maximumPublished) continue;
            }
            else
            {
                if (!CoversRetiredOwners(removals, additions)) continue;
            }
            accepted.ExceptWith(removals);accepted.UnionWith(additions);
            added += additions.Count;
            if(added>=additionBudget)break;
        }
        if(accepted.SetEquals(original))return null;
        return accepted.OrderBy(p=>p.Key.Z).ThenBy(p=>p.Key.Y).ThenBy(p=>p.Key.X).ToArray();
    }
}
