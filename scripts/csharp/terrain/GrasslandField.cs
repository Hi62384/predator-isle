using Godot;
using System;
using System.Collections.Generic;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

/// <summary>Canonical world-space grassland landforms and hydrology, independent of mesh LOD.</summary>
public partial class GrasslandField : RefCounted
{
    public Resource settings { get; set; } = null!;
    public long world_seed { get; set; }
    public FastNoiseLite region { get; set; } = null!;
    public FastNoiseLite macro { get; set; } = null!;
    public FastNoiseLite forms { get; set; } = null!;
    public FastNoiseLite ridges { get; set; } = null!;
    public FastNoiseLite fractal { get; set; } = null!;
    public FastNoiseLite detail { get; set; } = null!;
    public FastNoiseLite water { get; set; } = null!;
    public bool profile { get; set; }
    public D field_timings { get; set; } = new();
    public D river_cache { get; private set; } = new();
    public D river_columns { get; private set; } = new();
    public D lake_cache { get; private set; } = new();
    public D grid_cache { get; private set; } = new();
    public double river_cache_spacing { get; set; } = double.PositiveInfinity;
    public double river_column_spacing { get; set; } = double.PositiveInfinity;
    public Vector2 last_surface { get; private set; }
    public Vector3 last_geology { get; private set; }
    public double last_precision { get; private set; }
    private readonly TerrainRegions _hash = new();
    private readonly Dictionary<Vector2I, Node> _grid = new();
    private readonly record struct Node(Vector3 Value, Vector2 Surface, double Precision, Vector3 Geology);
    private readonly TerrainParameterSnapshot _parameters = new();
    private double P(string key) => _parameters["grass_" + key];
    private double Random(long x, long z, int biome, int salt) => _hash.random(x, z, biome, salt, world_seed);
    private static double N(FastNoiseLite noise, double x, double z) => noise.GetNoise2D((float)x, (float)z);
    private static double L(double a, double b, double t) => a + (b - a) * t;
    private static double C(double v, double a = 0, double b = 1) => Math.Clamp(v, a, b);
    private static double S(double a, double b, double v) { double t = C((v - a) / (b - a)); return t * t * (3 - 2 * t); }
    private static long Round(double v) => (long)Math.Round(v, MidpointRounding.AwayFromZero);
    private static bool Exact(double x, long lane, double spacing) => x == Math.Floor(x) && Math.Abs(x) < 2000000000 && lane > -2000000000 && lane < 2000000000 && double.IsFinite(spacing);
    public void configure(Resource config, long seed, FastNoiseLite regionNoise, FastNoiseLite macroNoise,
        FastNoiseLite formsNoise, FastNoiseLite ridgesNoise, FastNoiseLite fractalNoise, FastNoiseLite detailNoise, FastNoiseLite waterNoise)
    {
        settings = config; world_seed = seed; region = regionNoise; macro = macroNoise; forms = formsNoise;
        _parameters.Capture(config);
        ridges = ridgesNoise; fractal = fractalNoise; detail = detailNoise; water = waterNoise;
        river_cache.Clear(); river_columns.Clear(); lake_cache.Clear(); grid_cache.Clear(); _grid.Clear();
        river_cache_spacing = double.PositiveInfinity; river_column_spacing = double.PositiveInfinity;
    }
    private ulong Stamp() => profile ? Time.GetTicksUsec() : 0;
    private void Timing(string key, ref ulong stamp)
    {
        if (!profile) return;
        ulong now = Time.GetTicksUsec(); field_timings[key] = (field_timings.TryGetValue(key, out var old) ? old.AsInt64() : 0) + (long)(now - stamp); stamp = now;
    }
    public double river_center(double x, long lane, double spacing)
    {
        bool exact = Exact(x, lane, spacing); var key = Vector2I.Zero;
        if (exact)
        {
            key = new Vector2I((int)x, (int)lane);
            if (spacing != river_cache_spacing) { river_cache.Clear(); river_cache_spacing = spacing; }
            if (river_cache.TryGetValue(key, out var cached)) return cached.AsDouble();
        }
        double seed = Random(lane, 0, 93, 541), broad = N(water, x * .3, lane * 7919.0), bends = N(water, x * 1.15 + 3171, lane * 7919.0 + 137);
        double value = lane * spacing + (seed - .5) * spacing * .3 + broad * spacing * .32 + bends * spacing * .075;
        if (exact) { if (river_cache.Count >= 4096) river_cache.Clear(); river_cache[key] = value; } return value;
    }
    public Godot.Collections.Array<Vector4> lake_sites(Vector2I cell, double pitch)
    {
        if (lake_cache.TryGetValue(cell, out var cached)) return cached.AsGodotArray<Vector4>();
        var sites = new Godot.Collections.Array<Vector4>();
        for (int dz = -1; dz <= 1; dz++) for (int dx = -1; dx <= 1; dx++)
        {
            var site = cell + new Vector2I(dx, dz); double chance = Random(site.X, site.Y, 91, 131);
            if (chance > P("lake_frequency")) continue;
            var center = ((Vector2)site + new Vector2((float)(.2 + Random(site.X, site.Y, 91, 227) * .6), (float)(.2 + Random(site.X, site.Y, 91, 229) * .6))) * (float)pitch;
            if (P("river_frequency") > 0 && chance < P("lake_frequency") * .5)
            {
                double spacing = 4000 / Math.Max(P("river_frequency"), .01), riverZ = river_center(center.X, Round(center.Y / spacing), spacing);
                if (Math.Abs(riverZ - center.Y) < pitch * .3) center.Y = (float)riverZ;
            }
            double radius = P("lake_size") * L(.15, 1, Random(site.X, site.Y, 91, 337));
            sites.Add(new Vector4(center.X, center.Y, (float)radius, (float)(chance * Math.Tau)));
        }
        if (lake_cache.Count >= 256) lake_cache.Clear(); lake_cache[cell] = sites; return sites;
    }
    public Vector3 river_column(double x, long lane, double spacing)
    {
        bool exact = Exact(x, lane, spacing); var key = Vector2I.Zero;
        if (exact)
        {
            key = new Vector2I((int)x, (int)lane);
            if (spacing != river_column_spacing) { river_columns.Clear(); river_column_spacing = spacing; }
            if (river_columns.TryGetValue(key, out var cached)) return cached.AsVector3();
        }
        var result = new Vector3((float)river_center(x, lane, spacing), (float)((river_center(x + 8, lane, spacing) - river_center(x - 8, lane, spacing)) / 16), (float)N(water, x * .6, lane * 711.0));
        if (exact) { if (river_columns.Count >= 2048) river_columns.Clear(); river_columns[key] = result; } return result;
    }
    private Node Grid(Vector2I cell, double step)
    {
        if (grid_cache.Count == 0) _grid.Clear();
        if (grid_cache.TryGetValue(cell, out var payload))
        {
            if (_grid.TryGetValue(cell, out var cached)) return cached;
            var a = payload.AsGodotArray(); return _grid[cell] = new Node(a[0].AsVector3(), a[1].AsVector2(), a[2].AsDouble(), a[3].AsVector3());
        }
        var value = sample_raw(cell.X * step, cell.Y * step); var entry = new Node(value, last_surface, last_precision, last_geology);
        if (grid_cache.Count >= 8192) { grid_cache.Clear(); _grid.Clear(); }
        grid_cache[cell] = new A { value, last_surface, last_precision, last_geology }; _grid[cell] = entry; return entry;
    }
    public A grid_sample(Vector2I cell, double step)
    { var n = Grid(cell, step); return new A { n.Value, n.Surface, n.Precision, n.Geology }; }
    public Vector3 sample(double x, double z)
    {
        double step = Math.Min(P("field_spacing"), Math.Max(1, P("river_width") * .25));
        var p = new Vector2((float)x, (float)z) / (float)step;
        var cell = new Vector2I((int)Math.Floor(p.X), (int)Math.Floor(p.Y)); var f = p - (Vector2)cell;
        var a = Grid(cell, step);
        if (f.X < .000001 && f.Y < .000001) { last_surface = a.Surface; last_geology = a.Geology; return a.Value; }
        var b = f.X == 0 ? a : Grid(cell + new Vector2I(1, 0), step);
        var c = f.Y == 0 ? a : Grid(cell + new Vector2I(0, 1), step);
        var d = f.X == 0 ? c : f.Y == 0 ? b : Grid(cell + new Vector2I(1, 1), step);
        var surface = a.Surface.Lerp(b.Surface, f.X).Lerp(c.Surface.Lerp(d.Surface, f.X), f.Y);
        var value = a.Value.Lerp(b.Value, f.X).Lerp(c.Value.Lerp(d.Value, f.X), f.Y);
        var geology = a.Geology.Lerp(b.Geology, f.X).Lerp(c.Geology.Lerp(d.Geology, f.X), f.Y);
        double precision = L(L(a.Precision, b.Precision, f.X), L(c.Precision, d.Precision, f.X), f.Y);
        if (precision > .001) { value = value.Lerp(sample_raw(x, z), (float)precision); surface = surface.Lerp(last_surface, (float)precision); geology = geology.Lerp(last_geology, (float)precision); }
        last_surface = surface; last_geology = geology; return value;
    }
    public Vector2 geographic_identity(double x, double z)
    {
        double scale = P("landform_size") / Math.Max(P("geographic_scale"), 1000);
        return new Vector2((float)N(region, x * scale + 51371, z * scale - 21319), (float)N(region, x * scale - 19871, z * scale + 89131)) * .5f + Vector2.One * .5f;
    }
    public Vector3 sample_raw(double x, double z)
    {
        ulong timer = Stamp();
        double regionValue = N(region, x, z) * .5 + .5, geologyValue = N(region, x + 17391, z - 9137) * .5 + .5;
        var province = geographic_identity(x, z); double variety = P("geographic_variety");
        double calm = (1 - S(.34, .49, province.X)) * variety, folded = S(.48, .65, province.X) * variety;
        double basinCountry = (1 - S(.40, .56, province.X)) * S(.45, .64, province.Y) * variety;
        double canyonCountry = S(.50, .65, province.X) * (1 - S(.44, .60, province.Y)) * variety;
        double humid = S(.46, .59, province.Y), waterCountry = L(1, humid, variety);
        double plains = P("plains_frequency") > 0 ? 1 - S(P("plains_frequency") - .08, P("plains_frequency") + .14, regionValue) : 0;
        double hills = P("hill_frequency") > 0 ? S(1 - P("hill_frequency") - .2, 1 - P("hill_frequency") + .1, regionValue) * (1 - plains) : 0;
        double mountains = P("mountain_frequency") > 0 ? S(1 - P("mountain_frequency") - .28, 1 - P("mountain_frequency") + .12, regionValue) : 0;
        plains = Math.Max(plains, calm); hills *= 1 - calm;
        mountains = C(mountains * L(1, .3 + folded * 1.4, variety) * (1 - calm));
        mountains = Math.Max(mountains, folded * S(.28, .52, regionValue) * .9);
        double plateauDistance = ((geologyValue * 2 - 1) - (.42 - P("plateau_frequency") * .9)) * P("landform_size") * .6;
        plateauDistance -= (1 - S(.46, .65, province.Y)) * P("landform_size") * .65 * variety;
        double plateau = 0, wallPrecision = 0, talus = 0, incision = 0, cliffControl = 0, crest = 0;
        double macroValue = N(macro, x, z), roll = N(forms, x, z * .7), structure = N(ridges, x * 3.8 + 917, z * 2.1 - 371);
        plateauDistance += structure * 90 + roll * 65;
        bool needsGeology = mountains > .001 || (P("plateau_frequency") > 0 && plateauDistance > -P("talus_width") * 3.6 - 100);
        double lithology = needsGeology ? N(forms, x * .22 + 7103, z * .22 - 2911) : 0;
        double drainageAxis = needsGeology ? N(forms, x * .45 - 3191, z * .45 + 7319) : 0;
        if (P("plateau_frequency") > 0)
        {
            if (Math.Abs(plateauDistance) < Math.Max(P("talus_width"), P("cliff_width") * 3) + 100) plateauDistance += N(forms, x * 1.5, z * 1.5) * 90;
            plateau = S(-P("talus_width"), 0, plateauDistance); mountains *= 1 - plateau;
        }
        hills *= 1 - mountains * .85;
        double divide = 1 - Math.Sqrt(structure * structure + .0064), flatness = plains * C(P("plains_flatness"));
        double relief = 10 + (macroValue * .5 + .5) * P("macro_height") * (1 - flatness * .95);
        relief += roll * P("rolling_strength") * (1 - flatness);
        relief += (roll * roll * 2 + roll) * P("hill_height") * 5 * hills;
        relief += (divide * divide - .55) * P("hill_height") * 3 * hills;
        relief += (roll * 1.6 + (divide - .65) * 2) * plains;
        relief += folded * hills * (divide * divide * divide - .45) * P("hill_height") * 4;
        relief = L(relief, 6 + roll * 3, basinCountry * (1 - mountains) * .8);
        Timing("regional_fields_us", ref timer);
        if (mountains > .001)
        {
            double warp = N(forms, x + 7113, z - 3719) * P("foothill_size") * .12;
            double ridgeNoise = N(ridges, (x + warp) * 1.15, (z + x * .26) * .42);
            double crestWidth = L(.009, .04, S(-.4, .4, structure));
            double ridge = C(1 - (Math.Sqrt(ridgeNoise * ridgeNoise + crestWidth * crestWidth) - crestWidth) / (Math.Sqrt(1 + crestWidth * crestWidth) - crestWidth));
            crest = (1 - S(.04, .22, Math.Abs(ridgeNoise))) * mountains;
            double peakVariation = .74 + lithology * .38 + drainageAxis * .22;
            double backbone = Math.Pow(ridge, L(1.3, 3.4, S(-.10, .14, ridgeNoise))) * peakVariation;
            double mass = L(.3 + roll * .12, backbone, P("ridge_strength"));
            double flank = S(.02, .16, Math.Abs(ridgeNoise)) * (1 - S(.6, .95, Math.Abs(ridgeNoise)));
            double branch = N(forms, x * .55 + warp, z * .45 + ridgeNoise * 400), branchRidge = 1 - Math.Sqrt(branch * branch + .0064);
            double tributary = N(forms, x * 2.1 + branch * 130, z * 1.6 + ridgeNoise * 650);
            double drainage = Math.Pow(1 - branchRidge, 1.3) * flank * .3;
            drainage += Math.Pow(1 - Math.Abs(tributary), 6) * flank * L(.035, .11, S(.18, .4, Math.Abs(ridgeNoise)));
            drainage *= S(-.35, .25, structure) * .85 + .15;
            mass += (branchRidge * branchRidge - .5) * flank * .18 * P("mountain_ruggedness");
            mass -= drainage * P("erosion_strength"); mass *= 1 + ridgeNoise * .22;
            relief += mountains * P("mountain_height") * Math.Max(mass, .015);
        }
        Timing("ridge_valley_us", ref timer);
        double capRelief = macroValue * 28 + roll * 7;
        if (plateau > 0) capRelief += roll * roll * 18 - (1 - S(.02, .16, Math.Abs(drainageAxis))) * 12;
        if (P("plateau_frequency") > 0 && plateauDistance > Math.Max(600, P("talus_width") * 2))
        { relief = P("plateau_height") * (1 + lithology * .42) + capRelief; plateau = 1; }
        else if (P("plateau_frequency") > 0 && plateauDistance > -P("talus_width") * 3.6)
        {
            double competence = S(-.28, .25, lithology + structure * .22), apronWidth = P("talus_width") * L(.7, 1.8, C(lithology + .5));
            double width = Math.Max(L(apronWidth * 1.8, P("cliff_width") * L(2.5, 1, P("escarpment_strength")), competence), 96);
            wallPrecision = 1 - S(width + 16, width + 80, Math.Abs(plateauDistance));
            double wall = S(-width * .5, width * .5, plateauDistance), ledgeHeight = C(.5 + structure * .6, .28, .72);
            double ledged = S(-width * .95, -width * .30, plateauDistance) * ledgeHeight + S(width * .08, width * .65, plateauDistance) * (1 - ledgeHeight);
            wall = L(wall, ledged, competence * S(-.1, .3, drainageAxis) * .8);
            double apron = S(-apronWidth, width * .2, plateauDistance), shelf = apron * .32 + wall * .68;
            double top = P("plateau_height") * (1 + lithology * .42) + capRelief, foot = relief;
            relief = L(relief, top, shelf);
            double fanWidth = L(.032, .13, 1 - S(-apronWidth, 0, plateauDistance));
            double corridor = (1 - S(fanWidth, fanWidth + .055, Math.Abs(drainageAxis))) * S(-.18, .18, lithology);
            incision = corridor * (1 - S(30, 600, Math.Max(plateauDistance, 0)));
            incision *= S(-apronWidth * 2, -apronWidth * .65, plateauDistance) * P("plateau_erosion");
            double channelFloor = L(Math.Max(foot * .2, 5), top - 12, S(-apronWidth, 550, plateauDistance));
            relief = L(relief, Math.Min(relief, channelFloor), incision);
            talus = apron * (1 - wall) * competence * C((top - foot) / 180);
            talus *= C(.65 + structure * .7 + corridor * .6); talus = Math.Max(talus, corridor * apron * (1 - wall) * .8);
            relief += talus * P("talus_relief") * (1 - incision * .7);
            cliffControl = 4 * wall * (1 - wall) * competence * (1 - incision); plateau = shelf;
        }
        Timing("plateau_cliff_talus_us", ref timer);
        double local = N(detail, x, z);
        relief += local * P("local_detail") * (1 - flatness * .98) * (1 - plateau * .8) * (1 - crest * .9);
        if (P("fractal_strength") > 0)
        {
            double detailMask = (1 - flatness * .99) * (1 - plateau * .85) * (1 - crest * .92), ruggedness = (.55 + hills * .65) * (1 - mountains * .55);
            relief += N(fractal, x, z) * P("fractal_strength") * detailMask * ruggedness;
        }
        Timing("fractal_detail_us", ref timer);
        double wet = 0, drainageInfluence = incision * .65, bed = -P("river_depth");
        if (P("river_frequency") > 0 && waterCountry > .001)
        {
            double spacing = 4000 / Math.Max(P("river_frequency"), .01); long lane = Round(z / spacing), nearestLane = lane;
            double across = double.PositiveInfinity; var column = Vector3.Zero;
            for (int offset = -1; offset <= 1; offset++)
            {
                var candidate = river_column(x, lane + offset, spacing); double delta = z - candidate.X;
                if (Math.Abs(delta) < Math.Abs(across)) { across = delta; nearestLane = lane + offset; column = candidate; }
            }
            double riverSlope = column.Y, distance = Math.Abs(across) / Math.Sqrt(1 + riverSlope * riverSlope), bankNoise = N(water, x * 2, z * 2);
            double width = Math.Max(P("river_width"), 1) * (1 + bankNoise * .55 + column.Z * .35), valleyDistance = Math.Abs(across);
            width *= L(1, 1.7, basinCountry) * L(1, .65, canyonCountry);
            double valley = 1 - S(width * 2, width * 2 + P("foothill_size") * L(.65, .12, canyonCountry), valleyDistance);
            double lowlandWater = Math.Max(1 - S(.05, .4, Math.Max(mountains, plateau * .7)), canyonCountry * (1 - plateau)) * waterCountry;
            drainageInfluence = Math.Max(drainageInfluence, valley * lowlandWater);
            double valleyFloor = L(relief - Math.Min(35, relief * .1), 4 + roll * 2, lowlandWater);
            relief = L(relief, valleyFloor, valley * P("valley_strength"));
            double floodplain = (1 - S(width * 2.2, width * L(5, 9, C(roll + .5)), valleyDistance)) * lowlandWater;
            double terrace = S(width * 1.6, width * 3, valleyDistance);
            relief = L(relief, 3 + terrace * (2 + bankNoise) + roll, floodplain * P("valley_strength"));
            if (floodplain > 0) relief -= (1 - S(width * .2, width * .8, Math.Abs(valleyDistance - width * (3.2 + column.Z)))) * floodplain * .75;
            wet = (1 - S(width * .35, width * 1.7, distance)) * lowlandWater;
            bed *= .65 + .35 * (1 - C(distance / width));
            if (lowlandWater > 0)
            {
                double segmentSize = spacing * .6; long segment = (long)Math.Floor(x / segmentSize);
                for (int k = -1; k <= 1; k++)
                {
                    long branch = segment + k; double random = Random(branch, nearestLane, 97, 617); if (random > .7) continue;
                    double start = (branch + .1 + random * .3) * segmentSize, t = (x - start) / (segmentSize * L(.5, .9, random));
                    if (t < 0 || t > 1) continue;
                    double side = Random(branch, nearestLane, 97, 619) < .5 ? -1 : 1, offset = side * spacing * .24 * t * t;
                    offset += N(water, x * 1.8, branch * 931.0) * spacing * .045 * t * t;
                    double branchSlope = riverSlope + side * spacing * .48 * t / (segmentSize * L(.5, .9, random));
                    double tributary = Math.Abs(across - offset) / Math.Sqrt(1 + branchSlope * branchSlope), reach = 1 - S(.65, 1, t);
                    double streamWidth = width * L(.65, .18, t), stream = (1 - S(streamWidth * .4, streamWidth * 1.7, tributary)) * reach;
                    double streamValley = (1 - S(streamWidth, streamWidth + 80, Math.Abs(across - offset))) * reach;
                    relief = L(relief, 5, streamValley * P("valley_strength") * lowlandWater);
                    wet = Math.Max(wet, stream * lowlandWater); drainageInfluence = Math.Max(drainageInfluence, streamValley * lowlandWater);
                }
            }
        }
        if (P("lake_frequency") > 0 && mountains < .4 && plateau < .4 && basinCountry > .05)
        {
            double lakePitch = Math.Max(P("lake_size") * 5, 1200); var cell = new Vector2I((int)Math.Floor(x / lakePitch), (int)Math.Floor(z / lakePitch));
            foreach (var descriptor in lake_sites(cell, lakePitch))
            {
                var center = new Vector2(descriptor.X, descriptor.Y); double radius = descriptor.Z; var p = new Vector2((float)x, (float)z) - center;
                if (p.LengthSquared() > radius * radius * 9) continue;
                float sine = (float)Math.Sin(descriptor.W), cosine = (float)Math.Cos(descriptor.W);
                p = new Vector2(p.X * cosine - p.Y * sine, p.X * sine + p.Y * cosine); p /= (float)Math.Max(radius, 1);
                p += new Vector2((float)N(water, x * 2, z * 2), (float)N(water, x * 2 + 3187, z * 2 - 971)) * .3f;
                double main = new Vector2((float)(p.X / .85), (float)(p.Y / .65)).Length();
                double lobe = (p - new Vector2(.48f, .25f)).Length() / .6;
                double arm = new Vector2((float)((p.X + .55) / .65), (float)((p.Y - .25) / .28)).Length();
                double contour = Math.Min(main, Math.Min(lobe, arm)), lowland = (1 - S(.1, .4, Math.Max(mountains, plateau))) * L(1, basinCountry, variety);
                double basinExtent = 1.6 + C(p.X * .2 + roll * .25, -.25, .45), basin = (1 - S(.7, basinExtent, contour)) * lowland;
                drainageInfluence = Math.Max(drainageInfluence, basin);
                relief = L(relief, 2 + S(1, basinExtent, contour) * (4 + roll * 2), basin);
                double lake = (1 - S(.65, 1.12, contour)) * lowland, lakeBed = -P("lake_depth") * (.3 + .7 * (1 - C(contour))) + local * .3;
                bed = L(bed, lakeBed, lake); wet = Math.Max(wet, lake);
            }
        }
        last_surface = new Vector2((float)Math.Max(mountains, plateau), (float)Math.Max(drainageInfluence, wet));
        Timing("water_and_bank_us", ref timer);
        last_geology = new Vector3((float)talus, (float)incision, (float)cliffControl);
        last_precision = Math.Max(wallPrecision, Math.Max(S(0, .03, wet * (1 - wet)), crest));
        return new Vector3((float)relief, (float)wet, (float)bed);
    }
}
