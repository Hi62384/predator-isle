using Godot;
using System;
using System.Collections.Generic;

namespace PredatorIsle.Terrain;

/// <summary>Numeric controls from the worker's private preset; refreshed when that worker is configured.</summary>
internal sealed class TerrainParameterSnapshot
{
    private readonly Dictionary<string, double> _numbers = new();
    public double this[string key] => _numbers[key];
    public void Capture(Resource settings, string prefix = "")
    {
        _numbers.Clear();
        foreach (var property in settings.GetPropertyList())
        {
            var type = (Variant.Type)property["type"].AsInt32();
            if (type is not (Variant.Type.Float or Variant.Type.Int)) continue;
            string name = property["name"].AsString();
            if (!name.StartsWith(prefix, StringComparison.Ordinal)) continue;
            _numbers[name[prefix.Length..]] = settings.Get(name).AsDouble();
        }
    }
}
