using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

namespace PredatorIsle.Terrain;

internal static class TerrainPrefetch
{
    internal static TerrainRingLayout.Patch[] Select(Vector2 focus,Vector2 velocity,double latency,double size)
    {
        if(!focus.IsFinite()||!velocity.IsFinite()||!double.IsFinite(size)||size<=0)return Array.Empty<TerrainRingLayout.Patch>();
        // A surrounding row also covers reversals. Prediction is capped at three patch widths.
        var direction=velocity.LengthSquared()>.01?velocity.Normalized():Vector2.Zero;
        var lead=direction*(float)Math.Clamp(velocity.Length()*Math.Clamp(latency,.01,2)+size,size,size*3);
        var cells=new HashSet<Vector2I>();var current=new Vector2I((int)Math.Floor(focus.X/size),(int)Math.Floor(focus.Y/size));
        for(int z=-2;z<=2;z++)for(int x=-2;x<=2;x++)if(Math.Abs(x)==2||Math.Abs(z)==2)cells.Add(current+new Vector2I(x,z));
        var center=new Vector2I((int)Math.Floor((focus.X+lead.X)/size),(int)Math.Floor((focus.Y+lead.Y)/size));
        for(int z=-1;z<=1;z++)for(int x=-1;x<=1;x++)cells.Add(center+new Vector2I(x,z));
        return cells.Where(c=>Math.Abs(c.X-current.X)>1||Math.Abs(c.Y-current.Y)>1).OrderBy(c=>((Vector2)c-(Vector2)center).LengthSquared()).ThenBy(c=>c.Y).ThenBy(c=>c.X).Take(24).Select(c=>new TerrainRingLayout.Patch(new Vector3I(c.X,c.Y,0),size,TerrainRingLayout.Mask.None)).ToArray();
    }
}
