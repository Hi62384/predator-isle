using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using D = Godot.Collections.Dictionary;
using A = Godot.Collections.Array;

namespace PredatorIsle.Terrain;

/// <summary>Complete local cut replacement and actual emitted skirt coverage validation.</summary>
public partial class TerrainReadyCut : RefCounted
{
    public bool contains(Vector3I outer, Vector3I inner) => Contains(outer, inner);
    private static bool Contains(Vector3I outer, Vector3I inner) => outer.Z >= inner.Z
        && (inner.X >> (outer.Z - inner.Z)) == outer.X && (inner.Y >> (outer.Z - inner.Z)) == outer.Y;
    public long area(Vector3I key) => Area(key);
    private static long Area(Vector3I key) => 1L << (key.Z * 2);
    public string edge_id(Vector3I a, Vector3I b)
    {
        string first = a.ToString(), second = b.ToString();
        return string.CompareOrdinal(first, second) < 0 ? first + "|" + second : second + "|" + first;
    }
    public D edge_profiles(A arrays, int resolution)
    {
        if (resolution <= 0 || arrays.Count == 0) return new();
        var vertices = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        int row = resolution + 1, main = row * row;
        if (vertices.Length < main + 8 * resolution) return new();
        var result = new D { ["resolution"] = resolution };
        for (int side = 0; side < 4; side++)
        {
            var top = new float[row]; var bottom0 = new float[resolution]; var bottom1 = new float[resolution];
            for (int i = 0; i < row; i++)
            {
                int index = side == 0 ? i * row : side == 1 ? i * row + resolution : side == 2 ? i : resolution * row + i;
                top[i] = vertices[index].Y;
                if (i == resolution) continue;
                int segment = side == 0 ? 4 * resolution - 1 - i : side == 1 ? resolution + i : side == 2 ? i : 3 * resolution - 1 - i;
                bool reverse = side is 0 or 3; int first = main + segment * 2;
                bottom0[i] = vertices[first + (reverse ? 1 : 0)].Y;
                bottom1[i] = vertices[first + (reverse ? 0 : 1)].Y;
            }
            result[side] = new D { ["top"] = top, ["bottom0"] = bottom0, ["bottom1"] = bottom1 };
        }
        return result;
    }
    private readonly record struct Profile(float[] Top, float[] Bottom0, float[] Bottom1)
    {
        public static Profile Read(D value) => new(value["top"].AsFloat32Array(), value["bottom0"].AsFloat32Array(), value["bottom1"].AsFloat32Array());
    }
    private static int Resolution(D source, Vector3I key) => source.TryGetValue(key, out var value) ? value.AsInt32() : 0;
    private static D ProfileFor(D source, Vector3I key) => source.TryGetValue(key, out var value) ? value.AsGodotDictionary() : new();
    private static bool PowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;

    public D covered_edge(Vector3I a, Vector3I b, D resolutions, D profiles, TerrainPartition planner)
    {
        if (!TerrainPartition.Adjacent(a, b)) return new();
        int ar = Resolution(resolutions, a), br = Resolution(resolutions, b);
        if (!PowerOfTwo(ar) || !PowerOfTwo(br)) return new();
        D ap = ProfileFor(profiles, a), bp = ProfileFor(profiles, b);
        if (!ap.TryGetValue("resolution", out var apr) || apr.AsInt32() != ar || !bp.TryGetValue("resolution", out var bpr) || bpr.AsInt32() != br) return new();
        int wa = 1 << a.Z, wb = 1 << b.Z, ax = a.X * wa, az = a.Y * wa, bx = b.X * wb, bz = b.Y * wb;
        bool vertical = ax + wa == bx || bx + wb == ax;
        int sa = vertical ? (ax + wa == bx ? 1 : 0) : (az + wa == bz ? 3 : 2);
        int sb = vertical ? (sa == 1 ? 0 : 1) : (sa == 3 ? 2 : 3);
        double astep = (double)wa / ar, bstep = (double)wb / br;
        var fine = Profile.Read((astep <= bstep ? ap[sa] : bp[sb]).AsGodotDictionary());
        var coarse = Profile.Read((astep <= bstep ? bp[sb] : ap[sa]).AsGodotDictionary());
        double fs = Math.Min(astep, bstep), cs = Math.Max(astep, bstep);
        int ao = vertical ? az : ax, bo = vertical ? bz : bx;
        int fo = astep <= bstep ? ao : bo, co = astep <= bstep ? bo : ao;
        int low = Math.Max(ao, bo), high = Math.Min(ao + wa, bo + wb);
        double first = (low - fo) / fs, last = (high - fo) / fs;
        if (first != Math.Round(first) || last != Math.Round(last)) return new();
        for (int i = (int)first; i < (int)last; i++)
        {
            double p0 = fo + i * fs, p1 = p0 + fs;
            int j = (int)Math.Floor(((p0 + p1) * .5 - co) / cs);
            if (j < 0 || j >= coarse.Bottom0.Length) return new();
            double t0 = (p0 - co - j * cs) / cs, t1 = (p1 - co - j * cs) / cs;
            double ct0 = Lerp(coarse.Top[j], coarse.Top[j + 1], t0), ct1 = Lerp(coarse.Top[j], coarse.Top[j + 1], t1);
            double cb0 = Lerp(coarse.Bottom0[j], coarse.Bottom1[j], t0), cb1 = Lerp(coarse.Bottom0[j], coarse.Bottom1[j], t1);
            if (!double.IsFinite(ct0 + ct1 + cb0 + cb1 + fine.Top[i] + fine.Top[i + 1] + fine.Bottom0[i] + fine.Bottom1[i])) return new();
            if (fine.Bottom0[i] > fine.Top[i] || fine.Bottom1[i] > fine.Top[i + 1] || cb0 > ct0 || cb1 > ct1) return new();
            if (fine.Bottom0[i] > ct0 + .0001 || fine.Bottom1[i] > ct1 + .0001 || cb0 > fine.Top[i] + .0001 || cb1 > fine.Top[i + 1] + .0001) return new();
        }
        return new D { ["a"] = a, ["b"] = b, ["a_resolution"] = ar, ["b_resolution"] = br, ["kind"] = "covered_skirt_edge", ["segments_checked"] = (int)(last - first), ["maximum_grid_ratio"] = cs / fs };
    }
    private static double Lerp(double a, double b, double t) => a + (b - a) * t;

