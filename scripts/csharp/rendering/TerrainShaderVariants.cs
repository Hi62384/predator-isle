using Godot;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

namespace PredatorIsle.Rendering;

/// <summary>Omit globally impossible branches while preserving the original shader dispatch.</summary>
public partial class TerrainShaderVariants : RefCounted
{
    private static readonly string[] Legacy = { "jungle", "forest", "savanna", "swamp", "mountain", "tropical", "badlands" };
    private static readonly string[] Extensions = { "quarry", "wise_mountains", "volcanic", "spore_forest", "radiation_wasteland", "crystal_wastes", "insect_colony", "alien_infected" };
    private static readonly string[] Controls = { "jungle_control.z", "forest_control.z", "savanna_control.z", "swamp_control.z", "mountain_control.z", "tropical_control.x", "badlands_control.x", "coast_control.x" };
    private static readonly Dictionary<string, Shader> Cache = new();
    private static readonly LinkedList<string> Recency = new();
    private const int All = 65535;
    private const string Loop = "for(int i=0;i<8;i++){";

    public int configured_mask(Resource? settings)
    {
        if (settings == null) return All;
        int mask = 0;
        for (int i = 0; i < Legacy.Length; i++)
            if (settings.Get(Legacy[i] + "_coverage").AsDouble() > 0) mask |= 1 << i;
        if (settings.Get("rocky_coast_enabled").AsBool() || settings.Get("beaches_enabled").AsBool()) mask |= 1 << 7;
        for (int i = 0; i < Extensions.Length; i++)
            if (settings.Get(Extensions[i] + "_coverage").AsDouble() > 0) mask |= 1 << (i + 8);
        var alien = settings.Get("alien_infected").AsGodotObject();
        if (alien != null && alien.Get("overlay_strength").AsDouble() > 0) mask |= 1 << 15;
        return mask;
    }

    public bool supported(int mask) => mask >= 0 && mask < All;

    public string source_for(string source, int mask)
    {
        if (!supported(mask)) return source;
        var loops = new List<string>(2);
        int search = 0;
        for (int unused = 0; unused < 2; unused++)
        {
            int begin = source.IndexOf(Loop, search, StringComparison.Ordinal);
            if (begin < 0) return source;
            int depth = 1, end = begin + Loop.Length;
            while (end < source.Length && depth > 0)
            {
                if (source[end] == '{') depth++;
                else if (source[end] == '}') depth--;
                end++;
            }
            if (depth != 0) return source;
            loops.Add(source[begin..end]); search = end;
        }
        if (source.IndexOf(Loop, search, StringComparison.Ordinal) >= 0) return source;
        foreach (string control in Controls)
            foreach (string threshold in new[] { ".999", ".001" })
                if (Count(source, $"if({control}>{threshold})") != 1) return source;
        bool cachedTargets = source.Contains("vec3 cache_badlands_color=", StringComparison.Ordinal);
        if (cachedTargets)
            for (int i = 0; i < Legacy.Length; i++)
                if (Count(source, ".001<" + Controls[i]) != 1) return source;
        string result = source;
        foreach (string loop in loops)
        {
            int first = -1, last = -1;
            for (int i = 0; i < 8; i++)
                if ((mask & (1 << (i + 8))) != 0) { if (first < 0) first = i; last = i; }
            string replacement = first < 0 ? "" : loop.Replace(Loop, $"for(int i={first};i<{last + 1};i++){{", StringComparison.Ordinal);
            result = result.Replace(loop, replacement, StringComparison.Ordinal);
        }
        for (int i = 0; i < Controls.Length; i++)
            if ((mask & (1 << i)) == 0)
            {
                if (cachedTargets && i < Legacy.Length) result = result.Replace(".001<" + Controls[i], "false", StringComparison.Ordinal);
                foreach (string threshold in new[] { ".999", ".001" })
                    result = result.Replace($"if({Controls[i]}>{threshold})", "if(false)", StringComparison.Ordinal);
            }
        return $"// CONFIGURED_TERRAIN_OWNERS_{mask}\n" + result;
    }

    public Shader? select(Shader? original, Resource? settings, bool enabled = true)
    {
        if (!enabled || original == null) return original;
        int mask = configured_mask(settings);
        if (!supported(mask)) return original;
        string source = original.Code;
        string key = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(source))) + ":" + mask;
        if (Cache.TryGetValue(key, out var hit)) { Recency.Remove(key); Recency.AddLast(key); return hit; }
        string code = source_for(source, mask);
        if (code == source) return original;
        var variant = new Shader { Code = code };
        while (Cache.Count >= 8) { string oldest = Recency.First!.Value; Recency.RemoveFirst(); Cache.Remove(oldest); }
        Cache[key] = variant; Recency.AddLast(key);
        return variant;
    }

    private static int Count(string text, string pattern)
    {
        int count = 0, cursor = 0;
        while ((cursor = text.IndexOf(pattern, cursor, StringComparison.Ordinal)) >= 0) { count++; cursor += pattern.Length; }
        return count;
    }
}
