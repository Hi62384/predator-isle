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
    internal long ShapeHits{get;private set;}
    private Dictionary<TerrainBiomeShapePlan.Key,TerrainBiomeShapePlan.Result>? shapes;
    private Action<long>? reportShapes;
    internal int ShapeCount=>shapes?.Count??0;
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
    internal void InstallShapes(Dictionary<TerrainBiomeShapePlan.Key,TerrainBiomeShapePlan.Result> data,Action<long> report)
    {shapes=data;reportShapes=report;}
    internal bool TryReadShape(object owner,Vector2 p,int subtype,out TerrainBiomeShapePlan.Result result)
    {
        if(shapes is not null&&shapes.TryGetValue(new(owner,p,subtype),out result))return true;
        result=default;return false;
    }
    internal static bool TryShape(object owner,Vector2 p,int subtype,out TerrainBiomeShapePlan.Result result)
    {
        var scope=current;
        if(scope is not null&&scope.TryReadShape(owner,p,subtype,out result)){scope.ShapeHits++;return true;}
        result=default;return false;
    }
    internal IDisposable Activate()=>new Lease(this);
    private sealed class Lease:IDisposable
    {
        private readonly TerrainBiomeNoiseCache owner;
        private readonly TerrainBiomeNoiseCache? previous;
        private readonly long baseline,shapeBaseline;
        private bool disposed;
        internal Lease(TerrainBiomeNoiseCache cache){owner=cache;previous=current;baseline=cache.Hits;shapeBaseline=cache.ShapeHits;current=cache;}
        public void Dispose(){if(disposed)return;disposed=true;current=previous;owner.report(owner.Hits-baseline);owner.reportShapes?.Invoke(owner.ShapeHits-shapeBaseline);}
    }
}
