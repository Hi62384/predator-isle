using Godot;
using System;
using System.Linq;
using System.Threading;
using PredatorIsle.Caves;
using PredatorIsle.Terrain;

namespace PredatorIsle.Checks;

internal static class TerrainSamplingChecks
{
    internal static void Run(Action<bool, string> require)
    {
        CheckIslandCaches(require);
        CheckGpuHydrology(require);
        using var settings = (TerrainConfiguration)GD.Load<Resource>("res://config/world/terrain_settings.tres")
            .DuplicateDeep(Resource.DeepDuplicateMode.All);
        using var builder = new TerrainMeshBuilder { settings = settings, world_seed = 73921 };
        builder._configure_noise();
        var field = builder._native_height;
        foreach (var point in new[] { Vector2.Zero, new Vector2(-128, 96), new Vector2(17.125f, -42.375f), new Vector2(2048, -4096), new Vector2(-16384, 32768) })
        {
            double ground = builder._get_height(point.X, point.Y);
            double water = field.last_water;
            var retainedExtras = field.last_extras;
            var extrasCopy = retainedExtras.ToArray();
            var retainedMountain = field.last_mountain;
            var mountainCopy = retainedMountain.ToArray();
            byte[] payload = GD.VarToBytes(field.payload(ground));
            long evaluated = field.CanonicalEvaluations;
            require(builder.get_water_surface_height(point.X, point.Y) == water && field.CanonicalEvaluations == evaluated,
                "Paired height/water probe repeated generation or changed its water level");
            require(GD.VarToBytes(field.payload(ground)).SequenceEqual(payload), "Water reuse changed the current material payload");

            double unpublished = builder._get_height(point.X, point.Y, false);
            require(unpublished == ground, "Height-only query changed canonical geometry");
            require(retainedExtras.SequenceEqual(extrasCopy) && retainedMountain.SequenceEqual(mountainCopy),
                "Height-only scratch reset mutated a retained material payload");
            builder.get_water_surface_height(point.X, point.Y);
            require(field.CanonicalEvaluations == evaluated + 2 && field.last_water == water,
                "Unpublished sampling reused incomplete biome water state");

            builder._get_height(point.X + 31.25, point.Y - 17.5);
            evaluated = field.CanonicalEvaluations;
            require(builder.get_water_surface_height(point.X, point.Y) == water && field.CanonicalEvaluations == evaluated + 1,
                "Water query reused another coordinate's material state");
        }

        double cachedGround = field.grid_height(-32, 64);
        byte[] cachedPayload = GD.VarToBytes(field.payload(cachedGround));
        builder._get_height(113.25, -377.5);
        long beforeRestore = field.CanonicalEvaluations;
        require(field.grid_height(-32, 64) == cachedGround && field.CanonicalEvaluations == beforeRestore,
            "Payload cache did not retain the canonical sample");
        require(GD.VarToBytes(field.payload(cachedGround)).SequenceEqual(cachedPayload), "Restored sample lost material controls");
        double cachedWater = field.last_water;
        require(field.water_surface_height(-32, 64) == cachedWater && field.CanonicalEvaluations == beforeRestore,
            "Restored payload was regenerated for its water level");

        var heightCallback = new Callable(builder, "_sample_normal_height");
        var waterCallback = new Callable(builder, "get_water_surface_height");
        long beforePair = field.CanonicalEvaluations;
        require(CaveHeightSampler.TrySamplePair(heightCallback, waterCallback, -719.125, 316.25, out double height, out double level),
            "Native cave probe did not bind the combined terrain sample");
        require(field.CanonicalEvaluations == beforePair + 1 && height == builder._get_height(-719.125, 316.25, false),
            "Combined cave probe changed ground height or traversed geography twice");
        require(level == builder.get_water_surface_height(-719.125, 316.25), "Combined cave probe changed local water");
        using var other = new TerrainMeshBuilder();
        require(!CaveHeightSampler.TrySamplePair(heightCallback, new Callable(other, "get_water_surface_height"), 0, 0, out _, out _),
            "Combined cave probe bypassed an independently supplied water authority");

        builder.water_level += 11;
        beforePair = field.CanonicalEvaluations;
        builder.get_water_surface_height(-719.125, 316.25);
        require(field.CanonicalEvaluations == beforePair + 1, "Water-level change reused stale published state");
        builder._configure_noise();
        beforePair = field.CanonicalEvaluations;
        builder.get_water_surface_height(-719.125, 316.25);
        require(field.CanonicalEvaluations == beforePair + 1, "Worker reconfiguration retained stale water state");
    }

