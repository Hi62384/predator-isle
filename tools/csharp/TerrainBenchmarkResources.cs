using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Checks;

/// <summary>Keeps a numerical fixture's resource graph alive through native property access.</summary>
internal sealed class TerrainBenchmarkResources : IDisposable
{
    // Native references also keep C# script-instance handles strong while a workload
    // allocates and collects. This is fixture setup, outside the measured region.
    private readonly Godot.Collections.Array<Resource> _resources = new();
    private readonly HashSet<ulong> _seen = new();

    internal T Retain<T>(T resource) where T : Resource
    {
        if (!_seen.Add(resource.GetInstanceId())) return resource;
        _resources.Add(resource);
        foreach (var property in resource.GetPropertyList())
        {
            if ((Variant.Type)property["type"].AsInt32() != Variant.Type.Object) continue;
            string name = property["name"].AsString();
            if (name == "script") continue;
            if (resource.Get(name).AsGodotObject() is Resource child) Retain(child);
        }
        return resource;
    }

    public void Dispose() => _resources.Clear();
}
