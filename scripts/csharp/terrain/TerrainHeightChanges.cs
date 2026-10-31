using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>Ordered canonical height edits: X/Z centre, radius, signed height delta. No render settings.</summary>
internal sealed class TerrainHeightChanges
{
    private readonly Dictionary<Vector2I,List<Vector4>> cells=new();
    public void Configure(Vector4[] changes)
    {
        cells.Clear();if(changes.Length>1024)throw new ArgumentException("A terrain snapshot supports at most 1024 height changes.");
        foreach(var change in changes)
        {
            if(!change.IsFinite()||Math.Abs(change.X)>1e9||Math.Abs(change.Y)>1e9||change.Z<=0||change.Z>512||Math.Abs(change.W)>512)throw new ArgumentException("Terrain height changes require finite centres, a radius of at most 512 metres, and a height delta within 512 metres.");
            int x0=(int)Math.Floor((change.X-change.Z)/256.0),z0=(int)Math.Floor((change.Y-change.Z)/256.0),x1=(int)Math.Floor((change.X+change.Z)/256.0),z1=(int)Math.Floor((change.Y+change.Z)/256.0);
            for(int z=z0;z<=z1;z++)for(int x=x0;x<=x1;x++){var key=new Vector2I(x,z);if(!cells.TryGetValue(key,out var list)){list=new List<Vector4>();cells.Add(key,list);}list.Add(change);}
        }
    }
    public double Offset(double x,double z)
    {
        if(cells.Count==0)return 0;var key=new Vector2I(checked((int)Math.Floor(x/256)),checked((int)Math.Floor(z/256)));if(!cells.TryGetValue(key,out var list))return 0;double sum=0;
        foreach(var change in list){double dx=(x-change.X)/change.Z,dz=(z-change.Y)/change.Z,t=dx*dx+dz*dz;if(t>=1)continue;double shoulder=1-t;sum+=change.W*shoulder*shoulder;}return sum;
    }
}
