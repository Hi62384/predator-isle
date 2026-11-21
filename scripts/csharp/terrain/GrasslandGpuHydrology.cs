using Godot;
using System;
using System.Collections.Generic;
using System.Threading;

namespace PredatorIsle.Terrain;

/// <summary>
/// Worker-owned river and lake planning for a raw GPU field batch. The canonical
/// planner retains its double intermediates; only its published float descriptors
/// cross into the render queue. No native collection or resource is retained here.
/// </summary>
internal sealed class GrasslandGpuHydrology
{
    internal readonly record struct RiverKey(float X,int Lane);
    internal sealed record RiverPlan(RiverKey Key,Vector3[] Columns);
    internal sealed record LakePlan(Vector2I Key,Vector4[] Sites);

    // A plan may be shared by many raw points. These arrays and their descriptors
    // are immutable after Capture returns, including while a render is pending.
    internal RiverPlan?[] Rivers {get;}
    internal LakePlan?[] Lakes {get;}

    private GrasslandGpuHydrology(RiverPlan?[] rivers,LakePlan?[] lakes)
    {Rivers=rivers;Lakes=lakes;}

    internal static GrasslandGpuHydrology Capture(GrasslandField field,Vector2[] positions,CancellationToken cancellation=default)
    {
        cancellation.ThrowIfCancellationRequested();
        var rivers=new RiverPlan?[positions.Length];var lakes=new LakePlan?[positions.Length];
        var riverPlans=new Dictionary<RiverKey,RiverPlan>();var lakePlans=new Dictionary<Vector2I,LakePlan>();
        double riverFrequency=field.settings.Get("grass_river_frequency").AsDouble();
        double lakeFrequency=field.settings.Get("grass_lake_frequency").AsDouble();
        double spacing=4000/Math.Max(riverFrequency,.01);
        double pitch=Math.Max(field.settings.Get("grass_lake_size").AsDouble()*5,1200);
        for(int i=0;i<positions.Length;i++)
        {
            if((i&127)==0)cancellation.ThrowIfCancellationRequested();
            var point=positions[i];
            if(riverFrequency>0)
            {
                int lane=checked((int)Math.Round((double)point.Y/spacing,MidpointRounding.AwayFromZero));
                var key=new RiverKey(point.X,lane);
                if(!riverPlans.TryGetValue(key,out var river))
                {
                    cancellation.ThrowIfCancellationRequested();
                    var columns=new Vector3[3];
                    for(int offset=-1;offset<=1;offset++)columns[offset+1]=field.river_column(point.X,(long)lane+offset,spacing);
                    river=new RiverPlan(key,columns);riverPlans.Add(key,river);
                }
                rivers[i]=river;
            }
            if(lakeFrequency>0)
            {
                var key=new Vector2I((int)Math.Floor((double)point.X/pitch),(int)Math.Floor((double)point.Y/pitch));
                if(!lakePlans.TryGetValue(key,out var lake))
                {
                    cancellation.ThrowIfCancellationRequested();
                    var source=field.lake_sites(key,pitch);var sites=new Vector4[source.Count];
                    for(int site=0;site<sites.Length;site++)sites[site]=source[site];
                    lake=new LakePlan(key,sites);lakePlans.Add(key,lake);
                }
                lakes[i]=lake;
            }
        }
        return new GrasslandGpuHydrology(rivers,lakes);
    }
}
