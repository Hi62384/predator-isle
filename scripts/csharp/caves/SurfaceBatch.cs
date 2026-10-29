using Godot;
using System.Collections.Generic;
using System.Linq;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Assemble independently extracted columns; incomplete batches cannot be committed.</summary>
public partial class SurfaceBatch : RefCounted
{
    public long id { get; set; }
    public long generation { get; set; }
    public D request { get; set; } = new();
    public A groups { get; set; } = new();
    public int cursor { get; set; }
    public D received { get; set; } = new();
    public string failure { get; set; } = "";
    public bool configure(long batch_id, long revision, D source)
    {
        var columns = source.TryGetValue("columns", out var value) ? value.AsGodotDictionary() : new();
        if (columns.Count == 0 || columns.Count > 64) return false;
        id = batch_id; generation = revision; request = source; groups = new(); cursor = 0; received = new(); failure = "";
        var ordered = columns.Keys.Select(key => key.AsVector2I()).OrderBy(key => key.X).ThenBy(key => key.Y).ToArray();
        for (int i = 0; i < System.Math.Min(4, ordered.Length); i++) groups.Add(new D());
        for (int i = 0; i < ordered.Length; i++) groups[i % groups.Count].AsGodotDictionary()[ordered[i]] = true;
        return true;
    }
    public bool pending() => failure.Length == 0 && cursor < groups.Count;
    public D take()
    {
        if (!pending()) return new();
        int part = cursor++;
        return new D { ["batch_id"] = id, ["generation"] = generation, ["part"] = part, ["columns"] = groups[part] };
    }
    public bool accept(long batch_id, long revision, int part, D data)
    {
        if (batch_id != id || revision != generation || part < 0 || part >= groups.Count || received.ContainsKey(part)) return false;
        if (!data.TryGetValue("valid", out var valid) || !valid.AsBool()) { failure = data.TryGetValue("reason", out var reason) ? reason.AsString() : "Surface column extraction failed"; return false; }
        var owned = data.TryGetValue("owned_columns", out var oc) ? oc.AsGodotDictionary() : new();
        var columns = data.TryGetValue("columns", out var c) ? c.AsGodotDictionary() : new();
        if (!owned.RecursiveEqual(groups[part].AsGodotDictionary()) || !columns.RecursiveEqual(request["columns"].AsGodotDictionary())) { failure = "Surface column ownership mismatch"; return false; }
        received[part] = data; return true;
    }
    public bool complete() => failure.Length == 0 && groups.Count > 0 && received.Count == groups.Count;
    public D assemble()
    {
        D Invalid(string reason) => new() { ["valid"] = false, ["reason"] = reason };
        if (!complete()) return Invalid(failure.Length > 0 ? failure : "Incomplete surface batch");
        var cells = new List<D>(); var keys = new HashSet<Vector3I>(); var ground = new D();
        for (int i = 0; i < groups.Count; i++)
        {
            var part = received[i].AsGodotDictionary();
            var source = part.TryGetValue("cells", out var value) ? value.AsGodotArray() : new();
            foreach (var item in source)
            {
                var data = item.AsGodotDictionary();
                if (!keys.Add(data["key"].AsVector3I())) return Invalid("Duplicate extracted surface cell");
                cells.Add(data);
            }
            if (i == 0) ground = part.TryGetValue("ground", out var g) ? g.AsGodotDictionary() : new();
        }
        if (ground.Count == 0) return Invalid("Missing complete original-ground subtraction");
        cells.Sort((a, b) =>
        {
            var ka = a["key"].AsVector3I(); var kb = b["key"].AsVector3I();
            int result = ka.X.CompareTo(kb.X); if (result == 0) result = ka.Y.CompareTo(kb.Y); return result == 0 ? ka.Z.CompareTo(kb.Z) : result;
        });
        var packed = new A(); foreach (var cell in cells) packed.Add(cell);
        return new D { ["valid"] = true, ["cells"] = packed, ["ground"] = ground, ["columns"] = request["columns"].AsGodotDictionary().Duplicate() };
    }
}