    public D equivalent_edge(Vector3I a, Vector3I other, D wanted, D resolutions, D wantedResolutions, TerrainPartition planner)
    {
        if (!wanted.ContainsKey(a) || !TerrainPartition.Adjacent(a, other)) return new();
        int resolution = Resolution(resolutions, other);
        if (!PowerOfTwo(resolution)) return new();
        double step = (double)(1 << other.Z) / resolution;
        int wa = 1 << a.Z, wb = 1 << other.Z, ax = a.X * wa, az = a.Y * wa, bx = other.X * wb, bz = other.Y * wb;
        bool vertical = ax + wa == bx || bx + wb == ax;
        int low = vertical ? Math.Max(az, bz) : Math.Max(ax, bx), high = vertical ? Math.Min(az + wa, bz + wb) : Math.Min(ax + wa, bx + wb);
        int covered = 0; var templates = new A();
        foreach (var pair in wanted)
        {
            var neighbor = pair.Key.AsVector3I();
            if (Math.Abs(a.Z - neighbor.Z) > 1 || !TerrainPartition.Adjacent(a, neighbor)) continue;
            if (!Contains(other, neighbor) && !Contains(neighbor, other)) continue;
            int nr = Resolution(wantedResolutions, neighbor);
            if (!PowerOfTwo(nr) || (double)(1 << neighbor.Z) / nr != step) continue;
            int span = 1 << neighbor.Z, origin = (vertical ? neighbor.Y : neighbor.X) * span;
            int first = Math.Max(low, origin), last = Math.Min(high, origin + span);
            if (first >= last) continue;
            if (first / step != Math.Round(first / step) || last / step != Math.Round(last / step)) return new();
            covered += last - first; templates.Add(neighbor);
        }
        if (covered != high - low || templates.Count == 0) return new();
        return new D { ["a"] = a, ["b"] = other, ["a_resolution"] = Resolution(resolutions, a), ["b_resolution"] = resolution, ["kind"] = "equivalent_final_grid", ["equivalent_final_neighbors"] = templates, ["grid_step_base_units"] = step };
    }

    private sealed record Group(List<Vector3I> Remove, List<Vector3I> Add);
    private static Group? MakeGroup(Vector3I region, Vector3I[] active, Vector3I[] wanted, HashSet<Vector3I> ready)
    {
        var remove = new List<Vector3I>(); var add = new List<Vector3I>(); long covered = 0;
        foreach (var existing in active)
            if (Contains(region, existing)) remove.Add(existing); else if (Contains(existing, region)) return null;
        foreach (var key in wanted)
        {
            if (!Contains(region, key)) continue;
            if (!ready.Contains(key)) return null;
            add.Add(key); covered += Area(key);
        }
        return add.Count > 0 && covered == Area(region) ? new(remove, add) : null;
    }
    private static Vector3I[] Keys(D source) => source.Select(pair => pair.Key.AsVector3I()).ToArray();