    private static void CheckIslandCaches(Action<bool, string> require)
    {
        using var settings = (TerrainConfiguration)GD.Load<Resource>("res://config/world/terrain_settings.tres")
            .DuplicateDeep(Resource.DeepDuplicateMode.All);
        using var managed = new TerrainMeshBuilder { settings = settings, world_seed = -17 };
        using var legacy = new TerrainMeshBuilder { settings = settings, world_seed = -17 };
        managed._configure_noise();legacy._configure_noise();
        var a = managed._native_islands;
        var b = legacy._native_islands;
        var sites = b.sites_cache;var planes = b.plane_cache;var owners = b.owner_cache;var coasts = b.coast_certificates;
        var random = new Random(73921);
        for (int i = 0; i < 256; i++)
        {
            if (i % 64 == 0)
            {
                a.configure(settings, -17, managed._continent_noise, managed._shoreline_noise);
                sites.Clear();planes.Clear();owners.Clear();coasts.Clear();
            }
            double x = i < 16 ? (i - 8) * 32000.125 : random.NextDouble() * 600000 - 300000;
            double z = i < 16 ? (8 - i) * 16777.75 : random.NextDouble() * 600000 - 300000;
            foreach (bool heightQuery in new[] { false, true })
            {
                double expected = b.mask(x, z, heightQuery, 3500);
                require(a.mask(x, z, heightQuery, 3500) == expected, "Managed island cache changed canonical mask or coast certificates");
            }
            require(sites.Count <= 513 && planes.Count <= 128 && owners.Count <= 512 && coasts.Count <= 512,
                "Legacy island cache mirrors escaped their numeric bounds");
        }
        require(ReferenceEquals(sites, b.sites_cache) && ReferenceEquals(planes, b.plane_cache),
            "Legacy island diagnostic reset handles stopped referring to live caches");
    }

    private static void CheckGpuHydrology(Action<bool, string> require)
    {
        using var settings = new TerrainConfiguration { grass_river_frequency = 2, grass_lake_frequency = 1, grass_lake_size = 240 };
        using var builder = new TerrainMeshBuilder { settings = settings, world_seed = -73921 };
        builder._configure_noise();var field = builder._native_grass;
        var points = new[] { new Vector2(40, 0), new Vector2(40, 100), new Vector2(40, 1000), new Vector2(40, -1000), new Vector2(-40, -1000), new Vector2(40, 1000), new Vector2(40, 1300) };
        var plan = GrasslandGpuHydrology.Capture(field, points);
        require(ReferenceEquals(plan.Rivers[0], plan.Rivers[1]) && ReferenceEquals(plan.Rivers[2], plan.Rivers[5]) && ReferenceEquals(plan.Rivers[2], plan.Rivers[6]),
            "Hydrology repeated a river plan for the same column and lane");
        require(plan.Rivers[2]!.Key.Lane == 1 && plan.Rivers[3]!.Key.Lane == -1,
            "GPU river planning did not use canonical halfway-away-from-zero lanes");
        require(ReferenceEquals(plan.Lakes[0], plan.Lakes[2]) && !ReferenceEquals(plan.Lakes[2], plan.Lakes[6]),
            "Lake planning did not share exactly one descriptor array per site cell");
        for (int i = 0; i < points.Length; i++)
        {
            var river = plan.Rivers[i]!;
            for (int offset = -1; offset <= 1; offset++)
                require(river.Columns[offset + 1] == field.river_column(points[i].X, (long)river.Key.Lane + offset, 2000),
                    "GPU river descriptor changed a canonical published float column");
            var lake = plan.Lakes[i]!;
            var key = new Vector2I((int)Math.Floor(points[i].X / 1200.0), (int)Math.Floor(points[i].Y / 1200.0));
            require(lake.Key == key && lake.Sites.SequenceEqual(field.lake_sites(key, 1200)),
                "GPU lake descriptor changed the canonical site selection or float values");
        }
        var retained = plan.Lakes[0]!.Sites.ToArray();var nativeSites = field.lake_sites(plan.Lakes[0]!.Key, 1200);
        nativeSites[0] = Vector4.Zero;field.lake_cache.Clear();
        require(plan.Lakes[0]!.Sites.SequenceEqual(retained), "Pending GPU hydrology retained a mutable native lake-cache array");

        using var cancellation = new CancellationTokenSource();cancellation.Cancel();bool cancelled = false;
        try { GrasslandGpuHydrology.Capture(field, points, cancellation.Token); }
        catch (OperationCanceledException) { cancelled = true; }
        require(cancelled, "Cancelled GPU hydrology planning still generated descriptors");
        settings.grass_river_frequency = settings.grass_lake_frequency = 0;builder._configure_noise();
        var dry = GrasslandGpuHydrology.Capture(field, points);
        require(dry.Rivers.All(value => value is null) && dry.Lakes.All(value => value is null),
            "Disabled river/lake planning retained an active descriptor group");
    }
}
