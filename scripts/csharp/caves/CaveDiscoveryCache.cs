using Godot;
using System.Collections.Generic;
using D=Godot.Collections.Dictionary;
namespace PredatorIsle.Caves;

/// <summary>Completed immutable discovery products, scoped to one stream's world/settings snapshot.</summary>
internal sealed class CaveDiscoveryCache
{
    private sealed record Entry(D Data,long Bytes,LinkedListNode<Vector2I> Order);
    private readonly Dictionary<Vector2I,Entry> entries=new();
    private readonly LinkedList<Vector2I> order=new();
    internal long ResidentBytes{get;private set;}
    internal long Hits{get;private set;}
    internal long Misses{get;private set;}
    internal long BudgetBytes{get;}=16L*1024*1024;
    internal bool TryGet(Vector2I cell,out D data)
    {
        if(entries.TryGetValue(cell,out var entry)){order.Remove(entry.Order);order.AddLast(entry.Order);Hits++;data=entry.Data;return true;}Misses++;data=new D();return false;
    }
    internal void Add(Vector2I cell,D data,long bytes)
    {
        if(bytes<=0||bytes>BudgetBytes)return;
        if(entries.Remove(cell,out var old)){order.Remove(old.Order);ResidentBytes-=old.Bytes;}
        while((entries.Count>=8||ResidentBytes+bytes>BudgetBytes)&&order.First is not null){var key=order.First.Value;order.RemoveFirst();ResidentBytes-=entries[key].Bytes;entries.Remove(key);}
        entries[cell]=new Entry(data,bytes,order.AddLast(cell));ResidentBytes+=bytes;
    }
    internal void Clear(){entries.Clear();order.Clear();ResidentBytes=0;}
}
