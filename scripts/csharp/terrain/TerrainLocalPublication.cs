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
    internal static TerrainRingLayout.Patch[]? Select(TerrainRingLayout.Patch[] published,TerrainRingLayout.Patch[] requested,HashSet<TerrainRingLayout.Patch> ready,Func<bool>? cancelled=null)
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
            if(overlapping.TryGetValue((a,b),out bool cached))return cached;
            bool hit=EnvelopesMeet(a,b,true)&&Regions(a).Any(x=>Regions(b).Any(x.Overlaps));
            overlapping[(a,b)]=hit;return hit;
        }
        bool Touch(TerrainRingLayout.Patch a,TerrainRingLayout.Patch b)
        {
            if(touching.TryGetValue((a,b),out bool cached))return cached;
            bool hit=EnvelopesMeet(a,b,false)&&Regions(a).Any(x=>Regions(b).Any(x.Touches));
            touching[(a,b)]=hit;return hit;
        }
        double Area(IEnumerable<TerrainRingLayout.Patch> patches)=>patches.Sum(p=>Regions(p).Sum(r=>r.Area));
        bool SameCoverage(IEnumerable<TerrainRingLayout.Patch> a,IEnumerable<TerrainRingLayout.Patch> b)
        {var left=a.SelectMany(Regions).ToArray();var right=b.SelectMany(Regions).ToArray();return left.All(r=>Math.Abs(r.Area-right.Sum(r.IntersectionArea))<=Math.Max(.0001,r.Area*1e-12))&&right.All(r=>Math.Abs(r.Area-left.Sum(r.IntersectionArea))<=Math.Max(.0001,r.Area*1e-12));}
        var original=new HashSet<TerrainRingLayout.Patch>(published);var accepted=new HashSet<TerrainRingLayout.Patch>(published);
        // Near owners get the first opportunity. Disjoint distant closures can also complete.
        foreach(var seed in requested.OrderBy(p=>p.Key.Z))
        {
            if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            if(accepted.Contains(seed)||!ready.Contains(seed))continue;
            var additions=new HashSet<TerrainRingLayout.Patch>{seed};var removals=new HashSet<TerrainRingLayout.Patch>();bool valid=true,changed=true;
            while(changed&&valid)
            {
                changed=false;
                foreach(var old in accepted)if(!removals.Contains(old)&&additions.Any(p=>Overlap(old,p))){removals.Add(old);changed=true;}
                foreach(var next in requested)if(!additions.Contains(next)&&removals.Any(p=>Overlap(p,next)))
                {if(!ready.Contains(next)&&!accepted.Contains(next)){valid=false;break;}additions.Add(next);changed=true;}
                if(!valid)break;
                var mixed=accepted.Where(p=>!removals.Contains(p)).Concat(additions).Distinct().ToArray();
                for(int i=0;i<mixed.Length&&valid;i++)for(int j=i+1;j<mixed.Length;j++)
                {
                    if(Math.Abs(mixed[i].Key.Z-mixed[j].Key.Z)<=1||!Touch(mixed[i],mixed[j]))continue;
                    // A temporarily retained neighbor may need to join this closure.
                    bool expanded=false;
                    foreach(var old in new[]{mixed[i],mixed[j]})if(accepted.Contains(old)&&!removals.Contains(old)){removals.Add(old);changed=true;expanded=true;}
                    if(!expanded){valid=false;break;}
                }
                if(cancelled?.Invoke()==true)throw new OperationCanceledException();
            }
            if(!valid)continue;
            // No disappearing old area, and no speculative expansion outside existing coverage.
            double oldArea=Area(removals),newArea=Area(additions);
            if(Math.Abs(oldArea-newArea)>Math.Max(.0001,oldArea*1e-12)||!SameCoverage(removals,additions))continue;
            accepted.ExceptWith(removals);accepted.UnionWith(additions);
        }
        if(accepted.SetEquals(original))return null;
        return accepted.OrderBy(p=>p.Key.Z).ThenBy(p=>p.Key.Y).ThenBy(p=>p.Key.X).ToArray();
    }
}
