using System.Linq;
using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;
/// <summary>Bounded, deterministic regions with independently proven dry return routes.</summary>
public partial class CaveNetwork : RefCounted
{
    private static readonly StringName NodeIdKey = "id";
    public GodotObject Solver { get; set; } = new RouteSolver();
    private readonly CaveChamberProfiles Profiles = new();
    private readonly CaveSeepageBasins Basins = new();
    internal double OceanLevel {get;set;}=double.NegativeInfinity;
    internal int EntrancesPerRegion {get;set;}=1;
    public double REGION_METRES => 1536; public int MAX_REGIONS => 32;
    private Callable _height,_water;
    private Func<double,double,double>? _sampleHeight,_sampleWater;
    public Callable height { get=>_height; set { _height=value;_sampleHeight=CaveHeightSampler.Bind(value); } }
    public Callable water { get=>_water; set { _water=value;_sampleWater=CaveHeightSampler.Bind(value); } }
    private double Height(double x,double z)=>_sampleHeight is not null?_sampleHeight(x,z):_height.Call(x,z).AsDouble();
    private double Water(double x,double z)=>_sampleWater is not null?_sampleWater(x,z):_water.Call(x,z).AsDouble();
    public long seed_id { get; set; } = 73921; public double max_depth { get; set; } = 400;
    public double half_width { get; set; } = 4; public double headroom { get; set; } = 8; public double minimum_roof { get; set; } = 10; public double maximum_grade { get; set; } = .2; public double activity { get; set; } = .85;
    public bool chamber_variety { get; set; } public bool geological_morphology { get; set; } public double seepage_density { get; set; } public double flat_radius { get; set; } = 26;
    public Callable region_context { get; set; } public Callable region_decorator { get; set; } public Callable region_finalizer { get; set; } public Callable access_admission { get; set; }
    public D _active_context { get; set; } = new(); public D _regions { get; set; } = new(); public D last_support_conflict { get; set; } = new();
    private readonly Queue<Vector2I> _ring = new();
    private static Variant Get(D d, string key, Variant fallback = default) => d.ContainsKey(key) ? d[key] : fallback;
    private static double Number(D d, string key, double fallback = 0) => d.ContainsKey(key) ? d[key].AsDouble() : fallback;
    private static A Items(D d, string key) => Get(d, key, new A()).AsGodotArray();
    private static bool Valid(Callable c) => c.Delegate != null || GodotObject.IsInstanceValid(c.Target) && c.Target.HasMethod(c.Method);
    private static Vector2 Xz(Vector3 p) => new(p.X, p.Z);
    private static double Lerp(double a, double b, double t) => a + (b - a) * t;
    private static double Smooth(double a, double b, double x) { double t = Math.Clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }
    public void configure(Callable surface, Callable water_surface, long seed_value) => configure(surface, water_surface, seed_value, 400);
    public void configure(Callable surface, Callable water_surface, long seed_value, double depth)
    { height = surface; water = water_surface; seed_id = seed_value; max_depth = depth; _regions.Clear(); _ring.Clear(); }
    public double random(Vector2I cell, long salt)
    { long h = unchecked(cell.X * 374761393L + cell.Y * 668265263L + seed_id * 69069 + salt * 1274126177) & 0x7fffffff; h = unchecked((h ^ (h >> 13)) * 1274126177) & 0x7fffffff; return (double)(h ^ (h >> 16)) / 2147483647.0; }
    public Vector2[] curve(Vector2[] control)
    {
        var path = new List<Vector2>();
        for (int segment = 0; segment < control.Length - 1; segment++)
        {
            var a = control[segment]; var b = control[segment + 1]; var before = control[Math.Max(0, segment - 1)]; var after = control[Math.Min(control.Length - 1, segment + 2)];
            var c = a + (b - before) / 6; var d = b - (after - a) / 6; int count = Math.Max(2, (int)Math.Ceiling(((double)a.DistanceTo(c) + c.DistanceTo(d) + d.DistanceTo(b)) / 6));
            for (int i = 0; i < count; i++) { double t = (double)i / count, s = 1 - t; path.Add(a * (float)s * (float)s * (float)s + c * 3 * (float)s * (float)s * (float)t + d * 3 * (float)s * (float)t * (float)t + b * (float)t * (float)t * (float)t); }
        }
        path.Add(control[^1]); return path.ToArray();
    }
    public D node_floor(Vector2 p, double depth)
    {
        double low = double.NegativeInfinity, high = double.PositiveInfinity;
        for (int dz = -1; dz <= 1; dz++) for (int dx = -1; dx <= 1; dx++)
        {
            double h = Height((double)p.X + dx * 24, (double)p.Y + dz * 24); if (!double.IsFinite(h)) return new();
            low = Math.Max(low, h - max_depth + 4 + Number(_active_context, "planning_depth_reserve")); high = Math.Min(high, h - minimum_roof - 18);
        }
        if (low > high) return new();
        return new D { ["point"] = new Vector3(p.X, (float)Math.Clamp(Height(p.X, p.Y) - depth, low, high), p.Y), ["half_width"] = half_width, ["headroom"] = headroom, ["chamber_radius"] = 18.0, ["chamber_height"] = 18.0 };
    }
    public D route(D a, D b, Vector2[] controls) => route(a, b, controls, false, 0);
    public D route(D a, D b, Vector2[] controls, bool entry) => route(a, b, controls, entry, 0);
    public D route(D a, D b, Vector2[] controls, bool entry, double extra_depth_reserve)
    {
        var path = curve(controls); float[] cover = System.Array.Empty<float>();
        if (entry)
        { double length = 0; var distances = new double[path.Length]; for (int i = 1; i < path.Length; i++) { length += path[i].DistanceTo(path[i - 1]); distances[i] = length; } cover = new float[path.Length]; for (int i = 0; i < path.Length; i++) cover[i] = (float)Smooth(0, .75, distances[i] / length); }
        double reserve = Math.Max(extra_depth_reserve, Number(_active_context, "planning_depth_reserve"));
        var solved = Solver is RouteSolver native ? native.solve(path, height, half_width, headroom, minimum_roof, max_depth - reserve, maximum_grade, a["point"].AsVector3().Y, b["point"].AsVector3().Y, cover, entry ? 0 : flat_radius, flat_radius)
            : Solver.Call("solve", path, height, half_width, headroom, minimum_roof, max_depth - reserve, maximum_grade, a["point"].AsVector3().Y, b["point"].AsVector3().Y, cover, entry ? 0 : flat_radius, flat_radius).AsGodotDictionary();
        if (!solved["valid"].AsBool()) return new();
        return new D { ["from"] = a["id"], ["to"] = b["id"], ["points"] = solved["points"], ["half_width"] = half_width, ["headroom"] = headroom, ["entrance"] = entry, ["maximum_grade"] = solved["maximum_grade"], ["minimum_measured_roof_m"] = solved["minimum_measured_roof_m"], ["maximum_measured_depth_m"] = solved["maximum_measured_depth_m"] };
    }
    // Fractures occasionally divide a buried reach and rejoin it downstream.
    // Follow its local floor so both openings share a traversable threshold.
    private A BuildBypasses(Vector2I cell,A edges)
    {
        var bypasses=new A();
        int originalCount=edges.Count;
        for(int i=0;i<originalCount;i++)
        {
            var edge=edges[i].AsGodotDictionary();
            var points=edge["points"].AsVector3Array();
            int salt=64000+i*5;
            if(points.Length<12 || random(cell,salt)>.43)continue;
            int first=(int)(points.Length*(.22+.17*random(cell,salt+1)));
            int last=Math.Min(points.Length-1,first+6+(int)(random(cell,salt+2)*10));
            var a=points[first];var b=points[last];
            if(Height(a.X,a.Z)-a.Y<headroom+minimum_roof+3 || Height(b.X,b.Z)-b.Y<headroom+minimum_roof+3)continue;
            var normal=(Xz(b)-Xz(a)).Normalized().Orthogonal();
            float offset=(float)((12+random(cell,salt+3)*22)*(random(cell,salt+4)<.5?-1:1));
            var start=new D{["id"]=edge["from"],["point"]=a};
            var end=new D{["id"]=edge["to"],["point"]=b};
            var side=route(start,end,new[]{Xz(a),Xz(points[(2*first+last)/3])+normal*offset,
                Xz(points[(first+2*last)/3])+normal*offset*.62f,Xz(b)});
            if(side.Count==0 || !supported_join(side,edges) || !supported_join(side,bypasses))continue;
            side["half_width"]=half_width*(.56+.23*random(cell,salt+2));
            side["headroom"]=headroom*(.62+.35*random(cell,salt+4));
            side["bypass"]=true;
            side["profile_phase"]=random(cell,salt)*Math.Tau;
            bypasses.Add(side);
        }
        return bypasses;
    }
    public bool supported_join(D candidate, A retained)
    {
        last_support_conflict = new D(); var points = candidate["points"].AsVector3Array();
        foreach (var value in retained)
        {
            var edge = value.AsGodotDictionary(); var previous = edge["points"].AsVector3Array(); double clearance = Number(candidate, "half_width") + Number(edge, "half_width") + 2;
            for (int i = 0; i < points.Length - 1; i++)
            {
                var a = points[i]; var b = points[i + 1]; var ab = Xz(b - a);
                for (int j = 0; j < previous.Length - 1; j++)
                {
                    var c = previous[j]; var d = previous[j + 1];
                    if (Math.Max(a.X, b.X) + clearance < Math.Min(c.X, d.X) || Math.Min(a.X, b.X) - clearance > Math.Max(c.X, d.X) || Math.Max(a.Z, b.Z) + clearance < Math.Min(c.Z, d.Z) || Math.Min(a.Z, b.Z) - clearance > Math.Max(c.Z, d.Z)) continue;
                    var cd = Xz(d - c);
                    for (int step = 0; step < 3; step++)
                    { double t = step * .5; var p = a.Lerp(b, (float)t); var q = Xz(p - c); double u = Math.Clamp(q.Dot(cd) / Math.Max(cd.LengthSquared(), .000001), 0, 1); if ((q - cd * (float)u).Length() >= clearance) continue; double separation = Math.Abs(p.Y - Lerp(c.Y, d.Y, u)); if (Conflict(separation, p, edge)) return false; }
                    for (int step = 0; step < 3; step++)
                    { double u = step * .5; var p = c.Lerp(d, (float)u); var q = Xz(p - a); double t = Math.Clamp(q.Dot(ab) / Math.Max(ab.LengthSquared(), .000001), 0, 1); if ((q - ab * (float)t).Length() >= clearance) continue; double separation = Math.Abs(p.Y - Lerp(a.Y, b.Y, t)); if (Conflict(separation, p, edge)) return false; }
                }
            }
            bool Conflict(double separation, Vector3 point, D e)
            { if (separation <= .35 || separation >= Math.Max(Number(candidate, "headroom"), Number(e, "headroom")) + 3) return false; last_support_conflict = new D { ["point"] = point, ["separation"] = separation, ["edge"] = e["from"].AsString() + ">" + e["to"].AsString() }; return true; }
        }
        return true;
    }
    // Follow locally varying fractures. Keep the initial heading at the lip so
    // the surface opening still ties into the same approach.
    private Vector2[] AccessControls(Vector2I cell, int attempt, Vector2 start, Vector2 end)
    {
        var delta = end - start;
        var side = delta.Orthogonal().Normalized();
        int salt = 18000 + attempt * 40;
        int spans = Math.Clamp((int)(delta.Length() / (40 + 35 * random(cell, salt))), 3, 18);
        var controls = new Vector2[spans + 1];
        controls[0] = start;
        controls[spans] = end;
        for (int i = 1; i < spans; i++)
        {
            float t = (float)i / spans;
            float bend = (float)((random(cell, salt + i) - .5) * Math.Min(80, delta.Length() / spans));
            controls[i] = start + delta * t + side * (bend * Mathf.Sin(Mathf.Pi * t));
        }
        return controls;
    }
    public D _build(Vector2I cell)
    {
        var empty = new D { ["id"] = cell, ["nodes"] = new A(), ["edges"] = new A(), ["entrances"] = new A(), ["valid"] = false, ["reason"] = "no_admitted_dry_return_route" };
        if (!Valid(height) || !Valid(water) || max_depth < 80 || max_depth > 10000) return empty;
        if (random(new Vector2I((int)Math.Floor(cell.X / 3.0), (int)Math.Floor(cell.Y / 3.0)), 17) > activity) return empty;
        var center = ((Vector2)cell + new Vector2((float)(.4 + .2 * random(cell, 1)), (float)(.4 + .2 * random(cell, 2)))) * 1536; double angle = random(cell, 3) * Math.Tau; var nodes = new A(); var edges = new A(); var entrances = new A();
        var first = node_floor(center + new Vector2(-120, -120).Rotated((float)angle), Math.Min(50, max_depth * .2)); if (first.Count == 0) return empty;
        first[NodeIdKey] = FormattableString.Invariant($"{cell.X}:{cell.Y}:0:0"); first["level"] = 0;
        nodes.Add(first);
        var previous = first;
        for (int level = 0; level < 4; level++)
        {
            var layerNodes = new A();
            int stationCount = 3 + (int)(random(cell, 3200 + level) * 4);
            for (int corner = 0; corner < stationCount; corner++)
            {
                int salt = 3300 + level * 32 + corner * 4;
                float bearing = (float)(angle + level * .83 + corner * 4.6 / stationCount + random(cell,salt) * .45);
                var offset = new Vector2((float)(160 + 190 * random(cell,salt+1)),0).Rotated(bearing);
                var p = center + offset;
                double deepest = Math.Clamp(Height(p.X,p.Y) + 1000, max_depth * .65, max_depth * .9); double depth = level switch { 0 => Math.Min(50, max_depth * .2), 1 => deepest * .37, 2 => deepest * .72, _ => deepest }; var node = level == 0 && corner == 0 ? first : node_floor(p, depth); if (node.Count == 0) break;
                node["chamber_radius"] = 8 + 16 * random(cell,salt);
                node["chamber_height"] = 10 + 8 * random(cell,salt+2);
                node[NodeIdKey] = FormattableString.Invariant($"{cell.X}:{cell.Y}:{level}:{corner}"); node["level"] = level; if (level == 0 && corner == 0) { layerNodes.Add(first); continue; }
                if (corner >= 2 && random(cell,salt+3) < .30)
                    previous = layerNodes[(int)(random(cell,salt+1) * (corner-1))].AsGodotDictionary();
                var a = Xz(previous["point"].AsVector3()); var b = Xz(node["point"].AsVector3()); var lateral = (b - a).Orthogonal();
                var controls = new[] { a, a.Lerp(b,.32f) + lateral * (float)((random(cell,salt + 2)-.5)*.62), a.Lerp(b,.72f) - lateral * (float)((random(cell,salt)-.5)*.46), b };
                if (corner == 0) controls = new[] { a, center + new Vector2(-450, -450).Rotated((float)angle), center + new Vector2(450, -450).Rotated((float)angle), center + new Vector2(450, 450).Rotated((float)angle), center + new Vector2(-450, 450).Rotated((float)angle), b };
                var connection = route(previous, node, controls);
                if (corner == 0)
                {
                    for (int alternative = 0; alternative < 8; alternative++)
                    {
                        if (connection.Count > 0 && supported_join(connection, edges)) break; connection = new D(); var winding = new List<Vector2> { a }; double turn = angle + (alternative / 2) * Math.PI * .5, clockwise = alternative % 2 == 0 ? 1 : -1;
                        for (int cornerId = 0; cornerId < 4; cornerId++) winding.Add(center + new Vector2(-450, -450).Rotated((float)(turn + clockwise * cornerId * Math.PI * .5)));
                        winding.Add(b); connection = route(previous, node, winding.ToArray());
                    }
                    if (connection.Count > 0 && !supported_join(connection, edges)) connection = new D();
                }
                if (connection.Count == 0) break; nodes.Add(node); edges.Add(connection); layerNodes.Add(node); previous = node;
            }
            if (layerNodes.Count != stationCount) break;
            var from = layerNodes[stationCount-1].AsGodotDictionary(); var to = layerNodes[0].AsGodotDictionary(); var loop = route(from, to, new[] { Xz(from["point"].AsVector3()), Xz(to["point"].AsVector3()) }); if (loop.Count > 0 && random(cell, 2400 + level) < .55) { edges.Add(loop); previous = to; } else previous = from;
        }
        // Density is independent of underground graph size. Bias the budget toward
        // one or two mouths; the configured count is a ceiling, not a quota.
        int entranceBudget = 1 + Math.Min(EntrancesPerRegion - 1,
            (int)(Math.Pow(random(cell, 75001), 1.8) * EntrancesPerRegion));
        const float minimumSeparation = 400;
        var regionOrigin = (Vector2)cell * (float)REGION_METRES;
        for (int attempt = 0; attempt < 24 * entranceBudget; attempt++)
        {
            double yaw = angle + Math.Tau * random(cell, 40 + attempt); var p = center + new Vector2((float)Math.Cos(yaw), (float)Math.Sin(yaw)) * (float)(360 + random(cell, 80 + attempt) * 220);
            if (attempt >= 24)
            {
                // Visit all 25 sectors before retrying one. The coprime stride
                // spreads successive candidates across the whole region.
                int sector = attempt * 7 % 25;
                double u = (sector % 5 + .15 + .7 * random(cell, 1000 + attempt * 2)) / 5;
                double v = (sector / 5 + .15 + .7 * random(cell, 1001 + attempt * 2)) / 5;
                p = new Vector2((float)((cell.X + u) * REGION_METRES), (float)((cell.Y + v) * REGION_METRES));
            }
            // Half the separation on each side of a region boundary gives the
            // same lower bound across independently discovered neighbouring regions.
            var local = p - regionOrigin;
            float margin = minimumSeparation * .5f;
            if(local.X < margin || local.Y < margin || local.X > REGION_METRES-margin || local.Y > REGION_METRES-margin)continue;
            if (nodes.Any(v=>v.AsGodotDictionary()["level"].AsInt32()==-1 && Xz(v.AsGodotDictionary()["point"].AsVector3()).DistanceSquaredTo(p)<minimumSeparation*minimumSeparation))continue;
            if (!CaveHeightSampler.TrySamplePair(height, water, p.X, p.Y, out double terrain, out double wet))
            { terrain = Height(p.X, p.Y); wet = Water(p.X, p.Y); }
            if (!double.IsFinite(terrain) || !double.IsFinite(wet) || terrain <= Math.Max(wet,OceanLevel) + 3) continue;
            double low = terrain, high = terrain;
            foreach (var offset in new[] { new Vector2(8, 0), new Vector2(-8, 0), new Vector2(0, 8), new Vector2(0, -8) }) { double h = Height((double)p.X + offset.X, (double)p.Y + offset.Y); low = Math.Min(low, h); high = Math.Max(high, h); }
            if (low <= Math.Max(wet,OceanLevel)+2 || high - low > headroom*.85) continue;
            var entry = new D { ["id"] = FormattableString.Invariant($"{cell.X}:{cell.Y}:entrance"), ["point"] = new Vector3(p.X, (float)(low - Math.Min(headroom*.25,1.5)), p.Y), ["level"] = -1 }; if(entrances.Count>0)entry["id"]=FormattableString.Invariant($"{cell.X}:{cell.Y}:entrance:{entrances.Count}"); var destination = nodes.Select(v => v.AsGodotDictionary()).Where(n => n["level"].AsInt32() == 0 && !n.ContainsKey("confluence")).OrderBy(n => Xz(n["point"].AsVector3()).DistanceSquaredTo(p)).First(); var q = Xz(destination["point"].AsVector3()); var delta = q - p; var middle = (p + q) * .5f + new Vector2(-delta.Y, delta.X) * .12f;
            var access=route(entry,destination,new[]{p,middle,q},true);if(access.Count==0)continue;
            if(access_admission.Target is CaveInsectEntryGuard guard&&access_admission.Method==nameof(CaveInsectEntryGuard.clear_access)){if(!guard.clear_access(access))continue;}else if(Valid(access_admission)&&!access_admission.Call(access).AsBool())continue;
            if (geological_morphology)
            {
                var receiver = nodes.Select(v => v.AsGodotDictionary())
                    .Where(n => n["level"].AsInt32() == 0)
                    .OrderBy(n => Xz(n["point"].AsVector3()).DistanceSquaredTo(p)).First();
                var tributary = route(entry, receiver, AccessControls(cell, attempt, p, Xz(receiver["point"].AsVector3())), true);
                if (tributary.Count > 0 && (!Valid(access_admission) || access_admission.Call(tributary).AsBool())) access = tributary;
            }
            // Buried confluences become destinations for subsequent entrances.
            // Split the solved route at an existing station to preserve its grade.
            var stations = access["points"].AsVector3Array();
            if (geological_morphology && stations.Length > 32 && random(cell, 41000 + attempt) < .7)
            {
                int split = (int)((stations.Length - 1) * (.78 + .09 * random(cell, 42000 + attempt)));
                var junction = stations[split];
                var id = entry["id"].AsString() + ":confluence";
                nodes.Add(new D { ["id"]=id, ["confluence"]=true, ["level"]=0, ["point"]=junction,
                    ["half_width"]=half_width, ["headroom"]=headroom,
                    ["chamber_radius"]=half_width+1, ["chamber_height"]=headroom });
                var downstream = access.Duplicate();
                downstream["from"]=id; downstream["points"]=stations[split..]; downstream["entrance"]=false;
                edges.Add(downstream);
                access["to"]=id; access["points"]=stations[..(split+1)];
            }
            nodes.Add(entry); edges.Add(access); entrances.Add(entry["id"]);
            if(entrances.Count>=entranceBudget)break;
        }
        if (entrances.Count == 0) return empty;
        var result = new D { ["id"] = cell, ["center"] = center, ["nodes"] = nodes, ["edges"] = edges, ["entrances"] = entrances, ["valid"] = true, ["reason"] = "", ["default_biome_id"] = 0, ["geology"] = Math.Min(5, (int)(random(cell, 102) * 6)) };
        if(geological_morphology)
        {
            result["cross_section_style"]=result["geology"];
            result["fracture_passages"]=BuildBypasses(cell,edges);
            int ordinal=0;
            foreach(var raw in edges)
            {
                var edge=raw.AsGodotDictionary();
                edge["profile_phase"]=random(cell, 52000 + ordinal++) * Math.Tau;
            }
        }
        if(region_decorator.Target is CaveHiveNetwork decoration&&region_decorator.Method==nameof(CaveHiveNetwork.decorate))result=decoration.decorate(result,_active_context);else if(Valid(region_decorator))result=region_decorator.Call(result,_active_context).AsGodotDictionary();
        if (chamber_variety && !result.ContainsKey("pockets")) { result["pockets"] = Profiles.make(result, height, seed_id, max_depth, minimum_roof); result["pocket_passages"] = Profiles.passages(result, result["pockets"].AsGodotArray()); }
        if(seepage_density>0)result["pools"]=Basins.make(result,seed_id,seepage_density);if(region_finalizer.Target is CaveBiomeRegions finalizer&&region_finalizer.Method==nameof(CaveBiomeRegions.decorate))result=finalizer.decorate(result);else if(Valid(region_finalizer))result=region_finalizer.Call(result).AsGodotDictionary();return result;
    }
    public D region(Vector2I cell)
    {
        if (_regions.ContainsKey(cell)) return _regions[cell].AsGodotDictionary(); double width = half_width, room = headroom, flat = flat_radius;
        _active_context=region_context.Target is CaveHiveNetwork context&&region_context.Method==nameof(CaveHiveNetwork.context)?context.context(cell):Valid(region_context)?region_context.Call(cell).AsGodotDictionary():new D();half_width=Number(_active_context,"half_width",half_width);headroom=Number(_active_context,"headroom",headroom);flat_radius=Number(_active_context,"flat_radius",flat_radius);
        D data; try { data = _build(cell); } finally { half_width = width; headroom = room; flat_radius = flat; }
        if (_active_context.ContainsKey("render_style")) data["render_style"] = _active_context["render_style"]; if (_active_context.ContainsKey("hive_region")) data["hive_region"] = _active_context["hive_region"]; _active_context = new D();
        if (_ring.Count >= 32) _regions.Remove(_ring.Dequeue()); _ring.Enqueue(cell); _regions[cell] = data; return data;
    }
    public D connection(Vector2I first, Vector2I second)
    {
        if (Math.Abs((long)first.X - second.X) + Math.Abs((long)first.Y - second.Y) != 1) return new(); if (first.X > second.X || first.X == second.X && first.Y > second.Y) (first, second) = (second, first);
        var a = region(first); var b = region(second); if (!a["valid"].AsBool() || !b["valid"].AsBool()) return new(); var from = a["nodes"].AsGodotArray()[1].AsGodotDictionary(); var to = b["nodes"].AsGodotArray()[1].AsGodotDictionary(); var p = Xz(from["point"].AsVector3()); var q = Xz(to["point"].AsVector3()); var delta = q - p;
        var mid = (p + q) * .5f + new Vector2(-delta.Y, delta.X) * (float)(.08 * Math.Sin(((long)first.X + first.Y) * 1.71)); var protectedEdges = Items(a, "edges").Duplicate(); protectedEdges.AddRange(Items(b, "edges"));
        foreach (var data in new[] { a, b })
        {
            protectedEdges.AddRange(Items(data, "pocket_passages")); protectedEdges.AddRange(Profiles.protected_edges(Items(data, "pockets"))); var beds = new A();
            foreach (var value in Items(data, "pools")) { var pool = value.AsGodotDictionary(); var guard = pool["bed"].AsGodotDictionary().Duplicate(); guard["chamber_radius"] = pool["radius"]; beds.Add(guard); beds.AddRange(Items(pool, "bank_lobes")); protectedEdges.AddRange(Items(pool, "stream_edges")); }
            protectedEdges.AddRange(Profiles.protected_edges(beds));
        }
        double reserve = Get(a, "cave_family", -1).AsInt32() == 7 || Get(b, "cave_family", -1).AsInt32() == 7 ? 2 : 0; var solved = route(from, to, new[] { p, mid, q }, false, reserve);
        foreach (double offset in new[] { 0.0, .12, -.12, .24, -.24, .36, -.36 }) { if (solved.Count > 0 && supported_join(solved, protectedEdges)) break; mid = (p + q) * .5f + new Vector2(-delta.Y, delta.X) * (float)offset; solved = route(from, to, new[] { p, mid, q }, false, reserve); }
        if (solved.Count > 0 && !supported_join(solved, protectedEdges)) return new(); if (solved.Count > 0) { solved["id"] = FormattableString.Invariant($"{first.X}:{first.Y}>{second.X}:{second.Y}"); if (geological_morphology) solved["cross_section_style"] = Get(a, "cross_section_style", 0); } return solved;
    }
}

