using Godot;
using System;
using System.Linq;
using PredatorIsle.Biomes;
using PredatorIsle.Caves;
using PredatorIsle.Rendering;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

namespace PredatorIsle.Terrain;

[GlobalClass]
public partial class ChunkTerrain : Node3D
{
    public D startup_timings{get;}=new();
    // Deterministic, endless terrain streamed in reusable square chunks.
    // Climate noise creates broad believable biome regions, while separate masks
    // keep dramatic biomes smaller and rarer.
    [ExportCategory("Terrain Preset")]
    // Expand to tune biome regions, individual landforms, materials and water. Restart to apply.
    [Export]
    public Resource settings { get; set; } = GD.Load<Resource>("res://config/world/terrain_settings.tres");
    // Explicit test override; saved biome settings remain untouched.
    [Export]
    public bool grass_preview { get; set; } = false;
    [Export(PropertyHint.Enum,"Disabled,quarry,wise_mountains,volcanic,spore_forest,radiation_wasteland,crystal_wastes,insect_colony,alien_infected")]
    public string extension_preview { get; set; } = "Disabled";
    [Export]
    public Vector2 extension_preview_position { get; set; } = Vector2.Inf;
    public Godot.Collections.Array<ShaderMaterial> _extension_materials { get; set; } = new();
    public Godot.Collections.Array<ShaderMaterial> _feature_materials { get; set; } = new();
    public D _extension_mesh_tiles { get; set; } = new();
    [Export]
    public bool badlands_preview { get; set; } = false;
    [Export]
    public string badlands_preview_feature { get; set; } = "";
    [Export]
    public bool start_in_badlands { get; set; } = false;
    public bool _badlands_feature_active { get; set; } = false;
    public Vector2 _badlands_feature_position { get; set; } = Vector2.Zero;
    public D _badlands_mesh_tiles { get; set; } = new();
    [Export]
    public bool jungle_preview { get; set; } = false;
    [Export]
    public bool forest_preview { get; set; } = false;
    [Export]
    public bool coast_preview { get; set; } = false;
    [Export]
    public bool beach_preview { get; set; } = false;
    [Export]
    public bool tropical_preview { get; set; } = false;
    [Export]
    public string tropical_preview_feature { get; set; } = "";
    [Export]
    public bool start_in_tropical { get; set; } = false;
    public bool _tropical_feature_active { get; set; } = false;
    public Vector2 _tropical_feature_position { get; set; } = Vector2.Zero;
    public D _tropical_mesh_tiles { get; set; } = new();
    [Export]
    public bool start_in_beach { get; set; } = true;
    [Export(PropertyHint.Enum,"Disabled,wide_beach,narrow_beach,dune_field,high_foredunes,backdunes,parabolic_dunes,sandy_cove,barrier_beach,sand_spit,lagoon,tidal_flat,sandy_estuary,low_sandy_island,storm_scarps,mixed_rock_sand,sandbars,grass_beach_transition,forest_beach_transition,jungle_beach_transition,savanna_beach_transition,swamp_beach_transition,mountain_beach_transition")]
    public string beach_preview_feature { get; set; } = "Disabled";
    [Export]
    public bool start_in_coast { get; set; } = true;
    [Export(PropertyHint.Enum,"Disabled,boulder_shingle,broad_platform,coastal_plateau,coastal_ravines,connected_pools,dark_rocky_coast,fjord_inlets,forest_coast_transition,granite_highlands,grass_coast_transition,headlands,isolated_stack,jungle_coast_transition,low_islands,mountain_coast_transition,offshore_group,river_mouth,rocky_estuary,rocky_islets,rugged_shore,savanna_coast_transition,sea_stacks,sedimentary_cliffs,sheltered_coves,sheltered_inlets,submerged_platform,swamp_coast_transition,tide_pools,towering_cliffs,underwater_cliff,wave_battered,wave_cut_platforms")]
    public string coast_preview_feature { get; set; } = "Disabled";
    public bool _coast_feature_active { get; set; } = false;
    public Vector2 _coast_feature_position { get; set; } = Vector2.Zero;
    public Vector2 _coast_outward { get; set; } = Vector2.Right;
    public D _coast_mesh_tiles { get; set; } = new();
    [Export]
    public bool mountain_preview { get; set; } = false;
    [Export]
    public bool start_in_mountain { get; set; } = true;
    [Export(PropertyHint.Enum,"Disabled,jagged_alpine,massive_ranges,rocky_mountains,ancient_highlands,glacial_country,granite_massifs,stratified_mountains,foothills,alpine_plateaus,basin_country,deep_valleys,escarpments,dry_mountains,scree_highlands,arete_country,meadow_valleys,ridge_system,secondary_ridge,high_pass,v_valley,u_valley,cirque,hanging_valley,tarn,valley_lake,mountain_river,cliff_face,alluvial_fan,grass_mountain_transition,forest_mountain_transition,jungle_mountain_transition,savanna_mountain_transition,swamp_mountain_transition")]
    public string mountain_preview_feature { get; set; } = "Disabled";
    public bool _mountain_feature_active { get; set; } = false;
    public Vector2 _mountain_feature_position { get; set; } = Vector2.Zero;
    public D _mountain_mesh_tiles { get; set; } = new();
    [Export]
    public bool swamp_preview { get; set; } = false;
    [Export]
    public bool start_in_swamp { get; set; } = true;
    [Export(PropertyHint.Enum,"Disabled,backswamp_basin,bayou,blackwater,coastal_wetland,deep_backwater,drained_upland,flooded_lowland,forest_swamp_transition,grass_swamp_transition,hummock_hollow,irregular_ponds,jungle_swamp_transition,major_channel,muddy_islands,muddy_shore,mudflat,narrow_channels,natural_levee,oxbow,peatland,river_floodplain,rocky_wetland,savanna_swamp_transition,seasonal_basin,sediment_bank,shallow_water,swamp_lake")]
    public string swamp_preview_feature { get; set; } = "Disabled";
    public bool _swamp_feature_active { get; set; } = false;
    public Vector2 _swamp_feature_position { get; set; } = Vector2.Zero;
    public ShaderMaterial _swamp_water_material { get; set; } = null!;
    public D _swamp_mesh_tiles { get; set; } = new();
    [Export]
    public bool savanna_preview { get; set; } = false;
    [Export]
    public bool start_in_savanna { get; set; } = true;
    [Export(PropertyHint.Enum,"Disabled,golden_plains,rolling,dry_rocky,lush,rugged_hills,kopje_country,highlands,dry_valley,floodplain,semi_arid,laterite,escarpment,basin_country,isolated_kopje,dry_riverbed,perennial_river,seasonal_lake,cracked_basin,worn_trail,rocky_soil_transition,grass_savanna_transition,forest_savanna_transition,jungle_savanna_transition")]
    public string savanna_preview_feature { get; set; } = "Disabled";
    public bool _savanna_feature_active { get; set; } = false;
    public Vector2 _savanna_feature_position { get; set; } = Vector2.Zero;
    // Discover real Forest in the mixed world; does not force coverage.
    [Export]
    public bool start_in_forest { get; set; } = true;
    [Export(PropertyHint.Enum,"Disabled,deciduous,conifer,mixed,old_growth,rolling_hills,rocky_woodland,mountain_forest,sheltered_valley,riparian,open_meadow,forest_river,forest_stream,forest_lake,forest_ravine,mossy_rock,forest_trail,grass_forest_transition,forest_jungle_transition")]
    public string forest_preview_feature { get; set; } = "Disabled";
    public bool _forest_feature_active { get; set; } = false;
    public Vector2 _forest_feature_position { get; set; } = Vector2.Zero;
    // Start the normal mixed world over actual Jungle land, without overriding biome weights.
    [Export]
    public bool start_in_jungle { get; set; } = true;
    // Runtime-only preset; use -- jungle-preview jungle-feature=river_rainforest.
    [Export(PropertyHint.Enum,"Disabled,lowland_rainforest,rolling_jungle,rugged_hills,foothills,jungle_mountains,river_rainforest,floodplain,rocky_jungle,karst,jungle_plateau,jungle_gorge,humid_basin,upland_rainforest,jungle_river,jungle_lake,grass_jungle_transition")]
    public string jungle_preview_feature { get; set; } = "Disabled";
    public Vector2 _jungle_feature_position { get; set; } = Vector2.Zero;
    public bool _jungle_feature_active { get; set; } = false;
    [ExportCategory("Cliff Normal Controls")]
    // Edit cliff_normals.tres. Saved changes reload automatically while running.
    [Export]
    public Resource? cliff_normal_settings { get; set; } = GD.Load<CliffNormalSettings>("res://config/rendering/cliff_normals.tres");
    [Export]
    public bool auto_reload_cliff_settings { get; set; } = true;
    public double _cliff_poll_time { get; set; } = 0.0;
    public long _cliff_file_time { get; set; } = 0;
    public D _cliff_uniform_cache { get; set; } = new();
    public A _cliff_texture_cache { get; set; } = new();
    public Texture2DArray? _cliff_array { get; set; } = null;
    [ExportCategory("Ground Material Controls")]
    [Export]
    public Resource? ground_material_settings { get; set; } = GD.Load<GroundMaterialSettings>("res://config/rendering/ground_materials.tres");
    [Export]
    public bool auto_reload_ground_settings { get; set; } = true;
    public long _ground_file_time { get; set; } = 0;
    public D _ground_uniform_cache { get; set; } = new();
    public int terrain_debug_view { get; set; } = 0;
    // Disable for the exact all-owner rendering reference. No terrain fields change.
    [Export]
    public bool specialize_terrain_shader { get; set; } = true;
    [ExportCategory("World")]
    [Export]
    public long world_seed { get; set; } = 73921;
    [Export(PropertyHint.Range,"-20.0,20.0,0.25")]
    public double water_level { get; set; } = 0.0;
    [ExportCategory("Chunk Streaming")]
    [Export(PropertyHint.Range,"16.0,256.0,1.0")]
    public double chunk_size { get; set; } = 256.0;
    [Export(PropertyHint.Range,"8,64,1")]
    public int chunk_resolution { get; set; } = 64;
    [Export(PropertyHint.Range,"1,32,1")]
    public int chunks_created_per_frame { get; set; } = 16;
    [Export]
    public Node3D? target { get; set; } = null;
    [Export(PropertyHint.Range,"1,6")]
    public int worker_count { get; set; } = 4;
    [Export(PropertyHint.Range,"1,8")]
    public int distant_job_batch { get; set; } = 8;
    [Export(PropertyHint.Range,"0.5,5.0")]
    public double upload_budget_ms { get; set; } = 1.5;
    [Export(PropertyHint.Range,"0,128")]
    public int cached_mesh_limit { get; set; } = 64;
    [ExportCategory("Detail Levels")]
    // Camera and adjacent leaves use 2 m vertices at the default 256 m base size.
    [Export(PropertyHint.Range,"64,128,16")]
    public int close_resolution { get; set; } = 128;
    [Export(PropertyHint.Range,"0,2")]
    public int close_detail_radius { get; set; } = 1;
    // Avoid a 2 m to 16 m/64 m jump immediately outside the closest leaves.
    [Export(PropertyHint.Range,"32,128,16")]
    public int nearby_parent_resolution { get; set; } = 64;
    // Grid resolution for large distant parent chunks.
    [Export(PropertyHint.Range,"4,64")]
    public int middle_resolution { get; set; } = 16;
    [Export]
    public bool terrain_shadows { get; set; } = true;
    // Close terrain and major structures only. Uses the transactional visible cut.
    [Export]
    public bool terrain_collision_enabled { get; set; } = true;
    [Export]
    public bool spatial_structure_collision { get; set; } = true;
    public Vector3 _last_structure_collision_cell { get; set; } = Vector3.Inf;
    [ExportCategory("Underground Caves")]
    // Shared foundation is disabled until live portal/collision acceptance passes.
    [Export]
    public Resource cave_settings { get; set; } = GD.Load<Resource>("res://config/caves/cave_settings.tres");
    public CaveStreamer? _cave_streamer { get; set; } = null;
    public Resource _settings_snapshot { get; set; } = null!;
    public TerrainMeshBuilder _sampler { get; set; } = null!;
    public D _jobs { get; set; } = new();
    public D _inflight { get; set; } = new();
    public A _ready_chunks { get; set; } = new();
    public D _wanted { get; set; } = new();
    public D _mesh_cache { get; set; } = new();
    public D _active_chunks { get; set; } = new();
    public Godot.Collections.Array<MeshInstance3D> _chunk_pool { get; set; } = new();
    public Godot.Collections.Array<Vector3I> _pending_chunks { get; set; } = new();
    public TerrainPartition _partition { get; set; } = new();
    public TerrainReadyCut _ready_cut { get; set; } = new();
    public TerrainCollision _collision { get; set; } = new();
    public D _staged { get; set; } = new();
    public Vector2 _last_plan_position { get; set; } = new Vector2(float.PositiveInfinity,float.PositiveInfinity);
    public long _last_plan_usec { get; set; } = 0;
    [Export(PropertyHint.Range,"3,7")]
    public int maximum_lod { get; set; } = 6;
    [Export(PropertyHint.Range,"0.5,3.0")]
    public double split_distance_ratio { get; set; } = 0.95;
    [Export(PropertyHint.Range,"0.1,1.0")]
    public double merge_hysteresis { get; set; } = 0.35;
    public int partition_revision { get; set; } = 0;
    public int committed_revision { get; set; } = 0;
    public bool _startup_coverage_complete { get; set; } = false;
    public int incremental_cut_swaps { get; set; } = 0;
    public long _last_incremental_frame { get; set; } = -1;
    public long _last_incremental_attempt_frame { get; set; } = -1;
    public int _staging_revision { get; set; } = 0;
    public Vector3I _ready_cut_cache_key { get; set; } = new Vector3I(-1,-1,-1);
    public D _ready_cut_cache { get; set; } = new();
    public D _ready_cut_diagnostics { get; set; } = new();
    public D _ready_edge_certificates { get; set; } = new();
    public bool _teleport_pending { get; set; } = false;
    public Vector3 _teleport_destination { get; set; } = Vector3.Zero;
    public Vector2I _target_chunk { get; set; } = new Vector2I(2147483647, 2147483647);
    public ShaderMaterial _terrain_material { get; set; } = null!;
    public D _lod_materials { get; set; } = new();
    public int _last_material_debug { get; set; } = -1;
    public MeshInstance3D? _water { get; set; } = null;
    public bool profile_streaming { get; set; } = false;
    public Godot.Collections.Array<D> streaming_records { get; set; } = new();
    public D _queued_at { get; set; } = new();
    public Godot.Collections.Array<TerrainMeshBuilder> _idle_builders { get; set; } = new();
    public D _jungle_mesh_tiles { get; set; } = new();
    public D _forest_mesh_tiles { get; set; } = new();
    public D _savanna_mesh_tiles { get; set; } = new();
    public double max_plan_ms { get; set; } = 0.0;
    public double max_partition_swap_ms { get; set; } = 0.0;
    private static readonly TropicalRiverDetail TropicalRiverDetail = new();
    private static readonly BiomeStructureGeometry StructureGeometry = new();
    private static readonly JunglePlacement JunglePlacement = new();
    private static readonly AlienTissueCoordinates AlienTissueCoordinates = new();
    private static readonly string[] BiomeNames = {"Grass","Forest","Savanna","Swamp","Jungle","Mountain Range","Tropical","Badlands","Quarry","Wise Chinese Mountains","Volcanic","Spore Forest","Radiation Wasteland","Crystal Wastes","Insect Colony","Alien-Infected"};
    private static double Number(GodotObject o, string key) => o.Get(key).AsDouble();
    private double P(string key) => Number(_settings_snapshot,key);
    private bool B(string key) => _settings_snapshot.Get(key).AsBool();
    private Resource R(string key) => _settings_snapshot.Get(key).AsGodotObject() as Resource ?? key switch
    {
        "forest"=>new ForestSettings(),"jungle"=>new JungleSettings(),"savanna"=>new SavannaSettings(),"swamp"=>new SwampSettings(),"mountain"=>new MountainSettings(),
        _=>throw new InvalidOperationException("Missing terrain settings resource: "+key)
    };
    private static bool Valid(GodotObject? o) => o is not null && GodotObject.IsInstanceValid(o);
    private static A Values(D d) => new(d.Values);
    private static A Keys(D d) => new(d.Keys);
    private static T Obj<T>(Variant v) where T:GodotObject => (T)v.AsGodotObject();
    private static Variant Get(D d,string key,Variant fallback) => d.TryGetValue(key,out var v)?v:fallback;
    public override void _Ready()
    {
        ulong stage=Time.GetTicksUsec();void Mark(string name){ulong now=Time.GetTicksUsec();startup_timings[name]=(now-stage)/1000.0;stage=now;}
        InitializeRings();ConfigurePreviews();_configure_noise();Mark("configuration_ms");SetupMaterials();Mark("materials_ms");_refresh_cliff_settings(true);_refresh_ground_settings(true);_create_water();Mark("surface_resources_ms");
        target ??= GetViewport().GetCamera3D();
        if (target is Camera3D)
        {
            double floor = get_height_at(target.GlobalPosition); if (B("water_enabled")) floor = Math.Max(floor, water_level);
            var p = target.GlobalPosition; p.Y = (float)Math.Max(p.Y, floor + 40); target.GlobalPosition = p;
        }
        if(!authority_only)PositionInitialTarget();
        Mark("initial_position_ms");
        if (cave_settings is not null && cave_settings.Get("enabled").AsBool())
        {
            var errors = cave_settings.Call("validation_errors").AsGodotArray();
            if (errors.Count == 0) { _cave_streamer = new CaveStreamer { Name = "CaveStreaming" }; AddChild(_cave_streamer); _cave_streamer.initialize(this); }
            else GD.PushWarning("Cave foundation disabled: " + errors);
        }
        _refresh_visible_chunks();
        Mark("cave_setup_and_plan_ms");
        if (OS.GetCmdlineUserArgs().Contains("smoke-test"))
        { var smoke = new RuntimeSmoke(); Callable.From(() => AddChild(smoke)).CallDeferred(); }
    }
    public override void _Process(double delta)
    {
        _cliff_poll_time += delta;
        if (_cliff_poll_time >= .5)
        {
            _cliff_poll_time = 0;
            if (auto_reload_cliff_settings && cliff_normal_settings is not null && cliff_normal_settings.ResourcePath.Length > 0)
            {
                string path = cliff_normal_settings.ResourcePath; long modified = (long)FileAccess.GetModifiedTime(path);
                if (modified != _cliff_file_time) { var updated=ResourceLoader.Load(path, "", ResourceLoader.CacheMode.Replace);if (updated is CliffNormalSettings || (updated is not null&&updated.HasMethod("uniforms")&&updated.HasMethod("texture_signature")&&updated.HasMethod("build_texture_array"))) cliff_normal_settings = updated; _cliff_file_time = modified; }
            }
            _refresh_cliff_settings(); _refresh_ground_settings();
        }
        int mode = _terrain_material.GetShaderParameter("debug_view").AsInt32();
        if (mode != _last_material_debug)
        { foreach (var m in _material_variants()) Obj<ShaderMaterial>(m).SetShaderParameter("debug_view", mode); foreach (var m in _structure_material_variants()) Obj<ShaderMaterial>(m).SetShaderParameter("debug_view", mode); _last_material_debug = mode; }
        if(authority_only){foreach(var id in authorityActors.Where(pair=>!Valid(pair.Value)||!pair.Value.IsInsideTree()||!pair.Value.GlobalPosition.IsFinite()).Select(pair=>pair.Key).ToArray())unregister_collision_actor(id);if(authorityActors.Count==0)return;}
        if (!Valid(target)) { target = GetViewport().GetCamera3D(); if (target is null) return; }
        var point = target!.GlobalPosition;if(nested_rings){TickRings(delta,point);return;} var next = world_to_chunk(point); var cell = (point / 256f).Floor();
        if (cell != _last_structure_collision_cell) { _last_structure_collision_cell = cell; foreach (var node in _active_chunks.Values) _update_near_collision(Obj<MeshInstance3D>(node), false, true); }
        double moved = new Vector2(target.Position.X, target.Position.Z).DistanceTo(_last_plan_position);
        if (!_teleport_pending && (next != _target_chunk || moved > chunk_size * .5) && (committed_revision == partition_revision || moved > chunk_size * (1 << maximum_lod) * .5 || (moved > chunk_size * 2 && (long)Time.GetTicksUsec() - _last_plan_usec > 1000000))) _refresh_visible_chunks();
        _collect_jobs();
        _cave_streamer?.tick(_teleport_pending ? _teleport_destination : point, point, Math.Max(0, worker_count - _jobs.Count), _pending_chunks.Count > 0);
        _dispatch_jobs();
    }
    public override void _ExitTree()
    {
        ringStream?.Dispose();ringStream=null;
        foreach (var job in _jobs.Values) WorkerThreadPool.WaitForTaskCompletion(job.AsGodotDictionary()["task"].AsInt64());
        _jobs.Clear(); _workerOutcomes.Clear(); foreach(var stream in CaveStreams())stream.shutdown();authorityCaves.Clear();authorityActors.Clear();
    }
    public void _configure_noise()
    {
        if(nested_rings)ringSourceRevision++;
        foreach (var cache in new[] { _badlands_mesh_tiles, _coast_mesh_tiles, _jungle_mesh_tiles, _forest_mesh_tiles, _savanna_mesh_tiles, _swamp_mesh_tiles, _mountain_mesh_tiles, _tropical_mesh_tiles }) cache.Clear();
        _settings_snapshot ??= settings.DuplicateDeep(Resource.DeepDuplicateMode.All);
        _sampler = new TerrainMeshBuilder { settings = _settings_snapshot, water_level = water_level, world_seed = world_seed, chunk_size = chunk_size }; _sampler._configure_noise();
    }
    public Vector2I world_to_chunk(Vector3 p) => new((int)Math.Floor(p.X / chunk_size), (int)Math.Floor(p.Z / chunk_size));
    public int get_loaded_chunk_count() => _active_chunks.Count;
    public Vector2I get_target_chunk() => _target_chunk;
    public Vector4 _biome_weights(double x, double z) => _sampler._biome_weights(x,z);
    public double _get_height(double x, double z) => _sampler._get_height(x,z);
    public double get_height_at(Vector3 p) => _get_height(p.X,p.Z);
    public double get_temperature_at(Vector3 p) => _sampler.get_temperature(p.X,p.Z);
    public string get_climate_description(Vector3 p) => B("temperature_enabled") ? "regional climate (Grass / Forest / Jungle / Savanna / Swamp / Mountains / Tropical)" : "climate OFF";
    public int _get_biome(double x, double z)
    {
        var w = _biome_weights(x,z); int strongest = 0; for(int i=1;i<4;i++) if(w[i]>w[strongest]) strongest=i;
        double best = Math.Max(Math.Max(Math.Max(w[strongest],_sampler._jungle_weight),Math.Max(_sampler._mountain_weight,_sampler._tropical_weight)),_sampler._badlands_weight); int extra=-1;
        for(int i=0;i<8;i++) if(_sampler._extra_weights[i]>best){best=_sampler._extra_weights[i];extra=i;}
        if(extra>=0)return extra+8;
        if(_sampler._badlands_weight>Math.Max(Math.Max(Math.Max(w[strongest],_sampler._jungle_weight),_sampler._mountain_weight),_sampler._tropical_weight))return 7;
        if(_sampler._tropical_weight>Math.Max(Math.Max(w[strongest],_sampler._jungle_weight),_sampler._mountain_weight))return 6;
        if(_sampler._mountain_weight>Math.Max(w[strongest],_sampler._jungle_weight))return 5;
        return _sampler._jungle_weight>w[strongest]?4:strongest;
    }
    public string get_biome_name_at(Vector3 p)
    {
        if(_sampler._coast is not null){_sampler._get_height(p.X,p.Z);var c=_sampler._last_coast;if(c.X>.5)return c.W<0&&(((long)(-(double)c.W-1)&255)/255.0)>.5?"Coastal Dunes / Beaches":"Rocky Coast";}
        return BiomeNames[_get_biome(p.X,p.Z)];
    }
    public void request_teleport(Vector3 destination){if(!destination.IsFinite())return;_teleport_pending=true;_teleport_destination=destination;_refresh_visible_chunks(destination);}
    public string get_partition_debug()
    {
        if(nested_rings)return RingDebug();
        var counts=new int[maximum_lod+1];foreach(var k in _active_chunks.Keys)counts[k.AsVector3I().Z]++;
        var p=target is not null?new Vector2(target.Position.X,target.Position.Z):Vector2.Zero;string detail="awaiting coverage";
        foreach(var item in _active_chunks.Keys){var k=item.AsVector3I();var rect=_partition.bounds(k);if(!rect.HasPoint(p))continue;detail=$"active L{k.Z} ({k.X},{k.Y}) bounds {rect} parent {_partition.parent(k)} children {(k.Z>0?4:0)}";break;}
        return $"LOD counts [{string.Join(", ",counts)}] | staging {_staged.Count} jobs {_jobs.Count} | cut {committed_revision}/{partition_revision}\n{detail}"+(_cave_streamer is null?"":"\n"+_cave_streamer.debug_text())+(last_error.Length==0?"":"\nTerrain worker failed: "+last_error);
    }
}
