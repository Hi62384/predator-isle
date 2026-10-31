using Godot;
using System;
using System.Linq;
using PredatorIsle.Terrain;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Caves;

/// <summary>Worker-owned cave orchestration. Produces numeric payloads without scene or physics mutation.</summary>
public partial class CaveWorkload : RefCounted
{
    private static readonly double[] EntranceFractions={0.0,.5,1.0};
    private readonly CaveSeepageBasins Basins = new();
    private readonly CaveBiomeFeatures Features = new();
    private readonly CaveBiomeRegions Regions = new();
    private readonly CaveSurfaceBiomes SurfaceBiomes = new();
    private readonly CaveStreamFrontiers Frontiers = new();
    private readonly CaveSurfaceCut SurfaceCut = new();
    private readonly TerrainCollision Collision = new();
    public GodotObject builder { get; set; } = null!;
    public CaveNetwork network { get; set; } = null!;
    // The generic boundary also permits comparison against the original field implementation.
    public GodotObject field { get; set; } = null!;
    public Resource configuration { get; set; } = null!;
    public Vector2I bundle_key { get; set; } = new(int.MaxValue, int.MaxValue);
    public A _regions { get; set; } = new();
    public long _seed { get; set; } = 73921;
    public D _water_cache { get; set; } = new();
    public GodotObject _insect_guard { get; set; } = null!;
    public GodotObject _colony { get; set; } = null!;
    public CaveBiomeRegions _biomes { get; set; } = null!;
    public GodotObject? _magma_heat { get; set; }
    public D _last_frontiers { get; set; } = new();
    public A _last_biome_ids { get; set; } = new();
    public bool _last_valid { get; set; } = true;
    private double Number(string name) => configuration.Get(name).AsDouble();
    private bool Enabled(string name) => configuration.Get(name).AsBool();
    private Resource Registry => configuration.Get("biome_regions").As<Resource>();
    private Callable Height => new(builder, builder is TerrainMeshBuilder?"_sample_normal_height":"_get_height");
    private static D Failure(string reason) => new() { ["valid"] = false, ["reason"] = reason };
    private static Variant Get(D d, string name, Variant fallback) => d.ContainsKey(name) ? d[name] : fallback;
    public bool configure(Resource terrain_settings, Resource caves, long seed_value, double water)
    {
        if (caves == null || caves.Call("validation_errors").AsGodotArray().Count > 0) return false;
        _water_cache.Clear(); configuration = caves.DuplicateDeep(Resource.DeepDuplicateMode.All); _seed = seed_value; _regions = new();
        builder = new TerrainMeshBuilder(); builder.Set("settings", terrain_settings.DuplicateDeep(Resource.DeepDuplicateMode.All));
        builder.Set("world_seed", seed_value); builder.Set("water_level", water); builder.Call("_configure_noise");
        network = new CaveNetwork(); network.configure(Height, new Callable(builder, "get_water_surface_height"), seed_value, Number("maximum_depth_metres"));
        network.activity = Number("regional_activity"); network.half_width = Number("main_route_width_metres") * .5; network.headroom = Number("main_route_height_metres");
        network.minimum_roof = Number("minimum_rock_cover_metres"); network.maximum_grade = Number("maximum_route_grade");
        network.chamber_variety = Enabled("chamber_variety"); network.geological_morphology = Enabled("geological_morphology"); network.seepage_density = Number("seepage_density");
        var guard = new CaveInsectEntryGuard(); guard.configure(builder); _insect_guard = guard; network.access_admission = new Callable(guard, "clear_access");
        var colony = new CaveColonyNetwork(); colony.configure(builder, configuration, network); _colony = colony;
        network.region_context = new Callable(_colony, "context"); network.region_decorator = new Callable(_colony, "decorate");
        _biomes = new CaveBiomeRegions(); _biomes.configure(builder, Registry, seed_value); _magma_heat = null;
        foreach (var item in Registry.Get("definitions").AsGodotArray())
        {
            var definition = item.AsGodotObject(); var features = definition.Get("feature_configuration").AsGodotDictionary();
            if (!Registry.Get("enabled").AsBool() || !definition.Get("enabled").AsBool() || definition.Get("biome_id").AsString() != "magma" || definition.Get("spawn_chance_percent").AsDouble() <= 0 || !Get(features, "source_heat", true).AsBool()) continue;
            var heat = new MagmaCaveHeat { geological_intrusions = Get(features, "geological_intrusions", true).AsBool() }; heat.configure(builder); _magma_heat = heat; break;
        }
        _biomes.geometry_provider = Callable.From<D, D>(region => Features.decorate(region, configuration, _seed, Height, _magma_heat));
        network.region_finalizer = new Callable(_biomes, "decorate");
        field = new PortalCaveField { maximum_depth = Number("maximum_depth_metres"), minimum_roof = Number("minimum_rock_cover_metres") };
        bundle_key = new(int.MaxValue, int.MaxValue); return true;
    }
    public D discover(Vector2I cell)
    {
        if (network == null) return new();
        var regions = new A(); var edges = new A(); var entrances = new A(); int halo = Registry.Call("discovery_halo").AsInt32();
        for (int z = cell.Y - halo; z <= cell.Y + halo; z++) for (int x = cell.X - halo; x <= cell.X + halo; x++)
        {
            var data = network.region(new(x,z)); regions.Add(data);
            if (data["valid"].AsBool()) entrances.Add(new D { ["region"] = data["id"], ["point"] = data["nodes"].AsGodotArray()[0].AsGodotDictionary()["point"], ["access"] = data["edges"].AsGodotArray()[0] });
        }
        for (int z = cell.Y - halo; z <= cell.Y + halo; z++) for (int x = cell.X - halo; x <= cell.X + halo; x++)
            foreach (var offset in new[] { Vector2I.Right, Vector2I.Down })
            {
                var other = new Vector2I(x,z) + offset; if (other.X > cell.X + halo || other.Y > cell.Y + halo) continue;
                var edge = network.connection(new(x,z), other); if (edge.Count > 0) edges.Add(edge);
            }
        var bundle = new D { ["cell"] = cell, ["regions"] = regions, ["connections"] = edges, ["entrances"] = entrances };
        if (Registry.Get("enabled").AsBool()) bundle["cave_biome_regions"] = Regions.combine(regions, edges, Registry.Get("fallback_biome_id").AsString());
        if (!use_bundle(bundle)) return new D { ["error"] = "Cave bundle exceeds numeric field bounds" };
        bundle["cells"] = new A(field.Get("chunks").AsGodotDictionary().Keys);
        foreach (var item in entrances) { var entrance = item.AsGodotDictionary(); entrance["columns"] = exposed_columns(entrance); }
        return bundle;
    }
    public bool use_bundle(D bundle)
    {
        if (field == null || !bundle.ContainsKey("cell") || !bundle.ContainsKey("regions") || !bundle.ContainsKey("connections")) return false;
        if (bundle_key == bundle["cell"].AsVector2I()) return true;
        var regions = bundle["regions"].AsGodotArray(); var connections = bundle["connections"].AsGodotArray();
        var assignment = Registry.Get("enabled").AsBool() ? Regions.combine(regions, connections, Registry.Get("fallback_biome_id").AsString()) : new D();
        if (!Get(assignment, "valid", true).AsBool() || !field.Call("compile", regions, Height, connections, assignment).AsBool()) return false;
        _regions = regions; bundle_key = bundle["cell"].AsVector2I(); _water_cache.Clear(); return true;
    }
    public D exposed_columns(D entrance)
    {
        var columns = new D(); var edge = entrance["access"].AsGodotDictionary(); var points = edge["points"].AsVector3Array(); double minimum = double.PositiveInfinity;
        double width = edge["half_width"].AsDouble(), room = edge["headroom"].AsDouble();
        var surface=Height;var sampleHeight=CaveHeightSampler.Bind(surface);bool shortCircuit=CaveHeightSampler.CanShortCircuit(surface);var offsets=new[]{-width,0,width};
        for (int i = 0; i < points.Length - 1; i++)
        {
            var a = points[i]; var b = points[i+1]; bool exposed = false;
            foreach (double fraction in EntranceFractions)
            {
                var p = a.Lerp(b, (float)fraction);
                // Exposure is an OR over height-only probes. Once true, later
                // probes cannot change column ownership or the measured floor.
                foreach (double dx in offsets)
                {
                    foreach(double dz in offsets)if(sampleHeight(p.X+dx,p.Z+dz)<p.Y+room+4){exposed=true;if(shortCircuit)break;}
                    if(shortCircuit&&exposed)break;
                }
                if(shortCircuit&&exposed)break;
            }
            if (!exposed) continue;
            minimum = Math.Min(minimum, Math.Min(a.Y,b.Y));
            int firstX = (int)Math.Floor((Math.Min(a.X,b.X)-width)/64)-1, lastX = (int)Math.Floor((Math.Max(a.X,b.X)+width)/64)+1;
            int firstZ = (int)Math.Floor((Math.Min(a.Z,b.Z)-width)/64)-1, lastZ = (int)Math.Floor((Math.Max(a.Z,b.Z)+width)/64)+1;
            for (int z = firstZ; z <= lastZ; z++) for (int x = firstX; x <= lastX; x++) columns[new Vector2I(x,z)] = true;
        }
        entrance["minimum_exposed_floor"] = minimum; return columns;
    }
    private void ClearSurface()
    { field.Get("surface_columns").AsGodotDictionary().Clear(); field.Get("surface_limits").AsGodotDictionary().Clear(); field.Set("top_height", default(Callable)); }
    public A build(Vector3I key) => build(key, false);
    public A build(Vector3I key, bool capture_frontiers)
    {
        if (field != null) { ClearSurface(); field.Set("include_surface_air", false); field.Set("opening_rock_cover", 6.0); }
        _last_frontiers = new(); _last_biome_ids = new(); _last_valid = true; if (field == null) return new();
        using var mesher = new PortalCaveMesher { capture_boundary_values = capture_frontiers }; var arrays = mesher.build(field,key,2);
        if (capture_frontiers) _last_frontiers = Frontiers.build(field,key,mesher.boundary_values);
        var bound = SurfaceBiomes.bind(decorated(arrays,key),field,key); _last_biome_ids = bound["ids"].AsGodotArray(); _last_valid = bound["valid"].AsBool();
        if (capture_frontiers) foreach (var face in _last_frontiers.Keys.ToArray()) _last_frontiers[face] = SurfaceBiomes.bind(_last_frontiers[face].AsGodotArray(),field,key,_last_biome_ids)["arrays"];
        return bound["arrays"].AsGodotArray();
    }
    public A decorated(A arrays, Vector3I key)
    {
        if (arrays.Count == 0 || Number("formation_density") <= 0) return arrays;
        var regionId = new Vector2I((int)Math.Floor((double)key.X/24),(int)Math.Floor((double)key.Z/24)); long style = 0;
        foreach (var item in _regions) { var region = item.AsGodotDictionary(); if (region["id"].AsVector2I() == regionId) { style = Get(region,"geology",0).AsInt64(); break; } }
        using var formations = new CaveFormations(); var detail = formations.build(field,key,_seed,(int)style,Number("formation_density"));
        return formations.join(arrays,detail["arrays"].AsGodotArray());
    }
    public D water_cell(Vector3I key)
    {
        if (_water_cache.ContainsKey(key)) return _water_cache[key].AsGodotDictionary();
        var result = field != null ? Basins.water_cell(_regions,field,key) : new D { ["arrays"] = new A(), ["ids"] = new A(), ["rejected"] = new A() };
        if (result["arrays"].AsGodotArray().Count > 0) { if (_water_cache.Count >= 8) _water_cache.Remove(_water_cache.Keys.First()); _water_cache[key] = result; }
        return result;
    }
    public D build_cell(Vector3I key)
    {
        var arrays = build(key,Enabled("seal_stream_frontiers")); var result = new D { ["key"] = key, ["arrays"] = arrays, ["water"] = water_cell(key), ["valid"] = _last_valid };
        if (Enabled("seal_stream_frontiers")) result["frontiers"] = _last_frontiers;
        if (_last_biome_ids.Count > 0)
        {
            result["biome_ids"] = _last_biome_ids; var features = Features.build(field,key,_seed,_regions,Registry,result["water"].AsGodotDictionary());
            if (!features["valid"].AsBool()) { result["valid"] = false; result["reason"] = features["reason"]; }
            else if (features["batches"].AsGodotArray().Count > 0) result["features"] = features["batches"];
        }
        return result;
    }
    public D portal(D bundle, D columns, A parents) => portal(bundle,columns,parents,new D(),true);
    public D portal(D bundle, D columns, A parents, D owned_columns) => portal(bundle,columns,parents,owned_columns,true);
    public D portal(D bundle, D columns, A parents, D owned_columns, bool prepare_ground)
    {
        if (!use_bundle(bundle)) return Failure("Invalid portal bundle");
        var extraction = owned_columns.Count == 0 ? columns : owned_columns;
        foreach (var column in extraction.Keys) if (!columns.ContainsKey(column)) return Failure("Owned column outside complete surface mask");
        using var context = new CaveSurfaceContext(); if (!context.configure(parents,Height)) return Failure("Invalid immutable surface snapshot");
        field.Set("top_height",new Callable(context,"height_at")); field.Set("include_surface_air",true); field.Set("opening_rock_cover",0.0);
        // Every exit releases the snapshot callable; build() restores ordinary underground extraction settings.
        try
        {
            if (!field.Call("measure_surface",columns).AsBool()) return Failure("Invalid measured surface bounds");
            var result = new A();
            foreach (var item in extraction.Keys)
            {
                var column = item.AsVector2I(); var limits = field.Get("surface_limits").AsGodotDictionary()[column].AsVector2();
                for (int y = (int)Math.Floor((double)limits.X/64)-1; y <= (int)Math.Floor((double)limits.Y/64); y++)
                {
                    var key = new Vector3I(column.X,y,column.Y); using var mesher = new PortalCaveMesher(); var arrays = decorated(mesher.build(field,key,2),key);
                    var groups = Enabled("indexed_entry_payload") ? context.surfaces_indexed(arrays,(Vector3)key*64) : context.surfaces(arrays,(Vector3)key*64);
                    if (!groups["valid"].AsBool()) return groups;
                    groups["key"] = key; groups["water"] = water_cell(key); var ids = field.Call("biome_ids_for_cell",key).AsGodotArray();
                    if (ids.Count > 4) return Failure("More than four surface biome overlaps at portal");
                    if (ids.Count > 0)
                    {
                        groups["biome_ids"] = ids;
                        foreach (var entry in groups["groups"].AsGodotDictionary().Values) { var group = entry.AsGodotDictionary(); group["arrays"] = SurfaceBiomes.bind(group["arrays"].AsGodotArray(),field,key,ids)["arrays"]; }
                        var features = Features.build(field,key,_seed,_regions,Registry,groups["water"].AsGodotDictionary());
                        if (!features["valid"].AsBool()) return Failure(features["reason"].AsString());
                        if (features["batches"].AsGodotArray().Count > 0) groups["features"] = features["batches"];
                    }
                    if (Enabled("seal_stream_frontiers"))
                    {
                        var frontiers = Frontiers.build(field,key); groups["frontiers"] = frontiers;
                        foreach (var face in frontiers.Keys.ToArray()) frontiers[face] = SurfaceBiomes.bind(frontiers[face].AsGodotArray(),field,key,ids)["arrays"];
                    }
                    result.Add(groups);
                }
            }
            var ground = new D();
            if (prepare_ground) foreach (var item in parents)
            {
                var parent = item.AsGodotDictionary(); var original = parent["ground_faces"].AsVector3Array();
                if (original.Length == 0) original = Collision.surface_faces(parent["arrays"].AsGodotArray(),parent["resolution"].AsInt32());
                var cut = SurfaceCut.ground(original,parent["origin"].AsVector3(),columns); ground[parent["id"]] = cut;
                if (!cut["valid"].AsBool()) return Failure("Original ground subtraction failed");
            }
            return new D { ["valid"] = true, ["cells"] = result, ["ground"] = ground, ["columns"] = columns, ["owned_columns"] = extraction };
        }
        finally { ClearSurface(); }
    }
}
