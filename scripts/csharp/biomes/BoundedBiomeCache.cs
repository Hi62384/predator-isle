using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;

namespace PredatorIsle.Biomes;

/// <summary>Worker-owned numerical FIFO; deterministic values survive capacity rollover.
/// No full-cache invalidation during traversal, and no shared locks or per-hit allocations.</summary>
internal sealed class BoundedBiomeCache<TKey,TValue> where TKey:notnull
{
    private readonly int capacity;
    private readonly Dictionary<TKey,TValue> entries=new();
    private readonly Queue<TKey> order=new();
    internal BoundedBiomeCache(int maximum)
    {
        if(maximum<1)throw new ArgumentOutOfRangeException(nameof(maximum));
        capacity=maximum;
    }
    internal int Count=>entries.Count;
    internal bool TryGetValue(TKey key,[MaybeNullWhen(false)] out TValue value)=>entries.TryGetValue(key,out value);
    internal TValue this[TKey key]
    {
        get=>entries[key];
        set
        {
            if(entries.ContainsKey(key)){entries[key]=value;return;}
            if(entries.Count>=capacity)entries.Remove(order.Dequeue());
            entries.Add(key,value);order.Enqueue(key);
        }
    }
    internal void Clear(){entries.Clear();order.Clear();}
}