    public D choose(D active, D wanted, D ready, TerrainPartition planner, Vector2 point,
        D? active_resolutions = null, D? ready_resolutions = null, D? wanted_resolutions = null,
        D? active_profiles = null, D? ready_profiles = null, Variant diagnostics = default)
    {
        var traceData = diagnostics.VariantType == Variant.Type.Dictionary ? diagnostics.AsGodotDictionary() : null;
        traceData?.Clear();
        active_resolutions ??= new(); ready_resolutions ??= new(); wanted_resolutions ??= new(); active_profiles ??= new(); ready_profiles ??= new();
        var activeKeys = Keys(active); var wantedKeys = Keys(wanted); var readyKeys = Keys(ready);
        var readySet = readyKeys.ToHashSet(); var regions = new HashSet<Vector3I>();
        foreach (var key in readyKeys)
        {
            if (!wanted.ContainsKey(key)) continue;
            var region = key;
            foreach (var existing in activeKeys) if (Contains(existing, key)) { region = existing; break; }
            regions.Add(region);
        }
        var ordered = regions.OrderBy(region => planner.distance_to(region, point)).ToArray();
        var groups = new Dictionary<Vector3I, Group?>();
        foreach (var region in ordered)
        {
            bool trace = traceData != null && region == ordered[0];
            void Record(string reason) { if (trace) traceData!["reason"] = reason; }
            void Block(string reason, Vector3I blocked) { Record(reason); if (trace) traceData!["blocked"] = blocked; }
            if (trace) traceData!["region"] = region;
            if (!groups.ContainsKey(region)) groups[region] = MakeGroup(region, activeKeys, wantedKeys, readySet);
            if (groups[region] == null) { Record("local_group_waiting"); continue; }
            var selected = new HashSet<Vector3I> { region };
            while (selected.Count <= 16)
            {
                var remove = new List<Vector3I>(); var add = new List<Vector3I>();
                foreach (var selectedRegion in selected) { remove.AddRange(groups[selectedRegion]!.Remove); add.AddRange(groups[selectedRegion]!.Add); }
                if (add.Count > 128)
                {
                    Record("transaction_leaf_limit"); if (trace) { traceData!["leaves"] = add.Count; traceData["groups"] = selected.Count; } break;
                }
                var proposed = activeKeys.ToHashSet(); var resolutions = active_resolutions.Duplicate(); var profiles = active_profiles.Duplicate(); var certificates = new A();
                foreach (var key in remove) { proposed.Remove(key); resolutions.Remove(key); profiles.Remove(key); }
                foreach (var key in add) { proposed.Add(key); resolutions[key] = Resolution(ready_resolutions, key); profiles[key] = ProfileFor(ready_profiles, key); }
                Vector3I? blocked = null; bool invalid = false;
                foreach (var key in add)
                {
                    foreach (var other in proposed)
                    {
                        if (key == other) continue;
                        if (Contains(key, other) || Contains(other, key)) { invalid = true; break; }
                        if (!TerrainPartition.Adjacent(key, other) || Math.Abs(key.Z - other.Z) <= 1) continue;
                        var certificate = equivalent_edge(key, other, wanted, resolutions, wanted_resolutions, planner);
                        if (certificate.Count == 0) certificate = covered_edge(key, other, resolutions, profiles, planner);
                        if (certificate.Count == 0) { blocked = other; break; }
                        certificates.Add(certificate);
                    }
                    if (invalid || blocked != null) break;
                }
                if (invalid) { Record("overlap"); break; }
                if (blocked == null)
                {
                    Record("complete"); if (trace) { traceData!["leaves"] = add.Count; traceData["groups"] = selected.Count; }
                    return new D { ["remove"] = new Godot.Collections.Array<Vector3I>(remove), ["add"] = new Godot.Collections.Array<Vector3I>(add), ["edge_certificates"] = certificates };
                }
                var blockedKey = blocked.Value;
                if (!active.ContainsKey(blockedKey) || add.Contains(blockedKey)) { Block("unresolvable_edge", blockedKey); break; }
                var neighborRegion = blockedKey;
                foreach (var leaf in wantedKeys) if (Contains(leaf, blockedKey)) { neighborRegion = leaf; break; }
                if (selected.Contains(neighborRegion)) { Block("selected_neighbor", blockedKey); break; }
                if (!groups.ContainsKey(neighborRegion)) groups[neighborRegion] = MakeGroup(neighborRegion, activeKeys, wantedKeys, readySet);
                if (groups[neighborRegion] == null)
                {
                    Block("neighbor_group_waiting", blockedKey);
                    if (trace) { traceData!["neighbor_region"] = neighborRegion; traceData["groups"] = selected.Count; } break;
                }
                selected.Add(neighborRegion);
            }
        }
        return new();
    }
}
