using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>One synchronous worker build owns the accepted numeric GPU values.
/// Never changes Godot noise objects or installs approximate data in other workers.</summary>
internal sealed class TerrainBiomeNoiseCache
{
    [ThreadStatic] private static TerrainBiomeNoiseCache? current;
    private readonly Dictionary<TerrainBiomeNoisePlan.Key,float> values;
    private readonly Action<long> report;
    internal long Hits{get;private set;}
    internal int Count=>values.Count;
    internal TerrainBiomeNoiseCache(Dictionary<TerrainBiomeNoisePlan.Key,float> data,Action<long> reportHits)
    {values=data;report=reportHits;}
    internal bool TryRead(FastNoiseLite noise,Vector2 p,out float value)=>values.TryGetValue(new(noise,p),out value);
    internal static float Read(FastNoiseLite noise,float x,float z)
    {
        var scope=current;
        if(scope is not null&&scope.TryRead(noise,new Vector2(x,z),out float value)){scope.Hits++;return value;}
        return noise.GetNoise2D(x,z);
    }
    internal static float Read(FastNoiseLite noise,Vector2 p)
    {
        var scope=current;
        if(scope is not null&&scope.TryRead(noise,p,out float value)){scope.Hits++;return value;}
        return noise.GetNoise2Dv(p);
    }
    internal IDisposable Activate()=>new Lease(this);
    private sealed class Lease:IDisposable
    {
        private readonly TerrainBiomeNoiseCache owner;
        private readonly TerrainBiomeNoiseCache? previous;
        private readonly long baseline;
        private bool disposed;
        internal Lease(TerrainBiomeNoiseCache cache){owner=cache;previous=current;baseline=cache.Hits;current=cache;}
        public void Dispose(){if(disposed)return;disposed=true;current=previous;owner.report(owner.Hits-baseline);}
    }
}
